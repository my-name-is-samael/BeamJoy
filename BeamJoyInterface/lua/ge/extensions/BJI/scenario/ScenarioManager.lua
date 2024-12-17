local M = {
    _name = "BJIScenario",
    TYPES = {},
    solo = {},
    multi = {},
    CurrentScenario = nil,
    scenarii = {},
}

local function _curr()
    return M.scenarii[M.CurrentScenario] or {}
end

local function registerSoloScenario(type, module)
    M.TYPES[type] = type
    M.scenarii[type] = module
    if not tincludes(M.solo, type, true) then
        table.insert(M.solo, type)
    end
end

local function registerMultiScenario(type, module)
    M.TYPES[type] = type
    M.scenarii[type] = module
    if not tincludes(M.multi, type, true) then
        table.insert(M.multi, type)
    end
end

local function init()
    M.TYPES.FREEROAM = "FREEROAM"
    M.scenarii[M.TYPES.FREEROAM] = require("ge/extensions/BJI/scenario/ScenarioFreeroam")

    registerSoloScenario("VEHICLE_DELIVERY", require("ge/extensions/BJI/scenario/ScenarioVehicleDelivery"))
    registerSoloScenario("PACKAGE_DELIVERY", require("ge/extensions/BJI/scenario/ScenarioPackageDelivery"))
    registerSoloScenario("BUS_MISSION", require("ge/extensions/BJI/scenario/ScenarioBusMission"))
    registerSoloScenario("RACE_SOLO", require("ge/extensions/BJI/scenario/ScenarioRaceSolo"))

    registerMultiScenario("RACE_MULTI", require("ge/extensions/BJI/scenario/ScenarioRaceMulti"))
    registerMultiScenario("SPEED", require("ge/extensions/BJI/scenario/ScenarioSpeed"))
    registerSoloScenario("DELIVERY_MULTI", require("ge/extensions/BJI/scenario/ScenarioDeliveryMulti"))
    registerMultiScenario("HUNTER", require("ge/extensions/BJI/scenario/ScenarioHunter"))
    registerMultiScenario("DERBY", require("ge/extensions/BJI/scenario/ScenarioDerby"))

    M.CurrentScenario = M.TYPES.FREEROAM
    if _curr().onLoad then
        _curr().onLoad()
    end
end
BJIAsync.task(
    function()
        return BJICache.areBaseCachesFirstLoaded() and
            BJICache.isFirstLoaded(BJICache.CACHES.MAP) and
            BJICache.isFirstLoaded(BJICache.CACHES.BJC)
    end,
    init, "BJIScenarioInit"
)

local function onVehicleSpawned(gameVehID)
    LogDebug(svar("Spawned vehicle {1}", { gameVehID }))
    BJIReputation.onVehicleResetted()
    if _curr().onVehicleSpawned then
        _curr().onVehicleSpawned(gameVehID)
    end
end

local function onVehicleResetted(gameVehID)
    LogDebug(svar("Resetted vehicle {1}", { gameVehID }))
    if not BJIVeh.isVehicleOwn(gameVehID) then
        return
    end

    BJIReputation.onVehicleResetted()
    if _curr().onVehicleResetted then
        _curr().onVehicleResetted(gameVehID)
    end
end

local function onVehicleSwitched(oldGameVehID, newGameVehID)
    LogDebug(svar("Switched vehicle from {1} to {2}", { oldGameVehID, newGameVehID }))

    -- assign the real gameVehID
    local finalGameVehID
    if newGameVehID ~= -1 then
        local veh = BJIVeh.getVehicleObject(newGameVehID)
        if veh then
            local remoteID = BJIVeh.getRemoteVehID(newGameVehID)
            if remoteID then
                finalGameVehID = remoteID
            else
                finalGameVehID = newGameVehID
            end
        end
    end
    BJITx.player.switchVehicle(finalGameVehID)
    BJIContext.User.currentVehicle = finalGameVehID

    -- anti unicycle-spam
    BJIAsync.delayTask(function()
        local veh = oldGameVehID ~= -1 and BJIVeh.getVehicleObject(oldGameVehID) or nil
        if veh and BJIVeh.isVehicleOwn(veh:getID())
            and BJIVeh.isUnicycle(veh:getID()) then
            BJIVeh.deleteVehicle(veh:getID())
        end
    end, 10, "BJIAntiUnicycleSpam")
    if _curr().onVehicleSwitched then
        _curr().onVehicleSwitched(oldGameVehID, newGameVehID)
    end
