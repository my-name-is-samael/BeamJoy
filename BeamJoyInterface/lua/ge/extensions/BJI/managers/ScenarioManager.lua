---@class BJIManagerScenario : BJIManager
local M = {
    _name = "Scenario",

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
    if not table.includes(M.solo, type) then
        table.insert(M.solo, type)
    end
end

local function registerMultiScenario(type, module)
    M.TYPES[type] = type
    M.scenarii[type] = module
    if not table.includes(M.multi, type) then
        table.insert(M.multi, type)
    end
end

local function initScenarii()
    M.TYPES.FREEROAM = "FREEROAM"
    M.scenarii[M.TYPES.FREEROAM] = require("ge/extensions/BJI/scenario/ScenarioFreeroam")

    registerSoloScenario("VEHICLE_DELIVERY", require("ge/extensions/BJI/scenario/ScenarioDeliveryVehicle"))
    registerSoloScenario("PACKAGE_DELIVERY", require("ge/extensions/BJI/scenario/ScenarioDeliveryPackage"))
    registerSoloScenario("BUS_MISSION", require("ge/extensions/BJI/scenario/ScenarioBusMission"))
    registerSoloScenario("RACE_SOLO", require("ge/extensions/BJI/scenario/ScenarioRaceSolo"))

    registerMultiScenario("RACE_MULTI", require("ge/extensions/BJI/scenario/ScenarioRaceMulti"))
    registerMultiScenario("SPEED", require("ge/extensions/BJI/scenario/ScenarioSpeed"))
    registerSoloScenario("DELIVERY_MULTI", require("ge/extensions/BJI/scenario/ScenarioDeliveryMulti"))
    registerMultiScenario("HUNTER", require("ge/extensions/BJI/scenario/ScenarioHunter"))
    registerMultiScenario("DERBY", require("ge/extensions/BJI/scenario/ScenarioDerby"))
    --registerSoloScenario("TAG_DUO", require("ge/extensions/BJI/scenario/ScenarioTagDuo"))

    M.CurrentScenario = M.TYPES.FREEROAM
    if _curr().onLoad then
        _curr().onLoad()
    end
end

local function onVehicleSpawned(gameVehID)
    BJI.Managers.Reputation.vehicleResetted()
    if _curr().onVehicleSpawned then
        _curr().onVehicleSpawned(gameVehID)
    end
end

local function onVehicleResetted(gameVehID)
    if gameVehID == -1 or not BJI.Managers.Veh.isVehicleOwn(gameVehID) or
        BJI.Managers.AI.isAIVehicle(gameVehID) or
        table.includes({ BJI.Managers.Veh.TYPES.TRAILER, BJI.Managers.Veh.TYPES.PROP },
            BJI.Managers.Veh.getType(gameVehID)) then
        return
    end

    BJI.Managers.Reputation.vehicleResetted()
    if _curr().onVehicleResetted then
        _curr().onVehicleResetted(gameVehID)
    end
end

local function onVehicleSwitched(oldGameVehID, newGameVehID)
    -- assign the real gameVehID
    local finalGameVehID
    if newGameVehID ~= -1 then
        local veh = BJI.Managers.Veh.getVehicleObject(newGameVehID)
        if veh then
            local remoteID = BJI.Managers.Veh.getRemoteVehID(newGameVehID)
            if remoteID then
                finalGameVehID = remoteID
            else
                finalGameVehID = newGameVehID
            end
        end
    end
    BJI.Tx.player.switchVehicle(finalGameVehID)
    BJI.Managers.Context.User.currentVehicle = finalGameVehID

    -- anti unicycle-spam
    BJI.Managers.Async.delayTask(function()
        local veh = oldGameVehID ~= -1 and BJI.Managers.Veh.getVehicleObject(oldGameVehID) or nil
        if veh and BJI.Managers.Veh.isVehicleOwn(veh:getID())
            and BJI.Managers.Veh.isUnicycle(veh:getID()) then
            BJI.Managers.Veh.deleteVehicle(veh:getID())
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
    BJI.Managers.Reputation.vehicleTeleported()
    if _curr().onDropPlayerAtCamera then
        _curr().onDropPlayerAtCamera()
    end
end

local function onDropPlayerAtCameraNoReset()
    BJI.Managers.Reputation.vehicleTeleported()
    if _curr().onDropPlayerAtCameraNoReset then
        _curr().onDropPlayerAtCameraNoReset()
    end
end

local function tryTeleportToPlayer(targetID, forced)
    BJI.Managers.Reputation.vehicleTeleported()
    if _curr().tryTeleportToPlayer then
        _curr().tryTeleportToPlayer(targetID, forced)
    end
end

local function tryTeleportToPos(pos, saveHome)
    BJI.Managers.Reputation.vehicleTeleported()
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

local function getModelList()
    if _curr().getModelList then
        return _curr().getModelList()
    end
    return {}
end

local function getPlayerListActions(player, ctxt)
    if _curr().getPlayerListActions then
        return _curr().getPlayerListActions(player, ctxt or BJI.Managers.Tick.getContext())
    else
        return {}
    end
end

---@param vehData { gameVehicleID: integer, ownerID: integer }
local function doShowNametag(vehData)
    if _curr().doShowNametag then
        return _curr().doShowNametag(vehData)
    else
        return not BJI.Managers.AI.isAIVehicle(vehData.gameVehicleID)
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
        return _curr().getCollisionsType(ctxt or BJI.Managers.Tick.getContext())
    else
        return BJI.Managers.Collisions.TYPES.GHOSTS
    end
end

---@return ScenarioRestriction[]
local function getRestrictions()
    if _curr().getRestrictions then
        return _curr().getRestrictions()
    else
        return {}
    end
end

local tickErrorProcess = { countRender = 0, countFast = 0, countSlow = 0 }

---@param ctxt TickContext
local function renderTick(ctxt)
    if type(_curr().renderTick) == "function" then
        local status, err = pcall(_curr().renderTick, ctxt)
        if not status then
            LogError(string.var("Error during scenario render tick : {1}", { err }))
            tickErrorProcess.countRender = tickErrorProcess.countRender + 1
            if tickErrorProcess.countRender >= 20 then
                BJI.Managers.Toast.error("Continuous error during scenario render tick, backup to Freeroam")
                tickErrorProcess.countRender = 0
                M.switchScenario(M.TYPES.FREEROAM)
            end
        elseif tickErrorProcess.countRender > 0 then
            tickErrorProcess.countRender = 0
        end
    end
end

---@param ctxt TickContext
local function fastTick(ctxt)
    if type(_curr().fastTick) == "function" then
        local status, err = pcall(_curr().fastTick, ctxt)
        if not status then
            LogError(string.var("Error during scenario fast tick : {1}", { err }))
            tickErrorProcess.countFast = tickErrorProcess.countFast + 1
            if tickErrorProcess.countFast >= 20 then
                BJI.Managers.Toast.error("Continuous error during scenario fast tick, backup to Freeroam")
                tickErrorProcess.countFast = 0
                M.switchScenario(M.TYPES.FREEROAM)
            end
        elseif tickErrorProcess.countFast > 0 then
            tickErrorProcess.countFast = 0
        end
    end
end

---@param ctxt TickContext
local function slowTick(ctxt)
    if type(_curr().slowTick) == "function" then
        local status, err = pcall(_curr().slowTick, ctxt)
        if not status then
            LogError(string.var("Error during scenario slow tick : {1}", { err }))
            tickErrorProcess.countSlow = tickErrorProcess.countSlow + 1
            if tickErrorProcess.countSlow >= 5 then
                BJI.Managers.Toast.error("Continuous error during scenario slow tick, backup to Freeroam")
                tickErrorProcess.countSlow = 0
                M.switchScenario(M.TYPES.FREEROAM)
            end
        elseif tickErrorProcess.countSlow > 0 then
            tickErrorProcess.countSlow = 0
        end
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
    if not table.includes(M.TYPES, newType) then
        LogError(string.var("Invalid scenario {1}", { newType }))
        return
    end

    if M.CurrentScenario == newType then
        return
    end

    ctxt = ctxt or BJI.Managers.Tick.getContext()
    if not M.scenarii[newType].canChangeTo(ctxt) then
        BJI.Managers.Toast.error(BJI.Managers.Lang.get("errors.scenarioUnavailable"))
        return
    end

    local previousScenario = M.CurrentScenario
    local status, err
    if _curr().onUnload then
        status, err = pcall(_curr().onUnload, ctxt)
        if not status then
            BJI.Managers.Toast.error("Error unloading scenario")
            error(err)
        end
    end
    M.CurrentScenario = newType
    if _curr().onLoad then
        status, err = pcall(_curr().onLoad, ctxt)
        if not status then
            BJI.Managers.Toast.error("Error loading scenario")
            M.CurrentScenario = previousScenario
            error(err)
        end
    end

    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_CHANGED, {
        previousScenario = previousScenario,
        newScenario = newType,
        type = M.solo[newType] and "solo" or M.multi[newType] and "multi" or "other",
    })
end

local function isFreeroam()
    return not M.CurrentScenario or M.CurrentScenario == M.TYPES.FREEROAM
end

local function getFreeroam()
    return M.scenarii[M.TYPES.FREEROAM]
end

local function isSoloScenario()
    return table.includes(M.solo, M.CurrentScenario)
end

local function isServerScenario()
    return table.includes(M.multi, M.CurrentScenario)
end

local function is(type)
    return M.CurrentScenario == type
end

---@param type string
---@return any? BJIScenario
local function get(type)
    return M.scenarii[type]
end

local function onLoad()
    initScenarii()

    -- init cache handlers
    table.forEach({
        [BJI.Managers.Cache.CACHES.RACE] = M.TYPES.RACE_MULTI,
        [BJI.Managers.Cache.CACHES.DELIVERY_MULTI] = M.TYPES.DELIVERY_MULTI,
        [BJI.Managers.Cache.CACHES.SPEED] = M.TYPES.SPEED,
        [BJI.Managers.Cache.CACHES.HUNTER] = M.TYPES.HUNTER,
        [BJI.Managers.Cache.CACHES.DERBY] = M.TYPES.DERBY,
        --[BJICache.CACHES.TAG_DUO] = M.TYPES.TAG_DUO,
    }, function(scenarioType, cacheName)
        BJI.Managers.Cache.addRxHandler(cacheName, function(cacheData)
            local sc = M.get(scenarioType)
            if type(sc.rxData) == "function" then
                local ok, err = pcall(sc.rxData, cacheData)
                if not ok then
                    LogError(string.var("RxCache failed (cache {1}, scenario {2}): {3}",
                        { cacheName, scenarioType, err }))
                end
            end
        end)
    end)

    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_VEHICLE_SPAWNED, onVehicleSpawned)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_VEHICLE_RESETTED, onVehicleResetted)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_VEHICLE_SWITCHED, onVehicleSwitched)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_VEHICLE_DESTROYED, onVehicleDestroyed)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_DROP_PLAYER_AT_CAMERA, onDropPlayerAtCamera)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.ON_DROP_PLAYER_AT_CAMERA_NO_RESET,
        onDropPlayerAtCameraNoReset)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.SLOW_TICK, slowTick)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.FAST_TICK, fastTick)
