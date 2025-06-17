if true then return { _name = "Pursuit", policeTargets = {}, getState = function() return false end } end

---@class BJIManagerPursuit: BJIManager
local M = {
    _name = "Pursuit",

    isPatrol = false,

    ---@type tablelib<integer, integer> index gameVehID, value originPlayerID
    policeTargets = Table(),
    ---@type {originPlayerID: integer, targetGameVehID: integer}?
    fugitivePursuit = nil,
}

---@return boolean
local function getState()
    return (M.isPatrol and M.policeTargets:length() > 0) or M.fugitivePursuit ~= nil
end

---@return BJIColor, BJIColor
local function getFugitiveNametagColors()
    return BJI.Utils.ShapeDrawer.Color(0, 0, 0, 1),
        BJI.Utils.ShapeDrawer.Color(1, 0, 0, .5)
end

local function resetAll()
    M.isPatrol = false
    M.policeTargets:clear()
    M.fugitivePursuit = nil
    BJI.Managers.GPS.removeByKey(BJI.Managers.GPS.KEYS.VEHICLE)
end

---@param ctxt TickContext
---@param veh NGVehicle
local function isVehPolice(ctxt, veh)
    local conf = BJI.Managers.Veh.getFullConfig(ctxt.veh.partConfig) or { parts = {} }
    return Table(conf.parts):any(function(v, k)
        return (tostring(k):lower():find("police") ~= nil and #v > 0) or
            tostring(v):lower():find("police") ~= nil
    end)
end

---@param ctxt TickContext
local function updateIsPatrol(ctxt)
    ctxt = ctxt or BJI.Managers.Tick.getContext()
    if BJI.Managers.Scenario.isServerScenarioInProgress() or
        ctxt.players[ctxt.user.playerID].isGhost then
        M.isPatrol = false
        return
    end

    if not ctxt.isOwner then
        M.isPatrol = false
        return
    end

    M.isPatrol = isVehPolice(ctxt, ctxt.veh)
end

local function gpsToNextTarget()
    if not M.isPatrol then
        return
    end

    if M.policeTargets:length() == 0 then
        BJI.Managers.GPS.removeByKey(BJI.Managers.GPS.KEYS.VEHICLE)
    else
        local closest = M.policeTargets:map(function(_, k)
            return {
                vid = k,
                pos = BJI.Managers.Veh.getPositionRotation(BJI.Managers.Veh.getVehicleObject(k))
            }
        end):values():sort()[1] or {}
        local currTarget = BJI.Managers.GPS.getByKey(BJI.Managers.GPS.KEYS.VEHICLE)
        if not currTarget or currTarget.gameVehID ~= closest.vid then
            BJI.Managers.GPS.prependWaypoint({
                key = BJI.Managers.GPS.KEYS.VEHICLE,
                radius = 0,
                gameVehID = closest.vid,
                clearable = false,
            })
        end
    end
end

---@param ctxt TickContext
---@param targetGameVehID integer
---@return boolean
local function canStartPursuit(ctxt, targetGameVehID)
    if BJI.Managers.AI.isSelfAIVehicle(targetGameVehID) then
        return true -- self AI or me targetting self AI
    end
    if BJI.Managers.AI.isRemoteAIVehicle(targetGameVehID) then
        return false -- self AI or me targetting other player AI
    end

    ctxt = ctxt or BJI.Managers.Tick.getContext()
    if ctxt.isOwner and ctxt.veh:getID() == targetGameVehID then
        return true -- self IA targetting my owned vehicle
    end

    local ownerID = BJI.Managers.Veh.getVehOwnerID(targetGameVehID)
    if ownerID then
        if not M.isPatrol then
            return false -- self is not a police
        end
        if ctxt.players[ownerID].isGhost then
            return false -- target is a permaghost
        end
        local remoteGameVehID = BJI.Managers.Veh.getRemoteVehID(targetGameVehID)
        if ctxt.players[ownerID].currentVehicle ~= remoteGameVehID then
            return false -- target veh is idle
        end
        local veh = BJI.Managers.Veh.getVehicleObject(targetGameVehID)
        if veh and isVehPolice(ctxt, veh) then
            LogWarn("target is a veh police, cancelling")
            return false -- target veh is a police
        end

        return true
    end

    return false
end

---@param ctxt TickContext
---@param targetGameVehID integer
local function localPursuitStart(ctxt, targetGameVehID)
    local allowed = canStartPursuit(ctxt, targetGameVehID)
    if not allowed then
        return gameplay_police.setPursuitMode(0, targetGameVehID)
    end

    if M.isPatrol then
        -- start pursuit
        M.policeTargets[targetGameVehID] = ctxt.user.playerID
        BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_START)
        BJI.Managers.GPS.prependWaypoint({
            key = BJI.Managers.GPS.KEYS.VEHICLE,
            radius = 0,
            gameVehID = targetGameVehID,
            clearable = false,
        })
        local remoteGameVehID = BJI.Managers.Veh.getRemoteVehID(targetGameVehID)
        BJI.Tx.scenario.PursuitData({
            event = "start",
            originPlayerID = ctxt.user.playerID,
            gameVehID = remoteGameVehID or targetGameVehID,
        })
        gpsToNextTarget()
        BJI.Managers.Restrictions.update({
            {
                restrictions = BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                state = BJI.Managers.Restrictions.STATE.RESTRICTED,
            }
        })
        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PURSUIT_UPDATE)
    elseif ctxt.veh and ctxt.veh:getID() == targetGameVehID then
        -- self fugitive
        M.fugitivePursuit = {
            originPlayerID = ctxt.user.playerID,
            targetGameVehID = targetGameVehID,
        }
        BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_START)
        BJI.Tx.scenario.PursuitData({
            event = "start",
            originPlayerID = ctxt.user.playerID,
            gameVehID = targetGameVehID,
        })
        BJI.Managers.Restrictions.update({
            {
                restrictions = Table({
                    BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                    BJI.Managers.Restrictions.RESETS.ALL,
                }):flat(),
                state = BJI.Managers.Restrictions.STATE.RESTRICTED,
            }
        })
        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PURSUIT_UPDATE)
    end
