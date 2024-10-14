local eventName = BJC_EVENTS.SCENARIO.EVENT

BJCTx.scenario = {}

function BJCTx.scenario.RaceDetails(targetID, raceData)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.SCENARIO.TX.RACE_DETAILS, targetID, { raceData })
end

function BJCTx.scenario.RaceSave(targetID, state)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.SCENARIO.TX.RACE_SAVE, targetID, state)
end

function BJCTx.scenario.DeliveryStop(targetID)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.SCENARIO.TX.DELIVERY_STOP, targetID)
end

function BJCTx.scenario.DeliverySave(targetID, state)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.SCENARIO.TX.DELIVERY_SAVE, targetID, state)
end

function BJCTx.scenario.EnergyStationsSave(targetID, state)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.SCENARIO.TX.ENERGY_STATIONS_SAVE, targetID, state)
end

function BJCTx.scenario.GaragesSave(targetID, state)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.SCENARIO.TX.GARAGES_SAVE, targetID, state)
end

function BJCTx.scenario.DeliveryPackageSuccess(targetID, streak)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.SCENARIO.TX.DELIVERY_PACKAGE_SUCCESS, targetID, streak)
end

function BJCTx.scenario.BusLinesSave(targetID, state)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.SCENARIO.TX.BUS_LINES_SAVE, targetID, state)
end

function BJCTx.scenario.SpeedStop()
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.SCENARIO.TX.SPEED_STOP, BJCTx.ALL_PLAYERS)
end

function BJCTx.scenario.HunterSave(targetID, state)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.SCENARIO.TX.HUNTER_SAVE, targetID, state)
end

function BJCTx.scenario.DerbySave(targetID, state)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.SCENARIO.TX.DERBY_SAVE, targetID, state)
end
