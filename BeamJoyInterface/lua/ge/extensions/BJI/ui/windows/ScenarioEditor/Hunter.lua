local W = {
    name = "ScenarioEditorHunter",

    labels = {
        title = "",
        enabled = "",
        hunterPositionName = "",
        huntedPositionName = "",
        targetName = "",
        radius = "",
        missingPoints = "",
        buttons = {
            refreshMarkers = "",
            toggleModeVisibility = "",
            showHunterStartPosition = "",
            setHunterStartPositionHere = "",
            deleteHunterStartPosition = "",
            addHunterStartPositionHere = "",
            showHuntedStartPosition = "",
            setHuntedStartPositionHere = "",
            deleteHuntedStartPosition = "",
            addHuntedStartPositionHere = "",
            addWaypointHere = "",
            showWaypoint = "",
            setWaypointHere = "",
            deleteWaypoint = "",
            close = "",
            save = "",
            errorMustHaveVehicle = "",
            errorInvalidData = "",
        },
    },
    cache = {
        enabled = false,
        targets = Table(),
        hunterPositions = Table(),
        huntedPositions = Table(),
        disableButtons = false,
    },
    changed = false,
    valid = false,
}
--- gc prevention
local opened, nextValue

local function onClose()
    BJI.Managers.WaypointEdit.reset()
    W.changed = false
    W.valid = true
end

local hunterColor = BJI.Utils.ShapeDrawer.Color(1, 1, 0, .5)
local huntedColor = BJI.Utils.ShapeDrawer.Color(1, 0, 0, .5)
local function reloadMarkers()
    BJI.Managers.WaypointEdit.setWaypoints(W.cache.targets:map(function(target, i)
        return {
            name = BJI.Managers.Lang.get("hunter.edit.targetName"):var({ index = i }),
            pos = target.pos,
            radius = target.radius,
            type = BJI.Managers.WaypointEdit.TYPES.CYLINDER,
        }
    end):addAll(W.cache.hunterPositions:map(function(hunter, i)
        return {
            name = BJI.Managers.Lang.get("hunter.edit.hunterPositionName"):var({ index = i }),
            pos = hunter.pos,
            rot = hunter.rot,
            radius = 2,
            color = hunterColor,
            textColor = hunterColor,
            textBg = BJI.Utils.ShapeDrawer.Color(0, 0, 0, .5),
            type = BJI.Managers.WaypointEdit.TYPES.ARROW,
        }
    end)):addAll(W.cache.huntedPositions:map(function(hunted, i)
        return {
            name = BJI.Managers.Lang.get("hunter.edit.huntedPositionName"):var({ index = i }),
            pos = hunted.pos,
            rot = hunted.rot,
            radius = 2,
            color = huntedColor,
            textColor = huntedColor,
            textBg = BJI.Utils.ShapeDrawer.Color(0, 0, 0, .5),
            type = BJI.Managers.WaypointEdit.TYPES.ARROW,
        }
    end)))
end

