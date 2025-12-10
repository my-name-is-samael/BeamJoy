---@class BJIManagerInput
local M = {
    _name = "Input",

    baseFunctions = {
        extensions = {},
    },

    INPUTS = {
        RECOVER = "recover_vehicle",
        RECOVER_ALT = "recover_vehicle_alt",
        RECOVER_LAST_ROAD = "recover_to_last_road",
        SAVE_HOME = "saveHome",
        LOAD_HOME = "loadHome",
        DROP_AT_CAMERA = "dropPlayerAtCamera",
        DROP_AT_CAMERA_NO_RESET = "dropPlayerAtCameraNoReset",
        RESET_PHYSICS = "reset_physics",
        RESET_ALL_PHYSICS = "reset_all_physics",
        RELOAD = "reload_vehicle",
        RELOAD_ALL = "reload_all_vehicles",
    },
}
-- INPUTS ACTIONS OVERRIDE
M.actions = {
    recover_vehicle = {
        downAction = function()
            local veh = BJI_Veh.getCurrentVehicle()
            if veh then
                BJI_Scenario.tryReset(veh:getID(), M.INPUTS.RECOVER,
                    M.actions.recover_vehicle.downBaseAction)
            end
        end,
        downBaseAction = function()
            local veh = BJI_Veh.getCurrentVehicle()
            if veh then veh:queueLuaCommand("recovery.reset.startRecovering()") end
        end,
        upBaseAction = function()
            local veh = BJI_Veh.getCurrentVehicle()
            if veh then veh:queueLuaCommand("recovery.stopRecovering()") end
        end
    },
    recover_vehicle_alt = {
        downAction = function()
            local veh = BJI_Veh.getCurrentVehicle()
            if veh then
                BJI_Scenario.tryReset(veh:getID(), M.INPUTS.RECOVER_ALT,
                    M.actions.recover_vehicle_alt.downBaseAction)
            end
        end,
        downBaseAction = function()
            local veh = BJI_Veh.getCurrentVehicle()
            if veh then veh:queueLuaCommand("recovery.reset.startRecovering(true)") end
        end,
        upBaseAction = function()
            local veh = BJI_Veh.getCurrentVehicle()
            if veh then veh:queueLuaCommand("recovery.stopRecovering()") end
        end
    },
    recover_to_last_road = {
        downAction = function()
            local veh = BJI_Veh.getCurrentVehicle()
            if veh then
                BJI_Scenario.tryReset(veh:getID(), M.INPUTS.RECOVER_LAST_ROAD,
                    M.actions.recover_to_last_road.downBaseAction or nop)
            end
        end,
        downBaseAction = function()
            M.baseFunctions.extensions.spawn.teleportToLastRoad()
        end,
    },
    saveHome = {
        downAction = function()
            local veh = BJI_Veh.getCurrentVehicle()
            if veh then
                BJI_Scenario.tryReset(veh:getID(), M.INPUTS.SAVE_HOME,
                    M.actions.saveHome.downBaseAction)
            end
        end,
        downBaseAction = function()
            local veh = BJI_Veh.getCurrentVehicle()
            if veh then veh:queueLuaCommand("recovery.reset.saveHome()") end
        end,
    },
    loadHome = {
        downAction = function()
            local veh = BJI_Veh.getCurrentVehicle()
            if veh then
                BJI_Scenario.tryReset(veh:getID(), M.INPUTS.LOAD_HOME,
                    M.actions.loadHome.downBaseAction)
            end
        end,
        downBaseAction = function()
            local veh = BJI_Veh.getCurrentVehicle()
            if veh then veh:queueLuaCommand("recovery.reset.loadHome()") end
        end,
    },
    dropPlayerAtCamera = {
        downAction = function()
            local veh = BJI_Veh.getCurrentVehicle()
            if veh then
                BJI_Scenario.tryReset(veh:getID(), M.INPUTS.DROP_AT_CAMERA,
                    M.actions.dropPlayerAtCamera.downBaseAction or nop)
            end
        end,
        downBaseAction = function()
            M.baseFunctions.extensions.commands.dropPlayerAtCamera(0)
        end,
    },
    dropPlayerAtCameraNoReset = {
        downAction = function()
            local veh = BJI_Veh.getCurrentVehicle()
            if veh then
                BJI_Scenario.tryReset(veh:getID(), M.INPUTS.DROP_AT_CAMERA_NO_RESET,
                    M.actions.dropPlayerAtCameraNoReset.downBaseAction or nop)
            end
        end,
        downBaseAction = function()
            M.baseFunctions.extensions.commands.dropPlayerAtCameraNoReset(0)
        end,
    },
    reset_physics = {
        downAction = function()
            local veh = BJI_Veh.getCurrentVehicle()
            if veh then
                BJI_Scenario.tryReset(veh:getID(), M.INPUTS.RESET_PHYSICS,
                    M.actions.reset_physics.downBaseAction)
            end
        end,
        downBaseAction = function()
            M.baseFunctions.resetGameplay(0)
        end,
    },
    reset_all_physics = {
        downAction = function()
            BJI_Scenario.tryReset(-1, M.INPUTS.RESET_ALL_PHYSICS,
                M.actions.reset_all_physics.downBaseAction)
        end,
        downBaseAction = function()
            M.baseFunctions.resetGameplay(-1)
        end,
    },
    reload_vehicle = {
        downAction = function()
            local veh = BJI_Veh.getCurrentVehicle()
            if veh then
                BJI_Scenario.tryReset(veh:getID(), M.INPUTS.RELOAD,
                    M.actions.reload_vehicle.downBaseAction)
            end
        end,
        downBaseAction = function()
            M.baseFunctions.extensions.core_vehicle_manager.reloadVehicle(0)
        end,
    },
    reload_all_vehicles = {
        downAction = function()
            BJI_Scenario.tryReset(-1, M.INPUTS.RELOAD_ALL,
                M.actions.reload_all_vehicles.downBaseAction or nop)
        end,
        downBaseAction = function()
            M.baseFunctions.extensions.core_vehicle_manager.reloadAllVehicles()
        end,
    },
}

