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

local function removeVehicles()
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
        local listVehs = M.parkedVehs:clone()
        M.selfVehs:forEach(function(v)
            listVehs:insert(v)
        end)
        listVehs:sort()
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
        LogWarn("Add AI vehicle")
        M.selfVehs:insert(gameVehID)
    elseif not state and M.selfVehs:includes(gameVehID) then
        LogWarn("Remove AI vehicle")
        M.selfVehs:remove(M.selfVehs:indexOf(gameVehID))
    end
end

local listeners = Table()

local function onUnload()
    gameplay_traffic.setupTrafficWaitForUi = M.baseFunctions.setupTrafficWaitForUi
    gameplay_traffic.createTrafficGroup = M.baseFunctions.createTrafficGroup
    core_multiSpawn.spawnGroup = M.baseFunctions.spawnGroup

    listeners:forEach(BJI.Managers.Events.removeListener)
end

local function onLoad()
    -- ge/extensions/core/quickAccess.lua:registerDefaultMenus()

    M.baseFunctions.setupTrafficWaitForUi = gameplay_traffic.setupTrafficWaitForUi
    gameplay_traffic.setupTrafficWaitForUi = function(...)
        if not BJI.Managers.Restrictions.getState(BJI.Managers.Restrictions.OTHER.AI_CONTROL) then
            return M.baseFunctions.setupTrafficWaitForUi(...)
        else
            BJI.Managers.Toast.error(BJI.Managers.Lang.get("ai.toastCantSpawn"))
        end
    end

    M.baseFunctions.createTrafficGroup = gameplay_traffic.createTrafficGroup
    gameplay_traffic.createTrafficGroup = function(...)
        if not BJI.Managers.Restrictions.getState(BJI.Managers.Restrictions.OTHER.AI_CONTROL) then
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
            if not BJI.Managers.Restrictions.getState(BJI.Managers.Restrictions.OTHER.AI_CONTROL) then
                return M.baseFunctions.spawnGroup(...)
            else
                BJI.Managers.Toast.error(BJI.Managers.Lang.get("ai.toastCantSpawn"))
                return nil
            end
        end
    end, "BJIAsyncInitMultispawn")

    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.VEHICLE_REMOVED, function()
        M.selfVehs = M.selfVehs:filter(function(gameVehID)
            return BJI.Managers.Veh.getVehicleObject(gameVehID) ~= nil
        end)

        M.parkedVehs = M.parkedVehs:filter(function(gameVehID)
            return BJI.Managers.Veh.getVehicleObject(gameVehID) ~= nil
        end)
    end))
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.ON_UNLOAD, onUnload))
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_AI_MODE_CHANGE, updateVehicle))
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.SLOW_TICK, slowTick))
end

M.isTrafficSpawned = isTrafficSpawned
M.removeVehicles = removeVehicles
M.toggle = toggle

M.updateAllAIVehicles = updateAllAIVehicles
M.isAIVehicle = isAIVehicle

M.onLoad = onLoad

return M