end

local function onVehicleDestroyed(gameVehID)
    if _curr().onVehicleDestroyed then
        _curr().onVehicleDestroyed(gameVehID)
    end
end

local function updateVehicles()
    if _curr().updateVehicles then
        _curr().updateVehicles()
    end
end

local function onGarageRepair()
    if _curr().onGarageRepair then
        _curr().onGarageRepair()
    end
end

local function onDropPlayerAtCamera()
    BJIReputation.onVehicleTeleport()
    if _curr().onDropPlayerAtCamera then
        _curr().onDropPlayerAtCamera()
    end
end

local function onDropPlayerAtCameraNoReset()
    BJIReputation.onVehicleTeleport()
    if _curr().onDropPlayerAtCameraNoReset then
        _curr().onDropPlayerAtCameraNoReset()
    end
end

local function tryTeleportToPlayer(targetID, forced)
    BJIReputation.onVehicleTeleport()
    if _curr().tryTeleportToPlayer then
        _curr().tryTeleportToPlayer(targetID, forced)
    end
end

local function tryTeleportToPos(pos, saveHome)
    BJIReputation.onVehicleTeleport()
    if _curr().tryTeleportToPos then
        _curr().tryTeleportToPos(pos, saveHome)
    end
end

local function tryFocus(targetID)
    if _curr().tryFocus then
        _curr().tryFocus(targetID)
    end
end

local function trySpawnNew(model, config)
    if _curr().trySpawnNew then
        _curr().trySpawnNew(model, config)
    end
end

local function tryReplaceOrSpawn(model, config)
    if _curr().tryReplaceOrSpawn then
        _curr().tryReplaceOrSpawn(model, config)
    end
end

local function tryPaint(paint, paintNumber)
    if _curr().tryPaint then
        _curr().tryPaint(paint, paintNumber)
    end
end

local function canRefuelAtStation()
    if _curr().canRefuelAtStation then
        return _curr().canRefuelAtStation()
    end
    return false
end

local function canRepairAtGarage()
    if _curr().canRepairAtGarage then
        return _curr().canRepairAtGarage()
    end
    return false
end

local function canSpawnAI()
    if _curr().canSpawnAI then
        return _curr().canSpawnAI()
    end
    return false
end

local function canSelectVehicle()
    if _curr().canSelectVehicle then
        return _curr().canSelectVehicle()
    end
    return true
end

local function canSpawnNewVehicle()
    if _curr().canSpawnNewVehicle then
        return _curr().canSpawnNewVehicle()
    end
    return true
end

local function canReplaceVehicle()
    if _curr().canReplaceVehicle then
        return _curr().canReplaceVehicle()
    end
    return true
end

local function canDeleteVehicle()
    if _curr().canDeleteVehicle then
        return _curr().canDeleteVehicle()
    end
    return true
end

local function canDeleteOtherVehicles()
    if _curr().canDeleteOtherVehicles then
        return _curr().canDeleteOtherVehicles()
    end
    return true
end

local function canDeleteOtherPlayersVehicle()
    if _curr().canDeleteOtherPlayersVehicle then
        return _curr().canDeleteOtherPlayersVehicle()
    end
    return false
end

local function canEditVehicle()
    if _curr().canEditVehicle then
        return _curr().canEditVehicle()
    end
    return true
end

local function getModelList()
    if _curr().getModelList then
        return _curr().getModelList()
    end
    return {}
end

local function getPlayerListActions(player, ctxt)
    if _curr().getPlayerListActions then
        return _curr().getPlayerListActions(player, ctxt or BJITick.getContext())
    else
        return {}
    end
end

local function doShowNametag(vehData)
    if _curr().doShowNametag then
        return _curr().doShowNametag(vehData)
    else
        return not BJIAI.isAIVehicle(vehData.gameVehicleID)
    end
end

local function doShowNametagsSpecs(vehData)
    if _curr().doShowNametagsSpecs then
        return _curr().doShowNametagsSpecs(vehData)
    else
        return false
    end
end

local function getCollisionsType(ctxt)
    if _curr().getCollisionsType then
        return _curr().getCollisionsType(ctxt or BJITick.getContext())
    else
        return BJICollisions.TYPES.GHOSTS
    end
end

