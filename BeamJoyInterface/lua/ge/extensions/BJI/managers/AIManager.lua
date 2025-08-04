---@class BJIManagerAI : BJIManager
local M = {
    _name = "AI",

    maxTraffic = 20,

    state = true,
    baseFunctions = {},
}

---@return boolean
local function getState()
    return extensions.gameplay_traffic.getState() == "on" or gameplay_parking.getState() == true
end

---@return tablelib<integer, integer> index 1-N, value gameVehID
local function getSelfTrafficVehiclesIDs()
    return Table(extensions.gameplay_traffic.getTrafficAiVehIds())
        :addAll(extensions.gameplay_parking.getParkedCarsList())
        :sort()
end

local function stopTraffic()
    getSelfTrafficVehiclesIDs()
        :forEach(function(vid) BJI_Veh.deleteVehicle(vid) end)
end

local function toggle(state)
    if state ~= nil then
        M.state = state
    else
        M.state = not M.state
    end
    if not M.state and M.getState() then
        M.stopTraffic()
    end
end

---@param gameVehID integer
---@return boolean
local function isSelfAIVehicle(gameVehID)
    local veh = BJI_Veh.getMPVehicle(gameVehID, true, true)
    return veh ~= nil and veh.isAi
end

---@param gameVehID integer
---@return boolean
local function isRemoteAIVehicle(gameVehID)
    local veh = BJI_Veh.getMPVehicle(gameVehID, false, true)
    return veh ~= nil and veh.isAi
end

---@param gameVehID integer
---@return boolean
local function isAIVehicle(gameVehID)
    local veh = BJI_Veh.getMPVehicle(gameVehID, nil, true)
    return veh ~= nil and veh.isAi
end

local function onTrafficStarted()
    BJI_UI.applyLoading(false)
    BJI_Veh.getMPVehicles(nil, true):forEach(function(mpVeh)
        local vehTraffic = extensions.gameplay_traffic.getTrafficData()[mpVeh.gameVehicleID]
        if not mpVeh.isLocal and not vehTraffic then
            extensions.gameplay_traffic.insertTraffic(mpVeh.gameVehicleID, true, true)
        elseif mpVeh.isLocal and mpVeh.isAi then
            if not vehTraffic then
                extensions.gameplay_traffic.insertTraffic(mpVeh.gameVehicleID)
                vehTraffic = extensions.gameplay_traffic.getTrafficData()[mpVeh.gameVehicleID]
            end
            vehTraffic:setAiMode("traffic")
            core_vehicleBridge.executeAction(mpVeh.veh, 'setAIMode', "traffic") -- force launch traffic
        end
    end)
end

---@param ctxt TickContext
---@return string[]
local function getRestrictions(ctxt)
    if not BJI_Cache.areBaseCachesFirstLoaded() or not BJI.CLIENT_READY then
        return {}
    end

    local canSpawnAI = BJI_Perm.canSpawnAI() and
        BJI_Scenario.canSpawnAI() and
        not BJI_Pursuit.getState()
    if not BJI_Pursuit.getState() then
        toggle(canSpawnAI)
    end

    return M.state and {} or BJI_Restrictions._SCENARIO_DRIVEN.AI_CONTROL
end

