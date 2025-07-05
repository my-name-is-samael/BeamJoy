local eventName = BJC_EVENTS.SCENARIO.EVENT

BJCTx.scenario = {}

---@param targetID integer
---@param raceData table|false raceData or error -- TODO type BJCRace
function BJCTx.scenario.RaceDetails(targetID, raceData)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.SCENARIO.TX.RACE_DETAILS, targetID, { raceData })
end

---@param targetID integer
---@param state integer|false raceID or error
function BJCTx.scenario.RaceSave(targetID, state)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.SCENARIO.TX.RACE_SAVE, targetID, state)
end

---@param targetID integer
function BJCTx.scenario.DeliveryStop(targetID)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.SCENARIO.TX.DELIVERY_STOP, targetID)
end

---@param targetID integer
---@param state boolean
function BJCTx.scenario.DeliverySave(targetID, state)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.SCENARIO.TX.DELIVERY_SAVE, targetID, state)
end

---@param targetID integer
---@param state boolean
function BJCTx.scenario.EnergyStationsSave(targetID, state)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.SCENARIO.TX.ENERGY_STATIONS_SAVE, targetID, state)
end

---@param targetID integer
---@param state boolean
function BJCTx.scenario.GaragesSave(targetID, state)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.SCENARIO.TX.GARAGES_SAVE, targetID, state)
end

---@param targetID integer
---@param streak integer
function BJCTx.scenario.DeliveryPackageSuccess(targetID, streak)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.SCENARIO.TX.DELIVERY_PACKAGE_SUCCESS, targetID, streak)
end

---@param targetID integer
---@param state boolean
function BJCTx.scenario.BusLinesSave(targetID, state)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.SCENARIO.TX.BUS_LINES_SAVE, targetID, state)
end

---@param targetID integer
---@param state boolean
function BJCTx.scenario.HunterSave(targetID, state)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.SCENARIO.TX.HUNTER_SAVE, targetID, state)
end

---@param targetID integer
---@param state boolean
function BJCTx.scenario.DerbySave(targetID, state)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.SCENARIO.TX.DERBY_SAVE, targetID, state)
end

---@param targetID integer
---@param data BJPursuitPayload
function BJCTx.scenario.PursuitData(targetID, data)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.SCENARIO.TX.PURSUIT_DATA, targetID, data)
end
