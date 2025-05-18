---@class BJIManagerAI : BJIManager
local M = {
    _name = "AI",

    state = true,
    baseFunctions = {},

    -- caches

    ---@type tablelib<integer[]>
    aiVehs = Table(),     -- all ai cars on the server to prevent nametags
    ---@type tablelib<integer[]>
    selfVehs = Table(),   -- traffic vehs and manually toggled ones
    ---@type tablelib<integer[]>
    parkedVehs = Table(), -- parked vehs (since they are not firing the onAiModeChange event)
}

local function isTrafficSpawned()
    return gameplay_traffic and #M.selfVehs > 0 or #M.parkedVehs > 0
end

local function getCurrentSelfAIList()
    local listVehs = M.parkedVehs:clone()
    M.selfVehs:forEach(function(v)
        listVehs:insert(v)
    end)
    listVehs:sort()
    return listVehs
end

local function removeVehicles()
    M.parkedVehs:forEach(function(vid)
        BJI.Managers.Veh.deleteVehicle(vid)
    end)
    M.parkedVehs:clear()
    local newVehs = Table()
    M.selfVehs:filter(function(vid, i)
        local veh = BJI.Managers.Veh.getVehicleObject(vid)
        if not veh then M.selfVehs:remove(i) end
        if veh and not veh.isTraffic then
            newVehs:insert(vid)
        end
        return veh ~= nil and veh.isTraffic == true
    end)
        :forEach(function(vid)
            BJI.Managers.Veh.deleteVehicle(vid)
        end)
    M.selfVehs = getCurrentSelfAIList()
    BJI.Tx.player.UpdateAI(newVehs)

    gameplay_parking.deleteVehicles()
    gameplay_traffic.deleteVehicles()
end

local function toggle(state)
    if state ~= nil then
        M.state = state
    else
        M.state = not M.state
    end
    if not M.state and M.isTrafficSpawned() then
        M.removeVehicles()
    end
end

local function slowTick(ctxt)
    -- update parked vehs
    M.parkedVehs = table.filter(getAllVehicles(), function(v)
        return v.isParked == "true"
    end):map(function(v)
        return v:getId()
    end)

    --detect changes and update if needed
    if BJI.Managers.Perm.canSpawnVehicle() and M.isTrafficSpawned() then
        local listVehs = getCurrentSelfAIList()
        table.sort(BJI.Managers.Context.Players[ctxt.user.playerID].ai)
        if not listVehs:compare(BJI.Managers.Context.Players[ctxt.user.playerID].ai) then
            BJI.Tx.player.UpdateAI(listVehs)
        end
    elseif BJI.Managers.Context.Players[ctxt.user.playerID] and
        BJI.Managers.Context.Players[ctxt.user.playerID].ai and
        #BJI.Managers.Context.Players[ctxt.user.playerID].ai > 0 then
        BJI.Tx.player.UpdateAI({})
    end
end

local function updateAllAIVehicles(aiVehs)
    aiVehs:sort()
    local diff = not M.aiVehs:compare(aiVehs)
    M.aiVehs = aiVehs
    if diff then
        BJI.Managers.Collisions.checkAIVehicles()
    end
end

local function isAIVehicle(gameVehID)
    return M.aiVehs:includes(gameVehID) or
        M.selfVehs:includes(gameVehID) or
        M.parkedVehs:includes(gameVehID)
end

--- Change vehicle manual AI state
---@param gameVehID integer
---@param aiState "disabled"|"traffic"|"stop"|"script"|"flee"|"chase"|"follow"|"manual"|"span"|"random"
local function updateVehicle(gameVehID, aiState)
    local state = aiState ~= "disabled"
    if state and not M.selfVehs:includes(gameVehID) then
        M.selfVehs:insert(gameVehID)
    elseif not state and M.selfVehs:includes(gameVehID) then
        M.selfVehs:remove(M.selfVehs:indexOf(gameVehID))
    end
end

local function onVehicleRemoved()
    M.parkedVehs = M.parkedVehs:filter(function(vid)
        return BJI.Managers.Veh.getVehicleObject(vid) ~= nil
    end)
    M.selfVehs = M.selfVehs:filter(function(vid)
        return BJI.Managers.Veh.getVehicleObject(vid) ~= nil
    end)
    BJI.Tx.player.UpdateAI(getCurrentSelfAIList())
end

local function onUpdateState()
    local function _update()
        toggle(BJI.Managers.Perm.canSpawnAI() and BJI.Managers.Scenario.canSpawnAI())
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
    core_multiSpawn.spawnGroup = M.baseFunctions.spawnGroup
end

local function onLoad()
    -- ge/extensions/core/quickAccess.lua:registerDefaultMenus()

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

    BJI.Managers.Async.task(function()
        return not not core_multiSpawn.spawnGroup
    end, function()
        M.baseFunctions.spawnGroup = core_multiSpawn.spawnGroup
        core_multiSpawn.spawnGroup = function(...)
            if not BJI.Managers.Restrictions.getState(BJI.Managers.Restrictions._SCENARIO_DRIVEN.AI_CONTROL) then
                return M.baseFunctions.spawnGroup(...)
            else
                BJI.Managers.Toast.error(BJI.Managers.Lang.get("ai.toastCantSpawn"))
                return nil
            end
        end
    end, "BJIAsyncInitMultispawn")

    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.ON_UNLOAD, onUnload)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_AI_MODE_CHANGE, updateVehicle)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.SLOW_TICK, slowTick)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.VEHICLE_REMOVED, onVehicleRemoved)
    BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        BJI.Managers.Events.EVENTS.SCENARIO_CHANGED,
        BJI.Managers.Events.EVENTS.SCENARIO_UPDATED,
    }, onUpdateState)
end

M.isTrafficSpawned = isTrafficSpawned
M.removeVehicles = removeVehicles
M.toggle = toggle

M.updateAllAIVehicles = updateAllAIVehicles
M.isAIVehicle = isAIVehicle

M.onLoad = onLoad

return M