end

---@param ctxt TickContext
---@param targetGameVehID integer
---@param ticket boolean
---@param offenses string[]
local function localPursuitArrest(ctxt, targetGameVehID, ticket, offenses)
    if M.isPatrol and M.policeTargets[targetGameVehID] then
        BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_SUCCESS)
        local remoteGameVehID = BJI.Managers.Veh.getRemoteVehID(targetGameVehID)
        BJI.Tx.scenario.PursuitData({
            event = "arrest",
            originPlayerID = ctxt.user.playerID,
            gameVehID = remoteGameVehID or targetGameVehID,
            ticket = ticket,
            offenses = offenses,
        })
        local targetVeh = BJI.Managers.Veh.getVehicleObject(targetGameVehID)
        BJI.Managers.Veh.getPositionRotation(targetVeh, function(pos)
            if ctxt.vehPosRot.pos:distance(pos) < 10 then
                BJI.Tx.scenario.PursuitReward(true)
            end
        end)
        M.policeTargets[targetGameVehID] = nil
        gpsToNextTarget()
        BJI.Managers.Restrictions.update({
            {
                restrictions = BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                state = BJI.Managers.Restrictions.STATE.ALLOWED,
            }
        })
        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PURSUIT_UPDATE)
    elseif M.fugitivePursuit and ctxt.veh and ctxt.veh:getID() == targetGameVehID then
        BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_FAIL)
        BJI.Tx.scenario.PursuitData({
            event = "arrest",
            originPlayerID = ctxt.user.playerID,
            gameVehID = targetGameVehID,
        })
        M.fugitivePursuit = nil
        BJI.Managers.Restrictions.update({
            {
                restrictions = Table({
                    BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                    BJI.Managers.Restrictions.RESETS.ALL,
                }):flat(),
                state = BJI.Managers.Restrictions.STATE.ALLOWED,
            }
        })
        BJI.Managers.GPS.removeByKey(BJI.Managers.GPS.KEYS.VEHICLE)
        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PURSUIT_UPDATE)
    end
