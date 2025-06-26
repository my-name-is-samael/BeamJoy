---@class BJIManagerPursuit: BJIManager
local M = {
    _name = "Pursuit",

    ---@type tablelib<integer, integer> index gameVehID, value originPlayerID
    policeTargets = Table(),
    ---@type {originPlayerID: integer, targetGameVehID: integer}?
    fugitivePursuit = nil,
}

---@return boolean
local function getState()
    return M.policeTargets:length() > 0 or M.fugitivePursuit ~= nil
end

---@return BJIColor, BJIColor
local function getFugitiveNametagColors()
    return BJI.Utils.ShapeDrawer.Color(0, 0, 0, 1),
        BJI.Utils.ShapeDrawer.Color(1, 0, 0, .5)
end

local function resetAll()
    M.policeTargets:filter(function(originPlayerID)
        return originPlayerID == BJI.Managers.Context.User.playerID
    end):forEach(function(originPlayerID, targetVehID)
        BJI.Tx.scenario.PursuitData({
            event = "reset",
            originPlayerID = originPlayerID,
            gameVehID = targetVehID,
        })
        M.policeTargets[targetVehID] = nil
        gameplay_police.setPursuitMode(0, targetVehID)
    end)
    BJI.Managers.GPS.removeByKey(BJI.Managers.GPS.KEYS.VEHICLE)
end

local function gpsToNextTarget()
    if M.policeTargets:length() == 0 then
        BJI.Managers.GPS.removeByKey(BJI.Managers.GPS.KEYS.VEHICLE)
    else
        local selfVeh = BJI.Managers.Veh.getMPVehicle(BJI.Managers.Context.User.currentVehicle, true) or {}
        local closest = M.policeTargets:map(function(_, k)
            local targetVeh = BJI.Managers.Veh.getMPVehicle(k) or {}
            return {
                vid = k,
                dist = math.horizontalDistance(selfVeh.position, targetVeh.position),
            }
        end):values():sort(function(a, b)
            return a.dist < b.dist
        end)[1]
        if closest then
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
end

---@param ctxt TickContext
---@param targetGameVehID integer
---@return boolean
local function canStartPursuit(ctxt, targetGameVehID)
    ctxt = ctxt or BJI.Managers.Tick.getContext()

    local mpVeh = BJI.Managers.Veh.getMPVehicle(targetGameVehID)
    if not mpVeh then
        return false -- invalid target
    elseif mpVeh.isAi then
        -- accept pursuit only if AI is mine
        return mpVeh.ownerID == ctxt.user.playerID
    end

    if BJI.Managers.Scenario.isServerScenarioInProgress() or
        ctxt.players[mpVeh.ownerID].isGhost then
        return false -- target is a permaghost or server scenario in progress
    end
    if mpVeh.veh.isPatrol then
        return false -- target veh is a police
    end
    if mpVeh.ownerID == ctxt.user.playerID then
        if ctxt.user.currentVehicle ~= mpVeh.gameVehicleID then
            return false -- target veh is mine and idle
        end
    elseif ctxt.players[mpVeh.ownerID].currentVehicle ~= mpVeh.remoteVehID then
        return false -- target veh is others and idle
    end

    ---@param v BJIMPVehicle
    if not BJI.Managers.Veh.getMPVehicles({ isAi = false }):any(function(v)
            return v.veh.isPatrol ~= nil and not ctxt.players[v.ownerID].isGhost
        end) then
        -- no valid police veh avail
        return false
    end

    return true
end