local function updateLabels()
    W.labels.title = BJI.Managers.Lang.get("hunter.edit.title")
    W.labels.enabled = BJI.Managers.Lang.get("hunter.edit.enabled")
    W.labels.hunterPositionName = BJI.Managers.Lang.get("hunter.edit.hunterPositionName")
    W.labels.huntedPositionName = BJI.Managers.Lang.get("hunter.edit.huntedPositionName")
    W.labels.targetName = BJI.Managers.Lang.get("hunter.edit.targetName")
    W.labels.radius = BJI.Managers.Lang.get("hunter.edit.radius")
    W.labels.missingPoints = BJI.Managers.Lang.get("hunter.edit.missingPoints")

    W.labels.buttons.refreshMarkers = BJI.Managers.Lang.get("hunter.edit.buttons.refreshMarkers")
    W.labels.buttons.toggleModeVisibility = BJI.Managers.Lang.get("hunter.edit.buttons.toggleModeVisibility")
    W.labels.buttons.showHunterStartPosition = BJI.Managers.Lang.get("hunter.edit.buttons.showHunterStartPosition")
    W.labels.buttons.setHunterStartPositionHere = BJI.Managers.Lang.get("hunter.edit.buttons.setHunterStartPositionHere")
    W.labels.buttons.deleteHunterStartPosition = BJI.Managers.Lang.get("hunter.edit.buttons.deleteHunterStartPosition")
    W.labels.buttons.addHunterStartPositionHere = BJI.Managers.Lang.get("hunter.edit.buttons.addHunterStartPositionHere")
    W.labels.buttons.showHuntedStartPosition = BJI.Managers.Lang.get("hunter.edit.buttons.showHuntedStartPosition")
    W.labels.buttons.setHuntedStartPositionHere = BJI.Managers.Lang.get("hunter.edit.buttons.setHuntedStartPositionHere")
    W.labels.buttons.deleteHuntedStartPosition = BJI.Managers.Lang.get("hunter.edit.buttons.deleteHuntedStartPosition")
    W.labels.buttons.addHuntedStartPositionHere = BJI.Managers.Lang.get("hunter.edit.buttons.addHuntedStartPositionHere")
    W.labels.buttons.addWaypointHere = BJI.Managers.Lang.get("hunter.edit.buttons.addWaypointHere")
    W.labels.buttons.showWaypoint = BJI.Managers.Lang.get("hunter.edit.buttons.showWaypoint")
    W.labels.buttons.setWaypointHere = BJI.Managers.Lang.get("hunter.edit.buttons.setWaypointHere")
    W.labels.buttons.deleteWaypoint = BJI.Managers.Lang.get("hunter.edit.buttons.deleteWaypoint")
    W.labels.buttons.close = BJI.Managers.Lang.get("common.buttons.close")
    W.labels.buttons.save = BJI.Managers.Lang.get("common.buttons.save")
    W.labels.buttons.errorMustHaveVehicle = BJI.Managers.Lang.get("errors.mustHaveVehicle")
    W.labels.buttons.errorInvalidData = BJI.Managers.Lang.get("errors.someDataAreInvalid")
end

local function validateData()
    W.valid = not W.cache.enabled or (
        #W.cache.targets >= 2 and
        #W.cache.hunterPositions >= 5 and
        #W.cache.huntedPositions > 0
    )
end

local function updateCache()
    local hunterData = BJI.Managers.Context.Scenario.Data.Hunter
    W.cache.enabled = hunterData.enabled
    W.cache.targets = Table(hunterData.targets):map(function(target)
        return math.tryParsePosRot({
            pos = target.pos,
            radius = target.radius,
        })
    end)
    W.cache.hunterPositions = Table(hunterData.hunterPositions):map(function(hunter)
        return math.tryParsePosRot(hunter)
    end)
    W.cache.huntedPositions = Table(hunterData.huntedPositions):map(function(hunted)
        return math.tryParsePosRot(hunted)
    end)
    validateData()
    reloadMarkers()
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.LANG_CHANGED, updateLabels, W.name))

    updateCache()
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.CACHE_LOADED,
        function(_, data)
            if data.cache == BJI.Managers.Cache.CACHES.HUNTER_DATA then
                updateCache()
            end
        end, W.name))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

local function save()
    W.cache.disableButtons = true
    BJI.Tx.scenario.HunterSave({
        enabled = W.cache.enabled,
        targets = W.cache.targets:map(function(target)
            return {
                pos = target.pos,
                radius = target.radius,
            }
        end),
        hunterPositions = W.cache.hunterPositions:map(function(hunter)
            return math.roundPositionRotation(hunter)
        end),
        huntedPositions = W.cache.huntedPositions:map(function(hunted)
            return math.roundPositionRotation(hunted)
        end),
    }, function(result)
        if result then
            W.changed = false
        else
            BJI.Managers.Toast.error(BJI.Managers.Lang.get("hunter.edit.saveErrorToast"))
        end
        W.cache.disableButtons = false
    end)
end

