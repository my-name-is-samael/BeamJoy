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

---@return boolean
local function canReset()
    return not M.fugitivePursuit
end

---@return BJIColor, BJIColor
local function getFugitiveNametagColors()
    return BJI.Utils.ShapeDrawer.Color(0, 0, 0, 1),
        BJI.Utils.ShapeDrawer.Color(1, 0, 0, .5)
end

---@param ctxt TickContext
---@param mpVeh BJIMPVehicle
---@param isServerScenarioOrGhost boolean?
---@return string
local function getVehRole(ctxt, mpVeh, isServerScenarioOrGhost)
    if isServerScenarioOrGhost == nil then
        isServerScenarioOrGhost = BJI_Scenario.isServerScenarioInProgress() or
            (ctxt.players[mpVeh.ownerID] and ctxt.players[mpVeh.ownerID].isGhost)
    end

    if isServerScenarioOrGhost or mpVeh.isAi then
        return "empty"
    elseif mpVeh.veh.isPatrol then
        if ctxt.isOwner and ctxt.veh.gameVehicleID == mpVeh.gameVehicleID then
            return "police"
        end
        return "empty"
    end
    return "standard"
end

local function resetAll()
    M.policeTargets:filter(function(originPlayerID)
        return originPlayerID == BJI_Context.User.playerID
    end):forEach(function(originPlayerID, targetVehID)
        BJI_Tx_scenario.PursuitData({
            event = "reset",
            originPlayerID = originPlayerID,
            gameVehID = targetVehID,
        })
        M.policeTargets[targetVehID] = nil
        gameplay_police.setPursuitMode(0, targetVehID)
    end)
    BJI_GPS.removeByKey(BJI_GPS.KEYS.VEHICLE)
end

local function gpsToNextTarget()
    local selfVeh = BJI_Veh.getMPVehicle(BJI_Context.User.currentVehicle, true)
    if not selfVeh then
        return
    end
    if M.policeTargets:length() == 0 then
        BJI_GPS.removeByKey(BJI_GPS.KEYS.VEHICLE)
    else
        local closest = M.policeTargets:map(function(_, k)
            local targetVeh = BJI_Veh.getMPVehicle(k)
            if not targetVeh then
                return nil
            end
            return {
                vid = k,
                dist = math.horizontalDistance(selfVeh.position, targetVeh.position),
            }
        end):values():sort(function(a, b)
            return a.dist < b.dist
        end)[1]
        if closest then
            local currTarget = BJI_GPS.getByKey(BJI_GPS.KEYS.VEHICLE)
            if not currTarget or currTarget.gameVehID ~= closest.vid then
                BJI_GPS.prependWaypoint({
                    key = BJI_GPS.KEYS.VEHICLE,
                    radius = 0,
                    gameVehID = closest.vid,
                    clearable = false,
                })
            end
        end
    end
end

