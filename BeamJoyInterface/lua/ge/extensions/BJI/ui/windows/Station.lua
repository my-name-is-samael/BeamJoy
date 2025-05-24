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
local function onRepair(ctxt)
    BJI.Managers.Veh.stopCurrentVehicle()
    ctxt.user.stationProcess = true
    local previousRestrictions = BJI.Managers.Restrictions.getCurrentResets()
    BJI.Managers.Restrictions.updateResets(BJI.Managers.Restrictions.RESET.ALL)
    BJI.Managers.Cam.forceCamera(BJI.Managers.Cam.CAMERAS.EXTERNAL)
    ctxt.vehData.freezeStation = true
    BJI.Managers.Veh.freeze(true, ctxt.vehData.finalGameVehID)
    ctxt.vehData.engineStation = false
    BJI.Managers.Veh.engine(false, ctxt.vehData.finalGameVehID)
    BJI.Managers.Reputation.onGarageRepair()
    BJI.Managers.Scenario.onGarageRepair()

    BJI.Managers.Message.flashCountdown("BJIRefill", GetCurrentTimeMillis() + 5010, false,
        BJI.Managers.Lang.get("garages.flashVehicleRepaired"))
    BJI.Managers.Async.delayTask(function()
        BJI.Managers.Veh.setPositionRotation(BJI.Managers.Veh.getPositionRotation().pos, nil, {
            safe = false
        })
        BJI.Managers.Veh.postResetPreserveEnergy(ctxt.vehData.gameVehID)
        ctxt.vehData.freezeStation = false
        if not ctxt.vehData.freeze then
            BJI.Managers.Veh.freeze(false, ctxt.vehData.finalGameVehID)
        end
        ctxt.vehData.engineStation = true
        if ctxt.vehData.engine then
            BJI.Managers.Veh.engine(true, ctxt.vehData.finalGameVehID)
        end
        BJI.Managers.Cam.resetForceCamera(true)
        BJI.Managers.Restrictions.updateResets(previousRestrictions)
        ctxt.user.stationProcess = false
    end, 5000, "BJIStationRepair")
end

local function commonDrawEnergyLines(ctxt, energyStation)
    if not energyStation or not ctxt.vehData.tanks then
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
                ICONS.ev_station or ICONS.local_gas_station,
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            disabled = energyData.currentEnergy / energyData.maxEnergy > .95,
            onClick = function()
                BJI.Managers.Stations.tryRefillVehicle(ctxt, { energyType }, 100, 5)
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

local function drawGarage(ctxt, garage)
    if not garage or not ctxt.vehData.tanks then
        return
    end

    commonDrawEnergyLines(ctxt)

    if not BJI.Managers.Scenario.canRepairAtGarage() then
        LineBuilder()
            :icon({
                icon = ICONS.block,
                style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            })
            :text(W.labels.noRepairScenario)
            :build()
    elseif ctxt.vehData.damageState >= 1 then
        LineBuilder()
            :text(W.labels.damagedWarning)
            :btnIcon({
                id = "repairVehicle",
                icon = ICONS.build,
                style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                onClick = function()
                    onRepair(ctxt)
                end,
            })
            :build()
    else
        LineLabel(W.labels.vehiclePristine)
    end
end

local function drawEnergyStation(ctxt, station)
    if not station or not ctxt.vehData.tanks then
        return
    end

    if not BJI.Managers.Scenario.canRefuelAtStation() then
        LineBuilder()
            :icon({
                icon = ICONS.block,
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
                    icon = ICONS.local_gas_station,
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

    ---@type table<string, any>
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