local function checkEnabled()
    if W.cache.enabled then
        if #W.cache.targets < 2 or
            #W.cache.hunterPositions < 5 or
            #W.cache.huntedPositions < 2 then
            W.cache.enabled = false
        end
    end
end

---@param ctxt TickContext
local function header(ctxt)
    Text(W.labels.title)
    SameLine()
    if IconButton("reloadMarkers", BJI.Utils.Icon.ICONS.sync) then
        reloadMarkers()
    end
    TooltipText(W.labels.buttons.refreshMarkers)

    Text(W.labels.enabled)
    SameLine()
    if IconButton("toggleEnabled", W.cache.enabled == true and BJI.Utils.Icon.ICONS.visibility or
            BJI.Utils.Icon.ICONS.visibility_off, { disabled = W.cache.disableButtons,
                btnStyle = W.cache.enabled == true and BJI.Utils.Style.BTN_PRESETS.SUCCESS or
                    BJI.Utils.Style.BTN_PRESETS.ERROR }) then
        local origin = W.cache.enabled
        W.cache.enabled = not W.cache.enabled
        checkEnabled()
        if origin ~= W.cache.enabled then
            W.changed = true
        end
    end
    TooltipText(W.labels.buttons.toggleModeVisibility)
end

---@param ctxt TickContext
local function drawHunters(ctxt)
    if BeginTable("BJIScenarioEditorHunterHuntersStarts", {
            { label = "##scenarioeditor-hunter-huntersstarts-labels" },
            { label = "##scenarioeditor-hunter-huntersstarts-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        W.cache.hunterPositions:forEach(function(hunterPoint, i)
            TableNewRow()
            Text(W.labels.hunterPositionName:var({ index = i }))
            TableNextColumn()
            if IconButton("goToHunter" .. tostring(i), BJI.Utils.Icon.ICONS.pin_drop) then
                if ctxt.isOwner then
                    if ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE then
                        BJI.Managers.Cam.toggleFreeCam()
                    end
                    BJI.Managers.Veh.setPositionRotation(hunterPoint.pos, hunterPoint.rot, { safe = false })
                else
                    BJI.Managers.Cam.setCamera(BJI.Managers.Cam.CAMERAS.FREE)
                    BJI.Managers.Cam.setPositionRotation(hunterPoint.pos + vec3(0, 0, 1),
                        hunterPoint.rot * quat(0, 0, 1, 0))
                end
            end
            TooltipText(W.labels.buttons.showHunterStartPosition)
            SameLine()
            if IconButton("moveHunter" .. tostring(i), BJI.Utils.Icon.ICONS.edit_location,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, disabled = W.cache.disableButtons or
                        not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE }) then
                W.cache.hunterPositions[i] = math.roundPositionRotation({
                    pos = ctxt.veh.position,
                    rot = ctxt.veh.rotation,
                })
                W.changed = true
                reloadMarkers()
                validateData()
            end
            TooltipText(W.labels.buttons.setHunterStartPositionHere ..
                ((not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE) and
                    " (" .. W.labels.buttons.errorMustHaveVehicle .. ")" or ""))
            SameLine()
            if IconButton("deleteHunter" .. tostring(i), BJI.Utils.Icon.ICONS.delete_forever,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = W.cache.disableButtons }) then
                W.cache.hunterPositions:remove(i)
                W.changed = true
                reloadMarkers()
                validateData()
            end
            TooltipText(W.labels.buttons.deleteHunterStartPosition)
        end)

        EndTable()
    end
end

