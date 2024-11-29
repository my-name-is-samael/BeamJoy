local blEdit

local function reloadMarkers(iLine)
    BJIWaypointEdit.reset()
    local busline = blEdit.lines[iLine]
    if busline then
        local stops = {}
        for iStop, stop in ipairs(busline.stops) do
            local color -- default color for start and finish (blue)
            if iStop > 1 and (iStop < #busline.stops or busline.loopable) then
                -- rest color (white) otherwise
                color = ShapeDrawer.Color(1, 1, 1, .5)
            end
            local parents
            if iStop > 1 then
                parents = { busline.stops[iStop - 1].name }
            elseif busline.loopable then
                parents = { busline.stops[#busline.stops].name }
            end
            table.insert(stops, {
                name = stop.name,
                parents = parents,
                pos = stop.pos,
                radius = stop.radius,
                color = color,
            })
        end

        BJIWaypointEdit.setWaypointsWithSegments(stops, false)
        blEdit.markersLine = iLine
    end
end

local function save()
    local lines = {}
    for _, line in ipairs(blEdit.lines) do
        local nline = {
            name = line.name,
            loopable = line.loopable,
            stops = {},
        }

        local points = {}
        for _, stop in ipairs(line.stops) do
            table.insert(points, vec3(stop.pos))
            table.insert(nline.stops, {
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
            })
        end
        nline.distance = BJIGPS.getRouteLength(points)

        table.insert(lines, nline)
    end


    blEdit.processSave = true
    local _, err = pcall(BJITx.scenario.BusLinesSave, lines)
    if not err then
        BJIAsync.task(function()
            return blEdit.processSave and blEdit.saveSuccess ~= nil
        end, function()
            if blEdit.saveSuccess then
                blEdit.changed = false
            else
                -- error message
                BJIToast.error(BJILang.get("buslines.edit.saveErrorToast"))
            end

            blEdit.processSave = nil
            blEdit.saveSuccess = nil
        end, "BusLinesSave")
    else
        blEdit.processSave = nil
    end
end

local function drawHeader(ctxt)
    blEdit = BJIContext.Scenario.BusLinesEdit

    LineBuilder()
        :text(BJILang.get("buslines.edit.title"))
        :build()

    if not ctxt.isOwner or ctxt.veh.jbeam ~= "citybus" then
        LineBuilder()
            :btnIcon({
                id = "spawnBus",
                icon = ICONS.directions_bus,
                background = BTN_PRESETS.INFO,
                onClick = function()
                    local camPosRot = BJICam.getPositionRotation(false)
                    camPosRot.rot = camPosRot.rot * quat(0, 0, 1, 0) -- invert forward
                    BJIVeh.replaceOrSpawnVehicle("citybus", nil, camPosRot)
                end
            })
            :build()
    end
end

local function validLineName(iLine)
    local name = blEdit.lines[iLine].name
    if #strim(name) == 0 then
        return false
    end
    for i, line in ipairs(blEdit.lines) do
        if i ~= iLine and name == line.name then
            return false
        end
    end
    return true
end

local function validStopName(iLine, iStop)
    local name = blEdit.lines[iLine].stops[iStop].name
    if #strim(name) == 0 then
        return false
    end
    for i, stop in ipairs(blEdit.lines[iLine].stops) do
        if i ~= iStop and name == stop.name then
            return false
        end
    end
    return true
end

local function drawBody(ctxt)
    local vehPos = (ctxt.isOwner and ctxt.veh.jbeam == "citybus") and ctxt.vehPosRot or nil

    blEdit.valid = true

    local stopNameRadiusWidth = 0
    for _, key in pairs({ "buslines.edit.stopName", "buslines.edit.stopRadius" }) do
        local label = BJILang.get(key)
        local w = GetColumnTextWidth(label .. ":")
        if w > stopNameRadiusWidth then
            stopNameRadiusWidth = w
        end
    end

    for iLine, busLine in ipairs(blEdit.lines) do
        local displayed = blEdit.markersLine == iLine
        AccordionBuilder()
            :label(svar("##{1}", { iLine }))
            :commonStart(function()
                local line = LineBuilder(true)
                    :text(svar(BJILang.get("buslines.edit.line"), { index = iLine }),
                        displayed and TEXT_COLORS.HIGHLIGHT or TEXT_COLORS.DEFAULT)
                    :text(svar("({1})", { busLine.name }))
                    :btnIcon({
                        id = svar("reloadMarkers{1}", { iLine }),
                        icon = ICONS.visibility,
                        style = displayed and TEXT_COLORS.SUCCESS or TEXT_COLORS.DEFAULT,
                        background = displayed and BTN_PRESETS.DISABLED or BTN_PRESETS.INFO,
                        onClick = function()
                            if not displayed then
                                reloadMarkers(iLine)
                            end
                        end,
                    })
                    :btnIcon({
                        id = svar("deleteLine{1}", { iLine }),
                        icon = ICONS.delete_forever,
                        background = BTN_PRESETS.ERROR,
                        disabled = blEdit.processSave,
                        onClick = function()
                            table.remove(blEdit.lines, iLine)
                            blEdit.changed = true
                            if displayed then
                                BJIWaypointEdit.reset()
                                blEdit.markersLine = nil
                            end
                        end
                    })
                if #busLine.stops < 2 then
                    line:text(BJILang.get("buslines.edit.stopsMinimumError"), TEXT_COLORS.ERROR)
                    blEdit.valid = false
                end
                line:build()
            end)
            :openedBehavior(function()
                local validName = validLineName(iLine)
                if not validName then
                    blEdit.valid = false
                end
                LineBuilder()
                    :text(svar("{1}:", { BJILang.get("buslines.edit.lineName") }),
                        validName and TEXT_COLORS.DEFAULT or TEXT_COLORS.ERROR)
                    :inputString({
                        id = svar("lineName{1}", { iLine }),
                        value = busLine.name,
                        disabled = blEdit.processSave,
                        style = validName and INPUT_PRESETS.DEFAULT or INPUT_PRESETS.ERROR,
                        onUpdate = function(value)
                            busLine.name = value
                            blEdit.changed = true
                        end
                    })
                    :build()
                LineBuilder()
                    :text(BJILang.get("buslines.edit.loopable"))
                    :btnIconSwitch({
                        id = svar("lineLoopable{1}", { iLine }),
                        iconEnabled = ICONS.rotate_90_degrees_ccw,
                        state = busLine.loopable,
                        disabled = blEdit.processSave,
                        onClick = function()
                            busLine.loopable = not busLine.loopable
                            blEdit.changed = true
                            reloadMarkers(iLine)
                        end
                    })
                    :build()

                for iStop, stop in ipairs(busLine.stops) do
                    validName = validStopName(iLine, iStop)
                    if not validName then
                        blEdit.valid = false
                    end
                    local line = LineBuilder()
                        :icon({
                            icon = ICONS.simobject_bng_waypoint,
                        })
                        :text(svar(BJILang.get("buslines.edit.stop"), { index = iStop }))
                        :btnIcon({
                            id = svar("busStopMoveUp{1}{2}", { iLine, iStop }),
                            icon = ICONS.arrow_drop_up,
                            background = BTN_PRESETS.WARNING,
                            disabled = iStop == 1 or blEdit.processSave,
                            onClick = function()
                                table.insert(busLine.stops, iStop - 1, busLine.stops[iStop])
                                table.remove(busLine.stops, iStop + 1)
                                blEdit.changed = true
                                reloadMarkers(iLine)
                            end,
                        })
                        :btnIcon({
                            id = svar("busStopMoveDown{1}{2}", { iLine, iStop }),
                            icon = ICONS.arrow_drop_down,
                            background = BTN_PRESETS.WARNING,
                            disabled = iStop == #busLine.stops or blEdit.processSave,
                            onClick = function()
                                table.insert(busLine.stops, iStop + 2, busLine.stops[iStop])
                                table.remove(busLine.stops, iStop)
                                blEdit.changed = true
                                reloadMarkers(iLine)
                            end,
                        })
                        :btnIcon({
                            id = svar("busStopGoTo{1}{2}", { iLine, iStop }),
                            icon = ICONS.cameraFocusOnVehicle2,
                            background = BTN_PRESETS.INFO,
                            disabled = not vehPos,
                            onClick = function()
                                BJIVeh.setPositionRotation(stop.pos, stop.rot)
                            end
                        })
                        :btnIcon({
                            id = svar("busStopMoveHere{1}{2}", { iLine, iStop }),
                            icon = ICONS.crosshair,
                            background = BTN_PRESETS.WARNING,
                            disabled = not vehPos or blEdit.processSave,
                            onClick = function()
                                if vehPos then
                                    stop.pos = vehPos.pos
                                    stop.rot = vehPos.rot
                                    blEdit.changed = true
                                    reloadMarkers(iLine)
                                end
                            end
                        })
                    if iStop > 1 then
                        line:btnIcon({
                            id = svar("busStopDelete{1}{2}", { iLine, iStop }),
                            icon = ICONS.delete_forever,
                            background = BTN_PRESETS.ERROR,
                            disabled = blEdit.processSave,
                            onClick = function()
                                table.remove(busLine.stops, iStop)
                                blEdit.changed = true
                                reloadMarkers(iLine)
                            end
                        })
                    end
                    line:build()
                    Indent(1)
                    ColumnsBuilder(svar("BJIScenarioEditorBusLine{1}-{2}", { iLine, iStop }),
                        { stopNameRadiusWidth, -1 })
                        :addRow({
                            cells = {
                                function()
                                    LineBuilder()
                                        :text(svar("{1}:", { BJILang.get("buslines.edit.stopName") }))
                                        :build()
                                end,
                                function()
                                    LineBuilder()
                                        :inputString({
                                            id = svar("busStopName{1}{2}", { iLine, iStop }),
                                            value = stop.name,
                                            disabled = blEdit.processSave,
                                            style = validName and INPUT_PRESETS.DEFAULT or INPUT_PRESETS.ERROR,
                                            onUpdate = function(val)
                                                stop.name = val
                                                blEdit.changed = true
                                                reloadMarkers(iLine)
                                            end
                                        })
                                        :build()
                                end,
                            }
                        })
                        :addRow({
                            cells = {
                                function()
                                    LineBuilder()
                                        :text(svar("{1}:", { BJILang.get("buslines.edit.stopRadius") }))
                                        :build()
                                end,
                                function()
                                    LineBuilder()
                                        :inputNumeric({
                                            id = svar("busStopRadius{1}{2}", { iLine, iStop }),
                                            type = "float",
                                            precision = 1,
                                            value = stop.radius,
                                            min = 1,
                                            max = 5,
                                            step = .5,
                                            disabled = blEdit.processSave,
                                            onUpdate = function(val)
                                                stop.radius = val
                                                blEdit.changed = true
                                                reloadMarkers(iLine)
                                            end
                                        })
                                        :build()
                                end,
                            }
                        })
                        :build()
                    Indent(-1)
                end
                LineBuilder()
                    :btnIcon({
                        id = svar("addStop{1}", { iLine }),
                        icon = ICONS.addListItem,
                        background = TEXT_COLORS.SUCCESS,
                        disabled = not vehPos or blEdit.processSave,
                        onClick = function()
                            if vehPos then
                                table.insert(busLine.stops, {
                                    name = "",
                                    pos = vehPos.pos,
                                    rot = vehPos.rot,
                                    radius = 2,
                                })
                                blEdit.changed = true
                                reloadMarkers(iLine)
                            end
                        end
                    })
                    :build()
            end)
            :build()
        Separator()
    end

    LineBuilder()
        :btnIcon({
            id = "createBusLine",
            icon = ICONS.addListItem,
            background = BTN_PRESETS.SUCCESS,
            disabled = not vehPos or blEdit.processSave,
            onClick = function()
                if vehPos then
                    table.insert(blEdit.lines, {
                        name = "",
                        loopable = false,
                        stops = {
                            {
                                name = "",
                                pos = vehPos.pos,
                                rot = vehPos.rot,
                                radius = 2,
                            }
                        }
                    })
                    blEdit.changed = true
                    reloadMarkers(#blEdit.lines)
                end
            end
        })
        :build()
end

local function drawFooter(ctxt)
    local line = LineBuilder()
        :btnIcon({
            id = "cancel",
            icon = ICONS.exit_to_app,
            background = BTN_PRESETS.ERROR,
            onClick = function()
                BJIContext.Scenario.BusLinesEdit = nil
                BJIWaypointEdit.reset()
            end,
        })
    if blEdit.changed then
        line:btnIcon({
            id = "save",
            icon = ICONS.save,
            background = BTN_PRESETS.SUCCESS,
            disabled = not blEdit.valid or blEdit.processSave,
            onClick = save,
        })
    end
    line:build()
end

return {
    flags = {
        WINDOW_FLAGS.NO_COLLAPSE,
    },
    header = drawHeader,
    body = drawBody,
    footer = drawFooter,
    onClose = function()
        BJIContext.Scenario.BusLinesEdit = nil
        BJIWaypointEdit.reset()
    end,
}
