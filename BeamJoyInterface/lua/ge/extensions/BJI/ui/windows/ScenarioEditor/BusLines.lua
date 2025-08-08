local W = {
    name = "ScenarioEditorBusLines",

    labels = {
        title = "",
        line = "",
        lineName = "",
        loopable = "",
        stops = "",
        stop = "",
        stopName = "",
        stopRadius = "",

        stopsMinimumError = "",

        buttons = {
            showLine = "",
            deleteLine = "",
            spawnBus = "",
            addBusLine = "",
            showStop = "",
            setStopHere = "",
            deleteStop = "",
            toggleLoopable = "",
            addStopHere = "",
            moveUp = "",
            moveDown = "",
            close = "",
            save = "",
            errorNeedABus = "",
        },
    },
    cache = {
        lines = Table(),
        disableButtons = false,
    },
    ---@type integer?
    markersLine = nil,
    changed = false,
    valid = true,
}
--- gc prevention
local opened, nextValue, validName

local function onClose()
    BJI_WaypointEdit.reset()
    W.markersLine = nil
    W.changed = false
    W.valid = true
end

local function reloadMarkers(iLine)
    BJI_WaypointEdit.reset()
    if W.cache.lines[iLine] then
        BJI_WaypointEdit.setWaypointsWithSegments(
            W.cache.lines[iLine].stops:reduce(function(res, stop, iStop, stops)
                local color -- default color for start and finish (blue)
                if iStop > 1 and (iStop < #stops or W.cache.lines[iLine].loopable) then
                    -- rest color (white) otherwise
                    color = BJI.Utils.ShapeDrawer.Color(1, 1, 1, .5)
                end
                res:insert({
                    name = stop.name,
                    parents = iStop > 1 and { stops[iStop - 1].name } or
                        { W.cache.lines[iLine].loopable and stops[#stops].name or nil },
                    pos = stop.pos,
                    radius = stop.radius,
                    color = color,
                    type = BJI_WaypointEdit.TYPES.CYLINDER,
                })
                res:insert({
                    pos = stop.pos,
                    rot = stop.rot,
                    color = BJI.Utils.ShapeDrawer.Color(1, 1, 0, .5),
                    type = BJI_WaypointEdit.TYPES.ARROW,
                })
                return res
            end, Table()), false)
        W.markersLine = iLine
    end
end

local function updateLabels()
    W.labels.title = BJI_Lang.get("buslines.edit.title")
    W.labels.line = BJI_Lang.get("buslines.edit.line")
    W.labels.lineName = BJI_Lang.get("buslines.edit.lineName")
    W.labels.loopable = BJI_Lang.get("buslines.edit.loopable")
    W.labels.stops = BJI_Lang.get("buslines.edit.stops")
    W.labels.stop = BJI_Lang.get("buslines.edit.stop")
    W.labels.stopName = BJI_Lang.get("buslines.edit.stopName")
    W.labels.stopRadius = BJI_Lang.get("buslines.edit.stopRadius")
    W.labels.stopsMinimumError = BJI_Lang.get("buslines.edit.stopsMinimumError")

    W.labels.buttons.showLine = BJI_Lang.get("buslines.edit.buttons.showLine")
    W.labels.buttons.deleteLine = BJI_Lang.get("buslines.edit.buttons.deleteLine")
    W.labels.buttons.spawnBus = BJI_Lang.get("buslines.edit.buttons.spawnBus")
    W.labels.buttons.addBusLine = BJI_Lang.get("buslines.edit.buttons.addBusLine")
    W.labels.buttons.showStop = BJI_Lang.get("buslines.edit.buttons.showStop")
    W.labels.buttons.setStopHere = BJI_Lang.get("buslines.edit.buttons.setStopHere")
    W.labels.buttons.deleteStop = BJI_Lang.get("buslines.edit.buttons.deleteStop")
    W.labels.buttons.toggleLoopable = BJI_Lang.get("buslines.edit.buttons.toggleLoopable")
    W.labels.buttons.addStopHere = BJI_Lang.get("buslines.edit.buttons.addStopHere")
    W.labels.buttons.moveUp = BJI_Lang.get("common.buttons.moveUp")
    W.labels.buttons.moveDown = BJI_Lang.get("common.buttons.moveDown")
    W.labels.buttons.close = BJI_Lang.get("common.buttons.close")
    W.labels.buttons.save = BJI_Lang.get("common.buttons.save")
    W.labels.buttons.errorNeedABus = BJI_Lang.get("buslines.edit.buttons.errorNeedABus")
    W.labels.buttons.errorInvalidData = BJI_Lang.get("errors.someDataAreInvalid")
end

local function validateBuslines()
    W.valid = not W.cache.lines:any(function(line)
        return #line.name:trim() == 0 or #line.stops < 2 or line.stops:any(function(stop)
            return #stop.name:trim() == 0 or not stop.pos or not stop.rot or stop.radius < 0
        end)
    end)
end

local function updateCache()
    W.cache.lines = Table(BJI_Scenario.Data.BusLines)
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
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.LANG_CHANGED, updateLabels, W.name))

    updateCache()
    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.CACHE_LOADED,
        function(_, data)
            if data.cache == BJI_Cache.CACHES.BUS_LINES then
                updateCache()
            end
        end, W.name))
