local ctrl = {
    tag = "ScenarioRx"
}

local raceDetailsCallbackFn
---@param callback fun(raceData: table|false)
function ctrl.raceDetailsCallback(callback)
    raceDetailsCallbackFn = callback
end

---@param data table
function ctrl.RaceDetails(data)
    local raceDetails = data[1] -- table or false
    if type(raceDetailsCallbackFn) == "function" then
        raceDetailsCallbackFn(raceDetails)
    end
    raceDetailsCallbackFn = nil
end

local raceSaveCallbackFn
---@param callback fun(raceID: integer|false)
function ctrl.raceSaveCallback(callback)
    raceSaveCallbackFn = callback
end

function ctrl.RaceSave(data)
    local state = data[1]
    if type(raceSaveCallbackFn) == "function" then
        raceSaveCallbackFn(state)
    end
    raceSaveCallbackFn = nil
end

local energyStationsSaveCallbackFn
---@param callback fun(boolean)
function ctrl.energyStationsSaveCallback(callback)
    energyStationsSaveCallbackFn = callback
end

function ctrl.EnergyStationsSave(data)
    local state = data[1]
    if type(energyStationsSaveCallbackFn) == "function" then
        energyStationsSaveCallbackFn(state)
    end
    energyStationsSaveCallbackFn = nil
end

local garagesSaveCallbackFn
---@param callback fun(boolean)
function ctrl.garagesSaveCallback(callback)
    garagesSaveCallbackFn = callback
end

function ctrl.GaragesSave(data)
    local state = data[1]
    if type(garagesSaveCallbackFn) == "function" then
        garagesSaveCallbackFn(state)
    end
    garagesSaveCallbackFn = nil
end

function ctrl.DeliveryStop()
    BJI_Scenario.get(BJI_Scenario.TYPES.VEHICLE_DELIVERY)
        .onStopDelivery()
end

local deliverySaveCallbackFn
---@param callback fun(boolean)
function ctrl.deliverySaveCallback(callback)
    deliverySaveCallbackFn = callback
end

function ctrl.DeliverySave(data)
    local state = data[1]
    if type(deliverySaveCallbackFn) == "function" then
        deliverySaveCallbackFn(state)
    end
    deliverySaveCallbackFn = nil
end

function ctrl.DeliveryPackageSuccess(data)
    local streak = data[1]
    BJI_Scenario.get(BJI_Scenario.TYPES.PACKAGE_DELIVERY).rxStreak(streak)
end

local busLinesSaveCallbackFn
---@param callback fun(boolean)
function ctrl.busLinesSaveCallback(callback)
    busLinesSaveCallbackFn = callback
end

function ctrl.BusLinesSave(data)
    local state = data[1]
    if type(busLinesSaveCallbackFn) == "function" then
        busLinesSaveCallbackFn(state)
    end
    busLinesSaveCallbackFn = nil
end

local hunterInfectedSaveCallbackFn
---@param callback fun(boolean)
function ctrl.hunterInfectedSaveCallback(callback)
    hunterInfectedSaveCallbackFn = callback
end

function ctrl.HunterInfectedSave(data)
    local state = data[1]
    if type(hunterInfectedSaveCallbackFn) == "function" then
        hunterInfectedSaveCallbackFn(state)
    end
    hunterInfectedSaveCallbackFn = nil
end

local derbySaveCallbackFn
---@param callback fun(boolean)
function ctrl.derbySaveCallback(callback)
    derbySaveCallbackFn = callback
end

function ctrl.DerbySave(data)
    local state = data[1]
    if type(derbySaveCallbackFn) == "function" then
        derbySaveCallbackFn(state)
    end
    derbySaveCallbackFn = nil
end

---@param data BJPursuitPayload
function ctrl.PursuitData(data)
    BJI_Pursuit.rxData(data)
end

return ctrl