end

---@param ctxt TickContext
---@param targetGameVehID integer
local function localPursuitEvade(ctxt, targetGameVehID)
    local remoteGameVehID = BJI.Managers.Veh.getRemoteVehID(targetGameVehID)
    if M.isPatrol and M.policeTargets[targetGameVehID] then
        BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_FAIL)
        BJI.Tx.scenario.PursuitData({
            event = "evade",
            originPlayerID = ctxt.user.playerID,
            gameVehID = remoteGameVehID or targetGameVehID,
        })
        M.policeTargets[targetGameVehID] = nil
        gpsToNextTarget()
        BJI.Managers.Restrictions.update({
            {
                restrictions = BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                state = BJI.Managers.Restrictions.STATE.ALLOWED,
            }
        })
        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PURSUIT_UPDATE)
    elseif M.fugitivePursuit and ctxt.veh and ctxt.veh:getID() == targetGameVehID then
        BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_SUCCESS)
        BJI.Tx.scenario.PursuitData({
            event = "evade",
            originPlayerID = ctxt.user.playerID,
            gameVehID = targetGameVehID,
        })
        BJI.Tx.scenario.PursuitReward(false)
        M.fugitivePursuit = nil
        BJI.Managers.Restrictions.update({
            {
                restrictions = Table({
                    BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                    BJI.Managers.Restrictions.RESETS.ALL,
                }):flat(),
                state = BJI.Managers.Restrictions.STATE.ALLOWED,
            }
        })
        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PURSUIT_UPDATE)
    end
end

---@param ctxt TickContext
---@param targetGameVehID integer
local function localPursuitReset(ctxt, targetGameVehID)
    local remoteGameVehID = BJI.Managers.Veh.getRemoteVehID(targetGameVehID)
    if M.isPatrol and M.policeTargets[targetGameVehID] then
        BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_FAIL)
        BJI.Tx.scenario.PursuitData({
            event = "reset",
            originPlayerID = ctxt.user.playerID,
            gameVehID = remoteGameVehID or targetGameVehID,
        })
        M.policeTargets[targetGameVehID] = nil
        gpsToNextTarget()
        BJI.Managers.Restrictions.update({
            {
                restrictions = BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                state = BJI.Managers.Restrictions.STATE.ALLOWED,
            }
        })
        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PURSUIT_UPDATE)
    elseif M.fugitivePursuit and ctxt.veh and ctxt.veh:getID() == targetGameVehID then
        BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_FAIL)
        BJI.Tx.scenario.PursuitData({
            event = "reset",
            originPlayerID = ctxt.user.playerID,
            gameVehID = targetGameVehID,
        })
        M.fugitivePursuit = nil
        BJI.Managers.Restrictions.update({
            {
                restrictions = Table({
                    BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                    BJI.Managers.Restrictions.RESETS.ALL,
                }):flat(),
                state = BJI.Managers.Restrictions.STATE.ALLOWED,
            }
        })
        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PURSUIT_UPDATE)
    end
end


local function onPursuitActionUpdate(targetGameVehID, event, pursuitData)
    local ctxt = BJI.Managers.Tick.getContext()

    if event == "start" then
        localPursuitStart(ctxt, targetGameVehID)
    elseif event == "arrest" then
        localPursuitArrest(ctxt, targetGameVehID, pursuitData.mode == 1, pursuitData.offensesList)
    elseif event == "evade" then
        localPursuitEvade(ctxt, targetGameVehID)
    elseif event == "reset" then
        localPursuitReset(ctxt, targetGameVehID)
    end
end

