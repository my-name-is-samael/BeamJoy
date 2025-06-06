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

local cache = newCache()

local function updateCache(ctxt)
    cache = newCache()

    if BJI.Managers.Context.Scenario.Data.EnergyStations then
        for _, station in ipairs(BJI.Managers.Context.Scenario.Data.EnergyStations) do
            for _, energyType in ipairs(station.types) do
                if not cache.stationsCounts[energyType] then
                    cache.stationsCounts[energyType] = 0
                end
                cache.stationsCounts[energyType] = cache.stationsCounts[energyType] + 1
            end
        end
    end

    cache.garagesCount = BJI.Managers.Context.Scenario.Data.Garages and #BJI.Managers.Context.Scenario.Data.Garages or 0

    if ctxt.vehData and ctxt.vehData.tanks then
        local stationBtnEnabled = BJI.Managers.Scenario.canRefuelAtStation() and
            not BJI.Managers.Context.User.stationProcess
        for _, tank in pairs(ctxt.vehData.tanks) do
            if not cache.tanksMaxes[tank.energyType] then
                -- labels by energy type
                cache.labels.tanks[tank.energyType] = BJI.Managers.Lang.get(string.var("energy.tankNames.{1}",
                    { tank.energyType }))
                cache.labels.energyTypes[tank.energyType] = BJI.Managers.Lang.get(string.var("energy.energyUnits.{1}",
                    { tank.energyType }))

                -- gps button by energy type
                if stationBtnEnabled then
                    if table.includes(BJI.CONSTANTS.ENERGY_STATION_TYPES, tank.energyType) then
                        -- fuel / electricity
                        local stationCount = cache.stationsCounts[tank.energyType] or 0
                        if stationCount > 0 and (
                                not BJI.Managers.Stations.station or
                                not BJI.Managers.Stations.station.isEnergy or
                                not table.includes(BJI.Managers.Stations.station.types, tank.energyType)
                            ) then
                            cache.showGPSButton[tank.energyType] = true
                        end
                    elseif tank.energyType == BJI.Managers.Veh.FUEL_TYPES.N2O then
                        if cache.garagesCount > 0 and (
                                not BJI.Managers.Stations.station or
                                BJI.Managers.Stations.station.isEnergy
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
        BJI.Managers.Context.BJC.Freeroam.PreserveEnergy and
        not BJI.Managers.Context.User.stationProcess

    cache.ready = table.length(cache.tanksMaxes) > 0
end

local function draw(ctxt)
    if not ctxt.vehData or not ctxt.vehData.tanks or not cache.ready then
        return
    end

    -- energy amount values by type
    local tanksValues = {}
    for _, tank in pairs(ctxt.vehData.tanks) do
        if not tanksValues[tank.energyType] then
            tanksValues[tank.energyType] = 0
        end
        tanksValues[tank.energyType] = tanksValues[tank.energyType] + tank.currentEnergy
    end

    local i = 1
    for energyType, energyAmount in pairs(tanksValues) do
        local valuePercent = energyAmount / cache.tanksMaxes[energyType]
        local indicatorColor = BJI.Utils.Style.TEXT_COLORS.DEFAULT
        local progressColor = BJI.Utils.Style.BTN_PRESETS.SUCCESS[1]
        if valuePercent <= BJI.Managers.Veh.tankLowThreshold then
            indicatorColor = BJI.Utils.Style.TEXT_COLORS.ERROR
            progressColor = BJI.Utils.Style.BTN_PRESETS.ERROR[1]
        elseif valuePercent <= BJI.Managers.Veh.tankMedThreshold then
            indicatorColor = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT
            progressColor = BJI.Utils.Style.BTN_PRESETS.WARNING[1]
        end
        local line = LineBuilder()
            :text(string.var("{1}:", { cache.labels.tanks[energyType] }))
            :text(string.var("{1}{2}", {
                math.round(BJI.Managers.Veh.jouleToReadableUnit(energyAmount, energyType), 1),
                cache.labels.energyTypes[energyType]
            }), indicatorColor)
        if cache.showGPSButton[energyType] then
            line:btnIcon({
                id = string.var("setRouteStation{1}", { i }),
                icon = BJI.Utils.Icon.ICONS.add_location,
                style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                disabled = BJI.Managers.GPS.getByKey("BJIEnergyStation"),
                tooltip = BJI.Managers.Lang.get("common.buttons.setGPS"),
                onClick = function()
                    if table.includes(BJI.CONSTANTS.ENERGY_STATION_TYPES, energyType) then
                        -- Gas station energy types
                        local stations = {}
                        for _, station in ipairs(BJI.Managers.Context.Scenario.Data.EnergyStations) do
                            if table.includes(station.types, energyType) then
                                local distance = BJI.Managers.GPS.getRouteLength({ ctxt.vehPosRot.pos, station
                                    .pos })
                                table.insert(stations, { station = station, distance = distance })
                            end
                        end
                        table.sort(stations, function(a, b)
                            return a.distance < b.distance
                        end)
                        BJI.Managers.GPS.prependWaypoint(BJI.Managers.GPS.KEYS.STATION, stations[1].station.pos,
                            stations[1].station.radius)
                    else
                        -- Garage energy types
                        local garages = {}
                        for _, garage in ipairs(BJI.Managers.Context.Scenario.Data.Garages) do
                            local distance = BJI.Managers.GPS.getRouteLength({ ctxt.vehPosRot.pos, garage.pos })
                            table.insert(garages, { garage = garage, distance = distance })
                        end
                        table.sort(garages, function(a, b)
                            return a.distance < b.distance
                        end)
                        BJI.Managers.GPS.prependWaypoint(BJI.Managers.GPS.KEYS.STATION, garages[1].garage.pos,
                            garages[1].garage.radius)
                    end
                end,
                sound = BTN_NO_SOUND,
            })
        end
        if cache.canShowEmergencyRefuelButton and
            table.includes(BJI.CONSTANTS.ENERGY_STATION_TYPES, energyType) and
            valuePercent <= BJI.Managers.Veh.tankEmergencyRefuelThreshold then
            line:btn({
                id = string.var("emergencyRefuel{1}", { energyType }),
                label = BJI.Managers.Lang.get("energyStations.emergencyRefuel"),
                style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                onClick = function()
                    BJI.Managers.Stations.tryRefillVehicle(ctxt, { energyType })
                end,
            })
        end
        line:build()

        ProgressBar({
            floatPercent = valuePercent,
            style = progressColor,
            width = "100%",
        })
        i = i + 1
    end
end

return {
    updateCache = updateCache,
    draw = draw
}
