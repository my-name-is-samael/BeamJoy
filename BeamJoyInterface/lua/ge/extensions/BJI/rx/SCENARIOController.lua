local ctrl = {
    tag = "BJIScenarioController"
}

function ctrl.RaceDetails(data)
    local raceDetails = data[1] -- table or false
    BJIContext.Scenario.RaceDetails = raceDetails
end

function ctrl.RaceSave(data)
    local state = data[1]
    if BJIContext.Scenario.RaceEdit then
        BJIContext.Scenario.RaceEdit.saveSuccess = state
    end
end

function ctrl.EnergyStationsSave(data)
    local state = data[1]
    if BJIContext.Scenario.EnergyStationsEdit then
        BJIContext.Scenario.EnergyStationsEdit.saveSuccess = state
    end
end

function ctrl.GaragesSave(data)
    local state = data[1]
    if BJIContext.Scenario.GaragesEdit then
        BJIContext.Scenario.GaragesEdit.saveSuccess = state
    end
end

function ctrl.DeliveryStop()
    BJIScenario.get(BJIScenario.TYPES.VEHICLE_DELIVERY).onStopDelivery()
end

function ctrl.DeliverySave(data)
    local state = data[1]
    if BJIContext.Scenario.DeliveryEdit then
        BJIContext.Scenario.DeliveryEdit.saveSuccess = state
    end
end

function ctrl.DeliveryPackageSuccess(data)
    local streak = data[1]
    BJIScenario.get(BJIScenario.TYPES.PACKAGE_DELIVERY).rxStreak(streak)
end

function ctrl.BusLinesSave(data)
    local state = data[1]
    if BJIContext.Scenario.BusLinesEdit then
        BJIContext.Scenario.BusLinesEdit.saveSuccess = state
    end
end

function ctrl.SpeedStop()
    if BJIScenario.is(BJIScenario.TYPES.SPEED) then
        BJIScenario.get(BJIScenario.TYPES.SPEED).stop()
    end
end

function ctrl.HunterSave(data)
    local state = data[1]
    if BJIContext.Scenario.HunterEdit then
        BJIContext.Scenario.HunterEdit.saveSuccess = state
    end
end

function ctrl.DerbySave(data)
    local state = data[1]
    if BJIContext.Scenario.DerbyEdit then
        BJIContext.Scenario.DerbyEdit.saveSuccess = state
    end
end

return ctrl
