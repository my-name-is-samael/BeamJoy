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

BJI = {}
BJIVERSION = "1.2.0"

require("ge/extensions/utils/LoadDefaults")

local managers = {}
function GetBJIManagers()
    return managers
end

function RegisterBJIManager(manager)
    table.insert(managers, manager)
end

require("ge/extensions/utils/Bench")

function TriggerBJIManagerEvent(eventName, ...)
    for i, manager in ipairs(managers) do
        if type(manager[eventName]) == "function" then
            local status, err = pcall(manager[eventName], ...)
            if not status then
                LogError(string.var("Error executing event {1} on manager {2} : {3}",
                    { eventName, manager._name or i, err }))
            end
        end
    end
end

require("log")
require("ge/extensions/utils/Lua")
require("ge/extensions/utils/Math")
require("ge/extensions/utils/String")
require("ge/extensions/utils/Table")
require("ge/extensions/utils/Constants")
require("ge/extensions/utils/Icons")
ShapeDrawer = require("ge/extensions/utils/ShapeDrawer")

local function loadManagers()
    BJISound = require("ge/extensions/BJI/managers/SoundManager")
    BJIAsync = require("ge/extensions/BJI/managers/AsyncManager")
    BJIUI = require("ge/extensions/BJI/managers/UIManager")
    BJILocalStorage = require("ge/extensions/BJI/managers/LocalStorageManager")
    BJIEvents = require("ge/extensions/BJI/managers/EventManager")
    BJIPerm = require("ge/extensions/BJI/managers/PermissionManager")
    BJIContext = require("ge/extensions/BJI/Context")
    require("ge/extensions/BJI/ui/CommonStyle")
    require("ge/extensions/utils/Common")
    BJILang = require("ge/extensions/BJI/managers/LangManager")
    BJIRestrictions = require("ge/extensions/BJI/managers/RestrictionsManager")
    require("ge/extensions/BJI/tx/Tx")
    BJIToast = require("ge/extensions/BJI/managers/ToastManager")
    BJIMessage = require("ge/extensions/BJI/managers/MessageManager")
    BJIEnv = require("ge/extensions/BJI/managers/EnvironmentManager")
    BJIMods = require("ge/extensions/BJI/managers/ModsManager")
    BJICache = require("ge/extensions/BJI/managers/CacheManager")
    BJIVeh = require("ge/extensions/BJI/managers/VehicleManager")
    BJIAutomaticLights = require("ge/extensions/BJI/managers/AutomaticLightsManager")
    BJIReputation = require("ge/extensions/BJI/managers/ReputationManager")
    BJICam = require("ge/extensions/BJI/managers/CameraManager")
    BJIScenario = require("ge/extensions/BJI/scenario/ScenarioManager")
    BJIGPS = require("ge/extensions/BJI/managers/GPSManager")
    BJIWaypointEdit = require("ge/extensions/BJI/managers/WaypointEditManager")
    BJIRaceWaypoint = require("ge/extensions/BJI/managers/RaceWaypointManager")
    BJIControllers = require("ge/extensions/BJI/rx/Controllers")
    BJIVote = require("ge/extensions/BJI/managers/VotesManager")
    BJITick = require("ge/extensions/BJI/managers/TickManager")
    BJIBigmap = require("ge/extensions/BJI/managers/BigmapManager")
    BJIDrift = require("ge/extensions/BJI/managers/DriftManager")
    BJIChat = require("ge/extensions/BJI/managers/ChatManager")
    BJINametags = require("ge/extensions/BJI/managers/NametagsManager")
    BJIAI = require("ge/extensions/BJI/managers/AIManager")
    BJIPopup = require("ge/extensions/BJI/managers/PopupManager")
    BJIStations = require("ge/extensions/BJI/managers/StationsManager")
    BJICollisions = require("ge/extensions/BJI/managers/CollisionsManager")

    BJIRaceUI = require("ge/extensions/BJI/managers/RaceUIManager")
    BJIBusUI = require("ge/extensions/BJI/managers/BusUIManager")
    BJIVehUI = require("ge/extensions/BJI/managers/VehicleSelectorUIManager")

    BJIUserSettingsWindow = require("ge/extensions/BJI/ui/WindowUserSettings/DrawWindowUserSettings")
    BJIVehSelector = require("ge/extensions/BJI/ui/WindowVehicleSelector/DrawWindowVehicleSelector")
    BJIVehSelectorPreview = require("ge/extensions/BJI/ui/WindowVehicleSelector/DrawWindowVehicleSelectorPreview")
    BJIRacesLeaderboardWindow = require("ge/extensions/BJI/ui/WindowRacesLeaderboard/DrawWindowRacesLeaderboard")
    BJIRaceSettingsWindow = require("ge/extensions/BJI/ui/WindowRaceSettings/DrawWindowRaceSettings")
    BJIDerbySettingsWindow = require("ge/extensions/BJI/ui/WindowDerbySettings/DrawWindowDerbySettings")

    BJIWindows = require("ge/extensions/BJI/managers/WindowsManager")
