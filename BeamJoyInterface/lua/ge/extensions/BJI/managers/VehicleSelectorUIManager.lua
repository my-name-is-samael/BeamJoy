---@class BJIManagerVehSelectorUI : BJIManager
local M = {
    _name = "VehSelectorUI",
    baseFunctions = {},

    stateSelector = true, -- allow for veh selector
    stateEditor = true,   -- allow for vehicle parts editor
    statePaint = true,    -- allow for paint current veh
}

-- VEHICLE SELECTOR

local function postSpawnActions(ctxt)
    if ctxt.veh then
        if ctxt.camera == BJI_Cam.CAMERAS.FREE then
            BJI_Cam.toggleFreeCam()
            ctxt.camera = BJI_Cam.getCamera()
        end
    end
end

---@param model string
local function checkSpawnTypePermissions(model)
    local vehModel = BJI_Veh.getAllVehicleConfigs(true, true)[model]
    if not vehModel then
        return false
    end
    if vehModel.Type == BJI_Veh.TYPES.TRAILER and
        not BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SPAWN_TRAILERS) then
        return false
    elseif vehModel.Type == BJI_Veh.TYPES.PROP and
        not BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SPAWN_PROPS) then
        return false
    end
    return true
end

local function cloneCurrent(...)
    if not M.stateSelector then
        return
    elseif not BJI_Perm.canSpawnVehicle() then
        -- cannot spawn veh
        BJI_Toast.error(BJI_Lang.get("errors.cannotSpawnVeh"))
        return
    else
        -- maximum vehs reached
        local group = BJI_Perm.Groups[BJI_Context.User.group]
        if group and
            group.vehicleCap > -1 and
            group.vehicleCap <= BJI_Veh.getSelfVehiclesCount() then
            BJI_Toast.error(BJI_Lang.get("errors.cannotSpawnAnyMoreVeh"))
            return
        end

        if not BJI_Scenario.canSpawnNewVehicle() then
            -- cannot spawn veh in current scenario
            BJI_Toast.error(BJI_Lang.get("errors.unavailableDuringScenario"))
            return
        else
            local current = BJI_Veh.getCurrentVehicle()
            if current and not checkSpawnTypePermissions(current.jbeam) then
                BJI_Toast.error(BJI_Lang.get("errors.cannotSpawnVeh"))
                return -- invalid type spawn
            end
        end
    end

    BJI_Veh.waitForVehicleSpawn(postSpawnActions)
    return M.baseFunctions.cloneCurrent(...)
end

local function spawnDefault(...)
    if not M.stateSelector then
        return
    elseif not BJI_Perm.canSpawnVehicle() then
        -- cannot spawn veh
        BJI_Toast.error(BJI_Lang.get("errors.cannotSpawnVeh"))
        return
    else
        if BJI_Veh.isCurrentVehicleOwn() then
            if not BJI_Scenario.canReplaceVehicle() then
                -- cannot spawn veh in current scenario
                BJI_Toast.error(BJI_Lang.get("errors.unavailableDuringScenario"))
                return
            end
        else
            if not BJI_Scenario.canSpawnNewVehicle() then
                -- cannot spawn veh in current scenario
                BJI_Toast.error(BJI_Lang.get("errors.unavailableDuringScenario"))
                return
            end
            local defaultVeh = BJI_Veh.getDefaultModelAndConfig()
            if defaultVeh and not checkSpawnTypePermissions(defaultVeh.model) then
                BJI_Toast.error(BJI_Lang.get("errors.cannotSpawnVeh"))
                return -- invalid type spawn
            end
        end
    end

    BJI_Veh.waitForVehicleSpawn(postSpawnActions)
    return M.baseFunctions.spawnDefault(...)
end

