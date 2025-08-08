local W = {}

--- gc prevention
local opened, nextValue

local hunterColor = BJI.Utils.ShapeDrawer.Color(1, 1, 0, .5)
local huntedColor = BJI.Utils.ShapeDrawer.Color(1, 0, 0, .5)
local bgColor = BJI.Utils.ShapeDrawer.Color(0, 0, 0, .5)
---@param parent table
W.reloadMarkers = function(parent)
    BJI_WaypointEdit.setWaypoints(parent.data.waypoints:map(function(target, i)
        return {
            name = parent.labels.hunter.tags.waypointName:var({ index = i }),
            pos = target.pos,
            radius = target.radius,
            type = BJI_WaypointEdit.TYPES.CYLINDER,
        }
    end):addAll(parent.data.majorPositions:map(function(hunter, i)
        return {
            name = parent.labels.hunter.tags.hunterName:var({ index = i }),
            pos = hunter.pos,
            rot = hunter.rot,
            radius = 2,
            color = hunterColor,
            textColor = hunterColor,
            textBg = bgColor,
            type = BJI_WaypointEdit.TYPES.ARROW,
        }
    end)):addAll(parent.data.minorPositions:map(function(hunted, i)
        return {
            name = parent.labels.hunter.tags.huntedName:var({ index = i }),
            pos = hunted.pos,
            rot = hunted.rot,
            radius = 2,
            color = huntedColor,
            textColor = huntedColor,
            textBg = bgColor,
            type = BJI_WaypointEdit.TYPES.ARROW,
        }
    end)))
end

---@param parent table
---@param ctxt TickContext
local function drawHuntersPoints(parent, ctxt)
    if BeginTable("BJIScenarioEditorHunterHuntersStarts", {
            { label = "##scenarioeditor-hunter-huntersstarts-labels" },
            { label = "##scenarioeditor-hunter-huntersstarts-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        parent.data.majorPositions:forEach(function(hunterPoint, i)
            TableNewRow()
            Text(parent.labels.hunter.tags.hunterName:var({ index = i }))
            TableNextColumn()
            if IconButton("goToHunter" .. tostring(i), BJI.Utils.Icon.ICONS.pin_drop) then
                if ctxt.isOwner then
                    if ctxt.camera == BJI_Cam.CAMERAS.FREE then
                        BJI_Cam.toggleFreeCam()
                    end
                    BJI_Veh.setPositionRotation(hunterPoint.pos, hunterPoint.rot, { safe = false })
                else
                    BJI_Cam.setCamera(BJI_Cam.CAMERAS.FREE)
                    BJI_Cam.setPositionRotation(hunterPoint.pos + vec3(0, 0, 1),
                        hunterPoint.rot * quat(0, 0, 1, 0))
                end
            end
            TooltipText(parent.labels.hunter.buttons.showHunterStartPosition)
            SameLine()
            if IconButton("moveHunter" .. tostring(i), BJI.Utils.Icon.ICONS.edit_location,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, disabled = parent.disableButtons or
                        not ctxt.veh or ctxt.camera == BJI_Cam.CAMERAS.FREE }) then
                parent.data.majorPositions[i] = math.roundPositionRotation({
                    pos = ctxt.veh.position,
                    rot = ctxt.veh.rotation,
                })
                parent.changed = true
                W.reloadMarkers(parent)
                parent.validateData()
            end
            TooltipText(parent.labels.hunter.buttons.setHunterStartPositionHere ..
                ((not ctxt.veh or ctxt.camera == BJI_Cam.CAMERAS.FREE) and
                    " (" .. parent.labels.errors.errorMustHaveVehicle .. ")" or ""))
            SameLine()
            if IconButton("deleteHunter" .. tostring(i), BJI.Utils.Icon.ICONS.delete_forever,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = parent.disableButtons }) then
                parent.data.majorPositions:remove(i)
                parent.changed = true
                W.reloadMarkers(parent)
                parent.updateEnabled()
                parent.validateData()
            end
            TooltipText(parent.labels.hunter.buttons.deleteHunterStartPosition)
        end)

        EndTable()
    end
end

