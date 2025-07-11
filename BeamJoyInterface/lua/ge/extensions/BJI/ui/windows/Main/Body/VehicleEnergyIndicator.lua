local function newCache()
    return {
        stationsCounts = {},
        garagesCount = 0,
        tanksMaxes = {},
        showGPSButton = {},
        canShowEmergencyRefuelButton = false,
        ready = false,

        labels = {
            tanks = {},
            energyTypes = {},
        },
    }
end
-- gc prevention
local tanksValues, valuePercent, indicatorColor, progressColor, stations, garages, distance

local cache = newCache()

---@param ctxt TickContext
local function updateCache(ctxt)
    cache = newCache()

    if BJI_Context.Scenario.Data.EnergyStations then
        for _, station in ipairs(BJI_Context.Scenario.Data.EnergyStations) do
            for _, energyType in ipairs(station.types) do
                if not cache.stationsCounts[energyType] then
                    cache.stationsCounts[energyType] = 0
                end
                cache.stationsCounts[energyType] = cache.stationsCounts[energyType] + 1
            end
        end
    end

    cache.garagesCount = BJI_Context.Scenario.Data.Garages and #BJI_Context.Scenario.Data.Garages or 0

    if ctxt.vehData and ctxt.vehData.tanks then
        local stationBtnEnabled = BJI_Scenario.canRefuelAtStation() and
            not BJI_Stations.stationProcess
        for _, tank in pairs(ctxt.vehData.tanks) do
            if not cache.tanksMaxes[tank.energyType] then
                -- labels by energy type
                cache.labels.tanks[tank.energyType] = BJI_Lang.get(string.var("energy.tankNames.{1}",
                    { tank.energyType }))
                cache.labels.energyTypes[tank.energyType] = BJI_Lang.get(string.var("energy.energyUnits.{1}",
                    { tank.energyType }))

                -- gps button by energy type
                if stationBtnEnabled then
                    if table.includes(BJI.CONSTANTS.ENERGY_STATION_TYPES, tank.energyType) then
                        -- fuel / electricity
                        local stationCount = cache.stationsCounts[tank.energyType] or 0
                        if stationCount > 0 and (
                                not BJI_Stations.station or
                                not BJI_Stations.station.isEnergy or
                                not table.includes(BJI_Stations.station.types, tank.energyType)
                            ) then
                            cache.showGPSButton[tank.energyType] = true
                        end
                    elseif tank.energyType == BJI_Veh.FUEL_TYPES.N2O then
                        if cache.garagesCount > 0 and (
                                not BJI_Stations.station or
                                BJI_Stations.station.isEnergy
                            ) then
                            cache.showGPSButton[tank.energyType] = true
                        end
                    end
                end

                -- max capacity by energy type
                cache.tanksMaxes[tank.energyType] = 0
            end
            cache.tanksMaxes[tank.energyType] = cache.tanksMaxes[tank.energyType] + tank.maxEnergy
        end
    end

    cache.canShowEmergencyRefuelButton = ctxt.isOwner and
        BJI_Context.BJC.Freeroam.PreserveEnergy and
        not BJI_Stations.stationProcess

    cache.ready = table.length(cache.tanksMaxes) > 0
end

