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
require("ge/extensions/utils/Lua")
require("ge/extensions/utils/Math")
require("ge/extensions/utils/String")
require("ge/extensions/utils/Table")
require("ge/extensions/utils/Icons")

local M = {
    dependencies = { "ui_imgui" },
}

BJI = {
    VERSION = "1.2.0",
    tag = "BJI",
    MOD_LOADED = false,
    CLIENT_READY = false,
    CONSTANTS = require("ge/extensions/utils/Constants"),
    Utils = {},
    Managers = {},
    ---@type BJIWindow[]
    Windows = {},
    Physics = {
        physmult = 1,
    },
    WorldReadyState = 0,

    ---@type fun(ctxt: TickContext): any|table|string|number|boolean|nil
    DEBUG = nil,
}
BJI.Utils.ShapeDrawer = require("ge/extensions/utils/ShapeDrawer")
BJI.Utils.Common = require("ge/extensions/utils/Common")
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
            if not BJI.Managers[m._name] then
                BJI.Managers[m._name] = m
                LogInfo(string.var("BJI.Managers.{1} loaded", { m._name }))
            else
                LogWarn(string.var("BJI.Managers.{1} already loaded", { m._name }))
            end
        else
            LogError(string.var("Error loading manager {1} : {2}", { managerPath, m }))
        end
    end)

    BJI.Tx = require("ge/extensions/BJI/tx/Tx")
    BJI.Rx = require("ge/extensions/BJI/rx/Rx")
end

local function bindNGHooks()
    Table({
        { commands, "dropPlayerAtCamera",        BJI.Managers.Events.EVENTS.NG_DROP_PLAYER_AT_CAMERA },
        { commands, "dropPlayerAtCameraNoReset", BJI.Managers.Events.EVENTS.NG_DROP_PLAYER_AT_CAMERA_NO_RESET },
        { M,        "onVehicleSpawned",          BJI.Managers.Events.EVENTS.NG_VEHICLE_SPAWNED },
        { M,        "onVehicleSwitched",         BJI.Managers.Events.EVENTS.NG_VEHICLE_SWITCHED },
        { M,        "onVehicleResetted",         BJI.Managers.Events.EVENTS.NG_VEHICLE_RESETTED },
        { M,        "onVehicleReplaced",         BJI.Managers.Events.EVENTS.NG_VEHICLE_REPLACED },
        { M,        "onAiModeChange",            BJI.Managers.Events.EVENTS.NG_AI_MODE_CHANGE },
        { M,        "onVehicleDestroyed",        BJI.Managers.Events.EVENTS.NG_VEHICLE_DESTROYED },
        { M,        "onDriftCompletedScored",    BJI.Managers.Events.EVENTS.NG_DRIFT_COMPLETED_SCORED },
    }):forEach(function(hook)
        hook[1][hook[2]] = function(...)
            BJI.Managers.Events.trigger(hook[3], ...)
        end
    end)
end

local function initGUI()
    require("ge/extensions/editor/api/gui")
        .initialize(BJI.Managers.Context.GUI)
end

function M.onExtensionLoaded()
    require("ge/extensions/BJI/ui/Builders")

    initManagers()
    bindNGHooks()
    initGUI()

    ---@param manager BJIManager
    Table(BJI.Managers):forEach(function(manager)
        if type(manager.onLoad) == "function" then
            local ok, err = pcall(manager.onLoad)
            if not ok then
                LogError(string.var("Error executing onLoad in BJI.Managers.{1} : {2}", { manager._name, err }), BJI.tag)
            end
        end
    end)

    LogInfo(string.var("BJI v{1} Extension Loaded", { BJI.VERSION }), BJI.tag)
    BJI.MOD_LOADED = true
end

M.onInit = function()
    setExtensionUnloadMode(M, "manual")
end

M.onWorldReadyState = function(state)
    BJI.WorldReadyState = state
end

M.onPreRender = function() end
M.onUpdate = function(...)
    if BJI.MOD_LOADED then
        if not BJI.CLIENT_READY and BJI.WorldReadyState == 2 and
            ui_imgui.GetIO().Framerate > 5 then
            BJI.CLIENT_READY = true
            BJI.Tx.player.connected()
        end

        if BJI.Managers.Tick then
            BJI.Managers.Tick.client()
        end
    end
end

M.setPhysicsSpeed = function(val)
    BJI.Physics.physmult = val
end

function M.onExtensionUnloaded()
    BJI.WorldReadyState = 0
    ---@param manager BJIManager
    Table(BJI.Managers):forEach(function(manager)
        if type(manager.onLoad) == "function" then
            local ok, err = pcall(manager.onLoad)
            if not ok then
                LogError(string.var("Error executing onLoad in BJI.Managers.{1} : {2}", { manager._name, err }), BJI.tag)
            end
        end
    end)

    LogInfo(string.var("BJI v{1} Extension Unloaded", { BJI.VERSION }), BJI.tag)
    BJI.MOD_LOADED = false
end

return M

-- FUTURE FEATURES TIPS

-- hide/show ui apps
-- guihooks.trigger('ShowApps', true/false)

-- if stuck in loading screen during disconnect => core_gamestate.requestExitLoadingScreen("serverConnection")

--- Game functions we cannot hook onto (guess we are unlucky) :
--- core_repository.requestMyMods (on open mods menu > tab my mods)
--- core_vehicle_partmgmt.savedefault (on save default config)
--- core_vehicle_partmgmt.getConfigList (on open vehicle configuration menu)


-- Enable manual vehicle AI:
-- BJI.Managers.Restrictions.update({{restrictions = {"toggleAITraffic"}, state = false}})

-- extensions.ui_apps.isAppOnLayout(appName)
