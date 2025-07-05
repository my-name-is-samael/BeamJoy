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
    local selfVeh = BJI.Managers.Veh.getMPVehicle(BJI.Managers.Context.User.currentVehicle, true)
    if not selfVeh then
        return
    end
    if M.policeTargets:length() == 0 then
        BJI.Managers.GPS.removeByKey(BJI.Managers.GPS.KEYS.VEHICLE)
    else
        local closest = M.policeTargets:map(function(_, k)
            local targetVeh = BJI.Managers.Veh.getMPVehicle(k)
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
---@param targetVeh BJIMPVehicle
---@return boolean
local function canStartPursuit(ctxt, targetVeh)
    if targetVeh.isAi then
        -- AI pursuit only when alone
        return ctxt.players:length() == 1
    end

    if BJI.Managers.Scenario.isServerScenarioInProgress() or
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
    if not BJI.Managers.Veh.getMPVehicles({ isAi = false }, true):any(function(v)
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
        return gameplay_police.setPursuitMode(-1, targetVeh.gameVehicleID)
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
        if ctxt.veh.veh.isPatrol then -- police
            if not isLocal and ctxt.veh.gameVehicleID == targetVeh.gameVehicleID then
                -- invalid target : self and police vehicle
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
            if not isLocal and extensions.gameplay_traffic.showMessages then
                ui_message(string.var("{1} {2}", {
                    translateLanguage('ui.traffic.suspectFlee', 'A suspect is fleeing from you! Vehicle:'),
                    BJI.Managers.Veh.getModelLabel(targetVeh.jbeam) or targetVeh.jbeam or "Unknown"
                }), 5, 'traffic', 'traffic')
            end
            if BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.AUTOMATIC_LIGHTS) then
                ctxt.veh.veh:queueLuaCommand('electrics.set_lightbar_signal(2)')
            end
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PURSUIT_UPDATE)
        elseif ctxt.veh.gameVehicleID == targetVeh.gameVehicleID then -- fugitive
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
        if ctxt.veh.veh.isPatrol and M.policeTargets[targetVeh.gameVehicleID] == originPlayerID then -- police
            if ctxt.veh.position:distance(targetVeh.position) < 10 then
                BJI.Tx.scenario.PursuitReward(true)
            end
            M.policeTargets[targetVeh.gameVehicleID] = nil
            BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_SUCCESS)
            gpsToNextTarget()
            if not isLocal and extensions.gameplay_traffic.showMessages then
                ui_message('ui.traffic.suspectArrest', 5, 'traffic', 'traffic')
            end
            if M.policeTargets:length() == 0 then
                ctxt.veh.veh:queueLuaCommand('electrics.set_lightbar_signal(0)')
            elseif BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.AUTOMATIC_LIGHTS) then
                ctxt.veh.veh:queueLuaCommand('electrics.set_lightbar_signal(2)')
            end
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PURSUIT_UPDATE)
        elseif ctxt.veh.gameVehicleID == targetVeh.gameVehicleID and M.fugitivePursuit then -- fugitive
            BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_FAIL)
            if not isLocal then
                BJI.Managers.Veh.freeze(true, ctxt.veh.gameVehicleID)
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
            BJI.Managers.Async.delayTask(function() -- wait for 5 seconds (freeze), then stop pursuit
                M.fugitivePursuit = nil
                if not isLocal then
                    BJI.Managers.Veh.freeze(false, ctxt.veh.gameVehicleID)
                end
                if extensions.gameplay_traffic.showMessages then
                    ui_message('ui.traffic.driveAway', 5, 'traffic', 'traffic')
                end
                BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PURSUIT_UPDATE)
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
    if isLocal and ctxt.players:length() > 1 then
        local finalVehID = targetVeh.remoteVehID ~= -1 and targetVeh.remoteVehID or targetVeh.gameVehicleID
        BJI.Tx.scenario.PursuitData({
            event = "evade",
            originPlayerID = originPlayerID,
            gameVehID = finalVehID,
        })
    end

    if ctxt.isOwner then
        if ctxt.veh.veh.isPatrol and M.policeTargets[targetVeh.gameVehicleID] == originPlayerID then -- police
            M.policeTargets[targetVeh.gameVehicleID] = nil
            BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_FAIL)
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
            elseif BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.AUTOMATIC_LIGHTS) then
                ctxt.veh.veh:queueLuaCommand('electrics.set_lightbar_signal(2)')
            end
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PURSUIT_UPDATE)
        elseif ctxt.veh.gameVehicleID == targetVeh.gameVehicleID and M.fugitivePursuit then -- fugitive
            M.fugitivePursuit = nil
            BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_SUCCESS)
            BJI.Tx.scenario.PursuitReward(false)
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
        if ctxt.veh.veh.isPatrol and M.policeTargets[targetVeh.gameVehicleID] == originPlayerID then -- police
            M.policeTargets[targetVeh.gameVehicleID] = nil
            gpsToNextTarget()
            if M.policeTargets:length() == 0 then
                ctxt.veh.veh:queueLuaCommand('electrics.set_lightbar_signal(0)')
            elseif BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.AUTOMATIC_LIGHTS) then
                ctxt.veh.veh:queueLuaCommand('electrics.set_lightbar_signal(2)')
            end
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PURSUIT_UPDATE)
        elseif ctxt.veh.gameVehicleID == targetVeh.gameVehicleID and M.fugitivePursuit then -- fugitive
            M.fugitivePursuit = nil
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

---@param ctxt TickContext
---@return string[]
local function getRestrictions(ctxt)
    return Table()
    :addAll((M.fugitivePursuit or M.policeTargets:length() > 0) and BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH or {}, true)
    :addAll(M.fugitivePursuit and BJI.Managers.Restrictions.RESETS.ALL or {}, true)