---@param ctxt TickContext
---@param data BJPursuitPayload
---@param targetVeh NGVehicle
local function rxStart(ctxt, data, targetVeh)
    if M.isPatrol then -- patrol
        if targetVeh:getID() == ctxt.veh:getID() then
            -- invalid self target
            BJI.Tx.scenario.PursuitData({
                event = "reset",
                originPlayerID = data.originPlayerID,
                gameVehID = data.gameVehID,
            })
            return
        end
        if extensions.gameplay_traffic.showMessages then
            ui_message(string.var("{1} {2}", {
                translateLanguage('ui.traffic.suspectFlee', 'A suspect is fleeing from you! Vehicle:'),
                BJI.Managers.Veh.getModelLabel(targetVeh.jbeam) or targetVeh.jbeam or "?"
            }), 5, 'traffic', 'traffic')
        end
        BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_START)
        M.policeTargets[targetVeh:getID()] = data.originPlayerID
        gpsToNextTarget()
        BJI.Managers.Restrictions.update({
            {
                restrictions = BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                state = BJI.Managers.Restrictions.STATE.RESTRICTED,
            }
        })
        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PURSUIT_UPDATE)
    elseif ctxt.veh:getID() == targetVeh:getID() then -- fugitive
        if extensions.gameplay_traffic.showMessages then
            ui_message('ui.traffic.policePursuit', 5, 'traffic', 'traffic')
        end
        BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_START)
        M.fugitivePursuit = {
            originPlayerID = data.originPlayerID,
            targetGameVehID = targetVeh:getID(),
        }
        BJI.Managers.Restrictions.update({
            {
                restrictions = Table({
                    BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                    BJI.Managers.Restrictions.RESETS.ALL,
                }):flat(),
                state = BJI.Managers.Restrictions.STATE.RESTRICTED,
            }
        })
        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PURSUIT_UPDATE)
    end
end

---@param ctxt TickContext
---@param data BJPursuitPayload
---@param targetVeh NGVehicle
local function rxArrest(ctxt, data, targetVeh)
    if M.isPatrol and M.policeTargets[targetVeh:getID()] then -- patrol
        if extensions.gameplay_traffic.showMessages then
            ui_message('ui.traffic.suspectArrest', 5, 'traffic', 'traffic')
        end
        BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_SUCCESS)
        BJI.Managers.Veh.getPositionRotation(targetVeh, function(pos)
            if ctxt.vehPosRot.pos:distance(pos) < 10 then
                BJI.Tx.scenario.PursuitReward(true)
            end
        end)
        M.policeTargets[targetVeh:getID()] = nil
        gpsToNextTarget()
        BJI.Managers.Restrictions.update({
            {
                restrictions = BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                state = BJI.Managers.Restrictions.STATE.ALLOWED,
            }
        })
        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PURSUIT_UPDATE)
    elseif M.fugitivePursuit and ctxt.veh:getID() == targetVeh:getID() then -- fugitive
        if extensions.gameplay_traffic.showMessages then
            ui_message(data.ticket and 'ui.traffic.policeTicket' or 'ui.traffic.policeArrest', 5, 'traffic',
                'traffic')
            ui_message(string.var("{1} {2}", {
                translateLanguage('ui.traffic.infractions.title', 'Offenses:'),
                Table(data.offenses):map(function(v)
                    return translateLanguage('ui.traffic.infractions.' .. v, v)
                end):join(", ")
            }), 10, 'trafficInfractions', 'traffic')
        end
        BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_FAIL)
        BJI.Managers.Veh.freeze(true, ctxt.veh:getID())
        BJI.Managers.Async.delayTask(function() -- freeze for 5 seconds
            BJI.Managers.Veh.freeze(false, ctxt.veh:getID())
            ui_message('ui.traffic.driveAway', 5, 'traffic', 'traffic')
        end, 5000)
        M.fugitivePursuit = nil
        BJI.Managers.Restrictions.update({
            {
                restrictions = Table({
                    BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                    BJI.Managers.Restrictions.RESETS.ALL,
                }):flat(),
                state = BJI.Managers.Restrictions.STATE.ALLOWED,
            }
        })
        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PURSUIT_UPDATE)
    end
