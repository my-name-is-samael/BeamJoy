local event = BJI_EVENTS.SCENARIO

BJITx.scenario = {}

function BJITx.scenario.RaceDetails(raceID)
    BJITx._send(event.EVENT, event.TX.RACE_DETAILS, { raceID })
end

function BJITx.scenario.RaceSave(raceData)
    BJITx._send(event.EVENT, event.TX.RACE_SAVE, { raceData })
end

function BJITx.scenario.RaceToggle(raceID, state)
    BJITx._send(event.EVENT, event.TX.RACE_TOGGLE, { raceID, state })
end

function BJITx.scenario.RaceDelete(raceID)
    BJITx._send(event.EVENT, event.TX.RACE_DELETE, { raceID })
end

function BJITx.scenario.RaceMultiUpdate(eventName, data)
    BJITx._send(event.EVENT, event.TX.RACE_MULTI_UPDATE, { eventName, data })
end

function BJITx.scenario.RaceMultiStop()
    BJITx._send(event.EVENT, event.TX.RACE_MULTI_STOP)
end

function BJITx.scenario.RaceSoloStart()
    BJITx._send(event.EVENT, event.TX.RACE_SOLO_START)
end

function BJITx.scenario.RaceSoloUpdate(raceID, time, model)
    BJITx._send(event.EVENT, event.TX.RACE_SOLO_UPDATE, { raceID, time, model })
end

function BJITx.scenario.RaceSoloEnd(finished)
    BJITx._send(event.EVENT, event.TX.RACE_SOLO_END, { finished })
end

function BJITx.scenario.EnergyStationsSave(energyStations)
    BJITx._send(event.EVENT, event.TX.ENERGY_STATIONS_SAVE, { energyStations })
end

function BJITx.scenario.GaragesSave(garages)
    BJITx._send(event.EVENT, event.TX.GARAGES_SAVE, { garages })
end

function BJITx.scenario.DeliverySave(positions)
    BJITx._send(event.EVENT, event.TX.DELIVERY_SAVE, { positions })
end

function BJITx.scenario.DeliveryVehicleStart()
    BJITx._send(event.EVENT, event.TX.DELIVERY_VEHICLE_START)
end

function BJITx.scenario.DeliveryVehicleSuccess(isPristine)
    BJITx._send(event.EVENT, event.TX.DELIVERY_VEHICLE_SUCCESS, { isPristine })
end

function BJITx.scenario.DeliveryVehicleFail()
    BJITx._send(event.EVENT, event.TX.DELIVERY_VEHICLE_FAIL)
end

function BJITx.scenario.DeliveryPackageStart()
    BJITx._send(event.EVENT, event.TX.DELIVERY_PACKAGE_START)
end

function BJITx.scenario.DeliveryPackageSuccess()
    BJITx._send(event.EVENT, event.TX.DELIVERY_PACKAGE_SUCCESS)
end

function BJITx.scenario.DeliveryPackageFail()
    BJITx._send(event.EVENT, event.TX.DELIVERY_PACKAGE_FAIL)
end

function BJITx.scenario.DeliveryMultiJoin(gameVehID, pos)
    BJITx._send(event.EVENT, event.TX.DELIVERY_MULTI_JOIN, { gameVehID, pos })
end

function BJITx.scenario.DeliveryMultiResetted()
    BJITx._send(event.EVENT, event.TX.DELIVERY_MULTI_RESETTED)
end

function BJITx.scenario.DeliveryMultiReached()
    BJITx._send(event.EVENT, event.TX.DELIVERY_MULTI_REACHED)
end

function BJITx.scenario.DeliveryMultiLeave()
    BJITx._send(event.EVENT, event.TX.DELIVERY_MULTI_LEAVE)
end

function BJITx.scenario.BusLinesSave(busLines)
    BJITx._send(event.EVENT, event.TX.BUS_LINES_SAVE, { busLines })
end

function BJITx.scenario.BusMissionStart()
    BJITx._send(event.EVENT, event.TX.BUS_MISSION_START)
end

function BJITx.scenario.BusMissionReward(idBusLine)
    BJITx._send(event.EVENT, event.TX.BUS_MISSION_REWARD, { idBusLine })
end

function BJITx.scenario.BusMissionStop()
    BJITx._send(event.EVENT, event.TX.BUS_MISSION_STOP)
end

function BJITx.scenario.SpeedStart(isVote)
    BJITx._send(event.EVENT, event.TX.SPEED_START, { isVote })
end

function BJITx.scenario.SpeedJoin(gameVehID)
    BJITx._send(event.EVENT, event.TX.SPEED_JOIN, { gameVehID })
end

function BJITx.scenario.SpeedFail(time)
    BJITx._send(event.EVENT, event.TX.SPEED_FAIL, { time })
end

function BJITx.scenario.SpeedStop()
    BJITx._send(event.EVENT, event.TX.SPEED_STOP)
end

function BJITx.scenario.HunterSave(hunterData)
    BJITx._send(event.EVENT, event.TX.HUNTER_SAVE, { hunterData })
end

function BJITx.scenario.HunterStart(settings)
    BJITx._send(event.EVENT, event.TX.HUNTER_START, { settings })
end

function BJITx.scenario.HunterUpdate(clientEvent, data)
    BJITx._send(event.EVENT, event.TX.HUNTER_UPDATE, { clientEvent, data })
end

function BJITx.scenario.HunterStop()
    BJITx._send(event.EVENT, event.TX.HUNTER_STOP)
end

function BJITx.scenario.DerbySave(arenas)
    BJITx._send(event.EVENT, event.TX.DERBY_SAVE, { arenas })
end

function BJITx.scenario.DerbyStart(index, lives, configs)
    BJITx._send(event.EVENT, event.TX.DERBY_START, { index, lives, configs })
end

function BJITx.scenario.DerbyUpdate(clientEvent, data)
    BJITx._send(event.EVENT, event.TX.DERBY_UPDATE, { clientEvent, data })
end

function BJITx.scenario.DerbyStop()
    BJITx._send(event.EVENT, event.TX.DERBY_STOP)
end

function BJITx.scenario.TagDuoJoin(lobbyId, gameVehID)
    BJITx._send(event.EVENT, event.TX.TAG_DUO_JOIN, { lobbyId, gameVehID })
end

function BJITx.scenario.TagDuoUpdate(lobbyId, clientEvent)
    BJITx._send(event.EVENT, event.TX.TAG_DUO_UPDATE, { lobbyId, clientEvent })
end

function BJITx.scenario.TagDuoLeave()
    BJITx._send(event.EVENT, event.TX.TAG_DUO_LEAVE)
end