end

---@param gameVehID integer
local function onVehReset(gameVehID)
    local targetVeh = BJI.Managers.Veh.getMPVehicle(gameVehID)
    if targetVeh and M.policeTargets[gameVehID] == BJI.Managers.Context.User.playerID and targetVeh.isAi then
        pursuitEvade(BJI.Managers.Tick.getContext(), targetVeh, true, nil, true)
        gameplay_police.setPursuitMode(-1, gameVehID)
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
                    BJI.Managers.Veh.getMPVehicle(ctxt.veh.gameVehicleID) or { gameVehicleID = ctxt.veh.gameVehicleID },
                    true,
                    M.fugitivePursuit.originPlayerID)
            end
        elseif not BJI.Managers.Veh.getMPVehicles({ isAi = true }, true):any(function(v)
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
                    BJI.Managers.Veh.getMPVehicle(ctxt.veh.gameVehicleID) or { gameVehicleID = ctxt.veh.gameVehicleID },
                    true,
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
        pursuitReset(ctxt,
            BJI.Managers.Veh.getMPVehicle(ctxt.veh.gameVehicleID) or { gameVehicleID = ctxt.veh.gameVehicleID }, false,
            M.fugitivePursuit.originPlayerID)
    end
end

---@return boolean
local function isPursuitTrafficEnabled()
    return Table(extensions.gameplay_traffic.getTrafficData())
        :any(function(v) return not v.isAi end)
end

---@param gameVehID integer?
local function initPursuitTraffic(gameVehID)
    BJI.Managers.Veh.getMPVehicles({ isAI = false }, true)
        :filter(function(v) return not gameVehID or v.gameVehicleID == gameVehID end)
        :forEach(function(mpVeh)
            if not extensions.gameplay_traffic.getTrafficData()[mpVeh.gameVehicleID] then
                extensions.gameplay_traffic.insertTraffic(mpVeh.gameVehicleID, true)
            end
            extensions.gameplay_traffic.getTrafficData()[mpVeh.gameVehicleID]
                :setRole(mpVeh.veh.isPatrol and "police" or "standard")
        end)
end

---@param gameVehID integer?
local function removePursuitTraffic(gameVehID)
    Table(extensions.gameplay_traffic.getTrafficData())
        :filter(function(v)
            return not v.isAi and
                (not gameVehID or v.gameVehicleID == gameVehID)
        end)
        :forEach(function(_, vid)
            extensions.gameplay_traffic.removeTraffic(vid)
        end)
end

---@param oldGameVehID integer|-1
---@param newGameVehID integer|-1
local function onVehSwitched(oldGameVehID, newGameVehID)
    if BJI.Managers.Scenario.isServerScenarioInProgress() or
        BJI.Managers.Context.Players[BJI.Managers.Context.User.playerID].isGhost then
        return -- do not impact server scenarios and no collisions scenarios
    end
    local isPursuitTrafficOn = isPursuitTrafficEnabled()
    if newGameVehID ~= -1 then
        local mpVeh = BJI.Managers.Veh.getMPVehicle(newGameVehID, true, true)
        if not mpVeh then
            return isPursuitTrafficOn and removePursuitTraffic() or nil
        end
        local ownValidPatrolVehicle = mpVeh.isLocal and not mpVeh.isAi and
            mpVeh.isVehicle and mpVeh.veh.isPatrol
        if isPursuitTrafficOn and not ownValidPatrolVehicle then
            removePursuitTraffic()
        elseif not isPursuitTrafficOn and ownValidPatrolVehicle then
            initPursuitTraffic()
        end
    elseif isPursuitTrafficOn then
        removePursuitTraffic()
    end
end

local function onVehSpawned(mpVeh)
    if not mpVeh.isAi then
        if mpVeh.isLocal then
            onVehSwitched(-1, mpVeh.gameVehicleID)
        elseif isPursuitTrafficEnabled() then
            if mpVeh.isVehicle then
                initPursuitTraffic(mpVeh.gameVehicleID)
            else
                removePursuitTraffic(mpVeh.gameVehicleID)
            end
        end
    end
end

---@param gameVehID integer
local function onVehDelete(gameVehID)
    if M.policeTargets[gameVehID] then
        ---@diagnostic disable-next-line vehicle not exists anymore, fake it
        pursuitReset(BJI.Managers.Tick.getContext(), { gameVehicleID = gameVehID }, false, M.policeTargets[gameVehID])
    end
end

---@param ctxt TickContext
local function onScenarioChanged(ctxt)
    if BJI.Managers.Scenario.isServerScenarioInProgress() or
        ctxt.players[ctxt.user.playerID].isGhost then
        resetAll()
        if isPursuitTrafficEnabled() then
            removePursuitTraffic()
        end
    end
end

local lastPermaGhostState = false
M.onLoad = function()
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_PURSUIT_ACTION, onPursuitActionUpdate, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_VEHICLE_RESETTED, onVehReset, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_TRAFFIC_STOPPED, onTrafficStopped, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.PLAYER_DISCONNECT, onPlayerDisconnect, M._name)

    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.VEHICLE_INITIALIZED, onVehSpawned, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_VEHICLE_SWITCHED, onVehSwitched, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_VEHICLE_DESTROYED, onVehDelete, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.SCENARIO_CHANGED, onScenarioChanged, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.CACHE_LOADED, function(ctxt, data)
        if data.cache == BJI.Managers.Cache.CACHES.PLAYERS and
            ctxt.players[ctxt.user.playerID].isGhost ~= lastPermaGhostState then
            onScenarioChanged(ctxt)
        end
    end, M._name)
end

M.rxData = rxData
M.getState = getState
M.getFugitiveNametagColors = getFugitiveNametagColors
M.getRestrictions = getRestrictions

return M
