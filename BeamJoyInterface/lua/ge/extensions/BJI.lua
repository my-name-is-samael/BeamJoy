--[[
BeamJoy for BeamMP
Copyright (C) 2024 TontonSamael

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

BJIVERSION = "1.1.3"

local managers = {}
function GetBJIManagers()
    return managers
end

function RegisterBJIManager(manager)
    table.insert(managers, manager)
end

function TriggerBJIEvent(eventName, ...)
    for i, manager in ipairs(managers) do
        if type(manager[eventName]) == "function" then
            local status, err = pcall(manager[eventName], ...)
            if not status then
                LogError(svar("Error executing event {1} on manager {2} : {3}", { eventName, i, err }))
            end
        end
    end
end

require("log")
require("ge/extensions/utils/String")
require("ge/extensions/utils/Table")
require("ge/extensions/utils/LUA")
require("ge/extensions/utils/MATH")
require("ge/extensions/utils/Constants")
require("ge/extensions/utils/Icons")
ShapeDrawer = require("ge/extensions/utils/ShapeDrawer")

local function loadManagers()
    BJISound = require("ge/extensions/BJI/managers/SoundManager")
    BJIAsync = require("ge/extensions/BJI/managers/AsyncManager")
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
    BJIQuickTravel = require("ge/extensions/BJI/managers/QuickTravelManager")
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

    BJIVehSelector = require("ge/extensions/BJI/ui/WindowVehicleSelector/DrawWindowVehicleSelector")
    BJIVehSelectorPreview = require("ge/extensions/BJI/ui/WindowVehicleSelector/DrawWindowVehicleSelectorPreview")

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
            manager.onLoad()
        end
    end

    LogInfo(svar("BJI v{1} Extension Loaded", { BJIVERSION }), tag)
end

M.onInit = function()
    LogInfo("Initialization", tag)
    setExtensionUnloadMode(M, "manual")
end

M.onWorldReadyState = function(state)
    BJIContext.WorldReadyState = state
end

M.onPreRender = function() end
M.onUpdate = function(...)
    BJITick.client()
end

commands.dropPlayerAtCamera = function(...)
    TriggerBJIEvent("onDropPlayerAtCamera", ...)
end
commands.dropPlayerAtCameraNoReset = function(...)
    TriggerBJIEvent("onDropPlayerAtCameraNoReset", ...)
end
M.onVehicleSpawned = function(...)
    TriggerBJIEvent("onVehicleSpawned", ...)
end
M.onVehicleSwitched = function(...)
    TriggerBJIEvent("onVehicleSwitched", ...)
end
M.onVehicleResetted = function(gameVehID)
    BJIAsync.delayTask(function()
        -- delay execution or else vehicle can't be own
        TriggerBJIEvent("onVehicleResetted", gameVehID)
    end, 100, svar("BJIVehReset{1}", { gameVehID }))
end
M.onVehicleDestroyed = function(...)
    TriggerBJIEvent("onVehicleDestroyed", ...)
end

function M.onDriftCompletedScored(...)
    TriggerBJIEvent("onDriftCompletedScored", ...)
end

M.setPhysicsSpeed = BJIContext.setPhysicsSpeed

function M.onExtensionUnloaded()
    for _, manager in ipairs(managers) do
        if type(manager.onUnload) == "function" then
            manager.onUnload()
        end
    end
    LogInfo(svar("BJI v{1} Extension Unloaded", { BJIVERSION }), tag)
end

return M

-- FUTURE FEATURES TIPS

-- hide/show ui apps
-- guihooks.trigger('ShowApps', true/false)

-- top left message
-- guihooks.trigger('Message',{ttl=1,msg="Hello World !",category=""})

-- get map height below pos
-- be:getSurfaceHeightBelow(vec3)