end

---@param ctxt TickContext
---@param data BJPursuitPayload
---@param targetVeh NGVehicle
local function rxEvade(ctxt, data, targetVeh)
    if M.isPatrol and M.policeTargets[targetVeh:getID()] then -- patrol
        if extensions.gameplay_traffic.showMessages then
            ui_message('ui.traffic.suspectEvade', 5, 'traffic', 'traffic')
        end
        BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_FAIL)
        M.policeTargets[targetVeh:getID()] = nil
        gpsToNextTarget()
        BJI.Managers.Restrictions.update({
            {
                restrictions = BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                state = BJI.Managers.Restrictions.STATE.ALLOWED,
            }
        })
        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PURSUIT_UPDATE)
    elseif M.fugitivePursuit and ctxt.veh:getID() == targetVeh:getID() then -- fugitive
        if extensions.gameplay_traffic.showMessages then
            ui_message('ui.traffic.policeEvade', 5, 'traffic', 'traffic')
        end
        BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_SUCCESS)
        BJI.Tx.scenario.PursuitReward(false)
        M.fugitivePursuit = nil
        BJI.Managers.Restrictions.update({
            {
                restrictions = Table({
                    BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                    BJI.Managers.Restrictions.RESETS.ALL,
                }):flat(),
                state = BJI.Managers.Restrictions.STATE.ALLOWED,
            }
        })
        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PURSUIT_UPDATE)
    end
end

---@param ctxt TickContext
---@param data BJPursuitPayload
---@param targetVeh NGVehicle
local function rxReset(ctxt, data, targetVeh)
    if M.isPatrol and M.policeTargets[targetVeh:getID()] then -- patrol
        BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_FAIL)
        M.policeTargets[targetVeh:getID()] = nil
        gpsToNextTarget()
        BJI.Managers.Restrictions.update({
            {
                restrictions = BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                state = BJI.Managers.Restrictions.STATE.ALLOWED,
            }
        })
        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PURSUIT_UPDATE)
    elseif M.fugitivePursuit and ctxt.veh:getID() == targetVeh:getID() then -- fugitive
        BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_FAIL)
        M.fugitivePursuit = nil
        BJI.Managers.Restrictions.update({
            {
                restrictions = Table({
                    BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                    BJI.Managers.Restrictions.RESETS.ALL,
                }):flat(),
                state = BJI.Managers.Restrictions.STATE.ALLOWED,
            }
        })
        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PURSUIT_UPDATE)
    end
end

---@param data BJPursuitPayload
local function rxData(data)
    if BJI.Managers.Collisions.type == BJI.Managers.Collisions.TYPES.DISABLED or
        BJI.Managers.Scenario.isServerScenarioInProgress() then
        return nil
    end

    local targetVeh = BJI.Managers.Veh.getVehicleObject(data.gameVehID)
    if not targetVeh then
        if M.policeTargets[data.gameVehID] then
            M.policeTargets[data.gameVehID] = nil
            BJI.Managers.Restrictions.update({
                {
                    restrictions = BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                    state = BJI.Managers.Restrictions.STATE.ALLOWED,
                }
            })
        end
        return
    end

    local ctxt = BJI.Managers.Tick.getContext()
    if not ctxt.veh then
        return
    elseif not M.isPatrol and ctxt.veh:getID() ~= targetVeh:getID() then
        return
    end

    if data.event == "start" then
        rxStart(ctxt, data, targetVeh)
    elseif data.event == "arrest" then
        rxArrest(ctxt, data, targetVeh)
    elseif data.event == "evade" then
        rxEvade(ctxt, data, targetVeh)
    elseif data.event == "reset" then
        rxReset(ctxt, data, targetVeh)
    end
