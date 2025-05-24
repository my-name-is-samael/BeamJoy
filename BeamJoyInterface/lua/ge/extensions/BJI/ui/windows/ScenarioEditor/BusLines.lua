local W = {
    labels = {
        title = "",
        line = "",
        lineName = "",
        loopable = "",
        stop = "",
        stopName = "",
        stopRadius = "",

        stopsMinimumError = "",
    },
    cache = {
        labelsWidth = 0,
        lines = Table(),
        disableButtons = false,
    },
    ---@type integer?
    markersLine = nil,
    changed = false,
    valid = true,
}

local function onClose()
    BJI.Managers.WaypointEdit.reset()
    W.markersLine = nil
end

local function reloadMarkers(iLine)
    BJI.Managers.WaypointEdit.reset()
    if W.cache.lines[iLine] then
        BJI.Managers.WaypointEdit.setWaypointsWithSegments(W.cache.lines[iLine].stops:map(function(stop, iStop, stops)
            local color -- default color for start and finish (blue)
            if iStop > 1 and (iStop < #stops or W.cache.lines[iLine].loopable) then
                -- rest color (white) otherwise
                color = BJI.Utils.ShapeDrawer.Color(1, 1, 1, .5)
            end
            return {
                name = stop.name,
                parents = iStop > 1 and { stops[iStop - 1].name } or
                    { W.cache.lines[iLine].loopable and stops[#stops].name or nil },
                pos = stop.pos,
                rot = stop.rot,
                radius = stop.radius,
                color = color,
                type = BJI.Managers.WaypointEdit.TYPES.CYLINDER
            }
        end), false)
        W.markersLine = iLine
    end
end

local function updateLabels()
    W.labels.title = BJI.Managers.Lang.get("buslines.edit.title")
    W.labels.line = BJI.Managers.Lang.get("buslines.edit.line")
    W.labels.lineName = BJI.Managers.Lang.get("buslines.edit.lineName")
    W.labels.loopable = BJI.Managers.Lang.get("buslines.edit.loopable")
    W.labels.stop = BJI.Managers.Lang.get("buslines.edit.stop")
    W.labels.stopName = BJI.Managers.Lang.get("buslines.edit.stopName")
    W.labels.stopRadius = BJI.Managers.Lang.get("buslines.edit.stopRadius")
    W.labels.stopsMinimumError = BJI.Managers.Lang.get("buslines.edit.stopsMinimumError")
end

local function udpateWidths()
    W.cache.labelsWidth = Table({ W.labels.stopName, W.labels.stopRadius })
        :reduce(function(acc, l)
            local w = BJI.Utils.Common.GetColumnTextWidth(l)
            return w > acc and w or acc
        end, 0)
end

local function updateCache()
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, function()
        updateLabels()
        udpateWidths()
    end))

    udpateWidths()
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED, udpateWidths))

    updateCache()
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.CACHE_LOADED,
        function(_, data)
            if data.cache == BJI.Managers.Cache.CACHES.BUS_LINES then
                updateCache()
            end
        end))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

local function validateBuslines()
    W.valid = not W.cache.lines:any(function(line)
        return #line.name:trim() == 0 or #line.stops < 2 or line.stops:any(function(stop)
            return #stop.name:trim() == 0 or not stop.pos or not stop.rot or stop.radius < 0
        end)
    end)
end

local function save()
    W.cache.disableButtons = true
    BJI.Tx.scenario.BusLinesSave(W.cache.lines:map(function(line)
        return {
            name = line.name,
            loopable = line.loopable,
            stops = line.stops:map(function(stop)
                return {
                    name = stop.name,
                    pos = {
                        x = stop.pos.x,
                        y = stop.pos.y,
                        z = stop.pos.z,
                    },
                    rot = {
                        x = stop.rot.x,
                        y = stop.rot.y,
                        z = stop.rot.z,
                        w = stop.rot.w,
                    },
                    radius = stop.radius
                }
            end),
            distance = BJI.Managers.GPS.getRouteLength(line.stops:map(function(stop) return vec3(stop.pos) end))
        }
    end), function(result)
        if result then
            W.changed = false
        else
            BJI.Managers.Toast.error(BJI.Managers.Lang.get("buslines.edit.saveErrorToast"))
        end
        W.cache.disableButtons = false
    end)
end

