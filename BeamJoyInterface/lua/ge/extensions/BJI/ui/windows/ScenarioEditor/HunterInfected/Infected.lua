local W = {}

--- gc prevention
local opened

local survivorColor = BJI.Utils.ShapeDrawer.Color(.33, 1, .33, .5)
local infectedColor = BJI.Utils.ShapeDrawer.Color(1, 0, 0, .5)
local bgColor = BJI.Utils.ShapeDrawer.Color(0, 0, 0, .5)
---@param parent table
W.reloadMarkers = function(parent)
    BJI_WaypointEdit.setWaypoints(parent.data.majorPositions:map(function(survivor, i)
        return {
            name = parent.labels.infected.tags.survivorName:var({ index = i }),
            pos = survivor.pos,
            rot = survivor.rot,
            radius = 2,
            color = survivorColor,
            textColor = survivorColor,
            textBg = bgColor,
            type = BJI_WaypointEdit.TYPES.ARROW,
        }
    end):addAll(parent.data.minorPositions:map(function(infected, i)
        return {
            name = parent.labels.infected.tags.infectedName:var({ index = i }),
            pos = infected.pos,
            rot = infected.rot,
            radius = 2,
            color = infectedColor,
            textColor = infectedColor,
            textBg = bgColor,
            type = BJI_WaypointEdit.TYPES.ARROW,
        }
    end)))
end