local function tryAction(actionKey, isDown)
    if M.actions[actionKey] then
        if isDown and M.actions[actionKey].downAction then
            M.actions[actionKey].downAction()
        elseif not isDown and M.actions[actionKey].upAction then
            M.actions[actionKey].upAction()
        end
    end
end

local function callBaseAction(actionKey, isDown)
    if M.actions[actionKey] then
        if isDown and M.actions[actionKey].downBaseAction then
            M.actions[actionKey].downBaseAction()
        elseif not isDown and M.actions[actionKey].upBaseAction then
            M.actions[actionKey].upBaseAction()
        end
    end
end

M.tryAction = tryAction
M.callBaseAction = callBaseAction

local function overrideNGFunctions()
    M.baseFunctions = {
        resetGameplay = resetGameplay,
        extensions = {
            core_vehicle_manager = {
                reloadVehicle = extensions.core_vehicle_manager.reloadVehicle,
                reloadAllVehicles = extensions.core_vehicle_manager.reloadAllVehicles,
            },
            commands = {
                dropPlayerAtCamera = extensions.commands.dropPlayerAtCamera,
                dropPlayerAtCameraNoReset = extensions.commands.dropPlayerAtCameraNoReset,
            },
            spawn = {
                teleportToLastRoad = extensions.spawn.teleportToLastRoad,
            },
        }
    }

    extensions.core_vehicle_manager.reloadVehicle = function(localPlayerID)
        M.tryAction(M.INPUTS.RELOAD, true)
    end
    extensions.core_vehicle_manager.reloadAllVehicles = function()
        M.tryAction(M.INPUTS.RELOAD_ALL, true)
    end
    extensions.commands.dropPlayerAtCamera = function()
        M.tryAction(M.INPUTS.DROP_AT_CAMERA, true)
    end
    extensions.commands.dropPlayerAtCameraNoReset = function()
        M.tryAction(M.INPUTS.DROP_AT_CAMERA_NO_RESET, true)
    end
    extensions.spawn.teleportToLastRoad = function(veh, options)
        M.tryAction(M.INPUTS.RECOVER_LAST_ROAD, true)
    end

    ---@diagnostic disable-next-line: lowercase-global
    resetGameplay = function(localPlayerID)
        M.tryAction(localPlayerID == -1 and M.INPUTS.RESET_ALL_PHYSICS or
            M.INPUTS.RESET_PHYSICS, true)
    end
end

local function onUnload()
    RollBackNGFunctionsWrappers(M.baseFunctions.extensions)
    resetGameplay = M.baseFunctions.resetGameplay ---@diagnostic disable-line: lowercase-global
end

---@param gameVehID integer
local function initVehicleResets(gameVehID)
    if gameVehID ~= -1 then
        local veh = BJI_Veh.getVehicleObject(gameVehID)
        if veh then
            veh:queueLuaCommand([[
                recovery.reset = { -- backed up functions
                    startRecovering = recovery.startRecovering,
                    saveHome = recovery.saveHome,
                    loadHome = recovery.loadHome,
                }

                recovery.startRecovering = function(alt)
                    if alt then
                        obj:queueGameEngineLua('BJI_Input.tryAction("]] .. M.INPUTS.RECOVER_ALT .. [[",true)')
                    else
                        obj:queueGameEngineLua('BJI_Input.tryAction("]] .. M.INPUTS.RECOVER .. [[",true)')
                    end
                end
                recovery.saveHome = function()
                    obj:queueGameEngineLua('BJI_Input.tryAction("]] .. M.INPUTS.SAVE_HOME .. [[",true)')
                end
                recovery.loadHome = function()
                    obj:queueGameEngineLua('BJI_Input.tryAction("]] .. M.INPUTS.LOAD_HOME .. [[",true)')
                end
            ]])
        end
    end
end

M.onLoad = function()
    overrideNGFunctions()
    BJI_Events.addListener(BJI_Events.EVENTS.ON_UNLOAD, onUnload, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.NG_VEHICLE_SPAWNED, initVehicleResets, M._name)
end

return M
