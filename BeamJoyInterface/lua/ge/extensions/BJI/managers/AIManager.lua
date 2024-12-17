local M = {
    _name = "BJIAI",
    state = true,
    baseFunctions = {},

    -- cache
    aiCars = {},
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
        return core_multiSpawn.spawnGroup
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

local function isTrafficSpawned()
    return gameplay_traffic and gameplay_traffic.getState() == "on"
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
        local listVehs = {}
        for _, v in ipairs(getAllVehicles()) do
          if v.isTraffic == "true" or v.isParked == "true" then
            table.insert(listVehs, v:getId())
          end
        end
        table.sort(listVehs)
        table.sort(BJIContext.Players[ctxt.user.playerID].ai)
        if not tshallowcompare(listVehs, BJIContext.Players[ctxt.user.playerID].ai) then
            BJITx.player.UpdateAI(listVehs)
        end
    elseif BJIContext.Players[ctxt.user.playerID] and
        BJIContext.Players[ctxt.user.playerID].ai and
        #BJIContext.Players[ctxt.user.playerID].ai > 0 then
        BJITx.player.UpdateAI({})
    end
end

local function updateVehicles()
    M.aiCars = {}
    for playerID, player in pairs(BJIContext.Players) do
        local isSelf = BJIContext.isSelf(playerID)
        if #player.ai > 0 then
            for _, aiVehID in ipairs(player.ai) do
                if isSelf then
                    if BJIVeh.getVehicleObject(aiVehID) then
                        table.insert(M.aiCars, aiVehID)
                    end
                else
                    local gameVehID = BJIVeh.getGameVehIDByRemoteVehID(aiVehID)
                    if BJIVeh.getVehicleObject(gameVehID) then
                        table.insert(M.aiCars, gameVehID)
                    end
                end
            end
        end
    end
end

local function isAIVehicle(gameVehID)
    return tincludes(M.aiCars, gameVehID, true)
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

RegisterBJIManager(M)
return M
