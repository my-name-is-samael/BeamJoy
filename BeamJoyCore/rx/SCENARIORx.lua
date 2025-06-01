local ctrl = {}

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

function ctrl.RaceSave(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local status, raceID = pcall(BJCScenario.saveRace, ctxt.data[1])
    BJCTx.scenario.RaceSave(ctxt.senderID, status and raceID or false)
    if not status then
        local err = raceID
        error(err)
    end
end

function ctrl.RaceToggle(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local raceID, state = tonumber(ctxt.data[1]), ctxt.data[2] == true
    local race = BJCScenarioData.getRace(raceID)
    if race then
        race.enabled = state
        local raceID = BJCScenarioData.saveRace(race)
    else
        error({ key = "rx.errors.invalidData" })
    end
end

function ctrl.RaceDelete(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCScenarioData.raceDelete(ctxt.data[1])
end

function ctrl.RaceMultiUpdate(ctxt)
    BJCScenario.RaceManager.clientUpdate(ctxt.senderID, ctxt.data[1], ctxt.data[2])
end

function ctrl.RaceMultiStop(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_SERVER_SCENARIO) and
        not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCScenario.RaceManager.stop()
end

function ctrl.RaceSoloStart(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCPlayers.setPlayerScenario(ctxt.senderID, BJCScenario.PLAYER_SCENARII.RACE_SOLO)
end

function ctrl.RaceSoloUpdate(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local raceID, time, model = ctxt.data[1], ctxt.data[2], ctxt.data[3]
    BJCScenarioData.onRaceSoloTime(ctxt.senderID, raceID, time, model)
end

function ctrl.RaceSoloEnd(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local finished = ctxt.data[1] == true
    BJCPlayers.onRaceSoloEnd(ctxt.senderID, finished)
end

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

function ctrl.DeliverySave(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local _, err = pcall(BJCScenario.saveDeliveryPositions, ctxt.data[1])
    BJCTx.scenario.DeliverySave(ctxt.senderID, not err)
    if err then
        error(err)
    end
end

function ctrl.DeliveryVehicleStart(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCPlayers.setPlayerScenario(ctxt.senderID, BJCScenario.PLAYER_SCENARII.DELIVERY_VEHICLE)
end

function ctrl.DeliveryVehicleSuccess(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCPlayers.onDeliveryVehicleSuccess(ctxt.senderID, ctxt.data[1] == true)
end

function ctrl.DeliveryVehicleFail(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCPlayers.setPlayerScenario(ctxt.senderID, BJCScenario.PLAYER_SCENARII.FREEROAM)
end

function ctrl.DeliveryPackageStart(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCPlayers.setPlayerScenario(ctxt.senderID, BJCScenario.PLAYER_SCENARII.DELIVERY_PACKAGE)
end

function ctrl.DeliveryPackageSuccess(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCPlayers.onDeliveryPackageSuccess(ctxt.senderID)
end

function ctrl.DeliveryPackageFail(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCPlayers.onDeliveryPackageFail(ctxt.senderID)
end

function ctrl.DeliveryMultiJoin(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local gameVehID, pos = ctxt.data[1], ctxt.data[2]
    BJCScenario.Hybrids.DeliveryMultiManager.join(ctxt.senderID, gameVehID, pos)
end

function ctrl.DeliveryMultiResetted(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCScenario.Hybrids.DeliveryMultiManager.resetted(ctxt.senderID)
end

function ctrl.DeliveryMultiReached(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCScenario.Hybrids.DeliveryMultiManager.reached(ctxt.senderID)
end

function ctrl.DeliveryMultiLeave(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCScenario.Hybrids.DeliveryMultiManager.leave(ctxt.senderID)
end

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

function ctrl.BusMissionStart(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCPlayers.setPlayerScenario(ctxt.senderID, BJCScenario.PLAYER_SCENARII.BUS_MISSION)
end

function ctrl.BusMissionReward(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local idBusLine = ctxt.data[1]
    BJCPlayers.onBusMissionReward(ctxt.senderID, idBusLine)
end

function ctrl.BusMissionStop(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCPlayers.setPlayerScenario(ctxt.senderID, BJCScenario.PLAYER_SCENARII.FREEROAM)
end

function ctrl.SpeedStart(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_SERVER_SCENARIO) and
        not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.VOTE_SERVER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    if BJCScenario.isServerScenarioInProgress() then
        error({ key = "rx.errors.invalidData" })
    end

    local isVote = ctxt.data[1] == true
    BJCVote.Speed.start(ctxt.senderID, isVote)
end

function ctrl.SpeedJoin(ctxt)
    if not BJCPerm.canSpawnVehicle(ctxt.senderID) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local gameVehID = ctxt.data[1]
    BJCVote.Speed.join(ctxt.senderID, gameVehID)
end

function ctrl.SpeedFail(ctxt)
    if not BJCPerm.canSpawnVehicle(ctxt.senderID) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local time = ctxt.data[1]
    BJCScenario.SpeedManager.clientUpdate(ctxt.senderID, time)
end

function ctrl.SpeedStop(ctxt)
    if not BJCPerm.canSpawnVehicle(ctxt.senderID) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCScenario.SpeedManager.stop()
end

function ctrl.HunterSave(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local _, err = pcall(BJCScenarioData.saveHunter, ctxt.data[1])
    BJCTx.scenario.HunterSave(ctxt.senderID, not err)
    if err then
        error(err)
    end
end

function ctrl.HunterStart(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_SERVER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCScenario.HunterManager.start(ctxt.data[1])
end

function ctrl.HunterUpdate(ctxt)
    if not BJCPerm.canSpawnVehicle(ctxt.senderID) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local event, data = ctxt.data[1], ctxt.data[2]
    BJCScenario.HunterManager.clientUpdate(ctxt.senderID, event, data)
end

function ctrl.HunterStop(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_SERVER_SCENARIO) or
        not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCScenario.HunterManager.stop()
end

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

function ctrl.DerbyStart(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_SERVER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local derbyIndex, lives, configs = ctxt.data[1], ctxt.data[2], ctxt.data[3]
    BJCScenario.DerbyManager.start(derbyIndex, lives, configs)
end

function ctrl.DerbyUpdate(ctxt)
    local event, data = ctxt.data[1], ctxt.data[2]
    BJCScenario.DerbyManager.clientUpdate(ctxt.senderID, event, data)
end

function ctrl.DerbyStop(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_SERVER_SCENARIO) or
        not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCScenario.DerbyManager.stop()
end

function ctrl.TagDuoJoin(ctxt)
    if not BJCPerm.canSpawnVehicle(ctxt.senderID) or
        not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local lobbyIndex, vehID = ctxt.data[1], ctxt.data[2]
    BJCScenario.Hybrids.TagDuoManager.onClientJoin(ctxt.senderID, lobbyIndex, vehID)
end

function ctrl.TagDuoUpdate(ctxt)
    if not BJCPerm.canSpawnVehicle(ctxt.senderID) or
        not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local lobbyIndex, event = ctxt.data[1], ctxt.data[2]
    BJCScenario.Hybrids.TagDuoManager.onClientUpdate(ctxt.senderID, lobbyIndex, event)
end

function ctrl.TagDuoLeave(ctxt)
    if not BJCPerm.canSpawnVehicle(ctxt.senderID) or
        not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCScenario.Hybrids.TagDuoManager.onPlayerDisconnect(ctxt.sender)
end

return ctrl
