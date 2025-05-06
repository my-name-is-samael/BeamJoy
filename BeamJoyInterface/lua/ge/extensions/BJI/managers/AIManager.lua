local M = {
    _name = "BJIAI",
    state = true,
    baseFunctions = {},

    -- cache

    ---@type tablelib<integer[]>
    aiVehs = Table(),     -- all ai cars on the server to prevent nametags
    ---@type tablelib<integer[]>
    selfVehs = Table(),   -- traffic vehs and manually toggled ones
    ---@type tablelib<integer[]>
    parkedVehs = Table(), -- parked vehs (since they are not firing the onAiModeChange event)
}

local listeners = Table()
local function onLoad()
    -- ge/extensions/core/quickAccess.lua:registerDefaultMenus()

    M.baseFunctions.setupTrafficWaitForUi = gameplay_traffic.setupTrafficWaitForUi
    gameplay_traffic.setupTrafficWaitForUi = function(...)
        if M.canSpawnAI() then
            return M.baseFunctions.setupTrafficWaitForUi(...)
        else
            BJIToast.error(BJILang.get("ai.toastCantSpawn"))
        end
    end

    M.baseFunctions.createTrafficGroup = gameplay_traffic.createTrafficGroup
    gameplay_traffic.createTrafficGroup = function(...)
        if M.canSpawnAI() then
            return M.baseFunctions.createTrafficGroup(...)
        else
            -- BJIToast.error(BJILang.get("ai.toastCantSpawn"))
            return nil
        end
    end

    BJIAsync.task(function()
        return not not core_multiSpawn.spawnGroup
    end, function()
        M.baseFunctions.spawnGroup = core_multiSpawn.spawnGroup
        core_multiSpawn.spawnGroup = function(...)
            if M.canSpawnAI() then
                return M.baseFunctions.spawnGroup(...)
            else
                BJIToast.error(BJILang.get("ai.toastCantSpawn"))
                return nil
            end
        end
    end, "BJIAsyncInitMultispawn")

    listeners:insert(BJIEvents.addListener(BJIEvents.EVENTS.VEHICLE_REMOVED, function()
        M.selfVehs = M.selfVehs:filter(function(gameVehID)
            return BJIVeh.getVehicleObject(gameVehID) ~= nil
        end)

        M.parkedVehs = M.parkedVehs:filter(function(gameVehID)
            return BJIVeh.getVehicleObject(gameVehID) ~= nil
        end)
    end))
end

local function onUnload()
    gameplay_traffic.setupTrafficWaitForUi = M.baseFunctions.setupTrafficWaitForUi
    gameplay_traffic.createTrafficGroup = M.baseFunctions.createTrafficGroup
    core_multiSpawn.spawnGroup = M.baseFunctions.spawnGroup

    listeners:forEach(BJIEvents.removeListener)
end

local function canSpawnAI()
    return M.state and BJIScenario.canSpawnAI()
end

local function isTrafficSpawned()
    return gameplay_traffic and #M.selfVehs > 0 or #M.parkedVehs > 0
end

local function removeVehicles()
    gameplay_parking.deleteVehicles()
    gameplay_traffic.deleteVehicles()
end

local function toggle(state)
    M.state = state ~= nil and state or not M.state
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
    if BJIPerm.canSpawnVehicle() and M.isTrafficSpawned() then
        local listVehs = M.parkedVehs:clone()
        M.selfVehs:forEach(function(v)
            listVehs:insert(v)
        end)
        listVehs:sort()
        table.sort(BJIContext.Players[ctxt.user.playerID].ai)
        if not listVehs:compare(BJIContext.Players[ctxt.user.playerID].ai) then
            BJITx.player.UpdateAI(listVehs)
        end
    elseif BJIContext.Players[ctxt.user.playerID] and
        BJIContext.Players[ctxt.user.playerID].ai and
        #BJIContext.Players[ctxt.user.playerID].ai > 0 then
        BJITx.player.UpdateAI({})
    end
end

local function updateAllAIVehicles(aiVehs)
    M.aiVehs = aiVehs
end

local function isAIVehicle(gameVehID)
    return M.aiVehs:includes(gameVehID) or
        M.selfVehs:includes(gameVehID) or
        M.parkedVehs:includes(gameVehID)
end

--- Change vehicle manual AI state
---@param gameVehID integer
---@param aiState boolean
local function updateVehicle(gameVehID, aiState)
    if aiState and not M.selfVehs:includes(gameVehID) then
        M.selfVehs:insert(gameVehID)
    elseif not aiState and M.selfVehs:includes(gameVehID) then
        M.selfVehs:remove(M.selfVehs:indexOf(gameVehID))
    end
end

M.onLoad = onLoad
M.onUnload = onUnload

M.canSpawnAI = canSpawnAI
M.isTrafficSpawned = isTrafficSpawned
M.removeVehicles = removeVehicles
M.toggle = toggle

M.slowTick = slowTick

M.updateVehicles = updateAllAIVehicles
M.isAIVehicle = isAIVehicle
M.updateVehicle = updateVehicle

RegisterBJIManager(M)
return M