---@param ctxt TickContext
---@param targetVeh BJIMPVehicle
---@param isLocal boolean
---@param originPlayerID integer?
local function pursuitStart(ctxt, targetVeh, isLocal, originPlayerID)
    originPlayerID = originPlayerID or ctxt.user.playerID
    if isLocal and not canStartPursuit(ctxt, targetVeh.gameVehicleID) then
        return gameplay_police.setPursuitMode(0, targetVeh.gameVehicleID)
    end

    if isLocal and ctxt.players:length() > 1 then
        local finalVehID = targetVeh.remoteVehID ~= -1 and targetVeh.remoteVehID or targetVeh.gameVehicleID
        BJI.Tx.scenario.PursuitData({
            event = "start",
            originPlayerID = originPlayerID,
            gameVehID = finalVehID,
        })
    end

    if ctxt.isOwner then
        if ctxt.veh.isPatrol then -- police
            if not isLocal and ctxt.veh:getID() == targetVeh.gameVehicleID then
                -- invalid target : police vehicle
                BJI.Tx.scenario.PursuitData({
                    event = "reset",
                    originPlayerID = originPlayerID,
                    gameVehID = targetVeh.remoteVehID,
                })
                return
            end
            M.policeTargets[targetVeh.gameVehicleID] = originPlayerID
            BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_START)
            gpsToNextTarget()
            BJI.Managers.Restrictions.update({
                {
                    restrictions = BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH, -- TODO block walking too
                    state = BJI.Managers.Restrictions.STATE.RESTRICTED,
                }
            })
            if not isLocal and extensions.gameplay_traffic.showMessages then
                ui_message(string.var("{1} {2}", {
                    translateLanguage('ui.traffic.suspectFlee', 'A suspect is fleeing from you! Vehicle:'),
                    BJI.Managers.Veh.getModelLabel(targetVeh.jbeam) or targetVeh.jbeam or "Unknown"
                }), 5, 'traffic', 'traffic')
            end
            if BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.AUTOMATIC_LIGHTS) then
                ctxt.veh:queueLuaCommand('electrics.set_lightbar_signal(2)')
            end
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PURSUIT_UPDATE)
        elseif ctxt.veh:getID() == targetVeh.gameVehicleID then -- fugitive
            if not isLocal and (BJI.Managers.Scenario.isServerScenarioInProgress() or
                    BJI.Managers.Collisions.type == BJI.Managers.Collisions.TYPES.DISABLED) then
                -- invalid target : already in scenario
                BJI.Tx.scenario.PursuitData({
                    event = "reset",
                    originPlayerID = originPlayerID or -1,
                    gameVehID = targetVeh.gameVehicleID,
                })
                return
            end
            M.fugitivePursuit = {
                originPlayerID = originPlayerID or -1,
                targetGameVehID = targetVeh.gameVehicleID,
            }
            BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_START)
            BJI.Managers.Restrictions.update({
                {
                    restrictions = Table({
                        BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                        BJI.Managers.Restrictions.RESETS.ALL, -- TODO block walking too
                    }):flat(),
                    state = BJI.Managers.Restrictions.STATE.RESTRICTED,
                }
            })
            if extensions.gameplay_traffic.showMessages then
                ui_message('ui.traffic.policePursuit', 5, 'traffic', 'traffic')
            end
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PURSUIT_UPDATE)
        end
    end
end