local function spawnNewVehicle(model, opts)
    if not M.stateSelector then
        return
    elseif not BJI_Perm.canSpawnVehicle() then
        -- cannot spawn veh
        BJI_Toast.error(BJI_Lang.get("errors.cannotSpawnVeh"))
        return
    elseif model ~= "unicycle" then
        -- check maximum vehs reached
        local group = BJI_Perm.Groups[BJI_Context.User.group]
        if group and
            group.vehicleCap > -1 and
            group.vehicleCap <= BJI_Veh.getSelfVehiclesCount() then
            BJI_Toast.error(BJI_Lang.get("errors.cannotSpawnAnyMoreVeh"))
            return
        end

        if not BJI_Scenario.canSpawnNewVehicle() then
            -- cannot spawn veh in current scenario
            BJI_Toast.error(BJI_Lang.get("errors.unavailableDuringScenario"))
            return
        end

        if not checkSpawnTypePermissions(model) then
            BJI_Toast.error(BJI_Lang.get("errors.cannotSpawnVeh"))
            return -- invalid type spawn
        end
    end

    BJI_Veh.waitForVehicleSpawn(postSpawnActions)
    return M.baseFunctions.spawnNewVehicle(model, opts)
end

local function replaceVehicle(model, opt, otherVeh)
    if not M.stateSelector and not M.statePaint then
        return
    elseif BJI_Veh.isCurrentVehicleOwn() then
        if not BJI_Scenario.canReplaceVehicle() and
            not BJI_Scenario.canPaintVehicle() then
            -- cannot update veh now during current scenario
            BJI_Toast.error(BJI_Lang.get("errors.unavailableDuringScenario"))
            return
        end
    else
        if not BJI_Perm.canSpawnVehicle() then
            -- cannot spawn veh
            BJI_Toast.error(BJI_Lang.get("errors.cannotSpawnVeh"))
            return
        elseif not BJI_Scenario.canSpawnNewVehicle() then
            -- cannot spawn veh in current scenario
            BJI_Toast.error(BJI_Lang.get("errors.unavailableDuringScenario"))
            return
        elseif not checkSpawnTypePermissions(model) then
            BJI_Toast.error(BJI_Lang.get("errors.cannotSpawnVeh"))
            return -- invalid type spawn
        end
    end

    BJI_Veh.waitForVehicleSpawn(postSpawnActions)
    return M.baseFunctions.replaceVehicle(model, opt, otherVeh)
end

local function removeCurrent(...)
    if not M.stateSelector then
        return
    elseif BJI_Veh.isCurrentVehicleOwn() then
        -- my own veh
        if BJI_Scenario.canDeleteVehicle() then
            BJI_Veh.deleteCurrentOwnVehicle()
            --return M.baseFunctions.removeCurrent(...)
        else
            -- cannot delete veh in current scenario
            BJI_Toast.error(BJI_Lang.get("errors.unavailableDuringScenario"))
        end
    else
        if BJI_Scenario.canDeleteOtherPlayersVehicle() then
            BJI_Veh.deleteOtherPlayerVehicle()
        else
            -- cannot delete veh in current scenario
            BJI_Toast.error(BJI_Lang.get("errors.unavailableDuringScenario"))
        end
    end
end

local function removeAllExceptCurrent(...)
    if not M.stateSelector then
        return
    elseif not BJI_Scenario.canDeleteOtherVehicles() then
        -- cannot delete other vehs in current scenario
        BJI_Toast.error(BJI_Lang.get("errors.unavailableDuringScenario"))
        return
    end

    BJI_Veh.deleteOtherOwnVehicles()
    -- return M.baseFunctions.removeAllExceptCurrent(...)
end

local function getTiles(...)
    local validModels = BJI_Scenario.getModelList()
    if not M.stateSelector or table.length(validModels) == 0 then
        -- cannot spawn veh
        BJI_Toast.error(BJI_Lang.get("errors.cannotSpawnVeh"))
        BJI_UI.hideGameMenu()
        return {}
    end

    local model, config
    local tiles = table.reduce(M.baseFunctions.getTiles(...), function(res, category)
        category.tiles = table.filter(category.tiles, function(tile)
            model = tile.doubleClickDetails.model
            config = tile.doubleClickDetails.config
            return validModels[model] ~= nil or
                (tile.isConfig and validModels[model].configs[config] ~= nil)
        end)
        if #category.tiles > 0 then
            res:insert(category)
        end
        return res
    end, Table())
    return tiles
end

