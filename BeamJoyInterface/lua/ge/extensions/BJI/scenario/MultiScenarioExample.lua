local M = {}

-- can switch to scenario hook
local function canChangeTo(ctxt)
    return false
end

-- load hook
local function onLoad(ctxt)
    -- declare restrictions
    BJIRestrictions.update({
        {
            restrictions = Table():addAll(BJIRestrictions.RESET.TELEPORT)
                :addAll(BJIRestrictions.OTHER.VEHICLE_SWITCH),
            state = true, -- forbidden bindings
        },
        {
            restrictions = Table():addAll(BJIRestrictions.OTHER.FREE_CAM),
            state = false, -- allowed bindings
        }
    })
end

-- player vehicle spawn hook
local function onVehicleSpawned(gameVehID)
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
    return BJICollisions.TYPES.GHOSTS
end

-- player list contextual actions getter
local function getPlayerListActions(player)
end

-- each frame tick hook
local function renderTick(ctxt)
end

-- each second tick hook
local function slowTick(ctxt)
end

-- unload hook (before switch to another scenario)
local function onUnload(ctxt)
    -- rollback restrictions
    BJIRestrictions.update({
        {
            restrictions = Table():addAll(BJIRestrictions.RESET.TELEPORT)
                :addAll(BJIRestrictions.OTHER.VEHICLE_SWITCH),
            state = false, -- forbidden bindings
        },
        {
            restrictions = Table():addAll(BJIRestrictions.OTHER.FREE_CAM),
            state = true, -- allowed bindings
        }
    })
end

M.canChangeTo = canChangeTo
M.onLoad = onLoad

M.onVehicleSpawned = onVehicleSpawned
M.onDropPlayerAtCamera = onDropPlayerAtCamera
M.onDropPlayerAtCameraNoReset = onDropPlayerAtCameraNoReset
M.onVehicleResetted = onVehicleResetted
M.onVehicleSwitched = onVehicleSwitched
M.onVehicleDestroyed = onVehicleDestroyed
M.updateVehicles = updateVehicles
M.canRefuelAtStation = canRefuelAtStation
M.canRepairAtGarage = canRepairAtGarage
M.onGarageRepair = onGarageRepair
M.tryTeleportToPlayer = tryTeleportToPlayer
M.tryTeleportToPos = tryTeleportToPos
M.tryFocus = tryFocus
M.canSpawnAI = canSpawnAI
M.canSpawnNewVehicle = canSpawnNewVehicle
M.canReplaceVehicle = canReplaceVehicle
M.canDeleteVehicle = canDeleteVehicle
M.canDeleteOtherVehicles = canDeleteOtherVehicles
M.getModelList = getModelList
M.doShowNametag = doShowNametag
M.getCollisionsType = getCollisionsType

M.getPlayerListActions = getPlayerListActions

M.renderTick = renderTick
M.slowTick = slowTick

M.onUnload = onUnload

return M
