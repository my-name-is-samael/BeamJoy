local function drawIndicator(ctxt)
    if not ctxt.vehData or not ctxt.vehData.tanks or
        not BJIContext.Scenario.Data.EnergyStations then
        return
    end

    local energyStationCounts = {}
    for _, station in ipairs(BJIContext.Scenario.Data.EnergyStations) do
        for _, energyType in ipairs(station.types) do
            if not energyStationCounts[energyType] then
                energyStationCounts[energyType] = 0
            end
            energyStationCounts[energyType] = energyStationCounts[energyType] + 1
        end
    end
    local garageCount = #BJIContext.Scenario.Data.Garages

    -- group energy types
    local tankGroups = {}
    for _, tank in pairs(ctxt.vehData.tanks) do
        local t = tankGroups[tank.energyType]
        if not t then
            tankGroups[tank.energyType] = {
                current = 0,
                max = 0,
            }
            t = tankGroups[tank.energyType]
        end
        t.current = t.current + tank.currentEnergy
        t.max = t.max + tank.maxEnergy
    end

    local i = 1
    for energyType, energyData in pairs(tankGroups) do
        local indicatorColor = TEXT_COLORS.DEFAULT
        if energyData.current / energyData.max <= .05 then
            indicatorColor = TEXT_COLORS.ERROR
        elseif energyData.current / energyData.max <= .15 then
            indicatorColor = TEXT_COLORS.HIGHLIGHT
        end
        local line = LineBuilder()
            :text(string.var("{1}:", { BJILang.get(string.var("energy.tankNames.{1}", { energyType })) }))
            :text(string.var("{1}{2}", {
                math.round(BJIVeh.jouleToReadableUnit(energyData.current, energyType), 1),
                BJILang.get(string.var("energy.energyUnits.{1}", { energyType }))
            }), indicatorColor)
        if BJIScenario.canRefuelAtStation() and
            not BJIStations.station and
            not BJIContext.User.stationProcess then
            local isEnergyStation = table.includes(BJI_ENERGY_STATION_TYPES, energyType)
            local stationCount = isEnergyStation and
                (energyStationCounts[energyType] and energyStationCounts[energyType]) or
                garageCount
            if stationCount > 0 then
                line:btnIcon({
                    id = string.var("setRouteStation{1}", { i }),
                    icon = ICONS.add_location,
                    style = BTN_PRESETS.SUCCESS,
                    disabled = BJIGPS.getByKey("BJIEnergyStation"),
                    onClick = function()
                        if isEnergyStation then
                            -- Gas station energy types
                            local stations = {}
                            for _, station in ipairs(BJIContext.Scenario.Data.EnergyStations) do
                                if table.includes(station.types, energyType) then
                                    local distance = BJIGPS.getRouteLength({ ctxt.vehPosRot.pos, station
                                        .pos })
                                    table.insert(stations, { station = station, distance = distance })
                                end
                            end
                            table.sort(stations, function(a, b)
                                return a.distance < b.distance
                            end)
                            BJIGPS.prependWaypoint(BJIGPS.KEYS.STATION, stations[1].station.pos,
                                stations[1].station.radius)
                        else
                            -- Garage energy types
                            local garages = {}
                            for _, garage in ipairs(BJIContext.Scenario.Data.Garages) do
                                local distance = BJIGPS.getRouteLength({ ctxt.vehPosRot.pos, garage.pos })
                                table.insert(garages, { garage = garage, distance = distance })
                            end
                            table.sort(garages, function(a, b)
                                return a.distance < b.distance
                            end)
                            BJIGPS.prependWaypoint(BJIGPS.KEYS.STATION, garages[1].garage.pos,
                                garages[1].garage.radius)
                        end
                    end
                })
            end
        end
        if BJIContext.BJC.Freeroam.PreserveEnergy and
            not BJIContext.User.stationProcess and
            energyData.current / energyData.max <= .02 then
            line:btn({
                id = string.var("emergencyRefuel{1}", { energyType }),
                label = BJILang.get("energyStations.emergencyRefuel"),
                style = BTN_PRESETS.ERROR,
                onClick = function()
                    BJIStations.tryRefillVehicle(ctxt, { energyType })
                end,
            })
        end
        line:build()

        ProgressBar({
            floatPercent = energyData.current / energyData.max,
            width = 250,
        })
        i = i + 1
    end
end
return drawIndicator