---@param parent table
---@param ctxt TickContext
local function drawSurvivorsPoints(parent, ctxt)
    if BeginTable("BJIScenarioEditorInfectedSurvivorsStarts", {
            { label = "##scenarioeditor-infected-survivorsstarts-labels" },
            { label = "##scenarioeditor-infected-survivorsstarts-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        parent.data.majorPositions:forEach(function(survivorPoint, i)
            TableNewRow()
            Text(parent.labels.infected.tags.survivorName:var({ index = i }))
            TableNextColumn()
            if IconButton("goToSurvivor" .. tostring(i), BJI.Utils.Icon.ICONS.pin_drop) then
                if ctxt.isOwner then
                    if ctxt.camera == BJI_Cam.CAMERAS.FREE then
                        BJI_Cam.toggleFreeCam()
                    end
                    BJI_Veh.setPositionRotation(survivorPoint.pos, survivorPoint.rot, { safe = false })
                else
                    BJI_Cam.setCamera(BJI_Cam.CAMERAS.FREE)
                    BJI_Cam.setPositionRotation(survivorPoint.pos + vec3(0, 0, 1),
                        survivorPoint.rot * quat(0, 0, 1, 0))
                end
            end
            TooltipText(parent.labels.infected.buttons.showSurvivorStartPosition)
            SameLine()
            if IconButton("moveSurvivor" .. tostring(i), BJI.Utils.Icon.ICONS.edit_location,
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
            TooltipText(parent.labels.infected.buttons.setSurvivorStartPositionHere ..
                ((not ctxt.veh or ctxt.camera == BJI_Cam.CAMERAS.FREE) and
                    " (" .. parent.labels.errors.errorMustHaveVehicle .. ")" or ""))
            SameLine()
            if IconButton("deleteSurvivor" .. tostring(i), BJI.Utils.Icon.ICONS.delete_forever,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = parent.disableButtons }) then
                parent.data.majorPositions:remove(i)
                parent.changed = true
                W.reloadMarkers(parent)
                parent.updateEnabled()
                parent.validateData()
            end
            TooltipText(parent.labels.infected.buttons.deleteSurvivorStartPosition)
        end)

        EndTable()
    end
end

---@param parent table
---@param ctxt TickContext
local function drawInfectedPoints(parent, ctxt)
    if BeginTable("BJIScenarioEditorInfectedStarts", {
            { label = "##scenarioeditor-infected-infectedstarts-labels" },
            { label = "##scenarioeditor-infected-infectedstarts-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        parent.data.minorPositions:forEach(function(infectedPoint, i)
            TableNewRow()
            Text(parent.labels.infected.tags.infectedName:var({ index = i }))
            TableNextColumn()
            if IconButton("goToInfected" .. tostring(i), BJI.Utils.Icon.ICONS.pin_drop) then
                if ctxt.isOwner then
                    if ctxt.camera == BJI_Cam.CAMERAS.FREE then
                        BJI_Cam.toggleFreeCam()
                    end
                    BJI_Veh.setPositionRotation(infectedPoint.pos, infectedPoint.rot, { safe = false })
                else
                    BJI_Cam.setCamera(BJI_Cam.CAMERAS.FREE)
                    BJI_Cam.setPositionRotation(infectedPoint.pos + vec3(0, 0, 1),
                        infectedPoint.rot * quat(0, 0, 1, 0))
                end
            end
            TooltipText(parent.labels.infected.buttons.showInfectedStartPosition)
            SameLine()
            if IconButton("moveInfected" .. tostring(i), BJI.Utils.Icon.ICONS.edit_location,
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
            TooltipText(parent.labels.infected.buttons.setInfectedStartPositionHere ..
                ((not ctxt.veh or ctxt.camera == BJI_Cam.CAMERAS.FREE) and
                    " (" .. parent.labels.errors.errorMustHaveVehicle .. ")" or ""))
            SameLine()
            if IconButton("deleteInfected" .. tostring(i), BJI.Utils.Icon.ICONS.delete_forever,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = parent.disableButtons }) then
                parent.data.minorPositions:remove(i)
                parent.changed = true
                W.reloadMarkers(parent)
                parent.updateEnabled()
                parent.validateData()
            end
            TooltipText(parent.labels.infected.buttons.deleteInfectedStartPosition)
        end)

        EndTable()
    end
end

---@param parent table
---@param ctxt TickContext
W.body = function(parent, ctxt)
    Text(parent.labels.enabled)
    SameLine()
    if IconButton("toggleEnabled", parent.data.enabledInfected == true and BJI.Utils.Icon.ICONS.visibility or
            BJI.Utils.Icon.ICONS.visibility_off, { disabled = parent.disableButtons or
                not parent.data.canEnableInfected, btnStyle = parent.data.enabledInfected == true and
                BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR }) then
        local origin = parent.data.enabledInfected
        parent.data.enabledInfected = not parent.data.enabledInfected
        parent.updateEnabled()
        if origin ~= parent.data.enabledInfected then
            parent.changed = true
        end
    end
    TooltipText(parent.labels.buttons.toggleModeVisibility ..
        (parent.data.canEnableInfected and "" or (" (" .. parent.data.cannotEnableInfectedTooltip .. ")")))

    opened = BeginTree(parent.labels.infected.fields.survivors)
    SameLine()
    Text(string.format("(%d)", #parent.data.majorPositions))
    if opened then
        SameLine()
        if IconButton("addSurvivorPosition", BJI.Utils.Icon.ICONS.add_location,
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
        TooltipText(parent.labels.infected.buttons.addSurvivorStartPositionHere ..
            ((not ctxt.veh or ctxt.camera == BJI_Cam.CAMERAS.FREE) and
                " (" .. parent.labels.errors.errorMustHaveVehicle .. ")" or ""))
    end
    if #parent.data.majorPositions < 5 then
        SameLine()
        Text(parent.labels.errors.missingPoints:var({ amount = 5 - #parent.data.majorPositions }),
            { color = BJI.Utils.Style.TEXT_COLORS.ERROR })
    end
    if opened then
        drawSurvivorsPoints(parent, ctxt)
        EndTree()
    end

    opened = BeginTree(parent.labels.infected.fields.infected)
    SameLine()
    Text(string.format("(%d)", #parent.data.minorPositions))
    if opened then
        SameLine()
        if IconButton("addInfectedPosition", BJI.Utils.Icon.ICONS.add_location,
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
        TooltipText(parent.labels.infected.buttons.addInfectedStartPositionHere ..
            ((not ctxt.veh or ctxt.camera == BJI_Cam.CAMERAS.FREE) and
                " (" .. parent.labels.errors.errorMustHaveVehicle .. ")" or ""))
    end
    if #parent.data.minorPositions < 2 then
        SameLine()
        Text(parent.labels.errors.missingPoints:var({ amount = 2 - #parent.data.minorPositions }),
            { color = BJI.Utils.Style.TEXT_COLORS.ERROR })
    end
    if opened then
        drawInfectedPoints(parent, ctxt)
        EndTree()
    end
end

return W