end

---@param ctxt TickContext
local function renderTick(ctxt)
    if M.isPatrol then
        M.policeTargets:filter(function(_, gameVehID)
            return not ctxt.veh or ctxt.veh:getID() ~= gameVehID
        end):forEach(function(_, gameVehID)
            -- render AI fugitive nametag (player fugitive is handled in nametags manager)
            local targetVeh = BJI.Managers.Veh.getVehicleObject(gameVehID)
            if targetVeh and not BJI.Managers.Veh.getVehOwnerID(gameVehID) then
                BJI.Managers.Veh.getPositionRotation(targetVeh, function(targetVehPos)
                    local finalPos = vec3(targetVehPos) +
                        vec3(0, 0, targetVeh:getInitialHeight())
                    BJI.Utils.ShapeDrawer.Text("Fugitive", finalPos, BJI.Utils.ShapeDrawer.Color(0, 0, 0, 1),
                        BJI.Utils.ShapeDrawer.Color(1, 0, 0, .5), false)
                end)
            end
        end)
    end
end

---@param ctxt TickContext
local function onScenarioChanged(ctxt)
    if BJI.Managers.Scenario.isServerScenarioInProgress() or
        ctxt.players[ctxt.user.playerID].isGhost then
        resetAll()
    end
end

local function onVehSwitch()
    updateIsPatrol(BJI.Managers.Tick.getContext())
end

---@param gameVehID integer
local function onVehReset(gameVehID)
    if M.policeTargets[gameVehID] == BJI.Managers.Context.User.playerID and
        BJI.Managers.AI.isAIVehicle(gameVehID) then
        localPursuitReset(BJI.Managers.Tick.getContext(), gameVehID)
    end
end

---@param gameVehID integer
local function onVehDelete(gameVehID)
    if M.policeTargets[gameVehID] and
        M.policeTargets[gameVehID] == BJI.Managers.Context.User.playerID then
        local remoteVehID = BJI.Managers.Veh.getRemoteVehID(gameVehID)
        BJI.Tx.scenario.PursuitData({
            event = "reset",
            originPlayerID = BJI.Managers.Context.User.playerID,
            gameVehID = remoteVehID or gameVehID,
        })
        M.policeTargets[gameVehID] = nil
    end
end

local function onTrafficStopped()
    if M.isPatrol then -- remove all self pursuits
        M.policeTargets:filter(function(originPlayerID) return originPlayerID == BJI.Managers.Context.User.playerID end)
            :forEach(function(_, gameVehID)
                localPursuitReset(BJI.Managers.Tick.getContext(), gameVehID)
            end)
    elseif M.fugitivePursuit and -- remove self fugitive pursuit
        M.fugitivePursuit.originPlayerID == BJI.Managers.Context.User.playerID then
        local ctxt = BJI.Managers.Tick.getContext()
        if ctxt.isOwner then
            localPursuitReset(BJI.Managers.Tick.getContext(), ctxt.veh:getID())
        end
    end
end

local function onPlayerDisconnect(ctxt, data)
    M.policeTargets:filter(function(originPlayerID) return originPlayerID == data.playerID end)
        :forEach(function(_, gameVehID)
            M.rxData({
                event = "reset",
                originPlayerID = data.playerID,
                gameVehID = gameVehID
            })
        end)
end

M.onLoad = function()
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_PURSUIT_ACTION, onPursuitActionUpdate, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.SCENARIO_CHANGED, onScenarioChanged, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_VEHICLE_SWITCHED, onVehSwitch, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_VEHICLE_RESETTED, onVehReset, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_VEHICLE_DESTROYED, onVehDelete, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_TRAFFIC_STOPPED, onTrafficStopped, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.PLAYER_DISCONNECT, onPlayerDisconnect, M._name)
end

M.rxData = rxData
M.getState = getState
M.getFugitiveNametagColors = getFugitiveNametagColors

M.renderTick = renderTick

return M