end

local function onUnload()
    listeners:forEach(BJI_Events.removeListener)
end

local function save()
    W.cache.disableButtons = true
    BJI_Tx_scenario.BusLinesSave(W.cache.lines:map(function(line)
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
            distance = BJI_GPS.getRouteLength(line.stops:map(function(stop) return vec3(stop.pos) end))
        }
    end), function(result)
        if result then
            W.changed = false
        else
            BJI_Toast.error(BJI_Lang.get("buslines.edit.saveErrorToast"))
        end
        W.cache.disableButtons = false
    end)
end

---@param ctxt TickContext
local function header(ctxt)
    Text(W.labels.title)
    if not ctxt.isOwner or ctxt.veh.jbeam ~= "citybus" then
        SameLine()
        if IconButton("spawnBus", BJI.Utils.Icon.ICONS.directions_bus,
                { btnStyle = not ctxt.isOwner and BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.WARNING }) then
            if ctxt.veh then
                BJI_Veh.replaceOrSpawnVehicle("citybus")
            else
                local camPosRot = BJI_Cam.getPositionRotation(false)
                camPosRot.rot = camPosRot.rot * quat(0, 0, 1, 0) -- invert forward
                BJI_Veh.replaceOrSpawnVehicle("citybus", nil, camPosRot)
            end
        end
        TooltipText(W.labels.buttons.spawnBus)
    end
    SameLine()
    if IconButton("createBusLine", BJI.Utils.Icon.ICONS.add, { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            disabled = W.cache.disableButtons or not ctxt.veh or ctxt.veh.jbeam ~= "citybus" or
                ctxt.camera == BJI_Cam.CAMERAS.FREE }) then
        W.cache.lines:insert({
            name = "",
            loopable = false,
            stops = Table({
                {
                    name = "",
                    pos = ctxt.veh.position,
                    rot = ctxt.veh.rotation,
                    radius = 2,
                }
            })
        })
        W.changed = true
        reloadMarkers(#W.cache.lines)
        validateBuslines()
    end
    TooltipText(W.labels.buttons.addBusLine ..
        ((not ctxt.veh or ctxt.veh.jbeam ~= "citybus" or ctxt.camera == BJI_Cam.CAMERAS.FREE) and
            " (" .. W.labels.buttons.errorNeedABus .. ")" or ""))
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
    TableNewRow()
    Indent()
    Text(W.labels.stop:var({ index = iStop }))
    Unindent()
    TableNextColumn()
    if IconButton(string.format("busStopMoveUp-%d-%d", iLine, iStop), BJI.Utils.Icon.ICONS.arrow_drop_up,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, disabled = W.cache.disableButtons or iStop == 1 }) then
        table.insert(bline.stops, iStop - 1, bline.stops[iStop])
        table.remove(bline.stops, iStop + 1)
        W.changed = true
        reloadMarkers(iLine)
        validateBuslines()
    end
    TooltipText(W.labels.buttons.moveUp)
    SameLine()
    if IconButton(string.format("busStopMoveDown-%d-%d", iLine, iStop), BJI.Utils.Icon.ICONS.arrow_drop_down,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, disabled = W.cache.disableButtons or iStop == #bline.stops }) then
        table.insert(bline.stops, iStop + 2, bline.stops[iStop])
        table.remove(bline.stops, iStop)
        W.changed = true
        reloadMarkers(iLine)
        validateBuslines()
    end
    TooltipText(W.labels.buttons.moveDown)
    SameLine()
    if IconButton(string.format("goToBusStop-%d-%d", iLine, iStop), BJI.Utils.Icon.ICONS.pin_drop,
            { disabled = not ctxt.isOwner or ctxt.veh.jbeam ~= "citybus" }) then
        if ctxt.camera == BJI_Cam.CAMERAS.FREE then
            BJI_Cam.toggleFreeCam()
        end
        BJI_Veh.setPositionRotation(stop.pos, stop.rot)
    end
    TooltipText(W.labels.buttons.showStop ..
        ((not ctxt.veh or ctxt.veh.jbeam ~= "citybus") and
            " (" .. W.labels.buttons.errorNeedABus .. ")" or ""))
    SameLine()
    if IconButton(string.format("moveBusStopHere-%d-%d", iLine, iStop), BJI.Utils.Icon.ICONS.edit_location,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, disabled = W.cache.disableButtons or
                not ctxt.veh or ctxt.veh.jbeam ~= "citybus" or ctxt.camera == BJI_Cam.CAMERAS.FREE }) then
        stop.pos = ctxt.veh.position
        stop.rot = ctxt.veh.rotation
        W.changed = true
        reloadMarkers(iLine)
        validateBuslines()
    end
    TooltipText(W.labels.buttons.setStopHere ..
        ((not ctxt.veh or ctxt.veh.jbeam ~= "citybus" or ctxt.camera == BJI_Cam.CAMERAS.FREE) and
            " (" .. W.labels.buttons.errorNeedABus .. ")" or ""))
    if iStop > 2 then
        SameLine()
        if IconButton(string.format("deleteBusStop-%d-%d", iLine, iStop), BJI.Utils.Icon.ICONS.delete_forever,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = W.cache.disableButtons }) then
            table.remove(bline.stops, iStop)
            W.changed = true
            reloadMarkers(iLine)
            validateBuslines()
        end
        TooltipText(W.labels.buttons.deleteStop)
    end

    TableNewRow()
    Indent()
    Indent()
    Text(W.labels.stopName)
    Unindent()
    Unindent()
    TableNextColumn()
    nextValue = InputText(string.format("busStopName-%d-%d", iLine, iStop), stop.name,
        {
            inputStyle = #stop.name:trim() == 0 and BJI.Utils.Style.INPUT_PRESETS.ERROR or nil,
            disabled = W.cache.disableInputs
        })
    if nextValue then
        stop.name = nextValue
        W.changed = true
        reloadMarkers(iLine)
        validateBuslines()
    end

    TableNewRow()
    Indent()
    Indent()
    Text(W.labels.stopRadius)
    Unindent()
    Unindent()
    TableNextColumn()
    nextValue = SliderFloatPrecision(string.format("busStopRadius-%d-%d", iLine, iStop), stop.radius, 1, 5,
        { step = .5, precision = 1, disabled = W.cache.disableInputs, formatRender = "%.1fm" })
    if nextValue then
        stop.radius = nextValue
        W.changed = true
        reloadMarkers(iLine)
        validateBuslines()
    end