---@param parent table
---@param ctxt TickContext
local function drawHuntedPoints(parent, ctxt)
    if BeginTable("BJIScenarioEditorHunterHuntedStarts", {
            { label = "##scenarioeditor-hunter-huntedstarts-labels" },
            { label = "##scenarioeditor-hunter-huntedstarts-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        parent.data.minorPositions:forEach(function(huntedPoint, i)
            TableNewRow()
            Text(parent.labels.hunter.tags.huntedName:var({ index = i }))
            TableNextColumn()
            if IconButton("goToHunted" .. tostring(i), BJI.Utils.Icon.ICONS.pin_drop) then
                if ctxt.isOwner then
                    if ctxt.camera == BJI_Cam.CAMERAS.FREE then
                        BJI_Cam.toggleFreeCam()
                    end
                    BJI_Veh.setPositionRotation(huntedPoint.pos, huntedPoint.rot, { safe = false })
                else
                    BJI_Cam.setCamera(BJI_Cam.CAMERAS.FREE)
                    BJI_Cam.setPositionRotation(huntedPoint.pos + vec3(0, 0, 1),
                        huntedPoint.rot * quat(0, 0, 1, 0))
                end
            end
            TooltipText(parent.labels.hunter.buttons.showHuntedStartPosition)
            SameLine()
            if IconButton("moveHunted" .. tostring(i), BJI.Utils.Icon.ICONS.edit_location,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, disabled = parent.disableButtons or
                        not ctxt.veh or ctxt.camera == BJI_Cam.CAMERAS.FREE }) then
                parent.data.minorPositions[i] = math.roundPositionRotation({
                    pos = ctxt.veh.position,
                    rot = ctxt.veh.rotation,
                })
                parent.changed = true
                W.reloadMarkers(parent)
                parent.validateData()
            end
            TooltipText(parent.labels.hunter.buttons.setHuntedStartPositionHere ..
                ((not ctxt.veh or ctxt.camera == BJI_Cam.CAMERAS.FREE) and
                    " (" .. parent.labels.errors.errorMustHaveVehicle .. ")" or ""))
            SameLine()
            if IconButton("deleteHunted" .. tostring(i), BJI.Utils.Icon.ICONS.delete_forever,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = parent.disableButtons }) then
                parent.data.minorPositions:remove(i)
                parent.changed = true
                W.reloadMarkers(parent)
                parent.updateEnabled()
                parent.validateData()
            end
            TooltipText(parent.labels.hunter.buttons.deleteHuntedStartPosition)
        end)
        EndTable()
    end
end

---@param parent table
---@param ctxt TickContext
local function drawWaypoints(parent, ctxt)
    if BeginTable("BJIScenarioEditorHunterWaypoints", {
            { label = "##scenarioeditor-hunter-waypoints-labels" },
            { label = "##scenarioeditor-hunter-waypoints-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        parent.data.waypoints:forEach(function(waypoint, i)
            TableNewRow()
            Text(parent.labels.hunter.tags.waypointName:var({ index = i }))
            TableNextColumn()
            if IconButton("gotoWaypoint" .. tostring(i), BJI.Utils.Icon.ICONS.pin_drop) then
                if ctxt.isOwner then
                    if ctxt.camera == BJI_Cam.CAMERAS.FREE then
                        BJI_Cam.toggleFreeCam()
                    end
                    BJI_Veh.setPositionRotation(waypoint.pos, ctxt.veh.rotation, { safe = false })
                else
                    BJI_Cam.setCamera(BJI_Cam.CAMERAS.FREE)
                    BJI_Cam.setPositionRotation(waypoint.pos + vec3(0, 0, 1))
                end
            end
            TooltipText(parent.labels.hunter.buttons.showWaypoint)
            SameLine()
            if IconButton("moveWaypoint" .. tostring(i), BJI.Utils.Icon.ICONS.edit_location,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, disabled = parent.disableButtons or
                        not ctxt.veh or ctxt.camera == BJI_Cam.CAMERAS.FREE }) then
                waypoint.pos = ctxt.veh.position
                parent.changed = true
                W.reloadMarkers(parent)
                parent.validateData()
            end
            TooltipText(parent.labels.hunter.buttons.setWaypointHere ..
                ((not ctxt.veh or ctxt.camera == BJI_Cam.CAMERAS.FREE) and
                    " (" .. parent.labels.errors.errorMustHaveVehicle .. ")" or ""))
            SameLine()
            if IconButton("deleteWaypoint" .. tostring(i), BJI.Utils.Icon.ICONS.delete_forever,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = parent.disableButtons }) then
                parent.data.waypoints:remove(i)
                parent.changed = true
                W.reloadMarkers(parent)
                parent.updateEnabled()
                parent.validateData()
            end
            TooltipText(parent.labels.hunter.buttons.deleteWaypoint)

            TableNewRow()
            Indent()
            Text(parent.labels.hunter.fields.radius)
            Unindent()
            TableNextColumn()
            nextValue = SliderFloatPrecision("radiusWaypoint" .. tostring(i), waypoint.radius, 1, 50,
                { step = .5, stepFast = 2, precision = 1, disabled = parent.disableButtons })
            if nextValue then
                waypoint.radius = nextValue
                parent.changed = true
                W.reloadMarkers(parent)
                parent.validateData()
            end
        end)
        EndTable()
    end
end

