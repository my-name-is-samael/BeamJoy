---@class BJIManagerVehSelectorUI : BJIManager
local M = {
    _name = "VehSelectorUI",
    baseFunctions = {}
}

-- VEHICLE SELECTOR
local filtersWhiteList = { "Drivetrain", "Type", "Config Type", "Transmission", "Country", "Derby Class",
    "Performance Class",
    "Value", "Brand", "Body Style", "Source", "Weight", "Top Speed", "0-100 km/h", "0-60 mph", "Weight/Power",
    "Off-Road Score", "Years", 'Propulsion', 'Fuel Type', 'Induction Type' }
local range = { 'Years' }
local convertToRange = { 'Value', 'Weight', 'Top Speed', '0-100 km/h', '0-60 mph', 'Weight/Power', "Off-Road Score" }
local finalRanges = {}
table.assign(table.assign(finalRanges, convertToRange), range)

local displayInfo = {
    ranges = {
        all = finalRanges,
        real = range
    },
    units = {
        Weight = { type = 'weight', dec = 0 },
        ['Top Speed'] = { type = 'speed', dec = 0 },
        ['Torque'] = { type = 'torque', dec = 0 },
        ['Power'] = { type = 'power', dec = 0 },
        ['Weight/Power'] = { type = 'weightPower', dec = 2 },
    },
    predefinedUnits = {
        ['0-60 mph'] = { unit = 's', type = 'speed', ifIs = 'mph', dec = 1 },
        ['0-100 mph'] = { unit = 's', type = 'speed', ifIs = 'mph', dec = 1 },
        ['0-200 mph'] = { unit = 's', type = 'speed', ifIs = 'mph', dec = 1 },
        ['60-100 mph'] = { unit = 's', type = 'speed', ifIs = 'mph', dec = 1 },
        ['0-100 km/h'] = { unit = 's', type = 'speed', ifIs = 'km/h', dec = 1 },
        ['0-200 km/h'] = { unit = 's', type = 'speed', ifIs = 'km/h', dec = 1 },
        ['0-300 km/h'] = { unit = 's', type = 'speed', ifIs = 'km/h', dec = 1 },
        ['100-200 km/h'] = { unit = 's', type = 'speed', ifIs = 'km/h', dec = 1 },
        ['100-0 km/h'] = { unit = 'm', type = 'length', ifIs = 'm', dec = 1 },
        ['60-0 mph'] = { unit = 'ft', type = 'length', ifIs = 'ft', dec = 1 }
    },
    dontShowInDetails = { 'Type', 'Config Type' },
    perfData = { '0-60 mph', '0-100 mph', '0-200 mph', '60-100 mph', '60-0 mph', '0-100 km/h', '0-200 km/h', '0-300 km/h', '100-200 km/h', '100-0 km/h', 'Braking G', 'Top Speed', 'Weight/Power', 'Off-Road Score', 'Propulsion', 'Fuel Type', 'Drivetrain', 'Transmission', 'Induction Type' },
    filterData = filtersWhiteList
}

local function createFilters(models)
    local filter = {}

    if models then
        for _, value in pairs(models) do
            for propName, propVal in pairs(value.aggregates) do
                if table.includes(finalRanges, propName) then
                    if filter[propName] then
                        filter[propName].min = math.min(value.aggregates[propName].min, filter[propName].min)
                        filter[propName].max = math.max(value.aggregates[propName].max, filter[propName].max)
                    else
                        filter[propName] = table.clone(value.aggregates[propName])
                    end
                else
                    if not filter[propName] then
                        filter[propName] = {}
                    end
                    for key, _ in pairs(propVal) do
                        filter[propName][key .. ''] = true
                    end
                end
            end
        end
    end

    return filter
end

local p
local function openSelectorUI()
    LogInfo("Vehicle selector triggered")
    p = LuaProfiler("Vehicle Selector menu (triggered by a binding)")
    if p then p:start() end
    guihooks.trigger('MenuOpenModule', 'vehicleselect')
    if p then p:add("guihook trigger") end
end

local function createVehiclesData()
    local resModels, resConfigs = {}, {}

    if not BJI.Managers.Perm.canSpawnVehicle() then
        -- cannot spawn veh
        BJI.Managers.Toast.error(BJI.Managers.Lang.get("errors.cannotSpawnVeh"))
        BJI.Utils.Common.HideGameMenu()
        return resModels, resConfigs
    elseif BJI.Managers.Restrictions.getState(BJI.Managers.Restrictions.OTHER.VEHICLE_SELECTOR) then
        -- cannot spawn veh in current scenario
        BJI.Managers.Toast.error(BJI.Managers.Lang.get("errors.unavailableDuringScenario"))
        BJI.Utils.Common.HideGameMenu()
        return resModels, resConfigs
    end

    local res = Table(BJI.Managers.Scenario.getModelList()):reduce(function(acc, model)
        acc.configs:addAll(model.configs)
        model.configs = nil
        acc.models:insert(model)
        return acc
    end, { models = Table(), configs = Table() })

    return res.models, res.configs