---@param ctxt TickContext
---@param targetVeh BJIMPVehicle
---@param isLocal boolean
---@param ticket boolean
---@param offenses string[]
---@param originPlayerID integer?
local function pursuitArrest(ctxt, targetVeh, isLocal, ticket, offenses, originPlayerID)
    originPlayerID = originPlayerID or ctxt.user.playerID
    if isLocal and ctxt.players:length() > 1 then
        local finalVehID = targetVeh.remoteVehID ~= -1 and targetVeh.remoteVehID or targetVeh.gameVehicleID
        BJI.Tx.scenario.PursuitData({
            event = "arrest",
            originPlayerID = originPlayerID,
            gameVehID = finalVehID,
            ticket = ticket,
            offenses = offenses,
        })
    end

    if ctxt.isOwner then
        if ctxt.veh.isPatrol and M.policeTargets[targetVeh.gameVehicleID] == originPlayerID then -- police
            if ctxt.vehPosRot.pos:distance(targetVeh.position) < 10 then
                BJI.Tx.scenario.PursuitReward(true)
            end
            M.policeTargets[targetVeh.gameVehicleID] = nil
            BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_SUCCESS)
            gpsToNextTarget()
            BJI.Managers.Restrictions.update({
                {
                    restrictions = BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                    state = BJI.Managers.Restrictions.STATE.ALLOWED,
                }
            })
            if not isLocal and extensions.gameplay_traffic.showMessages then
                ui_message('ui.traffic.suspectArrest', 5, 'traffic', 'traffic')
            end
            if M.policeTargets:length() == 0 then
                ctxt.veh:queueLuaCommand('electrics.set_lightbar_signal(0)')
            elseif BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.AUTOMATIC_LIGHTS) then
                ctxt.veh:queueLuaCommand('electrics.set_lightbar_signal(2)')
            end
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PURSUIT_UPDATE)
        elseif ctxt.veh:getID() == targetVeh.gameVehicleID and M.fugitivePursuit then -- fugitive
            M.fugitivePursuit = nil
            BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_FAIL)
            if isLocal then
                BJI.Managers.Restrictions.update({
                    {
                        restrictions = Table({
                            BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                            BJI.Managers.Restrictions.RESETS.ALL,
                        }):flat(),
                        state = BJI.Managers.Restrictions.STATE.ALLOWED,
                    }
                })
            else
                BJI.Managers.Veh.freeze(true, ctxt.veh:getID())
                BJI.Managers.Async.delayTask(function() -- freeze for 5 seconds
                    BJI.Managers.Veh.freeze(false, ctxt.veh:getID())
                    BJI.Managers.Restrictions.update({
                        {
                            restrictions = Table({
                                BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                                BJI.Managers.Restrictions.RESETS.ALL,
                            }):flat(),
                            state = BJI.Managers.Restrictions.STATE.ALLOWED,
                        }
                    })
                    ui_message('ui.traffic.driveAway', 5, 'traffic', 'traffic')
                end, 5000)
                if extensions.gameplay_traffic.showMessages then
                    ui_message(ticket and 'ui.traffic.policeTicket' or 'ui.traffic.policeArrest', 5, 'traffic',
                        'traffic')
                    ui_message(string.var("{1} {2}", {
                        translateLanguage('ui.traffic.infractions.title', 'Offenses:'),
                        Table(offenses):map(function(v)
                            return translateLanguage('ui.traffic.infractions.' .. v, v)
                        end):join(", ")
                    }), 10, 'trafficInfractions', 'traffic')
                end
            end
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PURSUIT_UPDATE)
        end
    end
end

---@param ctxt TickContext
---@param targetVeh BJIMPVehicle
---@param isLocal boolean
---@param originPlayerID integer?
---@param isAiReset boolean?
local function pursuitEvade(ctxt, targetVeh, isLocal, originPlayerID, isAiReset)
    originPlayerID = originPlayerID or ctxt.user.playerID
    if isLocal and ctxt.players:length() > 1 then
        local finalVehID = targetVeh.remoteVehID ~= -1 and targetVeh.remoteVehID or targetVeh.gameVehicleID
        BJI.Tx.scenario.PursuitData({
            event = "evade",
            originPlayerID = originPlayerID,
            gameVehID = finalVehID,
        })
    end

    if ctxt.isOwner then
        if ctxt.veh.isPatrol and M.policeTargets[targetVeh.gameVehicleID] == originPlayerID then -- police
            M.policeTargets[targetVeh.gameVehicleID] = nil
            BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_FAIL)
            gpsToNextTarget()
            BJI.Managers.Restrictions.update({
                {
                    restrictions = BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                    state = BJI.Managers.Restrictions.STATE.ALLOWED,
                }
            })
            if isAiReset then
                -- ai reset not always trigger evade, override it here
                gameplay_police.setPursuitMode(0, targetVeh.gameVehicleID)
            end
            if (not isLocal or isAiReset) and extensions.gameplay_traffic.showMessages then
                ui_message('ui.traffic.suspectEvade', 5, 'traffic', 'traffic')
            end
            if M.policeTargets:length() == 0 then
                ctxt.veh:queueLuaCommand('electrics.set_lightbar_signal(0)')
            elseif BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.AUTOMATIC_LIGHTS) then
                ctxt.veh:queueLuaCommand('electrics.set_lightbar_signal(2)')
            end
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PURSUIT_UPDATE)
        elseif ctxt.veh:getID() == targetVeh.gameVehicleID and M.fugitivePursuit then -- fugitive
            M.fugitivePursuit = nil
            BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_SUCCESS)
            BJI.Tx.scenario.PursuitReward(false)
            BJI.Managers.Restrictions.update({
                {
                    restrictions = Table({
                        BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                        BJI.Managers.Restrictions.RESETS.ALL,
                    }):flat(),
                    state = BJI.Managers.Restrictions.STATE.ALLOWED,
                }
            })
            if not isLocal and extensions.gameplay_traffic.showMessages then
                ui_message('ui.traffic.policeEvade', 5, 'traffic', 'traffic')
            end
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PURSUIT_UPDATE)
        end
    end