local function initNGFunctionsWrappers()
    M.baseFunctions = {
        gameplay_traffic = {
            setupTrafficWaitForUi = extensions.gameplay_traffic.setupTrafficWaitForUi,
            activate = extensions.gameplay_traffic.activate,
            setTrafficVars = extensions.gameplay_traffic.setTrafficVars,
            trackAIAllVeh = extensions.gameplay_traffic.trackAIAllVeh,
            setActiveAmount = extensions.gameplay_traffic.setActiveAmount,
            deactivate = extensions.gameplay_traffic.deactivate,
        },
        core_multiSpawn = {
            spawnGroup = extensions.core_multiSpawn.spawnGroup,
        },
    }

    extensions.gameplay_traffic.setupTrafficWaitForUi = function(withPolice)
        if not BJI_Restrictions.getState(BJI_Restrictions._SCENARIO_DRIVEN.AI_CONTROL) then
            if withPolice then
                BJI_Toast.warning(BJI_Lang.get("ai.policeDisabled"))
            end
            return M.baseFunctions.gameplay_traffic.setupTrafficWaitForUi(false)
        else
            BJI_Toast.error(BJI_Lang.get("ai.toastCantSpawn"))
        end
    end

    extensions.gameplay_traffic.activate = function(vehList, ignoreFilter)
        if not vehList then
            local ownVehs = BJI_Veh.getMPOwnVehicles(true)
            vehList = Table(getAllVehiclesByType()):filter(function(veh)
                return not veh.isParked and ownVehs:any(function(v)
                    return v.gameVehicleID == veh:getID() and v.isAi
                end)
            end):map(function(veh) return veh:getID() end)
        end
        M.baseFunctions.gameplay_traffic.activate(vehList, ignoreFilter)
    end

    extensions.gameplay_traffic.setTrafficVars = function(data, reset)
        if not BJI_Restrictions.getState(BJI_Restrictions._SCENARIO_DRIVEN.AI_CONTROL) then
            data = data or {}
            if data.aiMode and data.aiMode ~= "traffic" then
                BJI_Toast.warning(BJI_Lang.get("ai.onlyTrafficModeEnabled"))
            end
            data.aiMode = "traffic"
            M.baseFunctions.gameplay_traffic.setTrafficVars(data, reset)
        end
    end

    extensions.gameplay_traffic.trackAIAllVeh = function(mode)
        if not BJI_Restrictions.getState(BJI_Restrictions._SCENARIO_DRIVEN.AI_CONTROL) then
            if mode ~= "traffic" then
                BJI_Toast.warning(BJI_Lang.get("ai.onlyTrafficModeEnabled"))
            end
            M.baseFunctions.gameplay_traffic.trackAIAllVeh("traffic")
        end
    end

    extensions.gameplay_traffic.setActiveAmount = function(amount)
        if not BJI_Restrictions.getState(BJI_Restrictions._SCENARIO_DRIVEN.AI_CONTROL) then
            amount = math.min(amount,
                M.maxTraffic - table.filter(BJI_Context.Players[BJI_Context.User.playerID].vehicles,
                    function(v) return not v.isAi end):length())
            M.baseFunctions.gameplay_traffic.setActiveAmount(amount)
        end
    end

    extensions.gameplay_traffic.deactivate = function()
        BJI_Toast.warning(BJI_Lang.get("ai.onlyTrafficModeEnabled"))
    end

    extensions.core_multiSpawn.spawnGroup = function(group, amount, options)
        if not BJI_Restrictions.getState(BJI_Restrictions._SCENARIO_DRIVEN.AI_CONTROL) then
            local currentAIAmount = table.filter(BJI_Context.Players[BJI_Context.User.playerID].vehicles,
                function(v) return v.isAi end):length()
            if currentAIAmount >= M.maxTraffic then
                return BJI_Toast.error(BJI_Lang.get("ai.limitReached")
                    :var({ amount = M.maxTraffic }))
            end
            if amount then
                amount = math.min(amount,
                    M.maxTraffic - currentAIAmount)
            end
            M.baseFunctions.core_multiSpawn.spawnGroup(group, amount, options)
        else
            BJI_Toast.error(BJI_Lang.get("ai.toastCantSpawn"))
        end
    end
end

local function onUnload()
    RollBackNGFunctionsWrappers(M.baseFunctions)
end

-- force traffic play after creation (modded generation)
local function onVehGroupSpawned(vehIds)
    local vehs = {}
    BJI_Async.task(function()
        table.filter(vehIds, function(vid)
            return not vehs[vid]
        end):forEach(function(vid)
            vehs[vid] = BJI_Veh.getMPVehicle(vid, true, true)
        end)
        return table.length(vehIds) == table.length(vehs)
    end, function()
        extensions.gameplay_traffic.activate()
    end)
end

local function onLoad()
    BJI_Events.addListener(BJI_Events.EVENTS.ON_POST_LOAD, initNGFunctionsWrappers, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.ON_UNLOAD, onUnload, M._name)

    BJI_Events.addListener(BJI_Events.EVENTS.NG_TRAFFIC_STARTED, onTrafficStarted, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.NG_VEHICLE_GROUP_SPAWNED, onVehGroupSpawned, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.NG_ALL_AI_MODE_CHANGED,
        extensions.gameplay_traffic.activate, M._name)
end

M.getState = getState
M.stopTraffic = stopTraffic
M.toggle = toggle

M.isSelfAIVehicle = isSelfAIVehicle
M.isRemoteAIVehicle = isRemoteAIVehicle
M.isAIVehicle = isAIVehicle

M.getRestrictions = getRestrictions

M.onLoad = onLoad

return M