end

local function notifyUI()
    if p then
        p:add("CEF response to guihook")
    else
        p = LuaProfiler(
            "Vehicle Selector menu WITHOUT profiling the first CEF stages (because the menu was triggered programmatically, not through binding)")
        if p then p:start() end
    end
    local models, configs = createVehiclesData()

    guihooks.trigger('sendVehicleList',
        { models = models, configs = configs, filters = createFilters(models), displayInfo = displayInfo })
    if p then p:add("CEF request") end
end

local function notifyUIEnd()
    if p then p:add("CEF side") end
    if p then p:finish() end
    p = nil
end

local function postSpawnActions(ctxt)
    if BJI.Managers.AI.selfVehs:includes(ctxt.veh:getID()) then
        -- was manually toggled, resume state
        ctxt.veh:queueLuaCommand("ai.toggleTrafficMode()")
    end
    if ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE then
        BJI.Managers.Cam.toggleFreeCam()
        ctxt.camera = BJI.Managers.Cam.getCamera()
    end
end

local function cloneCurrent(...)
    if not BJI.Managers.Perm.canSpawnVehicle() then
        -- cannot spawn veh
        BJI.Managers.Toast.error(BJI.Managers.Lang.get("errors.cannotSpawnVeh"))
        return
    else
        -- maximum vehs reached
        local group = BJI.Managers.Perm.Groups[BJI.Managers.Context.User.group]
        if group and
            group.vehicleCap > -1 and
            group.vehicleCap <= table.length(BJI.Managers.Context.User.vehicles) then
            BJI.Managers.Toast.error(BJI.Managers.Lang.get("errors.cannotSpawnAnyMoreVeh"))
            return
        end

        if not BJI.Managers.Scenario.canSpawnNewVehicle() then
            -- cannot spawn veh in current scenario
            BJI.Managers.Toast.error(BJI.Managers.Lang.get("errors.unavailableDuringScenario"))
            return
        end
    end

    BJI.Managers.Veh.waitForVehicleSpawn(postSpawnActions)
    return M.baseFunctions.cloneCurrent(...)
end

local function spawnDefault(...)
    if not BJI.Managers.Perm.canSpawnVehicle() then
        -- cannot spawn veh
        BJI.Managers.Toast.error(BJI.Managers.Lang.get("errors.cannotSpawnVeh"))
        return
    else
        if BJI.Managers.Veh.isCurrentVehicleOwn() then
            if not BJI.Managers.Scenario.canReplaceVehicle() then
                -- cannot spawn veh in current scenario
                BJI.Managers.Toast.error(BJI.Managers.Lang.get("errors.unavailableDuringScenario"))
                return
            end
        else
            if not BJI.Managers.Scenario.canSpawnNewVehicle() then
                -- cannot spawn veh in current scenario
                BJI.Managers.Toast.error(BJI.Managers.Lang.get("errors.unavailableDuringScenario"))
                return
            end
        end
    end

    BJI.Managers.Veh.waitForVehicleSpawn(postSpawnActions)
    return M.baseFunctions.spawnDefault(...)
end

local function spawnNewVehicle(model, opts)
    if not BJI.Managers.Perm.canSpawnVehicle() then
        -- cannot spawn veh
        BJI.Managers.Toast.error(BJI.Managers.Lang.get("errors.cannotSpawnVeh"))
        return
    elseif model ~= "unicycle" then
        -- check maximum vehs reached
        local group = BJI.Managers.Perm.Groups[BJI.Managers.Context.User.group]
        if group and
            group.vehicleCap > -1 and
            group.vehicleCap <= table.length(BJI.Managers.Context.User.vehicles) then
            BJI.Managers.Toast.error(BJI.Managers.Lang.get("errors.cannotSpawnAnyMoreVeh"))
            return
        end

        if not BJI.Managers.Scenario.canSpawnNewVehicle() then
            -- cannot spawn veh in current scenario
            BJI.Managers.Toast.error(BJI.Managers.Lang.get("errors.unavailableDuringScenario"))
            return
        end
    end

    BJI.Managers.Veh.waitForVehicleSpawn(postSpawnActions)
    return M.baseFunctions.spawnNewVehicle(model, opts)
end

local function replaceVehicle(...)
    if BJI.Managers.Veh.isCurrentVehicleOwn() then
        if not BJI.Managers.Scenario.canReplaceVehicle() then
            -- cannot update veh in current scenario
            BJI.Managers.Toast.error(BJI.Managers.Lang.get("errors.unavailableDuringScenario"))
            return
        end
    else
        if not BJI.Managers.Perm.canSpawnVehicle() then
            -- cannot spawn veh
            BJI.Managers.Toast.error(BJI.Managers.Lang.get("errors.cannotSpawnVeh"))
            return
        elseif not BJI.Managers.Scenario.canSpawnNewVehicle() then
            -- cannot spawn veh in current scenario
            BJI.Managers.Toast.error(BJI.Managers.Lang.get("errors.unavailableDuringScenario"))
            return
        end
    end

    BJI.Managers.Veh.waitForVehicleSpawn(postSpawnActions)
    return M.baseFunctions.replaceVehicle(...)
