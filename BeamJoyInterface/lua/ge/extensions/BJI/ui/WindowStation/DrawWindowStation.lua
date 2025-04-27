local function onRepair(ctxt)
    BJIVeh.stopCurrentVehicle()
    BJIContext.User.stationProcess = true
    local wasResetRestricted = BJIRestrictions.getState(BJIRestrictions.TYPES.Reset)
    if not wasResetRestricted then
        BJIRestrictions.apply(BJIRestrictions.TYPES.Reset, true)
    end
    BJICam.forceCamera(BJICam.CAMERAS.EXTERNAL)
    ctxt.vehData.freezeStation = true
    BJIVeh.freeze(true, ctxt.vehData.vehGameID)
    ctxt.vehData.engineStation = false
    BJIVeh.engine(false, ctxt.vehData.vehGameID)

    BJIMessage.flashCountdown("BJIRefill", GetCurrentTimeMillis() + 5000, false,
        BJILang.get("garages.flashVehicleRepaired"))
    BJIAsync.delayTask(function()
        BJIReputation.onGarageRepair()
        BJIScenario.onGarageRepair()
        BJIVeh.setPositionRotation(BJIVeh.getPositionRotation().pos, nil, {
            safe = false
        })
        BJIVeh.postResetPreserveEnergy(ctxt.vehData.gameVehID)
        ctxt.vehData.freezeStation = false
        if not ctxt.vehData.freeze then
            BJIVeh.freeze(false, ctxt.vehData.vehGameID)
        end
        ctxt.vehData.engineStation = true
        if ctxt.vehData.engine then
            BJIVeh.engine(true, ctxt.vehData.vehGameID)
        end
        BJICam.resetForceCamera()
        if not wasResetRestricted then
            BJIRestrictions.apply(BJIRestrictions.TYPES.Reset, false)
        end
        BJIContext.User.stationProcess = false
    end, 5000, "BJIStationRepair")
end

local function commonDrawEnergyLines(ctxt, energyStation)
    if not energyStation or not ctxt.vehData.tanks then
        return
    end

    local function drawEnergyLine(energyType, energyData)
        local qty = BJIVeh.jouleToReadableUnit(energyData.currentEnergy, energyType)
        local max = BJIVeh.jouleToReadableUnit(energyData.maxEnergy, energyType)
        local line = LineBuilder()
            :text(string.var("{1} : {2}{4}/{3}{4}", {
                BJILang.get(string.var("energy.tankNames.{1}", { energyType })),
                math.round(qty, 2),
                math.round(max, 2),
                BJILang.get(string.var("energy.energyUnits.{1}", { energyType }))
            }))
        if energyData.amount > 1 then
            line:text(string.var(" ({1})", {
                BJILang.get("energyStations.tanksAmount")
                    :var({ amount = energyData.amount })
            }))
        end
        local icon = ICONS.local_gas_station
        if energyType == BJI_ENERGY_STATION_TYPES.ELECTRIC then
            -- ELECTRIC
            icon = ICONS.ev_station
        end
        line:btnIcon({
            id = string.var("refill{1}", { energyType }),
            icon = icon,
            style = BTN_PRESETS.SUCCESS,
            disabled = energyData.currentEnergy / energyData.maxEnergy > .95,
            onClick = function()
                BJIStations.tryRefillVehicle(ctxt, { energyType }, 100, 5)
            end,
        })
            :build()

        ProgressBar({
            floatPercent = energyData.currentEnergy / energyData.maxEnergy,
            width = 250,
        })
    end

    local tankGroups = {}
    for _, tank in pairs(ctxt.vehData.tanks) do
        if energyStation then
            -- Energy station
            if table.includes(BJI_ENERGY_STATION_TYPES, tank.energyType) and
                table.includes(energyStation.types, tank.energyType) then
                if not tankGroups[tank.energyType] then
                    tankGroups[tank.energyType] = {
                        currentEnergy = 0,
                        maxEnergy = 0,
                        amount = 0,
                    }
                end
                tankGroups[tank.energyType].currentEnergy = tankGroups[tank.energyType].currentEnergy +
                    tank.currentEnergy
                tankGroups[tank.energyType].maxEnergy = tankGroups[tank.energyType].maxEnergy + tank.maxEnergy
                tankGroups[tank.energyType].amount = tankGroups[tank.energyType].amount + 1
            end
        else
            -- Garage
            if not table.includes(BJI_ENERGY_STATION_TYPES, tank.energyType) then
                if not tankGroups[tank.energyType] then
                    tankGroups[tank.energyType] = {
                        currentEnergy = 0,
                        maxEnergy = 0,
                        amount = 0,
                    }
                end
                tankGroups[tank.energyType].currentEnergy = tankGroups[tank.energyType].currentEnergy +
                    tank.currentEnergy
                tankGroups[tank.energyType].maxEnergy = tankGroups[tank.energyType].maxEnergy + tank.maxEnergy
                tankGroups[tank.energyType].amount = tankGroups[tank.energyType].amount + 1
            end
        end
    end

    for energyType, energyData in pairs(tankGroups) do
        drawEnergyLine(energyType, energyData)
    end
end

local function drawGarage(ctxt, garage)
    if not garage or not ctxt.vehData.tanks then
        return
    end

    commonDrawEnergyLines(ctxt)

    if not BJIScenario.canRepairAtGarage() then
        LineBuilder()
            :icon({
                icon = ICONS.block,
                style = BTN_PRESETS.ERROR,
            })
            :text(BJILang.get("garages.noRepairScenario"))
            :build()
    elseif ctxt.vehData.damageState >= 1 then
        LineBuilder()
            :text(BJILang.get("garages.damagedWarning"))
            :btnIcon({
                id = "repairVehicle",
                icon = ICONS.build,
                style = BTN_PRESETS.SUCCESS,
                onClick = function()
                    onRepair(ctxt)
                end,
            })
            :build()
    else
        LineBuilder()
            :text(BJILang.get("garages.vehiclePristine"))
            :build()
    end
end

local function drawEnergyStation(ctxt, station)
    if not station or not ctxt.vehData.tanks then
        return
    end

    if not BJIScenario.canRefuelAtStation() then
        LineBuilder()
            :icon({
                icon = ICONS.block,
                style = BTN_PRESETS.ERROR,
            })
            :text(BJILang.get("energyStations.noRefuelScenario"))
            :build()
    else
        commonDrawEnergyLines(ctxt, station)
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
                local label = BJILang.get(string.var("energy.stationNames.{1}", { energyType }))
                if not table.includes(stationEnergyNames, label) then
                    table.insert(stationEnergyNames, label)
                end
            end
            local stationNamesLabel = table.concat(stationEnergyNames,
                string.var(" {1} ", { BJILang.get("common.and") }))
            LineBuilder()
                :icon({
                    icon = ICONS.local_gas_station,
                })
                :text(string.var("{1} \"{2}\"", { stationNamesLabel, station.name }))
                :build()
        else
            LineBuilder()
                :text(string.var("{1} \"{2}\"", { BJILang.get("garages.garage"), station.name }))
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
            drawEnergyStation(ctxt, station)
        else
            drawGarage(ctxt, station)
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