---@param ctxt TickContext
local function drawHunted(ctxt)
    if BeginTable("BJIScenarioEditorHunterHuntedStarts", {
            { label = "##scenarioeditor-hunter-huntedstarts-labels" },
            { label = "##scenarioeditor-hunter-huntedstarts-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        W.cache.huntedPositions:forEach(function(huntedPoint, i)
            TableNewRow()
            Text(W.labels.huntedPositionName:var({ index = i }))
            TableNextColumn()
            if IconButton("goToHunted" .. tostring(i), BJI.Utils.Icon.ICONS.pin_drop) then
                if ctxt.isOwner then
                    if ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE then
                        BJI.Managers.Cam.toggleFreeCam()
                    end
                    BJI.Managers.Veh.setPositionRotation(huntedPoint.pos, huntedPoint.rot, { safe = false })
                else
                    BJI.Managers.Cam.setCamera(BJI.Managers.Cam.CAMERAS.FREE)
                    BJI.Managers.Cam.setPositionRotation(huntedPoint.pos + vec3(0, 0, 1),
                        huntedPoint.rot * quat(0, 0, 1, 0))
                end
            end
            TooltipText(W.labels.buttons.showHuntedStartPosition)
            SameLine()
            if IconButton("moveHunted" .. tostring(i), BJI.Utils.Icon.ICONS.edit_location,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, disabled = W.cache.disableButtons or
                        not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE }) then
                W.cache.huntedPositions[i] = math.roundPositionRotation({
                    pos = ctxt.veh.position,
                    rot = ctxt.veh.rotation,
                })
                W.changed = true
                reloadMarkers()
                validateData()
            end
            TooltipText(W.labels.buttons.setHuntedStartPositionHere ..
                ((not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE) and
                    " (" .. W.labels.buttons.errorMustHaveVehicle .. ")" or ""))
            SameLine()
            if IconButton("deleteHunted" .. tostring(i), BJI.Utils.Icon.ICONS.delete_forever,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = W.cache.disableButtons }) then
                W.cache.huntedPositions:remove(i)
                W.changed = true
                reloadMarkers()
                validateData()
            end
            TooltipText(W.labels.buttons.deleteHuntedStartPosition)
        end)
        EndTable()
    end
end

---@param ctxt TickContext
local function drawWaypoints(ctxt)
    if BeginTable("BJIScenarioEditorHunterWaypoints", {
            { label = "##scenarioeditor-hunter-waypoints-labels" },
            { label = "##scenarioeditor-hunter-waypoints-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        W.cache.targets:forEach(function(waypoint, i)
            TableNewRow()
            Text(W.labels.targetName:var({ index = i }))
            TableNextColumn()
            if IconButton("gotoWaypoint" .. tostring(i), BJI.Utils.Icon.ICONS.pin_drop) then
                if ctxt.isOwner then
                    if ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE then
                        BJI.Managers.Cam.toggleFreeCam()
                    end
                    BJI.Managers.Veh.setPositionRotation(waypoint.pos, ctxt.veh.rotation, { safe = false })
                else
                    BJI.Managers.Cam.setCamera(BJI.Managers.Cam.CAMERAS.FREE)
                    BJI.Managers.Cam.setPositionRotation(waypoint.pos + vec3(0, 0, 1))
                end
            end
            TooltipText(W.labels.buttons.showWaypoint)
            SameLine()
            if IconButton("moveWaypoint" .. tostring(i), BJI.Utils.Icon.ICONS.edit_location,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, disabled = W.cache.disableInputs or
                        not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE }) then
                waypoint.pos = ctxt.veh.position
                W.changed = true
                reloadMarkers()
                validateData()
            end
            TooltipText(W.labels.buttons.setWaypointHere ..
                ((not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE) and
                    " (" .. W.labels.buttons.errorMustHaveVehicle .. ")" or ""))
            SameLine()
            if IconButton("deleteWaypoint" .. tostring(i), BJI.Utils.Icon.ICONS.delete_forever,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = W.cache.disableInputs }) then
                W.cache.targets:remove(i)
                W.changed = true
                reloadMarkers()
                validateData()
            end
            TooltipText(W.labels.buttons.deleteWaypoint)

            TableNewRow()
            Indent()
            Text(W.labels.radius)
            Unindent()
            TableNextColumn()
            nextValue = SliderFloatPrecision("radiusWaypoint" .. tostring(i), waypoint.radius, 1, 50,
                { step = .5, stepFast = 2, precision = 1, disabled = W.cache.disableInputs })
            if nextValue then
                waypoint.radius = nextValue
                W.changed = true
                reloadMarkers()
                validateData()
            end
        end)
        EndTable()
    end