---@param ctxt TickContext
---@param targetVeh BJIMPVehicle
---@return boolean
local function canStartPursuit(ctxt, targetVeh)
    if targetVeh.isAi then
        return false
    end

    if BJI_Scenario.isServerScenarioInProgress() or
        ctxt.players[targetVeh.ownerID].isGhost then
        return false -- target is a permaghost or server scenario in progress
    end
    if targetVeh.veh.isPatrol then
        return false -- target veh is a police
    end
    if targetVeh.ownerID == ctxt.user.playerID then
        if ctxt.user.currentVehicle ~= targetVeh.gameVehicleID then
            return false -- target veh is mine and idle
        end
    elseif ctxt.players[targetVeh.ownerID].currentVehicle ~= targetVeh.remoteVehID then
        return false -- target veh is others and idle
    end

    ---@param v BJIMPVehicle
    if not BJI_Veh.getMPVehicles({ isAi = false }, true):any(function(v)
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
    if isLocal and not canStartPursuit(ctxt, targetVeh) then
        gameplay_police.setPursuitMode(0, targetVeh.gameVehicleID)
        extensions.gameplay_traffic.getTrafficData()[targetVeh.gameVehicleID]:setRole(getVehRole(ctxt, targetVeh))
        return
    end

    if isLocal then
        local finalVehID = targetVeh.remoteVehID ~= -1 and targetVeh.remoteVehID or targetVeh.gameVehicleID
        BJI_Tx_scenario.PursuitData({
            event = "start",
            originPlayerID = originPlayerID,
            gameVehID = finalVehID,
        })
    end

    if ctxt.isOwner then
        if ctxt.veh.veh.isPatrol then -- police
            if not isLocal and ctxt.veh.gameVehicleID == targetVeh.gameVehicleID then
                -- invalid target : self and police vehicle
                BJI_Tx_scenario.PursuitData({
                    event = "reset",
                    originPlayerID = originPlayerID,
                    gameVehID = targetVeh.remoteVehID,
                })
                return
            end
            M.policeTargets[targetVeh.gameVehicleID] = originPlayerID
            BJI_Sound.play(BJI_Sound.SOUNDS.PURSUIT_START)
            gpsToNextTarget()
            if not isLocal and extensions.gameplay_traffic.showMessages then
                ui_message(string.var("{1} {2}", {
                    translateLanguage('ui.traffic.suspectFlee', 'A suspect is fleeing from you! Vehicle:'),
                    BJI_Veh.getModelLabel(targetVeh.jbeam) or targetVeh.jbeam or "Unknown"
                }), 5, 'traffic', 'traffic')
            end
            if BJI_LocalStorage.get(BJI_LocalStorage.GLOBAL_VALUES.AUTOMATIC_LIGHTS) then
                ctxt.veh.veh:queueLuaCommand('electrics.set_lightbar_signal(2)')
            end
            BJI_Events.trigger(BJI_Events.EVENTS.PURSUIT_UPDATE)
        elseif ctxt.veh.gameVehicleID == targetVeh.gameVehicleID then -- fugitive
            if not isLocal and (BJI_Scenario.isServerScenarioInProgress() or
                    BJI_Collisions.type == BJI_Collisions.TYPES.DISABLED) then
                -- invalid target : already in scenario
                BJI_Tx_scenario.PursuitData({
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
            BJI_Sound.play(BJI_Sound.SOUNDS.PURSUIT_START)
            if extensions.gameplay_traffic.showMessages then
                ui_message('ui.traffic.policePursuit', 5, 'traffic', 'traffic')
            end
            BJI_Events.trigger(BJI_Events.EVENTS.PURSUIT_UPDATE)
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
    if isLocal then
        local finalVehID = targetVeh.remoteVehID ~= -1 and targetVeh.remoteVehID or targetVeh.gameVehicleID
        BJI_Tx_scenario.PursuitData({
            event = "arrest",
            originPlayerID = originPlayerID,
            gameVehID = finalVehID,
            ticket = ticket,
            offenses = offenses,
        })
    end

    if ctxt.isOwner then
        if ctxt.veh.veh.isPatrol and M.policeTargets[targetVeh.gameVehicleID] == originPlayerID then -- police
            if ctxt.veh.position:distance(targetVeh.position) < 10 then
                BJI_Tx_scenario.PursuitReward(true)
            end
            M.policeTargets[targetVeh.gameVehicleID] = nil
            BJI_Sound.play(BJI_Sound.SOUNDS.PURSUIT_SUCCESS)
            gpsToNextTarget()
            if not isLocal and extensions.gameplay_traffic.showMessages then
                ui_message('ui.traffic.suspectArrest', 5, 'traffic', 'traffic')
            end
            if M.policeTargets:length() == 0 then
                ctxt.veh.veh:queueLuaCommand('electrics.set_lightbar_signal(0)')
            elseif BJI_LocalStorage.get(BJI_LocalStorage.GLOBAL_VALUES.AUTOMATIC_LIGHTS) then
                ctxt.veh.veh:queueLuaCommand('electrics.set_lightbar_signal(2)')
            end
            BJI_Events.trigger(BJI_Events.EVENTS.PURSUIT_UPDATE)
        elseif ctxt.veh.gameVehicleID == targetVeh.gameVehicleID and M.fugitivePursuit then -- fugitive
            BJI_Sound.play(BJI_Sound.SOUNDS.PURSUIT_FAIL)
            if not isLocal then
                BJI_Veh.freeze(true, ctxt.veh.gameVehicleID)
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
            BJI_Async.delayTask(function() -- wait for 5 seconds (freeze), then stop pursuit
                M.fugitivePursuit = nil
                if not isLocal then
                    BJI_Veh.freeze(false, ctxt.veh.gameVehicleID)
                end
                if extensions.gameplay_traffic.showMessages then
                    ui_message('ui.traffic.driveAway', 5, 'traffic', 'traffic')
                end
                BJI_Events.trigger(BJI_Events.EVENTS.PURSUIT_UPDATE)
            end, 5000)
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
    if isLocal then
        local finalVehID = targetVeh.remoteVehID ~= -1 and targetVeh.remoteVehID or targetVeh.gameVehicleID
        BJI_Tx_scenario.PursuitData({
            event = "evade",
            originPlayerID = originPlayerID,
            gameVehID = finalVehID,
        })
    end

    if ctxt.isOwner then
        if ctxt.veh.veh.isPatrol and M.policeTargets[targetVeh.gameVehicleID] == originPlayerID then -- police
            M.policeTargets[targetVeh.gameVehicleID] = nil
            BJI_Sound.play(BJI_Sound.SOUNDS.PURSUIT_FAIL)
            gpsToNextTarget()
            if isAiReset then
                -- ai reset not always trigger evade, override it here
                gameplay_police.setPursuitMode(0, targetVeh.gameVehicleID)
            end
            if (not isLocal or isAiReset) and extensions.gameplay_traffic.showMessages then
                ui_message('ui.traffic.suspectEvade', 5, 'traffic', 'traffic')
            end
            if M.policeTargets:length() == 0 then
                ctxt.veh.veh:queueLuaCommand('electrics.set_lightbar_signal(0)')
            elseif BJI_LocalStorage.get(BJI_LocalStorage.GLOBAL_VALUES.AUTOMATIC_LIGHTS) then
                ctxt.veh.veh:queueLuaCommand('electrics.set_lightbar_signal(2)')
            end
            BJI_Events.trigger(BJI_Events.EVENTS.PURSUIT_UPDATE)
        elseif ctxt.veh.gameVehicleID == targetVeh.gameVehicleID and M.fugitivePursuit then -- fugitive
            M.fugitivePursuit = nil
            BJI_Sound.play(BJI_Sound.SOUNDS.PURSUIT_SUCCESS)
            BJI_Tx_scenario.PursuitReward(false)
            if not isLocal and extensions.gameplay_traffic.showMessages then
                ui_message('ui.traffic.policeEvade', 5, 'traffic', 'traffic')
            end
            BJI_Events.trigger(BJI_Events.EVENTS.PURSUIT_UPDATE)
        end
    end
end

---@param ctxt TickContext
---@param targetVeh BJIMPVehicle
---@param isLocal boolean
---@param originPlayerID integer?
local function pursuitReset(ctxt, targetVeh, isLocal, originPlayerID)
    originPlayerID = originPlayerID or ctxt.user.playerID
    if isLocal then
        local finalVehID = targetVeh.remoteVehID ~= -1 and targetVeh.remoteVehID or targetVeh.gameVehicleID
        BJI_Tx_scenario.PursuitData({
            event = "reset",
            originPlayerID = originPlayerID,
            gameVehID = finalVehID,
        })
    end

    if ctxt.isOwner then
        if ctxt.veh.veh.isPatrol and M.policeTargets[targetVeh.gameVehicleID] == originPlayerID then -- police
            M.policeTargets[targetVeh.gameVehicleID] = nil
            gpsToNextTarget()
            if M.policeTargets:length() == 0 then
                ctxt.veh.veh:queueLuaCommand('electrics.set_lightbar_signal(0)')
            elseif BJI_LocalStorage.get(BJI_LocalStorage.GLOBAL_VALUES.AUTOMATIC_LIGHTS) then
                ctxt.veh.veh:queueLuaCommand('electrics.set_lightbar_signal(2)')
            end
            BJI_Events.trigger(BJI_Events.EVENTS.PURSUIT_UPDATE)
        elseif ctxt.veh.gameVehicleID == targetVeh.gameVehicleID and M.fugitivePursuit then -- fugitive
            M.fugitivePursuit = nil
            BJI_Events.trigger(BJI_Events.EVENTS.PURSUIT_UPDATE)
        end
    end
end


local function onPursuitActionUpdate(targetGameVehID, event, pursuitData)
    local ctxt = BJI_Tick.getContext()
    local targetVeh = BJI_Veh.getMPVehicle(targetGameVehID)
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
    local ctxt = BJI_Tick.getContext()
    if not ctxt.isOwner or BJI_Scenario.isServerScenarioInProgress() or
        BJI_Collisions.type == BJI_Collisions.TYPES.DISABLED then
        return
    end

    ---@param v BJIMPVehicle
    local targetVeh = BJI_Veh.getMPVehicles({ isAi = false }):find(function(v)
        return v.gameVehicleID == data.gameVehID or v.remoteVehID == data.gameVehID
    end)
    if not targetVeh then
        return
    elseif not ctxt.veh.veh.isPatrol and ctxt.veh.gameVehicleID ~= targetVeh.gameVehicleID then
        return -- not patrol nor target
    end

    if data.event ~= "start" then
        if ctxt.veh.veh.isPatrol and not M.policeTargets[targetVeh.gameVehicleID] then
            return -- invalid data
        elseif ctxt.veh.gameVehicleID == targetVeh.gameVehicleID and not M.fugitivePursuit then
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

---@param gameVehID integer
local function onVehReset(gameVehID)
    local targetVeh = BJI_Veh.getMPVehicle(gameVehID)
    if targetVeh and M.policeTargets[gameVehID] == BJI_Context.User.playerID and targetVeh.isAi then
        pursuitEvade(BJI_Tick.getContext(), targetVeh, true, nil, true)
        gameplay_police.setPursuitMode(0, gameVehID)
    end
end


local function onTrafficStopped()
    local ctxt = BJI_Tick.getContext()
    if ctxt.isOwner and ctxt.veh.veh.isPatrol then
        resetAll()
    end
end

local function onPlayerDisconnect(ctxt, data)
    M.policeTargets:filter(function(originPlayerID) return originPlayerID == data.playerID end)
        :forEach(function(originPlayerID, gameVehID)
            pursuitReset(ctxt, BJI_Veh.getMPVehicle(gameVehID) or { gameVehicleID = gameVehID }, false,
                originPlayerID)
        end)
    if M.fugitivePursuit and M.fugitivePursuit.originPlayerID == data.playerID then
        pursuitReset(ctxt,
            BJI_Veh.getMPVehicle(ctxt.veh.gameVehicleID) or { gameVehicleID = ctxt.veh.gameVehicleID }, false,
            M.fugitivePursuit.originPlayerID)
    end
end

---@param gameVehID integer
local function onVehDelete(gameVehID)
    if M.policeTargets[gameVehID] then
        ---@diagnostic disable-next-line vehicle not exists anymore, fake it
        pursuitReset(BJI_Tick.getContext(), { gameVehicleID = gameVehID }, false, M.policeTargets[gameVehID])
    end
end

---@param ctxt TickContext
local function initPursuitTraffic(ctxt)
    local isServerScenarioOrSelfGhost = BJI_Scenario.isServerScenarioInProgress() or
        (ctxt.players[ctxt.user.playerID] and ctxt.players[ctxt.user.playerID].isGhost)
    local trafficVeh, finalRole
    BJI_Veh.getMPVehicles(nil, true)
        :forEach(function(mpVeh)
            trafficVeh = extensions.gameplay_traffic.getTrafficData()[mpVeh.gameVehicleID]
            if not trafficVeh then
                extensions.gameplay_traffic.insertTraffic(mpVeh.gameVehicleID, not mpVeh.isLocal or not mpVeh.isAi)
                trafficVeh = extensions.gameplay_traffic.getTrafficData()[mpVeh.gameVehicleID]
            end
            if not isServerScenarioOrSelfGhost then
                if mpVeh.isAi then
                    if mpVeh.isLocal then
                        if not trafficVeh.isAi then
                            extensions.gameplay_traffic.removeTraffic(mpVeh.gameVehicleID)
                            extensions.gameplay_traffic.insertTraffic(mpVeh.gameVehicleID)
                            trafficVeh = extensions.gameplay_traffic.getTrafficData()[mpVeh.gameVehicleID]
                        end
                    else
                        if trafficVeh.isAi then
                            extensions.gameplay_traffic.removeTraffic(mpVeh.gameVehicleID)
                            extensions.gameplay_traffic.insertTraffic(mpVeh.gameVehicleID, true)
                            trafficVeh = extensions.gameplay_traffic.getTrafficData()[mpVeh.gameVehicleID]
                        end
                    end
                else
                    if trafficVeh.isAi then
                        extensions.gameplay_traffic.removeTraffic(mpVeh.gameVehicleID)
                        extensions.gameplay_traffic.insertTraffic(mpVeh.gameVehicleID, true)
                        trafficVeh = extensions.gameplay_traffic.getTrafficData()[mpVeh.gameVehicleID]
                    end
                end
            end
            trafficVeh:setRole(getVehRole(ctxt, mpVeh, isServerScenarioOrSelfGhost))
        end)
end

---@param mpVeh BJIMPVehicle
local function onVehSpawned(mpVeh)
    LogWarn("Pursuit veh spawned " .. tostring(mpVeh.gameVehicleID))
    if not mpVeh.isVehicle then return end
    local ctxt = BJI_Tick.getContext()
    if BJI_Scenario.isServerScenarioInProgress() or
        ctxt.players[ctxt.user.playerID].isGhost then
        return -- do not impact server scenarios and no collisions scenarios
    end
    local trafficVeh = extensions.gameplay_traffic.getTrafficData()[mpVeh.gameVehicleID]
    if not trafficVeh then
        extensions.gameplay_traffic.insertTraffic(mpVeh.gameVehicleID, not mpVeh.isLocal or not mpVeh.isAi)
        trafficVeh = extensions.gameplay_traffic.getTrafficData()[mpVeh.gameVehicleID]
    end
    if not trafficVeh then
        return LogWarn(string.format("Traffic vehicle not found (%d)", mpVeh.gameVehicleID))
    end
    trafficVeh:setRole(getVehRole(ctxt, mpVeh))
end

---@param ctxt TickContext
---@param event {previousMPVeh: BJIMPVehicle?, currentMPVeh: BJIMPVehicle?}
local function onVehSwitched(ctxt, event)
    if BJI_Scenario.isServerScenarioInProgress() or
        ctxt.players[ctxt.user.playerID].isGhost then
        return -- do not impact server scenarios and no collisions scenarios
    end
    if event.previousMPVeh then
        if event.previousMPVeh.isLocal and event.previousMPVeh.veh.isPatrol then
            local trafficVeh = extensions.gameplay_traffic.getTrafficData()[event.previousMPVeh.gameVehicleID]
            if trafficVeh then
                trafficVeh:setRole(getVehRole(ctxt, event.previousMPVeh))
            end
        end
    end
    if event.currentMPVeh then
        if event.currentMPVeh.isLocal and event.currentMPVeh.veh.isPatrol then
            local trafficVeh = extensions.gameplay_traffic.getTrafficData()[event.currentMPVeh.gameVehicleID]
            if trafficVeh then
                trafficVeh:setRole(getVehRole(ctxt, event.currentMPVeh))
            end
        end
    end
end

---@param ctxt TickContext
local function onScenarioChanged(ctxt)
    if ctxt.isOwner and ctxt.veh.veh.isPatrol then
        local trafficVeh = extensions.gameplay_traffic.getTrafficData()[ctxt.veh.gameVehicleID]
        if trafficVeh then
            trafficVeh:setRole(getVehRole(ctxt, ctxt.veh))
        end
    end
    if BJI_Scenario.isServerScenarioInProgress() then
        resetAll()
    end
end

---@param ctxt TickContext
---@param event {playerID: integer}
local function onPlayerScenariosChanged(ctxt, event)
    ---@param v BJIPlayerVehicle
    ctxt.players[event.playerID].vehicles:forEach(function(v)
        local mpVeh = BJI_Veh.getMPVehicle(v.gameVehID)
        if not mpVeh then return end
        local trafficVeh = extensions.gameplay_traffic.getTrafficData()[mpVeh.gameVehicleID]
        if not trafficVeh then
            extensions.gameplay_traffic.insertTraffic(mpVeh.gameVehicleID, not mpVeh.isLocal or not mpVeh.isAi)
            trafficVeh = extensions.gameplay_traffic.getTrafficData()[mpVeh.gameVehicleID]
        end
        trafficVeh:setRole(getVehRole(ctxt, mpVeh))
    end)
    if event.playerID == ctxt.user.playerID and
        ctxt.players[ctxt.user.playerID].isGhost then
        resetAll()
    end
end

local function onTrafficVehAdded(gameVehID)
    local trafficVeh = extensions.gameplay_traffic.getTrafficData()[gameVehID]
    ---@type BJIMPVehicle?
    local mpVeh = BJI_Veh.getMPVehicle(gameVehID)
    if not trafficVeh or not mpVeh then
        error("Invalid traffic vehicles added")
    end

    if not mpVeh.isLocal then -- not own veh
        if trafficVeh.isAi then
            extensions.gameplay_traffic.removeTraffic(gameVehID)
            extensions.gameplay_traffic.insertTraffic(gameVehID, true, true)
            BJI_Collisions.forceUpdateVeh(gameVehID)
        end
        trafficVeh = extensions.gameplay_traffic.getTrafficData()[gameVehID]
    end
    trafficVeh:setRole(getVehRole(BJI_Tick.getContext(), mpVeh))
end

M.onLoad = function()
    BJI_Events.addListener(BJI_Events.EVENTS.NG_TRAFFIC_VEHICLE_ADDED, onTrafficVehAdded, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.NG_PURSUIT_ACTION, onPursuitActionUpdate, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.NG_VEHICLE_RESETTED, onVehReset, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.NG_TRAFFIC_STOPPED, onTrafficStopped, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.PLAYER_DISCONNECT, onPlayerDisconnect, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.NG_VEHICLE_DESTROYED, onVehDelete, M._name)

    BJI_Events.addListener(BJI_Events.EVENTS.VEHICLE_INITIALIZED, onVehSpawned, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.VEHICLE_SPEC_CHANGED, onVehSwitched, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.SCENARIO_CHANGED, onScenarioChanged, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.PLAYER_SCENARIO_CHANGED, onPlayerScenariosChanged, M
        ._name)
    initPursuitTraffic(BJI_Tick.getContext())
end

M.getState = getState
M.canReset = canReset

M.rxData = rxData
M.getFugitiveNametagColors = getFugitiveNametagColors

return M
