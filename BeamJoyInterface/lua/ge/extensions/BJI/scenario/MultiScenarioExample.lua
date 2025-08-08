---@class BJIScenarioMultiExample : BJIScenario
local S = {
    _name = "MultiExample",
    _key = "MULTI_EXAMPLE",
    _isSolo = false,
    _skip = true,
}

-- can switch to scenario hook
local function canChangeTo(ctxt)
    return false
end

-- load hook
local function onLoad(ctxt)
end

-- unload hook (before switch to another scenario)
local function onUnload(ctxt)
end

---@param ctxt TickContext
---@return string[]
local function getRestrictions(ctxt)
    return Table():addAll(BJI_Restrictions.OTHER.VEHICLE_SWITCH, true)
        :addAll(BJI_Restrictions.OTHER.PHOTO_MODE, true)
end

---@param gameVehID integer
---@param resetType string BJI_Input.INPUTS
---@return boolean
local function canReset(gameVehID, resetType)
    return BJI_Veh.isVehicleOwn(gameVehID) or resetType == BJI_Input.INPUTS.RECOVER
end

---@param gameVehID integer
---@return number -1 = infinite, 0 = disabled, >0 = seconds
local function getRewindLimit(gameVehID)
    return -1
end

---@param gameVehID integer
---@param resetType string BJI_Input.INPUTS
---@param baseCallback fun()
---@return boolean
local function tryReset(gameVehID, resetType, baseCallback)
    baseCallback()
    return true
end

-- player vehicle spawn hook
---@param mpVeh BJIMPVehicle
local function onVehicleSpawned(mpVeh)
end

-- player vehicle drop at camera hook
local function onDropPlayerAtCamera()
end

-- player vehicle drop at camera without reset hook
local function onDropPlayerAtCameraNoReset()
end

-- player vehicle reset hook
local function onVehicleResetted(gameVehID)
end

-- player vehicle switch hook
local function onVehicleSwitched(oldGameVehID, newGameVehID)
end

-- player vehicle destroy hook
local function onVehicleDestroyed(gameVehID)
end

-- player vehicle update hook
local function updateVehicles()
end

-- can player refuel at a station
local function canRefuelAtStation()
end

-- can player repair vehicle at a garage
local function canRepairAtGarage()
end

-- player garage repair hook
local function onGarageRepair()
end

-- player teleport to player hook
local function tryTeleportToPlayer(playerID, forced)
end

-- player teleport to position hook
local function tryTeleportToPos(pos, saveHome)
end

-- player vehicle focus hook
local function tryFocus(targetID)
end

-- can player spawn AI
local function canSpawnAI()
end

-- can player spawn new vehicle
local function canSpawnNewVehicle()
end

-- can player replace vehicle
local function canReplaceVehicle()
end

-- can player delete vehicle
local function canDeleteVehicle()
end

-- can player delete other vehicles
local function canDeleteOtherVehicles()
end

-- vehicle model list getter
local function getModelList()
end

-- per vehicle show nametag
local function doShowNametag(vehData)
end

local function getCollisionsType(ctxt)
    return BJI_Collisions.TYPES.GHOSTS
end

-- player list contextual actions getter
local function getPlayerListActions(player)
    return {}
end

-- each frame tick hook
local function renderTick(ctxt)
end

-- max 4x/sec tick
local function fastTick(ctxt)
end

-- each second tick hook
local function slowTick(ctxt)
end

S.canChangeTo = canChangeTo
S.onLoad = onLoad
S.onUnload = onUnload

S.getRestrictions = getRestrictions

S.canReset = canReset
S.getRewindLimit = getRewindLimit
S.tryReset = tryReset

S.onVehicleSpawned = onVehicleSpawned
S.onDropPlayerAtCamera = onDropPlayerAtCamera
S.onDropPlayerAtCameraNoReset = onDropPlayerAtCameraNoReset
S.onVehicleResetted = onVehicleResetted
S.onVehicleSwitched = onVehicleSwitched
S.onVehicleDestroyed = onVehicleDestroyed
S.updateVehicles = updateVehicles
S.canRefuelAtStation = canRefuelAtStation
S.canRepairAtGarage = canRepairAtGarage
S.onGarageRepair = onGarageRepair
S.tryTeleportToPlayer = tryTeleportToPlayer
S.tryTeleportToPos = tryTeleportToPos
S.tryFocus = tryFocus
S.canSpawnAI = canSpawnAI
S.canSpawnNewVehicle = canSpawnNewVehicle
S.canReplaceVehicle = canReplaceVehicle
S.canDeleteVehicle = canDeleteVehicle
S.canDeleteOtherVehicles = canDeleteOtherVehicles
S.getModelList = getModelList
S.doShowNametag = doShowNametag
S.getCollisionsType = getCollisionsType

S.getPlayerListActions = getPlayerListActions

S.renderTick = renderTick
S.fastTick = fastTick
S.slowTick = slowTick

return S
