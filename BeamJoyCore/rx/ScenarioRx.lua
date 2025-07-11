local ctrl = {}

---@param ctxt BJCContext
function ctrl.RaceDetails(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.SCENARIO) and
        not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_SERVER_SCENARIO) and
        not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        BJCTx.scenario.RaceDetails(ctxt.senderID, false)
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local raceID = ctxt.data[1]
    local race = BJCScenarioData.getRace(raceID)
    if race then
        BJCTx.scenario.RaceDetails(ctxt.senderID, race)
    else
        BJCTx.scenario.RaceDetails(ctxt.senderID, false)
        error({ key = "rx.errors.invalidData" })
    end
end

---@param ctxt BJCContext
function ctrl.RaceSave(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local status, raceID = pcall(BJCScenarioData.saveRace, ctxt.data[1])
    BJCTx.scenario.RaceSave(ctxt.senderID, status and raceID or false)
    if not status then
        local err = raceID
        error(err)
    end
end

---@param ctxt BJCContext
function ctrl.RaceToggle(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local raceID, state = tonumber(ctxt.data[1]), ctxt.data[2] == true
    local race = BJCScenarioData.getRace(raceID)
    if race then
        race.enabled = state
        race.keepRecord = true ---@diagnostic disable-line polymorphism
        BJCScenarioData.saveRace(race) ---@diagnostic disable-line polymorphism
    else
        error({ key = "rx.errors.invalidData" })
    end
end

---@param ctxt BJCContext
function ctrl.RaceDelete(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCScenarioData.raceDelete(ctxt.data[1])
end

---@param ctxt BJCContext
function ctrl.RaceMultiUpdate(ctxt)
    BJCScenario.RaceManager.clientUpdate(ctxt.senderID, ctxt.data[1], ctxt.data[2])
end

---@param ctxt BJCContext
function ctrl.RaceMultiStop(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_SERVER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCScenario.RaceManager.stop()
end

---@param ctxt BJCContext
function ctrl.RaceSoloStart(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCPlayers.setPlayerScenario(ctxt.senderID, BJCScenario.PLAYER_SCENARII.RACE_SOLO)
end

---@param ctxt BJCContext
function ctrl.RaceSoloUpdate(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local raceID, time, model = ctxt.data[1], ctxt.data[2], ctxt.data[3]
    BJCScenarioData.onRaceSoloTime(ctxt.senderID, raceID, time, model)
end

---@param ctxt BJCContext
function ctrl.RaceSoloEnd(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local finished = ctxt.data[1] == true
    BJCPlayers.onRaceSoloEnd(ctxt.senderID, finished)
end

---@param ctxt BJCContext
function ctrl.EnergyStationsSave(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local _, err = pcall(BJCScenarioData.saveEnergyStations, ctxt.data[1])
    BJCTx.scenario.EnergyStationsSave(ctxt.senderID, not err)
    if err then
        error(err)
    end
end

---@param ctxt BJCContext
function ctrl.GaragesSave(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local _, err = pcall(BJCScenarioData.saveGarages, ctxt.data[1])
    BJCTx.scenario.GaragesSave(ctxt.senderID, not err)
    if err then
        error(err)
    end
end

---@param ctxt BJCContext
function ctrl.DeliverySave(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local _, err = pcall(BJCScenarioData.saveDeliveryPositions, ctxt.data[1])
    BJCTx.scenario.DeliverySave(ctxt.senderID, not err)
    if err then
        error(err)
    end
end

---@param ctxt BJCContext
function ctrl.DeliveryVehicleStart(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCPlayers.setPlayerScenario(ctxt.senderID, BJCScenario.PLAYER_SCENARII.DELIVERY_VEHICLE)
end

---@param ctxt BJCContext
function ctrl.DeliveryVehicleSuccess(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCPlayers.onDeliveryVehicleSuccess(ctxt.senderID, ctxt.data[1] == true)
end

---@param ctxt BJCContext
function ctrl.DeliveryVehicleFail(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCPlayers.setPlayerScenario(ctxt.senderID, BJCScenario.PLAYER_SCENARII.FREEROAM)
end

---@param ctxt BJCContext
function ctrl.DeliveryPackageStart(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCPlayers.setPlayerScenario(ctxt.senderID, BJCScenario.PLAYER_SCENARII.DELIVERY_PACKAGE)
end

---@param ctxt BJCContext
function ctrl.DeliveryPackageSuccess(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCPlayers.onDeliveryPackageSuccess(ctxt.senderID)
end

---@param ctxt BJCContext
function ctrl.DeliveryPackageFail(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCPlayers.onDeliveryPackageFail(ctxt.senderID)
end

---@param ctxt BJCContext
function ctrl.DeliveryMultiJoin(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local gameVehID, pos = ctxt.data[1], ctxt.data[2]
    BJCScenario.Hybrids.DeliveryMultiManager.join(ctxt.senderID, gameVehID, pos)
end

---@param ctxt BJCContext
function ctrl.DeliveryMultiResetted(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCScenario.Hybrids.DeliveryMultiManager.resetted(ctxt.senderID)
end

---@param ctxt BJCContext
function ctrl.DeliveryMultiReached(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCScenario.Hybrids.DeliveryMultiManager.reached(ctxt.senderID)
end

---@param ctxt BJCContext
function ctrl.DeliveryMultiLeave(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCScenario.Hybrids.DeliveryMultiManager.leave(ctxt.senderID)
end

---@param ctxt BJCContext
function ctrl.BusLinesSave(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local _, err = pcall(BJCScenarioData.saveBusLines, ctxt.data[1])
    BJCTx.scenario.BusLinesSave(ctxt.senderID, not err)
    if err then
        error(err)
    end
end

---@param ctxt BJCContext
function ctrl.BusMissionStart(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCPlayers.setPlayerScenario(ctxt.senderID, BJCScenario.PLAYER_SCENARII.BUS_MISSION)
end

---@param ctxt BJCContext
function ctrl.BusMissionReward(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local idBusLine = ctxt.data[1]
    BJCPlayers.onBusMissionReward(ctxt.senderID, idBusLine)
end

---@param ctxt BJCContext
function ctrl.BusMissionStop(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCPlayers.setPlayerScenario(ctxt.senderID, BJCScenario.PLAYER_SCENARII.FREEROAM)
end

---@param ctxt BJCContext
function ctrl.SpeedFail(ctxt)
    if not BJCPerm.canSpawnVehicle(ctxt.senderID) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local time = ctxt.data[1]
    BJCScenario.SpeedManager.clientUpdate(ctxt.senderID, time)
end

---@param ctxt BJCContext
function ctrl.SpeedStop(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_SERVER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCScenario.SpeedManager.stop()
end

---@param ctxt BJCContext
function ctrl.HunterInfectedSave(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local _, err = pcall(BJCScenarioData.saveHunterInfected, ctxt.data[1])
    BJCTx.scenario.HunterInfectedSave(ctxt.senderID, not err)
    if err then
        error(err)
    end
end

---@param ctxt BJCContext
function ctrl.HunterUpdate(ctxt)
    if not BJCPerm.canSpawnVehicle(ctxt.senderID) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local event, data = ctxt.data[1], ctxt.data[2]
    BJCScenario.HunterManager.clientUpdate(ctxt.senderID, event, data)
end

function ctrl.HunterForceFugitive(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_SERVER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local playerID = ctxt.data[1]
    BJCScenario.HunterManager.forceFugitive(playerID)
end

---@param ctxt BJCContext
function ctrl.HunterStop(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_SERVER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCScenario.HunterManager.stop()
end

---@param ctxt BJCContext
function ctrl.InfectedUpdate(ctxt)
    if not BJCPerm.canSpawnVehicle(ctxt.senderID) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local event, data = ctxt.data[1], ctxt.data[2]
    BJCScenario.InfectedManager.clientUpdate(ctxt.senderID, event, data)
end

function ctrl.InfectedForceInfected(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_SERVER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local playerID = ctxt.data[1]
    BJCScenario.InfectedManager.forceInfected(playerID)
end

---@param ctxt BJCContext
function ctrl.InfectedStop(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_SERVER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCScenario.InfectedManager.stop()
end

---@param ctxt BJCContext
function ctrl.DerbySave(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local _, err = pcall(BJCScenarioData.saveDerbyArenas, ctxt.data[1])
    BJCTx.scenario.DerbySave(ctxt.senderID, not err)
    if err then
        error(err)
    end
end

---@param ctxt BJCContext
function ctrl.DerbyUpdate(ctxt)
    local event, data = ctxt.data[1], ctxt.data[2]
    BJCScenario.DerbyManager.clientUpdate(ctxt.senderID, event, data)
end

---@param ctxt BJCContext
function ctrl.DerbyStop(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_SERVER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCScenario.DerbyManager.stop()
end

---@param ctxt BJCContext
function ctrl.TagDuoJoin(ctxt)
    if not BJCPerm.canSpawnVehicle(ctxt.senderID) or
        not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local lobbyIndex, vehID = ctxt.data[1], ctxt.data[2]
    BJCScenario.Hybrids.TagDuoManager.onClientJoin(ctxt.senderID, lobbyIndex, vehID)
end

---@param ctxt BJCContext
function ctrl.TagDuoUpdate(ctxt)
    if not BJCPerm.canSpawnVehicle(ctxt.senderID) or
        not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local lobbyIndex, event = ctxt.data[1], ctxt.data[2]
    BJCScenario.Hybrids.TagDuoManager.onClientUpdate(ctxt.senderID, lobbyIndex, event)
end

---@param ctxt BJCContext
function ctrl.TagDuoLeave(ctxt)
    if not BJCPerm.canSpawnVehicle(ctxt.senderID) or
        not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCScenario.Hybrids.TagDuoManager.onClientLeave(ctxt.senderID)
end

---@param ctxt BJCContext
function ctrl.PursuitData(ctxt)
    if not BJCPerm.canSpawnVehicle(ctxt.senderID) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    Table(BJCPlayers.Players):filter(function(p)
        return p.playerID ~= ctxt.senderID and BJCPerm.canSpawnVehicle(p.playerID) and
            not BJCScenario.isPlayerCollisionless(p)
    end):forEach(function(p)
        BJCTx.scenario.PursuitData(p.playerID, ctxt.data)
    end)
end

---@param ctxt BJCContext
function ctrl.PursuitReward(ctxt)
    if not BJCPerm.canSpawnVehicle(ctxt.senderID) then
        error({ key = "rx.errors.insufficientPermissions" })
    elseif BJCScenario.isServerScenarioInProgress() or
        BJCScenario.isPlayerCollisionless(ctxt.sender) then
        error({ key = "rx.errors.invalidData" })
    end

    local isArrest = ctxt.data[1] == true
    BJCPlayers.onPursuitReward(ctxt.senderID, isArrest)
end

return ctrl
