---@class BJIWindowGameDebug: BJIWindow
local W = {
    name = "GameDebug",
    position = ImVec2(ui_imgui.GetMainViewport().Pos.x + 14, ui_imgui.GetMainViewport().Pos.y + 100),
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.ALWAYS_AUTO_RESIZE,
        BJI.Utils.Style.WINDOW_FLAGS.NO_RESIZE,
        BJI.Utils.Style.WINDOW_FLAGS.NO_MOVE,
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE,
        BJI.Utils.Style.WINDOW_FLAGS.NO_DOCKING,
        BJI.Utils.Style.WINDOW_FLAGS.NO_TITLE_BAR,
        BJI.Utils.Style.WINDOW_FLAGS.NO_BACKGROUND,
    },

    gc = {
        windows = 0,
        managers = 0,
    },
    time = {
        windows = 0,
        managers = 0,
    },
}
-- gc prevention
local vehicles, pos, rot, val

---@param ctxt TickContext
W.body = function(ctxt)
    SetWindowFontScale(1)
    Text("BeamJoy v" .. BJI.VERSION)
    if ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE or not ctxt.veh then
        val = BJI.Managers.Cam.getPositionRotation()
        pos, rot = val.pos, val.rot or quat()
    else
        pos, rot = ctxt.veh.position, ctxt.veh.rotation
    end
    Text(string.format("pX:%.3f | pY:%.3f | pZ:%.3f | rX:%.3f | rY:%.3f | rZ:%.3f | rW:%.3f",
        pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w))
    vehicles = BJI.Managers.Veh.getMPVehicles(nil, true)
    Text(string.format("P:%d | E:%d (V:%d, T:%d, P:%d, AI:%d)",
        ctxt.players:length(), vehicles:length(),
        vehicles:filter(function(v) return not v.isAi and v.isVehicle end):length(),
        vehicles:filter(function(v)
            return not v.isAi and not v.isVehicle and v.type == BJI.Managers.Veh.TYPES.TRAILER
        end):length(),
        vehicles:filter(function(v)
            return not v.isAi and not v.isVehicle and v.type == BJI.Managers.Veh.TYPES.PROP
        end):length(),
        vehicles:filter(function(v) return v.isAi end):length()
    ))
    Text(string.format("C:%i | T:%i | M:%s", BJI.Managers.Collisions.getState(ctxt) and 1 or 0,
        BJI.Managers.Nametags.getState() and 1 or 0, getCurrentLevelIdentifier()))
end

W.getState = function() return extensions.core_metrics.currentMode == 2 end

return W
