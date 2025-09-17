--[[
BeamJoy for BeamMP
Copyright (C) 2024-2025 TontonSamael

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

Contact : https://github.com/my-name-is-samael
]]

require("ge/extensions/utils/LoadDefaults")

require("log")
require("ge/extensions/utils/LUA") ---@diagnostic disable-line
require("ge/extensions/utils/MATH")
require("ge/extensions/utils/String")
require("ge/extensions/utils/Table")

BJI = {
    VERSION = "2.0.4",
    tag = "BJI",
    CLIENT_READY = false,
    CONSTANTS = require("ge/extensions/utils/Constants"),
    Utils = {},
    Managers = {},
    ---@type table<string, BJIWindow>
    Windows = {},
    Physics = {
        physmult = 1,
    },
    dt = {
        real = 0,
        sim = 0,
        raw = 0,
    },

    ---@type (fun(ctxt: TickContext):any)|table|string|number|boolean|nil
    DEBUG = nil,
}
BJI.Utils.ShapeDrawer = require("ge/extensions/utils/ShapeDrawer")
BJI.Utils.Icon = require("ge/extensions/utils/Icons")
BJI.Utils.UI = require("ge/extensions/utils/UI")
BJI.Utils.Style = require("ge/extensions/BJI/ui/CommonStyle")
BJI.Bench = require("ge/extensions/utils/Bench")

local function initManagers()
    Table(FS:directoryList("/lua/ge/extensions/BJI/managers"))
        :filter(function(path)
            return path:endswith(".lua")
        end):map(function(el)
        return el:gsub("^/lua/", ""):gsub(".lua$", "")
    end):forEach(function(managerPath)
        local ok, m = pcall(require, managerPath)
        if ok then
            _G["BJI_" .. m._name] = m     -- quick access
            if not BJI.Managers[m._name] then
                BJI.Managers[m._name] = m -- object tree access
                LogInfo(string.var("BJI_{1} loaded", { m._name }))
            else
                LogWarn(string.var("BJI_{1} already loaded", { m._name }))
            end
        else
            LogError(string.var("Error loading manager {1} : {2}", { managerPath, m }))
        end
    end)

    BJI.Tx = require("ge/extensions/BJI/tx/Tx")
    BJI.Rx = require("ge/extensions/BJI/rx/Rx")
end
initManagers()


local M = {
    dependencies = { "ui_imgui", "core_camera", "core_vehicles", "core_vehicle_partmgmt", "ui_visibility",
        "gameplay_traffic", "gameplay_police", "core_modmanager", "core_repository",
        "core_groundMarkers", "core_vehicle_manager", "map", "spawn", "core_vehicleBridge",
        "core_environment", "gameplay_parking", "gameplay_drift_general", "gameplay_drift_drift",
        "gameplay_drift_scoring", "core_multiSpawn", "ui_missionInfo", "freeroam_bigMapMode", "gameplay_walk",
        "core_jobsystem" },
}

local function _initGUI()
    require("ge/extensions/editor/api/gui").initialize(BJI_Context.GUI)
end

function M.onExtensionLoaded()
    require("ge/extensions/BJI/ui/Builders")
    _initGUI()

    ---@param manager BJIManager
    Table(BJI.Managers):forEach(function(manager)
        if type(manager.onLoad) == "function" then
            local ok, err = pcall(manager.onLoad)
            if not ok then
                LogError(string.var("Error executing onLoad in BJI_{1} : {2}", { manager._name, err }), BJI.tag)
            end
        end
    end)

    LogInfo(string.var("BJI v{1} Extension Loaded", { BJI.VERSION }), BJI.tag)
end

M.onInit = function()
    setExtensionUnloadMode(M, "manual")
end

M.onWorldReadyState = function(state)
    BJI_Context.WorldReadyState = state
end

M.onPreRender = function() end
M.onUpdate = function(dtReal, dtSim, dtRaw)
    if not BJI.CLIENT_READY and BJI_Context.WorldReadyState == 2 and
        ui_imgui.GetIO().Framerate > 5 then
        BJI_UI.applyLoading(true) -- loading stops when base caches are loaded (CacheManager)
        BJI.CLIENT_READY = true
        BJI_Tx_player.connected()
        BJI_Async.task(function()
            return BJI_Cache.areBaseCachesFirstLoaded()
        end, function()
            BJI_Events.trigger(BJI_Events.EVENTS.ON_POST_LOAD)
        end)
    end

    BJI.dt.real = dtReal
    BJI.dt.sim = dtSim
    BJI.dt.raw = dtRaw
    BJI_Tick.client()
end

local function bindNGHooks()
    Table({
        { "onVehicleSpawned",       BJI_Events.EVENTS.NG_VEHICLE_SPAWNED },
        { "onVehicleSwitched",      BJI_Events.EVENTS.NG_VEHICLE_SWITCHED },
        { "onVehicleResetted",      BJI_Events.EVENTS.NG_VEHICLE_RESETTED },
        { "onVehicleReplaced",      BJI_Events.EVENTS.NG_VEHICLE_REPLACED },
        { "onVehicleDestroyed",     BJI_Events.EVENTS.NG_VEHICLE_DESTROYED },
        { "onDriftCompletedScored", BJI_Events.EVENTS.NG_DRIFT_COMPLETED_SCORED },
        { "onPursuitAction",        BJI_Events.EVENTS.NG_PURSUIT_ACTION },
        { "onPursuitModeUpdate",    BJI_Events.EVENTS.NG_PURSUIT_MODE_UPDATE },
        { "onAiModeChange",         BJI_Events.EVENTS.NG_AI_MODE_CHANGE },
        { "onTrafficStarted",       BJI_Events.EVENTS.NG_TRAFFIC_STARTED },
        { "onTrafficStopped",       BJI_Events.EVENTS.NG_TRAFFIC_STOPPED },
        { "onVehicleGroupSpawned",  BJI_Events.EVENTS.NG_VEHICLE_GROUP_SPAWNED },
        { "trackAIAllVeh",          BJI_Events.EVENTS.NG_ALL_AI_MODE_CHANGED },
        { "onTrafficVehicleAdded",  BJI_Events.EVENTS.NG_TRAFFIC_VEHICLE_ADDED },
        { "onUILayoutLoaded",       BJI_Events.EVENTS.NG_UI_LAYOUT_LOADED },
        { "onBeforeRadialOpened",   BJI_Events.EVENTS.NG_BEFORE_RADIAL_OPENED },
    }):forEach(function(hook)
        M[hook[1]] = function(...)
            BJI_Events.trigger(hook[2], ...)
        end
    end)
end
bindNGHooks()

M.setPhysicsSpeed = function(val)
    BJI.Physics.physmult = val
end

function M.onExtensionUnloaded()
    BJI_Events.trigger(BJI_Events.EVENTS.ON_UNLOAD)
    LogInfo(string.var("BJI v{1} Extension Unloaded", { BJI.VERSION }), BJI.tag)

    BJI = nil
end

return M

--- hide/show ui apps
-- guihooks.trigger('ShowApps', true/false)

-- if stuck in loading screen during disconnect
-- core_gamestate.requestExitLoadingScreen("serverConnection")
-- guihooks.trigger("app:waiting", false)

--- Game functions we cannot hook onto (guess we are unlucky) :
-- core_repository.requestMyMods (on open mods menu > tab my mods)
-- core_vehicle_partmgmt.savedefault (on save default config)
-- core_vehicle_partmgmt.getConfigList (on open vehicle configuration menu)