local function header(ctxt)
    local line = LineBuilder():text(W.labels.title)
    if not ctxt.veh or ctxt.veh.jbeam ~= "citybus" then
        line:btnIcon({
            id = "spawnBus",
            icon = ICONS.directions_bus,
            style = not ctxt.isOwner and BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.WARNING,
            onClick = function()
                if ctxt.veh then
                    BJI.Managers.Veh.replaceOrSpawnVehicle("citybus")
                else
                    local camPosRot = BJI.Managers.Cam.getPositionRotation(false)
                    camPosRot.rot = camPosRot.rot * quat(0, 0, 1, 0) -- invert forward
                    BJI.Managers.Veh.replaceOrSpawnVehicle("citybus", nil, camPosRot)
                end
            end
        })
    end
    line:btnIcon({
        id = "createBusLine",
        icon = ICONS.add,
        style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
        disabled = W.cache.disableButtons or not ctxt.veh or ctxt.veh.jbeam ~= "citybus",
        onClick = function()
            W.cache.lines:insert({
                name = "",
                loopable = false,
                stops = Table({
                    {
                        name = "",
                        pos = ctxt.vehPosRot.pos,
                        rot = ctxt.vehPosRot.rot,
                        radius = 2,
                    }
                })
            })
            W.changed = true
            reloadMarkers(#W.cache.lines)
        end
    }):build()
end

local function validLineName(iLine)
    return #W.cache.lines[iLine].name:trim() > 0 and
        not W.cache.lines:any(function(line, i)
            return i ~= iLine and
                line.name:trim() == W.cache.lines[iLine].name:trim()
        end)
end

---@param ctxt TickContext
---@param iLine integer
---@param bline table
---@param iStop integer
---@param stop {name: string, pos: vec3, rot: quat, radius: number}
local function drawStop(ctxt, iLine, bline, iStop, stop)
    local line = LineBuilder()
        :icon({
            icon = ICONS.simobject_bng_waypoint,
        })
        :text(BJI.Managers.Lang.get("buslines.edit.stop"):var({ index = iStop }))
        :btnIcon({
            id = string.var("busStopMoveUp{1}{2}", { iLine, iStop }),
            icon = ICONS.arrow_drop_up,
            style = BJI.Utils.Style.BTN_PRESETS.WARNING,
            disabled = W.cache.disableButtons or iStop == 1,
            onClick = function()
                table.insert(bline.stops, iStop - 1, bline.stops[iStop])
                table.remove(bline.stops, iStop + 1)
                W.changed = true
                reloadMarkers(iLine)
                validateBuslines()
            end,
        })
        :btnIcon({
            id = string.var("busStopMoveDown{1}{2}", { iLine, iStop }),
            icon = ICONS.arrow_drop_down,
            style = BJI.Utils.Style.BTN_PRESETS.WARNING,
            disabled = W.cache.disableButtons or iStop == #bline.stops,
            onClick = function()
                table.insert(bline.stops, iStop + 2, bline.stops[iStop])
                table.remove(bline.stops, iStop)
                W.changed = true
                reloadMarkers(iLine)
                validateBuslines()
            end,
        })
        :btnIcon({
            id = string.var("busStopGoTo{1}{2}", { iLine, iStop }),
            icon = ICONS.pin_drop,
            style = BJI.Utils.Style.BTN_PRESETS.INFO,
            disabled = not ctxt.veh or ctxt.veh.jbeam ~= "citybus",
            onClick = function()
                BJI.Managers.Veh.setPositionRotation(stop.pos, stop.rot)
            end
        })
        :btnIcon({
            id = string.var("busStopMoveHere{1}{2}", { iLine, iStop }),
            icon = ICONS.edit_location,
            style = BJI.Utils.Style.BTN_PRESETS.WARNING,
            disabled = W.cache.disableButtons or not ctxt.veh or ctxt.veh.jbeam ~= "citybus",
            onClick = function()
                stop.pos = ctxt.vehPosRot.pos
                stop.rot = ctxt.vehPosRot.rot
                W.changed = true
                reloadMarkers(iLine)
                validateBuslines()
            end
        })
    if iStop > 2 then
        line:btnIcon({
            id = string.var("busStopDelete{1}{2}", { iLine, iStop }),
            icon = ICONS.delete_forever,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            disabled = W.cache.disableButtons,
            onClick = function()
                table.remove(bline.stops, iStop)
                W.changed = true
                reloadMarkers(iLine)
                validateBuslines()
            end
        })
    end
    line:build()
    Indent(1)
    ColumnsBuilder(string.var("BJIScenarioEditorBusLine{1}-{2}", { iLine, iStop }), { W.cache.labelsWidth, -1 })
        :addRow({
            cells = {
                function() LineLabel(W.labels.stopName) end,
                function()
                    LineBuilder()
                        :inputString({
                            id = string.var("busStopName{1}{2}", { iLine, iStop }),
                            value = stop.name,
                            disabled = W.cache.disableButtons,
                            style = #stop.name:trim() == 0 and BJI.Utils.Style.INPUT_PRESETS.ERROR or nil,
                            onUpdate = function(val)
                                stop.name = val
                                W.changed = true
                                reloadMarkers(iLine)
                                validateBuslines()
                            end
                        })
                        :build()
                end,
            }
        })
        :addRow({
            cells = {
                function() LineLabel(W.labels.stopRadius) end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = string.var("busStopRadius{1}{2}", { iLine, iStop }),
                            type = "float",
                            precision = 1,
                            value = stop.radius,
                            min = 1,
                            max = 5,
                            step = .5,
                            disabled = W.cache.disableButtons,
                            onUpdate = function(val)
                                stop.radius = val
                                W.changed = true
                                reloadMarkers(iLine)
                                validateBuslines()
                            end
                        })
                        :build()
                end,
            }
        })
        :build()
    Indent(-1)