end

---@param ctxt TickContext
---@param targetVeh BJIMPVehicle
---@param isLocal boolean
---@param originPlayerID integer?
local function pursuitReset(ctxt, targetVeh, isLocal, originPlayerID)
    originPlayerID = originPlayerID or ctxt.user.playerID
    if isLocal and ctxt.players:length() > 1 then
        local finalVehID = targetVeh.remoteVehID ~= -1 and targetVeh.remoteVehID or targetVeh.gameVehicleID
        BJI.Tx.scenario.PursuitData({
            event = "reset",
            originPlayerID = originPlayerID,
            gameVehID = finalVehID,
        })
    end

    if ctxt.isOwner then
        if ctxt.veh.isPatrol and M.policeTargets[targetVeh.gameVehicleID] == originPlayerID then -- police
            M.policeTargets[targetVeh.gameVehicleID] = nil
            gpsToNextTarget()
            BJI.Managers.Restrictions.update({
                {
                    restrictions = BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                    state = BJI.Managers.Restrictions.STATE.ALLOWED,
                }
            })
            if M.policeTargets:length() == 0 then
                ctxt.veh:queueLuaCommand('electrics.set_lightbar_signal(0)')
            elseif BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.AUTOMATIC_LIGHTS) then
                ctxt.veh:queueLuaCommand('electrics.set_lightbar_signal(2)')
            end
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PURSUIT_UPDATE)
        elseif ctxt.veh:getID() == targetVeh.gameVehicleID and M.fugitivePursuit then -- fugitive
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
end


local function onPursuitActionUpdate(targetGameVehID, event, pursuitData)
    local ctxt = BJI.Managers.Tick.getContext()
    local targetVeh = BJI.Managers.Veh.getMPVehicle(targetGameVehID)
    if not targetVeh then return end

    if event == "start" then
        pursuitStart(ctxt, targetVeh, true)
    elseif event == "arrest" then
        pursuitArrest(ctxt, targetVeh, true, pursuitData.mode == 1, pursuitData.offensesList)
    elseif event == "evade" then
        pursuitEvade(ctxt, targetVeh, true)
    elseif event == "reset" then
        pursuitReset(ctxt, targetVeh, true)
    end
end

---@param data BJPursuitPayload
local function rxData(data)
    local ctxt = BJI.Managers.Tick.getContext()
    if not ctxt.isOwner or BJI.Managers.Scenario.isServerScenarioInProgress() or
        BJI.Managers.Collisions.type == BJI.Managers.Collisions.TYPES.DISABLED then
        return
    end

    ---@param v BJIMPVehicle
    local targetVeh = BJI.Managers.Veh.getMPVehicles({ isAi = false }):find(function(v)
        return v.gameVehicleID == data.gameVehID or v.remoteVehID == data.gameVehID
    end)
    if not targetVeh then
        return
    elseif not ctxt.veh.isPatrol and ctxt.veh:getID() ~= targetVeh.gameVehicleID then
        return -- not patrol nor target
    end

    if data.event ~= "start" then
        if ctxt.veh.isPatrol and not M.policeTargets[targetVeh.gameVehicleID] then
            return -- invalid data
        elseif ctxt.veh:getID() == targetVeh.gameVehicleID and not M.fugitivePursuit then
            return -- invalid data
        end
    end

    if data.event == "start" then
        pursuitStart(ctxt, targetVeh, false, data.originPlayerID)
    elseif data.event == "arrest" then
        pursuitArrest(ctxt, targetVeh, false, data.ticket, data.offenses, data.originPlayerID)
    elseif data.event == "evade" then
        pursuitEvade(ctxt, targetVeh, false, data.originPlayerID)
    elseif data.event == "reset" then
        pursuitReset(ctxt, targetVeh, false, data.originPlayerID)
    end
