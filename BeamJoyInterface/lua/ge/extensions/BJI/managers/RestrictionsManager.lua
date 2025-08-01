---@class BJIManagerRestrictions : BJIManager
local M = {
    _name = "Restrictions",

    baseFunctions = {},

    STATE = {
        RESTRICTED = true,
        ALLOWED = false,
    },

    CEN = {
        CONSOLE = { "toggleConsoleNG" },
        EDITOR = { "editorToggle", "editorSafeModeToggle", "objectEditorToggle" },
    },
    OTHER = {
        VEHICLE_SWITCH = { "switch_next_vehicle", "switch_previous_vehicle", "switch_next_vehicle_multiseat" },
        CAMERA_CHANGE = { "camera_1", "camera_2", "camera_3", "camera_4", "camera_5", "camera_6", "camera_7",
            "camera_8", "camera_9", "camera_10", "center_camera", "look_back", "rotate_camera_down",
            "rotate_camera_horizontal", "rotate_camera_hz_mouse", "rotate_camera_left", "rotate_camera_right",
            "rotate_camera_up", "rotate_camera_vertical", "rotate_camera_vt_mouse", "switch_camera_next",
            "switch_camera_prev", "changeCameraSpeed", "movedown", "movefast", "moveup", "moveleft",
            "moveright", "moveforward", "movebackward", "rollAbs", "xAxisAbs", "yAxisAbs", "yawAbs",
            "zAxisAbs", "pitchAbs" },
        FREE_CAM = { "toggleCamera", "dropCameraAtPlayer" },
        BIG_MAP = { "toggleBigMap" },
        PHOTO_MODE = { "photoMode" },
        FUN_STUFF = { "funBoom", "funBreak", "funExtinguish", "funFire", "funHinges", "funTires",
            "funRandomTire", "latchesOpen", "latchesClose" },
        COUPLERS = { "couplersLock", "couplersToggle", "couplersUnlock" },
    },
    _SCENARIO_DRIVEN = {
        VEHICLE_SELECTOR = { "vehicle_selector" },
        VEHICLE_PARTS_SELECTOR = { "parts_selector", "vehicledebugMenu" },
        AI_CONTROL = { "toggleTraffic" },
        WALKING = { "toggleWalkingMode" },
        NODEGRABBER = { "nodegrabberAction", "nodegrabberGrab", "nodegrabberRender", "nodegrabberStrength" },
    },
    ENV = {
        TIME = { "slower_motion", "faster_motion", "toggle_slow_motion" },
    },
    AI = {
        CHANGE_MODE = { "aiStop", "aiRandom", "carsFlee", "aiChase", "aiFollow", "aiFollowRoute", "aiRaceRoute",
            "aiDisableMyself" }
    },

    _tag = "BeamjoyRestrictions",
    _baseRestrictions = Table({ "pause", "toggleTrackBuilder", "toggleAITraffic", "forceField", "goto_checkpoint" }),
    _restrictions = Table(),
}
--- gc prevention
local ok, data, res

---@param restrictions tablelib<string>|string[]
---@return boolean
local function getState(restrictions)
    return Table(restrictions):all(function(r)
        return table.includes(M._restrictions, r)
    end)
end

local previous = Table()
local function update()
    local ctxt = BJI_Tick.getContext()
    res = M._baseRestrictions:clone()
        :addAll(M.AI.CHANGE_MODE, true)
    for _, m in pairs(BJI.Managers) do
        if type(m.getRestrictions) == "function" then
            ok, data = pcall(m.getRestrictions, ctxt)
            if ok then
                res:addAll(data, true)
            else
                LogError(string.var("Error while getting restrictions from {1} : {2}", { m._name, data }))
            end
        end
    end

    if not BJI_Scenario.canUseNodegrabber(ctxt) then
        res:addAll(M._SCENARIO_DRIVEN.NODEGRABBER, true)
    end

    for _, resetType in pairs(BJI_Input.INPUTS) do
        if not ctxt.veh or not BJI_Scenario.canReset(ctxt.veh.gameVehicleID, resetType) then
            res:addAll({ resetType }, true)
        end
    end

    res:sort()

    if not res:compare(previous) then
        M._restrictions = res:clone()
        previous = res
        extensions.core_input_actionFilter.addAction(0, M._tag, false)
        extensions.core_input_actionFilter.setGroup(M._tag, M._restrictions)
        extensions.core_input_actionFilter.addAction(0, M._tag, true)

        if M.getState(M.CEN.CONSOLE) then
            extensions.ui_console.hide()
        end

        BJI_GameState.updateMenuItems(
            not getState(M._SCENARIO_DRIVEN.VEHICLE_SELECTOR),
            not getState(M._SCENARIO_DRIVEN.VEHICLE_PARTS_SELECTOR),
            not getState(M.OTHER.BIG_MAP)
        )

        BJI_Events.trigger(BJI_Events.EVENTS.RESTRICTIONS_UPDATE)
    end
end

local function onUnload()
    RollBackNGFunctionsWrappers(M.baseFunctions)
end

-- restrict boost bindings
local function onPostLoad()
    extensions.core_funstuff.boost = function()
        if BJI_Scenario.canBoost() then
            M.baseFunctions.core_funstuff.boost()
        end
    end
    extensions.core_funstuff.boostBackwards = function()
        if BJI_Scenario.canBoost() then
            M.baseFunctions.core_funstuff.boostBackwards()
        end
    end
end

local function onLoad()
    extensions.load("core_funstuff")
    M.baseFunctions = {
        core_funstuff = {
            boost = extensions.core_funstuff.boost,
            boostBackwards = extensions.core_funstuff.boostBackwards,
        }
    }

    BJI_Events.addListener(BJI_Events.EVENTS.ON_POST_LOAD, onPostLoad, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.ON_UNLOAD, onUnload, M._name)

    extensions.core_input_actionFilter.setGroup(M._tag, {})
    extensions.core_input_actionFilter.addAction(0, M._tag, false)

    BJI_Events.addListener({
        BJI_Events.EVENTS.VEHICLE_SPEC_CHANGED,
        BJI_Events.EVENTS.SCENARIO_CHANGED,
        BJI_Events.EVENTS.SCENARIO_UPDATED,
        BJI_Events.EVENTS.PERMISSION_CHANGED,
        BJI_Events.EVENTS.PURSUIT_UPDATE,
    }, update, M._name)
end

M.update = update
M.getState = getState

M.onLoad = onLoad

return M
