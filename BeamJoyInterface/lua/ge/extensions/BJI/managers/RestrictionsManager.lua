---@class ScenarioRestriction
---@field restrictions string[] list of restrictions
---@field state boolean should be restricted

---@class BJIManagerRestrictions : BJIManager
local M = {
    _name = "Restrictions",

    STATE = {
        RESTRICTED = true,
        ALLOWED = false,
    },

    RESET = {
        TELEPORT = {
            "saveHome", "loadHome", "dropPlayerAtCamera", "dropPlayerAtCameraNoReset", "goto_checkpoint",
            "recover_to_last_road"
        },
        HEAVY_RELOAD = {
            "reset_physics", "reset_all_physics", "reload_vehicle", "reload_all_vehicles",
        },
        ALL = {
            "saveHome", "loadHome", "dropPlayerAtCamera", "dropPlayerAtCameraNoReset", "goto_checkpoint",
            "recover_to_last_road",
            "reset_physics", "reset_all_physics", "reload_vehicle", "reload_all_vehicles",
            "recover_vehicle", "recover_vehicle_alt"
        },
        ALL_BUT_LOADHOME = { -- only load home allowed
            "saveHome", "dropPlayerAtCamera", "dropPlayerAtCameraNoReset", "goto_checkpoint", "recover_to_last_road",
            "reset_physics", "reset_all_physics", "reload_vehicle", "reload_all_vehicles",
            "recover_vehicle", "recover_vehicle_alt"
        },
    },
    CEN = {
        CONSOLE = {
            "toggleConsoleNG",
        },
        EDITOR = {
            "editorToggle", "editorSafeModeToggle", "objectEditorToggle",
        },
        NODEGRABBER = {
            "nodegrabberRender",
        },
    },
    OTHER = {
        VEHICLE_SWITCH = { "switch_next_vehicle", "switch_previous_vehicle", "switch_next_vehicle_multiseat" },
        CAMERA_CHANGE = { "camera_1", "camera_2", "camera_3", "camera_4", "camera_5", "camera_6", "camera_7", "camera_8", "camera_9", "camera_10", "center_camera", "look_back", "rotate_camera_down", "rotate_camera_horizontal", "rotate_camera_hz_mouse", "rotate_camera_left", "rotate_camera_right", "rotate_camera_up", "rotate_camera_vertical", "rotate_camera_vt_mouse", "switch_camera_next", "switch_camera_prev", "changeCameraSpeed", "movedown", "movefast", "moveup", "rollAbs", "xAxisAbs", "yAxisAbs", "yawAbs", "zAxisAbs", "pitchAbs" },
        FREE_CAM = { "toggleCamera", "dropCameraAtPlayer" },
        BIG_MAP = { "toggleBigMap" },
        PHOTO_MODE = { "photoMode" },
    },
    _SCENARIO_DRIVEN = {
        VEHICLE_SELECTOR = { "vehicle_selector" },
        VEHICLE_PARTS_SELECTOR = { "parts_selector", "vehicledebugMenu" },
        AI_CONTROL = { "toggleTraffic", "toggleAITraffic" },
        WALKING = { "toggleWalkingMode" },
    },

    _tag = "BeamjoyRestrictions",
    _restrictions = Table({ "pause", "toggleTrackBuilder" }),
}

--- Applies reset restrictions and removes not specified
---@param resets string[]
local function updateResets(resets)
    M._restrictions = M._restrictions
        :filter(function(r) return not table.includes(M.RESET.ALL, r) end)
        :addAll(resets, true)
end

---@param cen string[]
local function updateCEN(cen)
    M._restrictions = M._restrictions
        :filter(function(r)
            return not table.any(M.CEN,
                function(cenRestrictions) return table.includes(cenRestrictions, r) end)
        end)
        :addAll(cen)
end

---@param restr ScenarioRestriction[]
local function update(restr)
    ---@param rest ScenarioRestriction
    Table(restr):forEach(function(rest)
        if not rest.state then
            M._restrictions = Table(rest.restrictions):reduce(function(acc, r)
                if acc:includes(r) then
                    acc:remove(M._restrictions:indexOf(r))
                end
                return acc
            end, M._restrictions)
            Table(rest.restrictions):forEach(function(r)
                M._restrictions = M._restrictions:filter(function(r2) return r2 ~= r end)
            end)
        elseif rest.state then
            M._restrictions:addAll(rest.restrictions, true)
        end
    end)
end

---@return tablelib<string>
local function getCurrentResets()
    return M._restrictions:filter(function(el) return table.includes(M.RESET.ALL, el) end)
end

---@param restrictions tablelib<string>|string[]
---@return boolean
local function getState(restrictions)
    return Table(restrictions):all(function(r)
        return table.includes(M._restrictions, r)
    end)
end

local function slowTick()
    update(BJI.Managers.Scenario.getRestrictions())
end

local previous = Table()
---@param ctxt TickContext
local function renderTick(ctxt)
    if not previous:compare(M._restrictions) then
        M._restrictions:sort()
        extensions.core_input_actionFilter.addAction(0, M._tag, false)
        extensions.core_input_actionFilter.setGroup(M._tag, M._restrictions)
        extensions.core_input_actionFilter.addAction(0, M._tag, true)
        previous = M._restrictions:clone()

        BJI.Managers.GameState.updateMenuItems(
            not getState(M._SCENARIO_DRIVEN.VEHICLE_SELECTOR),
            not getState(M._SCENARIO_DRIVEN.VEHICLE_PARTS_SELECTOR),
            not getState(M.OTHER.BIG_MAP),
            not getState(M.OTHER.PHOTO_MODE)
        )
    end
end

local function onLoad()
    extensions.core_input_actionFilter.setGroup(M._tag, {})
    extensions.core_input_actionFilter.addAction(0, M._tag, false)

    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.SLOW_TICK, slowTick, M._name)
end

M.updateResets = updateResets
M.updateCEN = updateCEN
M.update = update
M.getCurrentResets = getCurrentResets
M.getState = getState

M.onLoad = onLoad
M.renderTick = renderTick

return M
