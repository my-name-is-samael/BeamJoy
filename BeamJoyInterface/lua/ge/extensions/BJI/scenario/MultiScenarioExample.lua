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
    -- declare restrictions
    BJI.Managers.Restrictions.update({
        {
            restrictions = Table({
                BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                BJI.Managers.Restrictions.OTHER.PHOTO_MODE,
            }):flat(),
            state = BJI.Managers.Restrictions.STATE.RESTRICTED,
        },
        {
            restrictions = BJI.Managers.Restrictions.OTHER.FREE_CAM,
            state = BJI.Managers.Restrictions.STATE.ALLOWED,
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
    return BJI.Managers.Collisions.TYPES.GHOSTS
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

-- unload hook (before switch to another scenario)
local function onUnload(ctxt)
    -- rollback restrictions
    BJI.Managers.Restrictions.update({
        {
            restrictions = Table({
                BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                BJI.Managers.Restrictions.OTHER.PHOTO_MODE,
            }):flat(),
            state = false, -- forbidden bindings
        },
        {
            restrictions = BJI.Managers.Restrictions.OTHER.FREE_CAM,
            state = true, -- allowed bindings
        }
    })
end

S.canChangeTo = canChangeTo
S.onLoad = onLoad

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

S.onUnload = onUnload

return S
