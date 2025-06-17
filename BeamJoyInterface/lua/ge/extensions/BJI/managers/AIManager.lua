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
    return extensions.gameplay_traffic.getState() == "on" or gameplay_parking.getState() == true
end

---@return tablelib<integer, integer> index 1-N, value gameVehID
local function getSelfTrafficVehiclesIDs()
    local pool = extensions.gameplay_traffic.getTrafficPool()
    return Table(pool and pool.allVehs or {}):keys():addAll(
        gameplay_parking.getParkedCarsList(), true
    ):filter(function(vid)
        return table.any(BJI.Managers.Context.User.vehicles, function(v)
            return v.gameVehID == vid
        end)
    end):sort()
end

local function isTrafficSpawned()
    return getState()
end

local function stopTraffic()
    getSelfTrafficVehiclesIDs():forEach(function(vid)
        BJI.Managers.Veh.deleteVehicle(vid)
    end)

    gameplay_parking.setState(false)
    extensions.gameplay_traffic.onTrafficStopped()
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
        extensions.gameplay_traffic.onSettingsChanged()
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
    local parkedAmount = tonumber(settings.getValue('trafficParkedAmount')) or -1
    if math.clamp(parkedAmount, 0, 5) ~= parkedAmount then
        settings.setValue('trafficParkedAmount', math.clamp(parkedAmount, 0, 5))
    end
    local usePooling = settings.getValue('trafficExtraVehicles') or false
    local usePoolingNumber = tonumber(settings.getValue('trafficExtraAmount')) or 0
    if usePooling and math.clamp(usePoolingNumber, 1, 5) ~= usePoolingNumber then
        settings.setValue('trafficExtraAmount', math.clamp(usePoolingNumber, 1, 5))
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
        local canSpawnAI = BJI.Managers.Perm.canSpawnAI() and
            BJI.Managers.Scenario.canSpawnAI() and
            not BJI.Managers.Pursuit.getState()
        if not BJI.Managers.Pursuit.getState() then
            toggle(canSpawnAI)
        end
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
    table.assign(extensions, M.baseFunctions)
end

local function initNGFunctionsWrappers()
    M.baseFunctions = {
        gameplay_traffic = {
            setupTrafficWaitForUi = extensions.gameplay_traffic.setupTrafficWaitForUi,
            deactivate = extensions.gameplay_traffic.deactivate,
        },
        gameplay_traffic_trafficUtils = {
            createPoliceGroup = extensions.gameplay_traffic_trafficUtils.createPoliceGroup,
        },
        core_multiSpawn = {
            spawnGroup = extensions.core_multiSpawn.spawnGroup,
        },
    }

    extensions.gameplay_traffic.setupTrafficWaitForUi = function(withPolice)
        if not BJI.Managers.Restrictions.getState(BJI.Managers.Restrictions._SCENARIO_DRIVEN.AI_CONTROL) then
            if withPolice then
                -- toast Police AI is disabled
                -- TODO i18n
                BJI.Managers.Toast.warning("Police AI is disabled, spawning standard traffic vehicles...")
            end
            return M.baseFunctions.gameplay_traffic.setupTrafficWaitForUi(false) -- prevent AI police in traffic
        else
            BJI.Managers.Toast.error(BJI.Managers.Lang.get("ai.toastCantSpawn"))
        end
    end

    extensions.gameplay_traffic.deactivate = function() end                               -- disable traffic pausing
    extensions.gameplay_traffic_trafficUtils.createPoliceGroup = function() return {} end -- disable AI police in traffic

    extensions.core_multiSpawn.spawnGroup = function(group, amount, options)
        if not BJI.Managers.Restrictions.getState(BJI.Managers.Restrictions._SCENARIO_DRIVEN.AI_CONTROL) then
            getSelfTrafficVehiclesIDs():forEach(function(v) BJI.Managers.Veh.deleteVehicle(v) end)

            local max = (tonumber(settings.getValue('trafficAmount')) or 2) +
                (tonumber(settings.getValue('trafficParkedAmount')) or 0)
            if settings.getValue('trafficExtraVehicles') then
                max = max + (tonumber(settings.getValue('trafficExtraAmount')) or 1)
            end

            amount = math.clamp(amount, 0, max)
            if amount > 0 then
                BJI.Managers.UI.applyLoading(true, function()
                    BJI.Managers.Veh.deleteOtherOwnVehicles()
                    M.baseFunctions.core_multiSpawn.spawnGroup(group, amount, options)
                end)
            end
            return
        else
            BJI.Managers.Toast.error(BJI.Managers.Lang.get("ai.toastCantSpawn"))
            return
        end
    end
end

-- force traffic play after creation (modded generation)
local function onVehGroupSpawned()
    extensions.gameplay_traffic.activate()
    local poolAmount = tonumber(settings.getValue('trafficExtraAmount')) or 0
    if poolAmount > 0 then
        extensions.gameplay_traffic.setActiveAmount(poolAmount)
    end
    extensions.gameplay_traffic.scatterTraffic()
end

local function onTrafficVehAdded(gameVehID)
    local markDelete, removeFromAI = false, false
    local total = (tonumber(settings.getValue('trafficAmount')) or 2) +
        (tonumber(settings.getValue('trafficParkedAmount')) or 0)
    if settings.getValue('trafficExtraVehicles') then
        total = total + (tonumber(settings.getValue('trafficExtraAmount')) or 1)
    end
    if BJI.Managers.Restrictions.getState(BJI.Managers.Restrictions._SCENARIO_DRIVEN.AI_CONTROL) or
        getSelfTrafficVehiclesIDs():length() > total then
        markDelete = true -- not allowed
    elseif BJI.Managers.Context.Players
        :filter(function(p) return p.playerID ~= BJI.Managers.Context.User.playerID end)
        :any(function(p)
            return p.vehicles:any(function(v) return v.finalGameVehID == gameVehID end)
        end) then
        removeFromAI = true -- not own veh
    end
    if markDelete then
        BJI.Managers.Veh.deleteVehicle(gameVehID)
    elseif removeFromAI then
        extensions.gameplay_traffic.removeTraffic(gameVehID)
        BJI.Managers.Collisions.forceUpdateVeh(gameVehID)
    else
        local veh = extensions.gameplay_traffic.getTrafficData()[gameVehID]
        veh.autoRole = "standard"
        veh.role.name = "standard"
    end
end

local function onLoad()
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.ON_POST_LOAD, initNGFunctionsWrappers, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.ON_UNLOAD, onUnload, M._name)

    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_TRAFFIC_STARTED, onTrafficStarted, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_TRAFFIC_STOPPED, onTrafficStopped, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_VEHICLE_GROUP_SPAWNED, onVehGroupSpawned, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_ALL_AI_MODE_CHANGED,
        extensions.gameplay_traffic.activate, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_TRAFFIC_VEHICLE_ADDED, onTrafficVehAdded, M._name)

    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.SLOW_TICK, slowTick, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.VEHICLE_REMOVED, onVehicleRemoved, M._name)
    BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        BJI.Managers.Events.EVENTS.SCENARIO_CHANGED,
        BJI.Managers.Events.EVENTS.SCENARIO_UPDATED,
        BJI.Managers.Events.EVENTS.PLAYER_CONNECT,
        BJI.Managers.Events.EVENTS.PURSUIT_UPDATE,
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