end

---@param ctxt TickContext
---@param iLine integer
---@param bline table
local function drawLine(ctxt, iLine, bline)
    local validName = validLineName(iLine)
    LineBuilder()
        :text(W.labels.lineName, not validName and BJI.Utils.Style.TEXT_COLORS.ERROR or nil)
        :inputString({
            id = string.var("lineName{1}", { iLine }),
            value = bline.name,
            disabled = W.cache.disableButtons,
            style = not validName and BJI.Utils.Style.INPUT_PRESETS.ERROR or nil,
            onUpdate = function(value)
                bline.name = value
                W.changed = true
                validateBuslines()
            end
        })
        :build()
    LineBuilder()
        :text(BJI.Managers.Lang.get("buslines.edit.loopable"))
        :btnIconToggle({
            id = string.var("lineLoopable{1}", { iLine }),
            icon = ICONS.rotate_90_degrees_ccw,
            state = bline.loopable,
            disabled = W.cache.disableButtons,
            onClick = function()
                bline.loopable = not bline.loopable
                W.changed = true
                reloadMarkers(iLine)
                validateBuslines()
            end
        })
        :btnIcon({
            id = string.var("addStop{1}", { iLine }),
            icon = ICONS.add_location,
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            disabled = W.cache.disableButtons or not ctxt.veh or ctxt.veh.jbeam ~= "citybus",
            onClick = function()
                table.insert(bline.stops, {
                    name = "",
                    pos = ctxt.vehPosRot.pos,
                    rot = ctxt.vehPosRot.rot,
                    radius = 2,
                })
                W.changed = true
                reloadMarkers(iLine)
                validateBuslines()
            end
        })
        :build()

    bline.stops:forEach(function(stop, iStop)
        drawStop(ctxt, iLine, bline, iStop, stop)
    end)
end

local function body(ctxt)
    W.cache.lines:forEach(function(bline, iLine)
        local displayed = W.markersLine == iLine
        AccordionBuilder()
            :label(string.var("##{1}", { iLine }))
            :commonStart(function()
                local line = LineBuilder(true)
                    :text(W.labels.line:var({ index = iLine }), displayed and
                        BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT)
                    :text(string.var("({1})", { bline.name }))
                    :btnIcon({
                        id = string.var("reloadMarkers{1}", { iLine }),
                        icon = ICONS.visibility,
                        style = displayed and BJI.Utils.Style.BTN_PRESETS.DISABLED or
                            BJI.Utils.Style.BTN_PRESETS.INFO,
                        active = displayed,
                        onClick = function()
                            if not displayed then
                                reloadMarkers(iLine)
                            end
                        end,
                    })
                    :btnIcon({
                        id = string.var("deleteLine{1}", { iLine }),
                        icon = ICONS.delete_forever,
                        style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                        disabled = W.cache.disableButtons,
                        onClick = function()
                            table.remove(W.cache.lines, iLine)
                            W.changed = true
                            if displayed then
                                BJI.Managers.WaypointEdit.reset()
                                W.markersLine = nil
                            end
                            validateBuslines()
                        end
                    })
                if #bline.stops < 2 then
                    line:text(W.labels.stopsMinimumError, BJI.Utils.Style.TEXT_COLORS.ERROR)
                end
                line:build()
            end)
            :openedBehavior(function()
                drawLine(ctxt, iLine, bline)
            end)
            :build()
        Separator()
    end)
end

local function footer(ctxt)
    local line = LineBuilder()
        :btnIcon({
            id = "cancel",
            icon = ICONS.exit_to_app,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            onClick = BJI.Windows.ScenarioEditor.onClose,
        })
    if W.changed then
        line:btnIcon({
            id = "save",
            icon = ICONS.save,
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            disabled = W.cache.disableButtons or not W.valid,
            onClick = save,
        })
    end
    line:build()
end

local function open()
    W.cache.lines = Table(BJI.Managers.Context.Scenario.Data.BusLines)
        :map(function(bl)
            return {
                name = bl.name,
                loopable = bl.loopable,
                stops = Table(bl.stops):map(function(stop)
                    return {
                        name = stop.name,
                        pos = vec3(stop.pos),
                        rot = quat(stop.rot),
                        radius = stop.radius,
                    }
                end),
            }
        end)
    validateBuslines()
    BJI.Windows.ScenarioEditor.view = W
end

W.onLoad = onLoad
W.onUnload = onUnload
W.header = header
W.body = body
W.footer = footer
W.onClose = onClose
W.open = open

return W