local function draw(ctxt)
    if not ctxt.vehData or not ctxt.vehData.tanks or not cache.ready then
        return
    end

    -- energy amount values by type
    tanksValues = {}
    for _, tank in pairs(ctxt.vehData.tanks) do
        if not tanksValues[tank.energyType] then
            tanksValues[tank.energyType] = 0
        end
        tanksValues[tank.energyType] = tanksValues[tank.energyType] + tank.currentEnergy
    end

    if BeginTable("BJIMainVehicleEnergyIndicator", {
            { label = "##main-energy-indicator-amount", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
            { label = "##main-energy-indicator-buttons" },
        }) then
        for energyType, energyAmount in pairs(tanksValues) do
            if cache.labels.tanks[energyType] then
                valuePercent = energyAmount / (cache.tanksMaxes[energyType] or 1)
                indicatorColor = BJI.Utils.Style.TEXT_COLORS.DEFAULT
                progressColor = BJI.Utils.Style.BTN_PRESETS.SUCCESS[1]
                if valuePercent <= BJI_Veh.tankLowThreshold then
                    indicatorColor = BJI.Utils.Style.TEXT_COLORS.ERROR
                    progressColor = BJI.Utils.Style.BTN_PRESETS.ERROR[1]
                elseif valuePercent <= BJI_Veh.tankMedThreshold then
                    indicatorColor = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT
                    progressColor = BJI.Utils.Style.BTN_PRESETS.WARNING[1]
                end
                TableNewRow()
                Text(cache.labels.tanks[energyType] .. " :")
                SameLine()
                Text(string.var("{1}{2}", {
                    math.round(BJI_Veh.jouleToReadableUnit(energyAmount, energyType), 1),
                    cache.labels.energyTypes[energyType]
                }), { color = indicatorColor })
                ProgressBar(valuePercent, { color = progressColor }) -- progress on the next line
                TableNextColumn()
                if cache.showGPSButton[energyType] then
                    if IconButton("setRouteStation" .. energyType, #BJI_GPS.targets > 0 and
                            BJI.Utils.Icon.ICONS.simobject_bng_waypoint or BJI.Utils.Icon.ICONS.add_location,
                            { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, noSound = true,
                                disabled = BJI_GPS.getByKey("BJIEnergyStation") ~= nil }) then
                        if table.includes(BJI.CONSTANTS.ENERGY_STATION_TYPES, energyType) then
                            -- Gas station energy types
                            stations = {}
                            for _, station in ipairs(BJI_Context.Scenario.Data.EnergyStations) do
                                if table.includes(station.types, energyType) then
                                    distance = BJI_GPS.getRouteLength({ ctxt.veh.position, station
                                        .pos })
                                    table.insert(stations, { station = station, distance = distance })
                                end
                            end
                            table.sort(stations, function(a, b)
                                return a.distance < b.distance
                            end)
                            BJI_GPS.prependWaypoint({
                                key = BJI_GPS.KEYS.STATION,
                                pos = stations[1].station.pos,
                                radius = stations[1].station.radius
                            })
                        else
                            -- Garage energy types
                            garages = {}
                            for _, garage in ipairs(BJI_Context.Scenario.Data.Garages) do
                                distance = BJI_GPS.getRouteLength({ ctxt.veh.position, garage.pos })
                                table.insert(garages, { garage = garage, distance = distance })
                            end
                            table.sort(garages, function(a, b)
                                return a.distance < b.distance
                            end)
                            BJI_GPS.prependWaypoint({
                                key = BJI_GPS.KEYS.STATION,
                                pos = garages[1].garage.pos,
                                radius = garages[1].garage.radius
                            })
                        end
                    end
                    TooltipText(BJI_Lang.get("common.buttons.setGPS"))
                end
                if cache.canShowEmergencyRefuelButton and
                    table.includes(BJI.CONSTANTS.ENERGY_STATION_TYPES, energyType) and
                    valuePercent <= BJI_Veh.tankEmergencyRefuelThreshold then
                    if cache.showGPSButton[energyType] then
                        SameLine()
                    end
                    if IconButton("emergencyRefuel" .. energyType, energyType == BJI.CONSTANTS.ENERGY_STATION_TYPES.ELECTRIC and
                            BJI.Utils.Icon.ICONS.ev_station or BJI.Utils.Icon.ICONS.local_gas_station,
                            { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
                        BJI_Stations.tryRefillVehicle(ctxt, { energyType })
                    end
                    TooltipText(BJI_Lang.get("energyStations.emergencyRefuel"))
                end
            end
        end

        EndTable()
    end
end

return {
    updateCache = updateCache,
    draw = draw
}