---@param parent table
---@param ctxt TickContext
W.body = function(parent, ctxt)
    Text(parent.labels.enabled)
    SameLine()
    if IconButton("toggleEnabled", parent.data.enabledHunter == true and BJI.Utils.Icon.ICONS.visibility or
            BJI.Utils.Icon.ICONS.visibility_off, { disabled = parent.disableButtons or
                not parent.data.canEnableHunter, btnStyle = parent.data.enabledHunter == true and
                BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR }) then
        local origin = parent.data.enabledHunter
        parent.data.enabledHunter = not parent.data.enabledHunter
        parent.updateEnabled()
        if origin ~= parent.data.enabledHunter then
            parent.changed = true
        end
    end
    TooltipText(parent.labels.buttons.toggleModeVisibility ..
        (parent.data.canEnableHunter and "" or (" (" .. parent.data.cannotEnableHunterTooltip .. ")")))

    opened = BeginTree(parent.labels.hunter.fields.hunters)
    SameLine()
    Text(string.format("(%d)", #parent.data.majorPositions))
    if opened then
        SameLine()
        if IconButton("addHunterPosition", BJI.Utils.Icon.ICONS.add_location,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = parent.disableButtons or
                    not ctxt.veh or ctxt.camera == BJI_Cam.CAMERAS.FREE }) then
            parent.data.majorPositions:insert(math.roundPositionRotation({
                pos = ctxt.veh.position,
                rot = ctxt.veh.rotation,
            }))
            parent.changed = true
            W.reloadMarkers(parent)
            parent.updateEnabled()
            parent.validateData()
        end
        TooltipText(parent.labels.hunter.buttons.addHunterStartPositionHere ..
            ((not ctxt.veh or ctxt.camera == BJI_Cam.CAMERAS.FREE) and
                " (" .. parent.labels.errors.errorMustHaveVehicle .. ")" or ""))
    end
    if #parent.data.majorPositions < 5 then
        SameLine()
        Text(parent.labels.errors.missingPoints:var({ amount = 5 - #parent.data.majorPositions }),
            { color = BJI.Utils.Style.TEXT_COLORS.ERROR })
    end
    if opened then
        drawHuntersPoints(parent, ctxt)
        EndTree()
    end

    opened = BeginTree(parent.labels.hunter.fields.hunted)
    SameLine()
    Text(string.format("(%d)", #parent.data.minorPositions))
    if opened then
        SameLine()
        if IconButton("addHuntedPosition", BJI.Utils.Icon.ICONS.add_location,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = parent.disableButtons or
                    not ctxt.veh or ctxt.camera == BJI_Cam.CAMERAS.FREE }) then
            parent.data.minorPositions:insert(math.roundPositionRotation({
                pos = ctxt.veh.position,
                rot = ctxt.veh.rotation,
            }))
            parent.changed = true
            parent.updateEnabled()
            W.reloadMarkers(parent)
            parent.validateData()
        end
        TooltipText(parent.labels.hunter.buttons.addHuntedStartPositionHere ..
            ((not ctxt.veh or ctxt.camera == BJI_Cam.CAMERAS.FREE) and
                " (" .. parent.labels.errors.errorMustHaveVehicle .. ")" or ""))
    end
    if #parent.data.minorPositions < 2 then
        SameLine()
        Text(parent.labels.errors.missingPoints:var({ amount = 2 - #parent.data.minorPositions }),
            { color = BJI.Utils.Style.TEXT_COLORS.ERROR })
    end
    if opened then
        drawHuntedPoints(parent, ctxt)
        EndTree()
    end

    opened = BeginTree(parent.labels.hunter.fields.waypoints)
    SameLine()
    Text(string.format("(%d)", #parent.data.waypoints))
    if opened then
        SameLine()
        if IconButton("addWaypoint", BJI.Utils.Icon.ICONS.add_location,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = parent.disableButtons or
                    not ctxt.veh or ctxt.camera == BJI_Cam.CAMERAS.FREE }) then
            parent.data.waypoints:insert({
                pos = ctxt.veh.position,
                radius = 2,
            })
            parent.changed = true
            parent.updateEnabled()
            W.reloadMarkers(parent)
            parent.validateData()
        end
        TooltipText(parent.labels.hunter.buttons.addWaypointHere ..
            ((not ctxt.veh or ctxt.camera == BJI_Cam.CAMERAS.FREE) and
                " (" .. parent.labels.errors.errorMustHaveVehicle .. ")" or ""))
    end
    if #parent.data.waypoints < 2 then
        SameLine()
        Text(parent.labels.errors.missingPoints:var({ amount = 2 - #parent.data.waypoints }),
            { color = BJI.Utils.Style.TEXT_COLORS.ERROR })
    end
    if opened then
        drawWaypoints(parent, ctxt)
        EndTree()
    end
end

return W
