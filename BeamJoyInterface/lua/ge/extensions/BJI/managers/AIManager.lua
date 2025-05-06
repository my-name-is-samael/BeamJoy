local M = {
    _name = "BJIAI",
    state = true,
    baseFunctions = {},

    -- cache

    ---@type tablelib<integer[]>
    aiCars = Table(),      -- all ai cars on the server to prevent nametags
    ---@type tablelib<integer[]>
    addedCars = Table(),   -- user cars the player toggled auto drive on
    ---@type tablelib<integer[]>
    removedCars = Table(), -- traffic cars the player toggled auto drive off
}

local function onLoad()
    -- ge/extensions/core/quickAccess.lua:registerDefaultMenus()

    M.baseFunctions.setupTrafficWaitForUi = gameplay_traffic.setupTrafficWaitForUi
    gameplay_traffic.setupTrafficWaitForUi = function(...)
        if M.canToggleAI() then
            return M.baseFunctions.setupTrafficWaitForUi(...)
        else
            BJIToast.error(BJILang.get("ai.toastCantSpawn"))
        end
    end

    M.baseFunctions.createTrafficGroup = gameplay_traffic.createTrafficGroup
    gameplay_traffic.createTrafficGroup = function(...)
        if M.canToggleAI() then
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
            if M.canToggleAI() then
                return M.baseFunctions.spawnGroup(...)
            else
                BJIToast.error(BJILang.get("ai.toastCantSpawn"))
                return nil
            end
        end
    end, "BJIAsyncInitMultispawn")
end

local function onUnload()
    gameplay_traffic.setupTrafficWaitForUi = M.baseFunctions.setupTrafficWaitForUi
    gameplay_traffic.createTrafficGroup = M.baseFunctions.createTrafficGroup
    core_multiSpawn.spawnGroup = M.baseFunctions.spawnGroup
end

local function canToggleAI()
    return M.state and BJIScenario.canSpawnAI()
end

---@return tablelib<integer[]>
local function getSelfTrafficCars()
    return table.filter(getAllVehicles(), function(v)
        return v.isTraffic == "true" or v.isParked == "true"
    end):map(function(v)
        return v:getId()
    end)
end

---@return tablelib<integer[]>
local function getAllSelfAICars()
    local vehs = getSelfTrafficCars():filter(function(id)
        return not M.removedCars:includes(id)
    end)
    M.addedCars:forEach(function(v)
        vehs:insert(v)
    end)
    return vehs:sort()
end

local function isTrafficSpawned()
    return gameplay_traffic and #getAllSelfAICars() > 0
end

local function removeVehicles()
    gameplay_parking.deleteVehicles()
    gameplay_traffic.deleteVehicles()
end

local function update(state)
    if state ~= M.state then
        local previous = M.state
        M.state = state
        if previous and not M.state and M.isTrafficSpawned() then
            M.removeVehicles()
        end
    end
end

local function toggle(state)
    state = state ~= nil and state or not M.isTrafficSpawned()
    if state then
        if M.canToggleAI() and not M.isTrafficSpawned() then
            M.baseFunctions()
        end
    else
        if M.isTrafficSpawned() then
            M.removeVehicles()
        end
    end
end

local function slowTick(ctxt)
    if BJIPerm.canSpawnVehicle() and M.isTrafficSpawned() then
        local listVehs = getAllSelfAICars()
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

local function updateVehicles()
    M.aiCars = Table()
    for playerID, player in pairs(BJIContext.Players) do
        local isSelf = BJIContext.isSelf(playerID)
        if #player.ai > 0 then
            for _, aiVehID in ipairs(player.ai) do
                if isSelf then
                    if BJIVeh.getVehicleObject(aiVehID) then
                        M.aiCars:insert(aiVehID)
                    end
                else
                    local gameVehID = BJIVeh.getGameVehIDByRemoteVehID(aiVehID)
                    if BJIVeh.getVehicleObject(gameVehID) then
                        M.aiCars:insert(gameVehID)
                    end
                end
            end
        end
    end
end

local function isAIVehicle(gameVehID)
    return M.aiCars:includes(gameVehID)
end

--- Change vehicle manual AI state
---@param gameVehID integer
---@param aiState boolean
local function updateVehicle(gameVehID, aiState)
    local trafficCars = getSelfTrafficCars()
    if aiState then
        if M.removedCars:includes(gameVehID) then
            M.removedCars:remove(M.removedCars:indexOf(gameVehID))
        elseif not trafficCars:includes(gameVehID) and not M.addedCars:includes(gameVehID) then
            M.addedCars:insert(gameVehID)
        end
    else
        if M.addedCars:includes(gameVehID) then
            M.addedCars:remove(M.addedCars:indexOf(gameVehID))
        elseif trafficCars:includes(gameVehID) and
            not M.removedCars:includes(gameVehID) then
            M.removedCars:insert(gameVehID)
        end
    end
end

M.onLoad = onLoad
M.onUnload = onUnload

M.canToggleAI = canToggleAI
M.isTrafficSpawned = isTrafficSpawned
M.removeVehicles = removeVehicles
M.update = update
M.toggle = toggle

M.slowTick = slowTick

M.updateVehicles = updateVehicles
M.isAIVehicle = isAIVehicle
M.updateVehicle = updateVehicle

RegisterBJIManager(M)
return M
