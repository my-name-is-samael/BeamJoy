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

BJI = {
    VERSION = "1.2.0",
    tag = "BJI",
    CLIENT_READY = false,
    CONSTANTS = require("ge/extensions/utils/Constants"),
    Utils = {},
    Managers = {},
    ---@type BJIWindow[]
    Windows = {},
    Physics = {
        physmult = 1,
    },
}
BJI.Utils.ShapeDrawer = require("ge/extensions/utils/ShapeDrawer")
BJI.Utils.Common = require("ge/extensions/utils/Common")
BJI.Utils.Style = require("ge/extensions/BJI/ui/CommonStyle")
require("ge/extensions/utils/Bench")

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
initManagers()


local M = {
    dependencies = { "ui_imgui" },
}

local function _initGUI()
    require("ge/extensions/editor/api/gui")
        .initialize(BJI.Managers.Context.GUI)
end

function M.onExtensionLoaded()
    require("ge/extensions/BJI/ui/Builders")
    _initGUI()

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
end

M.onInit = function()
    setExtensionUnloadMode(M, "manual")
end

M.onWorldReadyState = function(state)
    BJI.Managers.Context.WorldReadyState = state
end

M.onPreRender = function() end
M.onUpdate = function(...)
    if not BJI.CLIENT_READY and BJI.Managers.Context.WorldReadyState == 2 and
        ui_imgui.GetIO().Framerate > 5 then
        BJI.CLIENT_READY = true
        BJI.Tx.player.connected()
    end

    BJI.Managers.Tick.client()
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
bindNGHooks()

M.setPhysicsSpeed = function(val)
    BJI.Physics.physmult = val
end

function M.onExtensionUnloaded()
    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.ON_UNLOAD)
    LogInfo(string.var("BJI v{1} Extension Unloaded", { BJI.VERSION }), BJI.tag)

    BJI = nil
end

return M

-- FUTURE FEATURES TIPS

-- hide/show ui apps
-- guihooks.trigger('ShowApps', true/false)

-- get map height below pos
-- be:getSurfaceHeightBelow(vec3)

-- if stuck in loading screen during disconnect => core_gamestate.requestExitLoadingScreen("serverConnection")
