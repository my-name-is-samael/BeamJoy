---@class BJIWindowStation : BJIWindow
local W = {
    name = "Station",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE,
        BJI.Utils.Style.WINDOW_FLAGS.ALWAYS_AUTO_RESIZE,
    },

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
        repair = "",
        refill = "",
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

    W.labels.repair = BJI.Managers.Lang.get("garages.repairBtn")
    W.labels.refill = BJI.Managers.Lang.get("energyStations.refill")
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
---@param station BJIStation
local function commonDrawEnergyLines(ctxt, station)
    if not ctxt.vehData.tanks then return end

    local function drawEnergyLine(energyType, energyData)
        local qty = BJI.Managers.Veh.jouleToReadableUnit(energyData.currentEnergy, energyType)
        local max = BJI.Managers.Veh.jouleToReadableUnit(energyData.maxEnergy, energyType)
        Text(string.var("{1} : {2}{4}/{3}{4}", {
            W.labels.tankNames[energyType],
            math.round(qty, 2),
            math.round(max, 2),
            W.labels.energyUnits[energyType]
        }))
        if energyData.amount > 1 then
            SameLine()
            Text(string.var(" ({1})", {
                W.labels.tanksAmount:var({ amount = energyData.amount })
            }))
        end
        SameLine()
        if IconButton(string.var("refill{1}", { energyType }),
                energyType == BJI.CONSTANTS.ENERGY_STATION_TYPES.ELECTRIC and
                BJI.Utils.Icon.ICONS.ev_station or BJI.Utils.Icon.ICONS.local_gas_station,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                    disabled = energyData.currentEnergy / energyData.maxEnergy > .95 }) then
            BJI.Managers.Stations.tryRefillVehicle(ctxt, { energyType }, 100, 5)
        end
        TooltipText(W.labels.refill)

        ProgressBar(energyData.currentEnergy / energyData.maxEnergy)
    end

    local tankGroups = {}
    for _, tank in pairs(ctxt.vehData.tanks) do
        if station.isEnergy then
            -- Energy station
            if table.includes(BJI.CONSTANTS.ENERGY_STATION_TYPES, tank.energyType) and
                table.includes(station.types, tank.energyType) then
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
        Icon(BJI.Utils.Icon.ICONS.block, { color = BJI.Utils.Style.TEXT_COLORS.ERROR })
        SameLine()
        Text(W.labels.noRefuelScenario)
    else
        commonDrawEnergyLines(ctxt, garage)
    end

    if not BJI.Managers.Scenario.canRepairAtGarage() then
        Icon(BJI.Utils.Icon.ICONS.block, { color = BJI.Utils.Style.TEXT_COLORS.ERROR })
        SameLine()
        Text(W.labels.noRepairScenario)
    elseif tonumber(ctxt.veh.veh.damageState) and
        tonumber(ctxt.veh.veh.damageState) >= 1 then
        Text(W.labels.damagedWarning)
        SameLine()
        if IconButton("repairVehicle", BJI.Utils.Icon.ICONS.build,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
            BJI.Managers.Stations.tryRepair(ctxt)
        end
        TooltipText(W.labels.repair)
    else
        Text(W.labels.vehiclePristine)
    end
end

---@param ctxt TickContext
---@param station BJIStation
local function drawEnergyStation(ctxt, station)
    if not station or not ctxt.vehData.tanks then
        return
    end

    if not BJI.Managers.Scenario.canRefuelAtStation() then
        Icon(BJI.Utils.Icon.ICONS.block, { color = BJI.Utils.Style.TEXT_COLORS.ERROR })
        SameLine()
        Text(W.labels.noRefuelScenario)
    else
        commonDrawEnergyLines(ctxt, station)
    end
end

local function header(ctxt)
    if not ctxt.vehData then return end

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
            Icon(BJI.Utils.Icon.ICONS.local_gas_station)
            SameLine()
            Text(string.var("{1} \"{2}\"", { stationNamesLabel, station.name }))
        else
            Text(string.var("{1} \"{2}\"", { W.labels.garage, station.name }))
        end
    end
end

local function body(ctxt)
    if not ctxt.vehData then return end

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
        not BJI.Managers.Stations.stationProcess
end

return W