end

---@param ctxt TickContext
local function body(ctxt)
    opened = BeginTree(BJI.Managers.Lang.get("hunter.edit.hunters"))
    SameLine()
    Text(string.format("(%d)", #W.cache.hunterPositions))
    if opened then
        SameLine()
        if IconButton("addHunterPosition", BJI.Utils.Icon.ICONS.add_location,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = W.cache.disableInputs or
                    not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE }) then
            W.cache.hunterPositions:insert(math.roundPositionRotation({
                pos = ctxt.veh.position,
                rot = ctxt.veh.rotation,
            }))
            W.changed = true
            reloadMarkers()
            validateData()
        end
        TooltipText(W.labels.buttons.addHunterStartPositionHere ..
            ((not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE) and
                " (" .. W.labels.buttons.errorMustHaveVehicle .. ")" or ""))
    end
    if #W.cache.hunterPositions < 5 then
        SameLine()
        Text(W.labels.missingPoints:var({ amount = 5 - #W.cache.hunterPositions }),
            { color = BJI.Utils.Style.TEXT_COLORS.ERROR })
    end
    if opened then
        drawHunters(ctxt)
        EndTree()
    end

    opened = BeginTree(BJI.Managers.Lang.get("hunter.edit.hunted"))
    SameLine()
    Text(string.format("(%d)", #W.cache.huntedPositions))
    if opened then
        SameLine()
        if IconButton("addHuntedPosition", BJI.Utils.Icon.ICONS.add_location,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = W.cache.disableInputs or
                    not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE }) then
            W.cache.huntedPositions:insert(math.roundPositionRotation({
                pos = ctxt.veh.position,
                rot = ctxt.veh.rotation,
            }))
            W.changed = true
            reloadMarkers()
            validateData()
        end
        TooltipText(W.labels.buttons.addHuntedStartPositionHere ..
            ((not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE) and
                " (" .. W.labels.buttons.errorMustHaveVehicle .. ")" or ""))
    end
    if #W.cache.huntedPositions < 2 then
        SameLine()
        Text(W.labels.missingPoints:var({ amount = 2 - #W.cache.huntedPositions }),
            { color = BJI.Utils.Style.TEXT_COLORS.ERROR })
    end
    if opened then
        drawHunted(ctxt)
        EndTree()
    end

    opened = BeginTree(BJI.Managers.Lang.get("hunter.edit.waypoints"))
    SameLine()
    Text(string.format("(%d)", #W.cache.targets))
    if opened then
        SameLine()
        if IconButton("addWaypoint", BJI.Utils.Icon.ICONS.add_location,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = W.cache.disableInputs or
                    not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE }) then
            W.cache.targets:insert({
                pos = ctxt.veh.position,
                radius = 2,
            })
            W.changed = true
            reloadMarkers()
            validateData()
        end
        TooltipText(W.labels.buttons.addWaypointHere ..
            ((not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE) and
                " (" .. W.labels.buttons.errorMustHaveVehicle .. ")" or ""))
    end
    if #W.cache.targets < 2 then
        SameLine()
        Text(W.labels.missingPoints:var({ amount = 2 - #W.cache.targets }),
            { color = BJI.Utils.Style.TEXT_COLORS.ERROR })
    end
    if opened then
        drawWaypoints(ctxt)
        EndTree()
    end
end

---@param ctxt TickContext
local function footer(ctxt)
    if IconButton("closeHunterEdit", BJI.Utils.Icon.ICONS.exit_to_app,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
        BJI.Windows.ScenarioEditor.onClose()
    end
    TooltipText(W.labels.buttons.close)
    if W.changed then
        SameLine()
        if IconButton("saveHunterEdit", BJI.Utils.Icon.ICONS.save,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                    disabled = W.cache.disableButtons or not W.valid }) then
            save()
        end
        TooltipText(W.labels.buttons.save ..
            (not W.valid and " (" .. W.labels.buttons.errorMustHaveVehicle .. ")" or ""))
    end
end

local function open()
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