end

local function removeCurrent(...)
    if BJI.Managers.Veh.isCurrentVehicleOwn() then
        -- my own veh
        if BJI.Managers.Scenario.canDeleteVehicle() then
            BJI.Managers.Veh.deleteCurrentOwnVehicle()
            --return M.baseFunctions.removeCurrent(...)
        else
            -- cannot delete veh in current scenario
            BJI.Managers.Toast.error(BJI.Managers.Lang.get("errors.unavailableDuringScenario"))
        end
    else
        if BJI.Managers.Scenario.canDeleteOtherPlayersVehicle() then
            BJI.Managers.Veh.deleteOtherPlayerVehicle()
        else
            -- cannot delete veh in current scenario
            BJI.Managers.Toast.error(BJI.Managers.Lang.get("errors.unavailableDuringScenario"))
        end
    end
end

local function removeAllExceptCurrent(...)
    if not BJI.Managers.Scenario.canDeleteOtherVehicles() then
        -- cannot delete other vehs in current scenario
        BJI.Managers.Toast.error(BJI.Managers.Lang.get("errors.unavailableDuringScenario"))
        return
    end

    BJI.Managers.Veh.deleteOtherOwnVehicles()
    -- return M.baseFunctions.removeAllExceptCurrent(...)
end

-- VEHICLE CONFIGURATION
local function getAvailableParts(ioCtx)
    if BJI.Managers.Restrictions.getState(BJI.Managers.Restrictions.OTHER.VEHICLE_PARTS_SELECTOR) then
        -- cannot edit veh in current scenario
        BJI.Managers.Toast.error(BJI.Managers.Lang.get("errors.unavailableDuringScenario"))
        BJI.Utils.Common.HideGameMenu()
        return {}
    end

    return M.baseFunctions.getAvailableParts(ioCtx)
end

local function onUnload()
    -- vehicle selector
    core_vehicles.openSelectorUI = M.baseFunctions.openSelectorUI
    core_vehicles.requestList = M.baseFunctions.requestList
    core_vehicles.requestListEnd = M.baseFunctions.requestListEnd
    core_vehicles.cloneCurrent = M.baseFunctions.cloneCurrent
    core_vehicles.spawnDefault = M.baseFunctions.spawnDefault
    core_vehicles.spawnNewVehicle = M.baseFunctions.spawnNewVehicle
    core_vehicles.replaceVehicle = M.baseFunctions.replaceVehicle
    core_vehicles.removeCurrent = M.baseFunctions.removeCurrent
    core_vehicles.removeAllExceptCurrent = M.baseFunctions.removeAllExceptCurrent
    -- vehicle configuration
    local jbeamIO = require('jbeam/io')
    jbeamIO.getAvailableParts = M.baseFunctions.getAvailableParts
end

local function onLoad()
    -- vehicle selector
    M.baseFunctions.openSelectorUI = core_vehicles.openSelectorUI
    M.baseFunctions.requestList = core_vehicles.requestList
    M.baseFunctions.requestListEnd = core_vehicles.requestListEnd
    M.baseFunctions.cloneCurrent = core_vehicles.cloneCurrent
    M.baseFunctions.spawnDefault = core_vehicles.spawnDefault
    M.baseFunctions.spawnNewVehicle = core_vehicles.spawnNewVehicle
    M.baseFunctions.replaceVehicle = core_vehicles.replaceVehicle
    M.baseFunctions.removeCurrent = core_vehicles.removeCurrent
    M.baseFunctions.removeAllExceptCurrent = core_vehicles.removeAllExceptCurrent
    core_vehicles.openSelectorUI = openSelectorUI
    core_vehicles.requestList = notifyUI
    core_vehicles.requestListEnd = notifyUIEnd
    core_vehicles.cloneCurrent = cloneCurrent
    core_vehicles.spawnDefault = spawnDefault
    core_vehicles.spawnNewVehicle = spawnNewVehicle
    core_vehicles.replaceVehicle = replaceVehicle
    core_vehicles.removeCurrent = removeCurrent
    core_vehicles.removeAllExceptCurrent = removeAllExceptCurrent

    -- vehicle configuration
    local jbeamIO = require('jbeam/io')
    M.baseFunctions.getAvailableParts = jbeamIO.getAvailableParts
    jbeamIO.getAvailableParts = getAvailableParts

    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.ON_UNLOAD, onUnload)
end

M.onLoad = onLoad

return M
