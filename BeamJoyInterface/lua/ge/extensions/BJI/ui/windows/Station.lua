---@class BJIWindowStation : BJIWindow
local W = {
    name = "Station",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE
    },
    w = 280,
    h = 150,

    labels = {
        andJoin = "",
        stationNames = {},
        tankNames = {},
        energyUnits = {},
        garage = "",
        noRefuelScenario = "",
        noRepairScenario = "",
        damagedWarning = "",
        vehiclePristine = "",
        tanksAmount = "",
    },
}

local function updateLabels()
    W.labels.andJoin = BJI.Managers.Lang.get("common.and")

    Table(BJI.Managers.Veh.FUEL_TYPES):forEach(function(energyType)
        W.labels.stationNames[energyType] = BJI.Managers.Lang.get(string.var("energy.stationNames.{1}", { energyType }))
        W.labels.tankNames[energyType] = BJI.Managers.Lang.get(string.var("energy.tankNames.{1}", { energyType }))
        W.labels.energyUnits[energyType] = BJI.Managers.Lang.get(string.var("energy.energyUnits.{1}", { energyType }))
    end)
    W.labels.garage = BJI.Managers.Lang.get("garages.garage")
    W.labels.noRefuelScenario = BJI.Managers.Lang.get("energyStations.noRefuelScenario")
    W.labels.noRepairScenario = BJI.Managers.Lang.get("garages.noRepairScenario")
    W.labels.damagedWarning = BJI.Managers.Lang.get("garages.damagedWarning")
    W.labels.vehiclePristine = BJI.Managers.Lang.get("garages.vehiclePristine")
    W.labels.tanksAmount = BJI.Managers.Lang.get("energyStations.tanksAmount")
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateLabels, W.name))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

---@param ctxt TickContext
---@param energyStation BJIStation
local function commonDrawEnergyLines(ctxt, energyStation)
    if not ctxt.vehData.tanks then
        return
    end

    local function drawEnergyLine(energyType, energyData)
        local qty = BJI.Managers.Veh.jouleToReadableUnit(energyData.currentEnergy, energyType)
        local max = BJI.Managers.Veh.jouleToReadableUnit(energyData.maxEnergy, energyType)
        local line = LineBuilder()
            :text(string.var("{1} : {2}{4}/{3}{4}", {
                W.labels.tankNames[energyType],
                math.round(qty, 2),
                math.round(max, 2),
                W.labels.energyUnits[energyType]
            }))
        if energyData.amount > 1 then
            line:text(string.var(" ({1})", {
                W.labels.tanksAmount:var({ amount = energyData.amount })
            }))
        end
        line:btnIcon({
            id = string.var("refill{1}", { energyType }),
            icon = energyType == BJI.CONSTANTS.ENERGY_STATION_TYPES.ELECTRIC and
                BJI.Utils.Icon.ICONS.ev_station or BJI.Utils.Icon.ICONS.local_gas_station,
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            disabled = energyData.currentEnergy / energyData.maxEnergy > .95,
            onClick = function()
                BJI.Managers.Stations.tryRefillVehicle(ctxt, { energyType }, 100, 5)
            end,
        })
            :build()

        ProgressBar({
            floatPercent = energyData.currentEnergy / energyData.maxEnergy,
            width = "100%",
        })
    end

    local tankGroups = {}
    for _, tank in pairs(ctxt.vehData.tanks) do
        if energyStation.isEnergy then
            -- Energy station
            if table.includes(BJI.CONSTANTS.ENERGY_STATION_TYPES, tank.energyType) and
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
            if not table.includes(BJI.CONSTANTS.ENERGY_STATION_TYPES, tank.energyType) then
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
        pcall(drawEnergyLine, energyType, energyData)
    end
end

---@param ctxt TickContext
---@param garage BJIStation
local function drawGarage(ctxt, garage)
    if not garage or not ctxt.vehData.tanks then
        return
    end

    if not BJI.Managers.Scenario.canRefuelAtStation() then
        LineBuilder()
            :icon({
                icon = BJI.Utils.Icon.ICONS.block,
                style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            })
            :text(W.labels.noRefuelScenario)
            :build()
    else
        commonDrawEnergyLines(ctxt, garage)
    end

    if not BJI.Managers.Scenario.canRepairAtGarage() then
        LineBuilder()
            :icon({
                icon = BJI.Utils.Icon.ICONS.block,
                style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            })
            :text(W.labels.noRepairScenario)
            :build()
    elseif tonumber(ctxt.veh.veh.damageState) and
        tonumber(ctxt.veh.veh.damageState) >= 1 then
        LineBuilder()
            :text(W.labels.damagedWarning)
            :btnIcon({
                id = "repairVehicle",
                icon = BJI.Utils.Icon.ICONS.build,
                style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                onClick = function()
                    BJI.Managers.Stations.tryRepair(ctxt)
                end,
            })
            :build()
    else
        LineLabel(W.labels.vehiclePristine)
    end
end

---@param ctxt TickContext
---@param station BJIStation
local function drawEnergyStation(ctxt, station)
    if not station or not ctxt.vehData.tanks then
        return
    end

    if not BJI.Managers.Scenario.canRefuelAtStation() then
        LineBuilder()
            :icon({
                icon = BJI.Utils.Icon.ICONS.block,
                style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            })
            :text(W.labels.noRefuelScenario)
            :build()
    else
        commonDrawEnergyLines(ctxt, station)
    end
end

local function header(ctxt)
    if not ctxt.vehData then
        return
    end

    ---@type table<string, any>
    local station = BJI.Managers.Stations.station
    if station then
        if station.isEnergy then
            local stationEnergyNames = {}
            for _, energyType in ipairs(station.types) do
                local label = W.labels.stationNames[energyType]
                if not table.includes(stationEnergyNames, label) then
                    table.insert(stationEnergyNames, label)
                end
            end
            local stationNamesLabel = table.join(stationEnergyNames,
                string.var(" {1} ", { W.labels.andJoin }))
            LineBuilder()
                :icon({
                    icon = BJI.Utils.Icon.ICONS.local_gas_station,
                })
                :text(string.var("{1} \"{2}\"", { stationNamesLabel, station.name }))
                :build()
        else
            LineLabel(string.var("{1} \"{2}\"", { W.labels.garage, station.name }))
        end
    end
end

local function body(ctxt)
    if not ctxt.vehData then
        return
    end

    ---@type BJIStation?
    local station = BJI.Managers.Stations.station
    if station then
        if station.isEnergy then
            drawEnergyStation(ctxt, station)
        else
            drawGarage(ctxt, station)
        end
    end
end

W.onLoad = onLoad
W.onUnload = onUnload
W.header = header
W.body = body
W.getState = function()
    return BJI.Managers.Perm.canSpawnVehicle() and
        not BJI.Windows.ScenarioEditor.getState() and
        BJI.Managers.Stations.station and
        not BJI.Managers.Context.User.stationProcess
end

return W
