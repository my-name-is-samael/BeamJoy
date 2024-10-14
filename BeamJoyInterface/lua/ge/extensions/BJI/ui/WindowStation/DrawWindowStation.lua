local function onRefill(veh, tankName, targetEnergy, energyType)
    BJIContext.User.stationProcess = true
    BJICam.forceCamera(BJICam.CAMERAS.EXTERNAL)
    local wasFreeze = veh.freeze
    veh.freeze = true
    BJIVeh.freeze(true, veh.vehGameID)
    local wasEngine = veh.engine
    veh.engine = false
    BJIVeh.engine(false, veh.vehGameID)

    local completedLabel = BJILang.get(energyType == BJI_ENERGY_STATION_TYPES.ELECTRIC and
        "energyStations.flashBatteryFilled" or
        "energyStations.flashTankFilled")
    BJIMessage.flashCountdown("BJIRefill", GetCurrentTimeMillis() + 5000, false,
        completedLabel)
    BJIAsync.delayTask(function()
        BJIVeh.setFuel(tankName, targetEnergy)
    end, 4000, "BJIStationRefillFuel")
    BJIAsync.delayTask(function()
        veh.freeze = wasFreeze
        if not wasFreeze then
            BJIVeh.freeze(false, veh.vehGameID)
        end
        veh.engine = wasEngine
        BJIVeh.engine(wasEngine, veh.vehGameID)
        BJICam.resetForceCamera()
        BJIContext.User.stationProcess = false
    end, 5000, "BJIStationRefillEnd")
end

local function onRepair(veh)
    BJIContext.User.stationProcess = true
    BJICam.forceCamera(BJICam.CAMERAS.EXTERNAL)
    local wasFreeze = veh.freeze
    veh.freeze = true
    BJIVeh.freeze(true, veh.vehGameID)
    local wasEngine = veh.engine
    veh.engine = false
    BJIVeh.engine(false, veh.vehGameID)

    BJIMessage.flashCountdown("BJIRefill", GetCurrentTimeMillis() + 5000, false,
        BJILang.get("garages.flashVehicleRepaired"))
    BJIAsync.delayTask(function()
        BJIReputation.onGarageRepair()
        BJIScenario.onGarageRepair()
        BJIVeh.setPositionRotation(BJIVeh.getPositionRotation().pos, nil, {
            safe = false
        })
        BJIVeh.postResetPreserveEnergy(veh.gameVehID)
        veh.freeze = wasFreeze
        if not wasFreeze then
            BJIVeh.freeze(false, veh.vehGameID)
        end
        veh.engine = wasEngine
        BJIVeh.engine(wasEngine, veh.vehGameID)
        BJICam.resetForceCamera()
        BJIContext.User.stationProcess = false
    end, 5000)
end

local function commonDrawEnergyLines(veh, energyStation)
    local function drawLine(tankName, tank)
        local qty = BJIVeh.jouleToReadableUnit(tank.currentEnergy, tank.energyType)
        local max = BJIVeh.jouleToReadableUnit(tank.maxEnergy, tank.energyType)
        local line = LineBuilder()
            :text(svar("{1} : {2}{4}/{3}{4}", {
                BJILang.get(svar("energy.tankNames.{1}", { tank.energyType })),
                Round(qty, 2),
                Round(max, 2),
                BJILang.get(svar("energy.energyUnits.{1}", { tank.energyType }))
            }))
        if qty < max * .95 then
            local icon = ICONS.local_gas_station
            if tank.energyType == BJI_ENERGY_STATION_TYPES.ELECTRIC then
                -- ELECTRIC
                icon = ICONS.ev_station
            end
            line:btnIcon({
                id = svar("refill{1}", { tankName }),
                icon = icon,
                style = TEXT_COLORS.DEFAULT,
                background = BTN_PRESETS.SUCCESS,
                onClick = function()
                    onRefill(veh, tankName, tank.maxEnergy, tank.energyType)
                end,
            })
        end
        line:build()
    end
    for tankName, tank in pairs(veh.tanks) do
        if energyStation then
            -- Energy station
            if tincludes(BJI_ENERGY_STATION_TYPES, tank.energyType, true) and
                tincludes(energyStation.types, tank.energyType, true) then
                drawLine(tankName, tank)
            end
        else
            -- Garage
            if not tincludes(BJI_ENERGY_STATION_TYPES, tank.energyType, true) then
                drawLine(tankName, tank)
            end
        end
    end
end

local function drawGarage(veh, garage)
    if not garage or not veh.tanks then
        return
    end

    commonDrawEnergyLines(veh)

    if not BJIScenario.canRepairAtGarage() then
        LineBuilder()
            :icon({
                icon = ICONS.block,
                style = TEXT_COLORS.ERROR,
            })
            :text(BJILang.get("garages.noRepairScenario"))
            :build()
    elseif veh.damageState >= 1 then
        LineBuilder()
            :text(BJILang.get("garages.damagedWarning"))
            :btnIcon({
                id = "repairVehicle",
                icon = ICONS.build,
                background = BTN_PRESETS.SUCCESS,
                onClick = function()
                    onRepair(veh)
                end,
            })
            :build()
    else
        LineBuilder()
            :text(BJILang.get("garages.vehiclePristine"))
            :build()
    end
end

local function drawEnergyStation(veh, station)
    if not station or not veh.tanks then
        return
    end

    if not BJIScenario.canRefuelAtStation() then
        LineBuilder()
            :icon({
                icon = ICONS.block,
                style = TEXT_COLORS.ERROR,
            })
            :text(BJILang.get("energyStations.noRefuelScenario"))
            :build()
    else
        commonDrawEnergyLines(veh, station)
    end
end

local function drawHeader(ctxt)
    if not ctxt.vehData then
        return
    end

    local station = BJIStations.station
    if station then
        if station.isEnergy then
            local stationEnergyNames = {}
            for _, energyType in ipairs(station.types) do
                local label = BJILang.get(svar("energy.stationNames.{1}", { energyType }))
                if not tincludes(stationEnergyNames, label, true) then
                    table.insert(stationEnergyNames, label)
                end
            end
            local stationNamesLabel = table.concat(stationEnergyNames,
                svar(" {1} ", { BJILang.get("common.and") }))
            LineBuilder()
                :icon({
                    icon = ICONS.local_gas_station,
                })
                :text(svar("{1} \"{2}\"", { stationNamesLabel, station.name }))
                :build()
        else
            LineBuilder()
                :text(svar("{1} \"{2}\"", { BJILang.get("garages.garage"), station.name }))
                :build()
        end
    end
end

local function drawBody(ctxt)
    if not ctxt.vehData then
        return
    end

    local station = BJIStations.station
    if station then
        if station.isEnergy then
            drawEnergyStation(ctxt.vehData, station)
        else
            drawGarage(ctxt.vehData, station)
        end
    end
end

return {
    flags = {
        WINDOW_FLAGS.NO_COLLAPSE
    },
    header = drawHeader,
    body = drawBody,
}