end

M.updateVehicles = updateVehicles
M.onGarageRepair = onGarageRepair

M.tryTeleportToPlayer = tryTeleportToPlayer
M.tryTeleportToPos = tryTeleportToPos
M.tryFocus = tryFocus

M.trySpawnNew = trySpawnNew
M.tryReplaceOrSpawn = tryReplaceOrSpawn
M.tryPaint = tryPaint

M.canRefuelAtStation = canRefuelAtStation
M.canRepairAtGarage = canRepairAtGarage
M.canSpawnNewVehicle = canSpawnNewVehicle
M.canReplaceVehicle = canReplaceVehicle
M.canDeleteVehicle = canDeleteVehicle
M.canDeleteOtherVehicles = canDeleteOtherVehicles
M.canDeleteOtherPlayersVehicle = canDeleteOtherPlayersVehicle
M.getModelList = getModelList
M.getPlayerListActions = getPlayerListActions
M.doShowNametag = doShowNametag
M.doShowNametagsSpecs = doShowNametagsSpecs
M.getCollisionsType = getCollisionsType
M.getRestrictions = getRestrictions

M.getAvailableScenarii = getAvailableScenarii
M.switchScenario = switchScenario

M.isFreeroam = isFreeroam
M.getFreeroam = getFreeroam
M.isPlayerScenarioInProgress = isSoloScenario
M.isServerScenarioInProgress = isServerScenario
M.is = is
M.get = get

M.onLoad = onLoad
M.renderTick = renderTick

return M