end
loadManagers()

local tag = "BJI"

local M = {
    dependencies = { "ui_imgui" },
}

local function _initGUI()
    require("ge/extensions/editor/api/gui")
        .initialize(BJIContext.GUI)
end

function M.onExtensionLoaded()
    BJIControllers.initListeners()

    BJILang.initClient()

    require("ge/extensions/BJI/ui/Builders")
    _initGUI()
    for _, manager in ipairs(managers) do
        if type(manager.onLoad) == "function" then
            local status, err = pcall(manager.onLoad)
            if not status then
                LogError(string.var("Error during {1} onLoad : {2}", { manager._name, err }), tag)
            end
        end
    end

    LogInfo(string.var("BJI v{1} Extension Loaded", { BJIVERSION }), tag)
end

M.onInit = function()
    LogInfo("Initialization", tag)
    setExtensionUnloadMode(M, "manual")
end

M.onWorldReadyState = function(state)
    BJIContext.WorldReadyState = state
end

M.onPreRender = function() end
BJICONNECTED = false
M.onUpdate = function(...)
    if not BJICONNECTED and BJIContext.WorldReadyState == 2 and
        ui_imgui.GetIO().Framerate > 5 then
        BJICONNECTED = true
        BJITx.player.connected()
    end

    BJITick.client()
end

commands.dropPlayerAtCamera = function(...)
    TriggerBJIManagerEvent("onDropPlayerAtCamera", ...)
end
commands.dropPlayerAtCameraNoReset = function(...)
    TriggerBJIManagerEvent("onDropPlayerAtCameraNoReset", ...)
end
M.onVehicleSpawned = function(...)
    TriggerBJIManagerEvent("onVehicleSpawned", ...)
end
M.onVehicleSwitched = function(...)
    TriggerBJIManagerEvent("onVehicleSwitched", ...)
end
M.onVehicleResetted = function(gameVehID)
    BJIAsync.delayTask(function()
        -- delay execution or else vehicle can't be own
        TriggerBJIManagerEvent("onVehicleResetted", gameVehID)
    end, 100, string.var("BJIVehReset{1}", { gameVehID }))
end
M.onVehicleReplaced = function(...)
    TriggerBJIManagerEvent("onVehicleReplaced", ...)
    BJIEvents.trigger(BJIEvents.EVENTS.VEHICLE_UPDATED)
end
M.onAiModeChange = function(gameVehID, aiState)
    BJIAI.updateVehicle(gameVehID, aiState ~= "disabled")
end
M.onVehicleDestroyed = function(...)
    TriggerBJIManagerEvent("onVehicleDestroyed", ...)
end

function M.onDriftCompletedScored(...)
    TriggerBJIManagerEvent("onDriftCompletedScored", ...)
end

M.setPhysicsSpeed = BJIContext.setPhysicsSpeed

function M.onExtensionUnloaded()
    for _, manager in ipairs(managers) do
        if type(manager.onUnload) == "function" then
            local status, err = pcall(manager.onUnload)
            if not status then
                LogError(string.var("Error during {1} onUnload : {2}", { manager._name, err }), tag)
            end
        end
    end
    LogInfo(string.var("BJI v{1} Extension Unloaded", { BJIVERSION }), tag)
end

return M

-- FUTURE FEATURES TIPS

-- hide/show ui apps
-- guihooks.trigger('ShowApps', true/false)

-- get map height below pos
-- be:getSurfaceHeightBelow(vec3)

-- if stuck in loading screen during disconnect => core_gamestate.requestExitLoadingScreen("serverConnection")