end

---@param ctxt TickContext
local function onScenarioChanged(ctxt)
    if BJI.Managers.Scenario.isServerScenarioInProgress() or
        ctxt.players[ctxt.user.playerID].isGhost then
        resetAll()
    end
end

---@param gameVehID integer
local function onVehReset(gameVehID)
    local targetVeh = BJI.Managers.Veh.getMPVehicle(gameVehID)
    if targetVeh and M.policeTargets[gameVehID] == BJI.Managers.Context.User.playerID and targetVeh.isAi then
        pursuitEvade(BJI.Managers.Tick.getContext(), targetVeh, true, nil, true)
    end
end

---@param gameVehID integer
local function onVehDelete(gameVehID)
    if M.policeTargets[gameVehID] then
        ---@diagnostic disable-next-line vehicle not exists anymore, fake it
        pursuitReset(BJI.Managers.Tick.getContext(), { gameVehicleID = gameVehID }, false, M.policeTargets[gameVehID])
    end
end

local function onTrafficStopped()
    local ctxt = BJI.Managers.Tick.getContext()
    if ctxt.isOwner then
        if ctxt.players:length() == 1 then -- alone (then no more pursuit process)
            -- remove all pursuits
            M.policeTargets:forEach(function(originPlayerID, gameVehID)
                pursuitReset(ctxt, BJI.Managers.Veh.getMPVehicle(gameVehID) or { gameVehicleID = gameVehID }, true,
                    originPlayerID)
            end)
            if M.fugitivePursuit then
                pursuitReset(ctxt,
                    BJI.Managers.Veh.getMPVehicle(ctxt.veh:getID()) or { gameVehicleID = ctxt.veh:getID() }, true,
                    M.fugitivePursuit.originPlayerID)
            end
        elseif not BJI.Managers.Veh.getMPVehicles({ isAi = true }):any(function(v)
                return v.ownerID ~= ctxt.user.playerID
            end) then -- no pursuit engine by other player
            M.policeTargets:filter(function(originPlayerID)
                return originPlayerID == ctxt.user.playerID
            end):forEach(function(originPlayerID, gameVehID)
                pursuitReset(ctxt, BJI.Managers.Veh.getMPVehicle(gameVehID) or { gameVehicleID = gameVehID }, true,
                    originPlayerID)
            end)
            if M.fugitivePursuit and M.fugitivePursuit.originPlayerID == ctxt.user.playerID then
                pursuitReset(ctxt,
                    BJI.Managers.Veh.getMPVehicle(ctxt.veh:getID()) or { gameVehicleID = ctxt.veh:getID() }, true,
                    M.fugitivePursuit.originPlayerID)
            end
        end
    end
end

local function onPlayerDisconnect(ctxt, data)
    M.policeTargets:filter(function(originPlayerID) return originPlayerID == data.playerID end)
        :forEach(function(originPlayerID, gameVehID)
            pursuitReset(ctxt, BJI.Managers.Veh.getMPVehicle(gameVehID) or { gameVehicleID = gameVehID }, false,
                originPlayerID)
        end)
    if M.fugitivePursuit and M.fugitivePursuit.originPlayerID == data.playerID then
        pursuitReset(ctxt, BJI.Managers.Veh.getMPVehicle(ctxt.veh:getID()) or { gameVehicleID = ctxt.veh:getID() }, false,
            M.fugitivePursuit.originPlayerID)
    end
end

M.onLoad = function()
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_PURSUIT_ACTION, onPursuitActionUpdate, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.SCENARIO_CHANGED, onScenarioChanged, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_VEHICLE_RESETTED, onVehReset, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_VEHICLE_DESTROYED, onVehDelete, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_TRAFFIC_STOPPED, onTrafficStopped, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.PLAYER_DISCONNECT, onPlayerDisconnect, M._name)
end

M.rxData = rxData
M.getState = getState
M.getFugitiveNametagColors = getFugitiveNametagColors

return M
