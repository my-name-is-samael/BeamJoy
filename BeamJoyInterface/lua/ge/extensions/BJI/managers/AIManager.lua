---@class BJIManagerAI : BJIManager
local M = {
    _name = "AI",

    state = true,
    baseFunctions = {},

    -- caches

    ---@type tablelib<integer, integer> index 1-N, value gameVehID
    remoteAIVehs = Table(), -- all ai cars on the server to prevent nametags
}

---@return boolean
local function getState()
    return gameplay_traffic.getState() == "on" or gameplay_parking.getState() == true
end

---@return tablelib<integer, integer> index 1-N, value gameVehID
local function getSelfTrafficVehiclesIDs()
    local pool = gameplay_traffic.getTrafficPool()
    return Table(pool and pool.allVehs or {}):keys():addAll(
        gameplay_parking.getParkedCarsList(), true
    ):sort()
end

local function isTrafficSpawned()
    return getState()
end

local function stopTraffic()
    if gameplay_parking.getState() then
        gameplay_parking.deleteVehicles()
        gameplay_parking.setState(false)
    end
    if gameplay_traffic.getState() == "on" then
        gameplay_traffic.onTrafficStopped()
    end

    BJI.Tx.player.UpdateAI(getSelfTrafficVehiclesIDs())
end

local function toggle(state)
    if state ~= nil then
        M.state = state
    else
        M.state = not M.state
    end
    if not M.state and M.isTrafficSpawned() then
        M.stopTraffic()
    end
end

local function slowTick(ctxt)
    -- CHECK CLIENT SETTINGS

    -- live settings
    local settingsChanged = false
    if settings.getValue('trafficEnableSwitching') then
        settings.setValue('trafficEnableSwitching', false)
        settingsChanged = true
    end
    if settings.getValue('trafficMinimap') then
        settings.setValue('trafficMinimap', false)
        settingsChanged = true
    end
    if settingsChanged then
        gameplay_traffic.onSettingsChanged()
    end

    -- on traffic spawn settings
    if not settings.getValue('trafficSimpleVehicles') then
        settings.setValue('trafficSimpleVehicles', true)
    end
    if settings.getValue('trafficAllowMods') then
        settings.setValue('trafficAllowMods', false)
    end
    local trafficAmount = tonumber(settings.getValue('trafficAmount')) or 0
    if math.clamp(trafficAmount, 2, 10) ~= trafficAmount then
        settings.setValue('trafficAmount', math.clamp(trafficAmount, 2, 10))
    end
    local parkedAmount = tonumber(settings.getValue('trafficParkedAmount')) or 0
    if math.clamp(parkedAmount, 1, 5) ~= parkedAmount then
        settings.setValue('trafficParkedAmount', math.clamp(parkedAmount, 1, 5))
    end
end

---@param remoteAiIDs tablelib<integer, integer> index 1-N, value gameVehID
local function updateRemoteAIVehicles(remoteAiIDs)
    local ctxt = BJI.Managers.Tick.getContext()
    local diff = not M.remoteAIVehs:compare(remoteAiIDs)
    M.remoteAIVehs = remoteAiIDs
    if diff then
        local needSwitch = false
        remoteAiIDs:forEach(function(vid)
            local veh = BJI.Managers.Veh.getVehicleObject(vid)
            -- remove AIs from minimap
            if veh then
                veh.uiState = 0
                veh.playerUsable = false
                if ctxt.veh and ctxt.veh:getID() == veh:getID() then
                    needSwitch = true
                end
            end
        end)
        if needSwitch then
            BJI.Managers.Veh.focusNextVehicle()
        end
    end
end

---@param gameVehID integer
---@return boolean
local function isSelfAIVehicle(gameVehID)
    return getSelfTrafficVehiclesIDs():includes(gameVehID)
end

---@param gameVehID integer
---@return boolean
local function isRemoteAIVehicle(gameVehID)
    return M.remoteAIVehs:includes(gameVehID)
end

---@param gameVehID integer
---@return boolean
local function isAIVehicle(gameVehID)
    return isSelfAIVehicle(gameVehID) or isRemoteAIVehicle(gameVehID)
end

local function onTrafficStarted()
    BJI.Managers.UI.applyLoading(false)
    local ais = getSelfTrafficVehiclesIDs()
    BJI.Tx.player.UpdateAI(ais)
    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.VEHICLES_UPDATED)
end

local function onTrafficStopped()
    BJI.Tx.player.UpdateAI({})
    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.VEHICLES_UPDATED)
end

local function onVehicleRemoved()
    local aiList = getSelfTrafficVehiclesIDs()
    local ctxt = BJI.Managers.Tick.getContext()
    if not table.compare(aiList, ctxt.players[ctxt.user.playerID].ai) then
        BJI.Tx.player.UpdateAI(aiList)
    end
end