local renderTickErrorLimitTime = nil
local function renderTick(ctxt)
    if _curr().renderTick then
        local status, err = pcall(_curr().renderTick, ctxt or BJITick.getContext())
        if not status then
            if not renderTickErrorLimitTime then
                renderTickErrorLimitTime = ctxt.now + 3000
            elseif ctxt.now >= renderTickErrorLimitTime then
                BJIToast.error("Continuous error during scenario, backup to Freeroam")
                renderTickErrorLimitTime = nil
                M.switchScenario(M.TYPES.FREEROAM)
            end
            error(err)
        elseif renderTickErrorLimitTime then
            renderTickErrorLimitTime = nil
        end
    end
end

local function slowTick(ctxt)
    if _curr().slowTick then
        _curr().slowTick(ctxt or BJITick.getContext())
    end
end

local function getAvailableScenarii()
    local res = {}
    for k, v in pairs(M.scenarii) do
        if v.canChangeTo() then
            table.insert(res, k)
        end
    end
    return res
end

local function switchScenario(newType, ctxt)
    if not tincludes(M.TYPES, newType, true) then
        LogError(svar("Invalid scenario {1}", { newType }))
        return
    end

    if M.CurrentScenario == newType then
        return
    end

    if not ctxt then
        ctxt = BJITick.getContext()
    end

    if not M.scenarii[newType].canChangeTo(ctxt) then
        BJIToast.error(BJILang.get("errors.scenarioUnavailable"))
        return
    end

    local previousScenario = M.CurrentScenario
    local status, err
    if _curr().onUnload then
        status, err = pcall(_curr().onUnload, ctxt)
        if not status then
            BJIToast.error("Error unloading scenario")
            error(err)
        end
    end
    M.CurrentScenario = newType
    if _curr().onLoad then
        status, err = pcall(_curr().onLoad, ctxt)
        if not status then
            BJIToast.error("Error loading scenario")
            M.CurrentScenario = previousScenario
            error(err)
        end
    end
end

local function isFreeroam()
    return not M.CurrentScenario or M.CurrentScenario == M.TYPES.FREEROAM
end

local function getFreeroam()
    return M.scenarii[M.TYPES.FREEROAM]
end

local function isSoloScenario()
    return tincludes(M.solo, M.CurrentScenario, true)
end

local function isServerScenario()
    return tincludes(M.multi, M.CurrentScenario, true)
end

local function is(type)
    return M.CurrentScenario == type
end

local function get(type)
    return M.scenarii[type]
end

M.onVehicleSpawned = onVehicleSpawned
M.onVehicleResetted = onVehicleResetted
M.onVehicleSwitched = onVehicleSwitched
M.onVehicleDestroyed = onVehicleDestroyed
M.updateVehicles = updateVehicles
M.onGarageRepair = onGarageRepair

M.onDropPlayerAtCamera = onDropPlayerAtCamera
M.onDropPlayerAtCameraNoReset = onDropPlayerAtCameraNoReset

M.tryTeleportToPlayer = tryTeleportToPlayer
M.tryTeleportToPos = tryTeleportToPos
M.tryFocus = tryFocus

M.trySpawnNew = trySpawnNew
M.tryReplaceOrSpawn = tryReplaceOrSpawn
M.tryPaint = tryPaint

M.canRefuelAtStation = canRefuelAtStation
M.canRepairAtGarage = canRepairAtGarage
M.canSpawnAI = canSpawnAI
M.canSelectVehicle = canSelectVehicle
M.canSpawnNewVehicle = canSpawnNewVehicle
M.canReplaceVehicle = canReplaceVehicle
M.canDeleteVehicle = canDeleteVehicle
M.canDeleteOtherVehicles = canDeleteOtherVehicles
M.canDeleteOtherPlayersVehicle = canDeleteOtherPlayersVehicle
M.canEditVehicle = canEditVehicle
M.getModelList = getModelList
M.getPlayerListActions = getPlayerListActions
M.doShowNametag = doShowNametag
M.doShowNametagsSpecs = doShowNametagsSpecs
M.getCollisionsType = getCollisionsType

M.renderTick = renderTick
M.slowTick = slowTick

M.getAvailableScenarii = getAvailableScenarii
M.switchScenario = switchScenario

M.isFreeroam = isFreeroam
M.getFreeroam = getFreeroam
M.isPlayerScenarioInProgress = isSoloScenario
M.isServerScenarioInProgress = isServerScenario
M.is = is
M.get = get

RegisterBJIManager(M)
return M