end

---@param ctxt TickContext
---@param iLine integer
---@param bline table
local function drawLine(ctxt, iLine, bline)
    validName = validLineName(iLine)
    if BeginTable("BJIScenarioEditorBusLine" .. tostring(iLine), {
            { label = "##scenarioeditor-busline-" .. tostring(iLine) .. "-labels" },
            { label = "##scenarioeditor-busline-" .. tostring(iLine) .. "-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        TableNewRow()
        Text(W.labels.lineName)
        TableNextColumn()
        nextValue = InputText("lineName" .. tostring(iLine), bline.name,
            {
                disabled = W.cache.disableButtons,
                inputStyle = not validName and BJI.Utils.Style.INPUT_PRESETS.ERROR or
                    nil
            })
        if nextValue then
            bline.name = nextValue
            W.changed = true
            validateBuslines()
        end

        TableNewRow()
        Text(W.labels.loopable)
        TableNextColumn()
        if IconButton("lineLoopable" .. tostring(iLine), BJI.Utils.Icon.ICONS.rotate_90_degrees_ccw,
                { btnStyle = bline.loopable and BJI.Utils.Style.BTN_PRESETS.SUCCESS or
                    BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = W.cache.disableButtons }) then
            bline.loopable = not bline.loopable
            W.changed = true
            reloadMarkers(iLine)
            validateBuslines()
        end
        TooltipText(W.labels.buttons.toggleLoopable)

        TableNewRow()
        Text(W.labels.stops)
        TableNextColumn()
        if IconButton("addStop" .. tostring(iLine), BJI.Utils.Icon.ICONS.add_location,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = W.cache.disableButtons or
                    not ctxt.veh or ctxt.veh.jbeam ~= "citybus" or ctxt.camera == BJI_Cam.CAMERAS.FREE }) then
            table.insert(bline.stops, {
                name = "",
                pos = ctxt.veh.position,
                rot = ctxt.veh.rotation,
                radius = 2,
            })
            W.changed = true
            reloadMarkers(iLine)
            validateBuslines()
        end
        TooltipText(W.labels.buttons.addStopHere ..
            ((not ctxt.veh or ctxt.veh.jbeam ~= "citybus" or ctxt.camera == BJI_Cam.CAMERAS.FREE) and
                " (" .. W.labels.buttons.errorNeedABus .. ")" or ""))

        bline.stops:forEach(function(stop, iStop)
            drawStop(ctxt, iLine, bline, iStop, stop)
        end)

        EndTable()
    end
end

local function body(ctxt)
    W.cache.lines:forEach(function(line, iLine)
        opened = BeginTree(W.labels.line:var({ index = iLine }), {
            color = W.markersLine == iLine and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or nil
        })
        SameLine()
        if IconButton("showLineMarkers" .. tostring(iLine), BJI.Utils.Icon.ICONS.visibility,
                { disabled = W.markersLine == iLine }) then
            reloadMarkers(iLine)
        end
        TooltipText(W.labels.buttons.showLine)
        SameLine()
        if IconButton("deleteLine" .. tostring(iLine), BJI.Utils.Icon.ICONS.delete_forever,
                { disabled = W.cache.disableButtons, btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
            table.remove(W.cache.lines, iLine)
            W.changed = true
            if W.markersLine == iLine then
                BJI_WaypointEdit.reset()
                W.markersLine = nil
            end
            validateBuslines()
        end
        TooltipText(W.labels.buttons.deleteLine)
        if not opened and line.name and #line.name:trim() > 0 then
            SameLine()
            Text(string.format("(%s)", line.name),
                { color = W.markersLine == iLine and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or nil })
        end
        if #line.stops < 2 then
            SameLine()
            Text(W.labels.stopsMinimumError, { color = BJI.Utils.Style.TEXT_COLORS.ERROR })
        end
        if opened then
            drawLine(ctxt, iLine, line)
            EndTree()
        end
    end)
end

---@param ctxt TickContext
local function footer(ctxt)
    if IconButton("closeBusEdit", BJI.Utils.Icon.ICONS.exit_to_app,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
        BJI_Win_ScenarioEditor.onClose()
    end
    TooltipText(W.labels.buttons.close)
    if W.changed then
        SameLine()
        if IconButton("saveBusEdit", BJI.Utils.Icon.ICONS.save,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                    disabled = W.cache.disableButtons or not W.valid }) then
            save()
        end
        TooltipText(W.labels.buttons.save ..
            (not W.valid and " (" .. W.labels.buttons.errorInvalidData .. ")" or ""))
    end
end

local function open()
    BJI_Win_ScenarioEditor.view = W
end

W.onLoad = onLoad
W.onUnload = onUnload
W.header = header
W.body = body
W.footer = footer
W.onClose = onClose
W.open = open

return W