local function onUpdate()
    local function _update()
        local canSpawnAI = BJI.Managers.Scenario.canSpawnAI()
        if canSpawnAI then
            if BJI.Managers.Context.Players:length() == 1 then
                -- if alone on the server and can spawn veh, then can spawn traffic too
                canSpawnAI = BJI.Managers.Perm.canSpawnVehicle()
            else
                canSpawnAI = BJI.Managers.Perm.canSpawnAI()
            end
        end
        toggle(canSpawnAI)
        BJI.Managers.Restrictions.update({
            {
                -- update AI restriction
                restrictions = BJI.Managers.Restrictions._SCENARIO_DRIVEN.AI_CONTROL,
                state = not M.state and BJI.Managers.Restrictions.STATE.RESTRICTED,
            }
        })
    end

    if BJI.Managers.Cache.areBaseCachesFirstLoaded() and BJI.CLIENT_READY then
        _update()
    else
        BJI.Managers.Async.task(function()
            return BJI.Managers.Cache.areBaseCachesFirstLoaded() and BJI.CLIENT_READY
        end, _update)
    end
end

local function onUnload()
    gameplay_traffic.setupTrafficWaitForUi = M.baseFunctions.setupTrafficWaitForUi
    gameplay_traffic.createTrafficGroup = M.baseFunctions.createTrafficGroup
    extensions.core_multiSpawn.spawnGroup = M.baseFunctions.spawnGroup
end

local function iniNGFunctionsWrappers()
    M.baseFunctions.setupTrafficWaitForUi = gameplay_traffic.setupTrafficWaitForUi
    gameplay_traffic.setupTrafficWaitForUi = function(...)
        if not BJI.Managers.Restrictions.getState(BJI.Managers.Restrictions._SCENARIO_DRIVEN.AI_CONTROL) then
            return M.baseFunctions.setupTrafficWaitForUi(...)
        else
            BJI.Managers.Toast.error(BJI.Managers.Lang.get("ai.toastCantSpawn"))
        end
    end

    M.baseFunctions.createTrafficGroup = gameplay_traffic.createTrafficGroup
    gameplay_traffic.createTrafficGroup = function(...)
        if not BJI.Managers.Restrictions.getState(BJI.Managers.Restrictions._SCENARIO_DRIVEN.AI_CONTROL) then
            return M.baseFunctions.createTrafficGroup(...)
        else
            -- BJIToast.error(BJILang.get("ai.toastCantSpawn"))
            return nil
        end
    end

    M.baseFunctions.deactivate = gameplay_traffic.deactivate
    gameplay_traffic.deactivate = function(...)
        -- disable traffic stopping
    end

    M.baseFunctions.spawnGroup = extensions.core_multiSpawn.spawnGroup
    extensions.core_multiSpawn.spawnGroup = function(...)
        if not BJI.Managers.Restrictions.getState(BJI.Managers.Restrictions._SCENARIO_DRIVEN.AI_CONTROL) then
            BJI.Managers.UI.applyLoading(true)
            return M.baseFunctions.spawnGroup(...)
        else
            BJI.Managers.Toast.error(BJI.Managers.Lang.get("ai.toastCantSpawn"))
            return nil
        end
    end
end

local function onLoad()
    iniNGFunctionsWrappers()
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.ON_UNLOAD, onUnload, M._name)

    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_TRAFFIC_STARTED, onTrafficStarted, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_TRAFFIC_STOPPED, onTrafficStopped, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_VEHICLE_GROUP_SPAWNED, function()
        -- force traffic start after spawn
        extensions.gameplay_traffic.activate()
        local poolAmount = tonumber(settings.getValue('trafficExtraAmount')) or 0
        if poolAmount > 0 then
            extensions.gameplay_traffic.setActiveAmount(poolAmount)
        end
        extensions.gameplay_traffic.scatterTraffic()
    end, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_ALL_AI_MODE_CHANGED, function()
        -- force regular traffic mode
        gameplay_traffic.activate()
    end)

    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.SLOW_TICK, slowTick, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.VEHICLE_REMOVED, onVehicleRemoved, M._name)
    BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        BJI.Managers.Events.EVENTS.SCENARIO_CHANGED,
        BJI.Managers.Events.EVENTS.SCENARIO_UPDATED,
        BJI.Managers.Events.EVENTS.PLAYER_CONNECT,
        BJI.Managers.Events.EVENTS.PLAYER_DISCONNECT,
    }, onUpdate, M._name)
end

M.isTrafficSpawned = isTrafficSpawned
M.stopTraffic = stopTraffic
M.toggle = toggle

M.updateRemoteAIVehicles = updateRemoteAIVehicles
M.isSelfAIVehicle = isSelfAIVehicle
M.isRemoteAIVehicle = isRemoteAIVehicle
M.isAIVehicle = isAIVehicle

M.onLoad = onLoad

return M