-- VEHICLE CONFIGURATION
local function getAvailableParts(ioCtx)
    if not M.stateEditor then
        -- cannot edit veh in current scenario
        BJI_Toast.error(BJI_Lang.get("errors.unavailableDuringScenario"))
        BJI_UI.hideGameMenu()
        return {}
    end

    return M.baseFunctions.getAvailableParts(ioCtx)
end

---@param ctxt TickContext
---@return string[]
local function getRestrictions(ctxt)
    if not BJI_Cache.areBaseCachesFirstLoaded() or not BJI.CLIENT_READY then
        return {}
    end

    M.stateSelector = BJI_Perm.canSpawnVehicle() and (
        BJI_Scenario.canSpawnNewVehicle() or (
            BJI_Scenario.canReplaceVehicle() and BJI_Veh.isCurrentVehicleOwn()
        ) and not BJI_Pursuit.getState()
    )
    M.stateEditor = BJI_Perm.canSpawnVehicle() and BJI_Scenario.isFreeroam() and
        not BJI_Pursuit.getState()
    M.statePaint = BJI_Perm.canSpawnVehicle() and BJI_Veh.isCurrentVehicleOwn() and
        BJI_Scenario.canPaintVehicle() and not BJI_Pursuit.getState()

    if BJI_Scenario.isFreeroam() and not M.stateSelector and not M.stateEditor then
        BJI_Win_VehSelector.tryClose(true)
    end

    return Table()
        :addAll(M.stateSelector and {} or BJI_Restrictions._SCENARIO_DRIVEN.VEHICLE_SELECTOR, true)
        :addAll(M.stateEditor and {} or BJI_Restrictions._SCENARIO_DRIVEN.VEHICLE_PARTS_SELECTOR, true)
end

local function onUnload()
    -- vehicle selector buttons + open
    core_vehicles.cloneCurrent = M.baseFunctions.cloneCurrent
    core_vehicles.spawnDefault = M.baseFunctions.spawnDefault
    core_vehicles.spawnNewVehicle = M.baseFunctions.spawnNewVehicle
    core_vehicles.replaceVehicle = M.baseFunctions.replaceVehicle
    core_vehicles.removeCurrent = M.baseFunctions.removeCurrent
    core_vehicles.removeAllExceptCurrent = M.baseFunctions.removeAllExceptCurrent
    ui_vehicleSelector_tiles.getTiles = M.baseFunctions.getTiles
    -- vehicle configuration
    local jbeamIO = require('jbeam/io')
    jbeamIO.getAvailableParts = M.baseFunctions.getAvailableParts
end

local function onLoad()
    -- vehicle selector buttons + open
    M.baseFunctions.cloneCurrent = core_vehicles.cloneCurrent
    M.baseFunctions.spawnDefault = core_vehicles.spawnDefault
    M.baseFunctions.spawnNewVehicle = core_vehicles.spawnNewVehicle
    M.baseFunctions.replaceVehicle = core_vehicles.replaceVehicle
    M.baseFunctions.removeCurrent = core_vehicles.removeCurrent
    M.baseFunctions.removeAllExceptCurrent = core_vehicles.removeAllExceptCurrent
    M.baseFunctions.getTiles = ui_vehicleSelector_tiles.getTiles
    core_vehicles.cloneCurrent = cloneCurrent
    core_vehicles.spawnDefault = spawnDefault
    core_vehicles.spawnNewVehicle = spawnNewVehicle
    core_vehicles.replaceVehicle = replaceVehicle
    core_vehicles.removeCurrent = removeCurrent
    core_vehicles.removeAllExceptCurrent = removeAllExceptCurrent
    ui_vehicleSelector_tiles.getTiles = getTiles
    -- vehicle configuration
    local jbeamIO = require('jbeam/io')
    M.baseFunctions.getAvailableParts = jbeamIO.getAvailableParts
    jbeamIO.getAvailableParts = getAvailableParts

    BJI_Events.addListener(BJI_Events.EVENTS.ON_UNLOAD, onUnload, M._name)
end

M.onLoad = onLoad

M.getRestrictions = getRestrictions

return M
