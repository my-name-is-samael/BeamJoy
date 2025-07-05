local W = {
    name = "ScenarioEditorDerby",

    labels = {
        title = "",
        arena = "",
        name = "",
        enabled = "",
        enabledTooltip = "",
        previewPosition = "",
        previewPositionTooltip = "",
        centerPosition = "",
        radius = "",
        startPositions = "",
        amountStartPositionsNeeded = "",
        startPositionName = "",

        buttons = {
            addArena = "",
            showArena = "",
            deleteArena = "",
            toggleArenaVisibility = "",
            setPreviewPositionHere = "",
            showPreviewPosition = "",
            setCenterPositionHere = "",
            showCenterPosition = "",
            addStartPositionHere = "",
            showStartPosition = "",
            setStartPositionHere = "",
            deleteStartPosition = "",
            close = "",
            save = "",
            errorMustHaveVehicle = "",
            errorMustBeFreecaming = "",
            errorInvalidData = "",
        },
    },
    cache = {
        ---@type tablelib<integer, BJArena>
        arenas = Table(),
        disableButtons = false,
    },
    minStartPositions = 6,
    ---@type integer?
    markersArena = nil,
    changed = false,
    valid = true,
}
--- gc prevention
local opened, nextValue

local function onClose()
    BJI.Managers.WaypointEdit.reset()
    W.markersArena = nil
    W.changed = false
    W.valid = true
end

local function reloadMarkers(indexArena)
    indexArena = indexArena or W.markersArena

    if not W.cache.arenas[indexArena] then
        -- not drawn case
        W.markersArena = nil
        BJI.Managers.WaypointEdit.reset()
        return
    end

    local waypoints = W.cache.arenas[indexArena].startPositions:map(function(sp, i)
        return {
            name = BJI.Managers.Lang.get("derby.edit.startPositionName"):var({ index = i }),
            pos = sp.pos,
            rot = sp.rot,
            radius = 2,
            color = BJI.Utils.ShapeDrawer.Color(1, 1, 0, .5),
            type = BJI.Managers.WaypointEdit.TYPES.ARROW,
        }
    end)
    if W.cache.arenas[indexArena].centerPosition then
        local name = W.cache.arenas[indexArena].name
        if not name or #name:trim() == 0 then
            name = BJI.Managers.Lang.get("derby.edit.centerPosition")
        end
        waypoints:insert({
            name = name,
            pos = W.cache.arenas[indexArena].centerPosition,
            top = 200,
            bottom = -W.cache.arenas[indexArena].radius / 2,
            radius = W.cache.arenas[indexArena].radius,
            color = BJI.Utils.ShapeDrawer.Color(.33, .33, 1, .15),
            type = BJI.Managers.WaypointEdit.TYPES.CYLINDER,
        })
    end

    BJI.Managers.WaypointEdit.setWaypoints(waypoints)
    W.markersArena = indexArena
end

local function updateLabels()
    W.labels.title = BJI.Managers.Lang.get("derby.edit.title")
    W.labels.arena = BJI.Managers.Lang.get("derby.edit.arena")
    W.labels.name = BJI.Managers.Lang.get("derby.edit.name")
    W.labels.enabled = BJI.Managers.Lang.get("derby.edit.enabled")
    W.labels.enabledTooltip = BJI.Managers.Lang.get("derby.edit.enabledTooltip")
    W.labels.previewPosition = BJI.Managers.Lang.get("derby.edit.previewPosition")
    W.labels.previewPositionTooltip = BJI.Managers.Lang.get("derby.edit.previewPositionTooltip")
    W.labels.centerPosition = BJI.Managers.Lang.get("derby.edit.centerPosition")
    W.labels.radius = BJI.Managers.Lang.get("derby.edit.radius")
    W.labels.startPositions = BJI.Managers.Lang.get("derby.edit.startPositions")
    W.labels.amountStartPositionsNeeded = BJI.Managers.Lang.get("derby.edit.amountStartPositionsNeeded")
    W.labels.startPositionName = BJI.Managers.Lang.get("derby.edit.startPositionName")

    W.labels.buttons.addArena = BJI.Managers.Lang.get("derby.edit.buttons.addArena")
    W.labels.buttons.showArena = BJI.Managers.Lang.get("derby.edit.buttons.showArena")
    W.labels.buttons.deleteArena = BJI.Managers.Lang.get("derby.edit.buttons.deleteArena")
    W.labels.buttons.toggleArenaVisibility = BJI.Managers.Lang.get("derby.edit.buttons.toggleArenaVisibility")
    W.labels.buttons.setPreviewPositionHere = BJI.Managers.Lang.get("derby.edit.buttons.setPreviewPositionHere")
    W.labels.buttons.showPreviewPosition = BJI.Managers.Lang.get("derby.edit.buttons.showPreviewPosition")
    W.labels.buttons.setCenterPositionHere = BJI.Managers.Lang.get("derby.edit.buttons.setCenterPositionHere")
    W.labels.buttons.showCenterPosition = BJI.Managers.Lang.get("derby.edit.buttons.showCenterPosition")
    W.labels.buttons.addStartPositionHere = BJI.Managers.Lang.get("derby.edit.buttons.addStartPositionHere")
    W.labels.buttons.showStartPosition = BJI.Managers.Lang.get("derby.edit.buttons.showStartPosition")
    W.labels.buttons.setStartPositionHere = BJI.Managers.Lang.get("derby.edit.buttons.setStartPositionHere")
    W.labels.buttons.deleteStartPosition = BJI.Managers.Lang.get("derby.edit.buttons.deleteStartPosition")
    W.labels.buttons.close = BJI.Managers.Lang.get("common.buttons.close")
    W.labels.buttons.save = BJI.Managers.Lang.get("common.buttons.save")
    W.labels.buttons.errorMustHaveVehicle = BJI.Managers.Lang.get("errors.mustHaveVehicle")
    W.labels.buttons.errorMustBeFreecaming = BJI.Managers.Lang.get("errors.mustBeFreecaming")
    W.labels.buttons.errorInvalidData = BJI.Managers.Lang.get("errors.someDataAreInvalid")
end

local function validateArenas()
    ---@param a BJArena
    W.valid = #W.cache.arenas == 0 or not W.cache.arenas:any(function(a)
        return #a.name:trim() == 0 or
            not a.previewPosition or
            #a.startPositions < W.minStartPositions or not a.centerPosition
    end)
end

local function updateCache()
    W.cache.arenas = Table(BJI.Managers.Context.Scenario.Data.Derby)
        :map(function(a)
            return {
                name = a.name,
                enabled = a.enabled,
                previewPosition = math.tryParsePosRot(a.previewPosition),
                startPositions = Table(a.startPositions):map(function(sp)
                    return math.tryParsePosRot(sp)
                end),
                centerPosition = vec3(a.centerPosition),
                radius = tonumber(a.radius) or 0
            }
        end)
    validateArenas()
    reloadMarkers()
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.LANG_CHANGED, updateLabels, W.name))

    updateCache()
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.CACHE_LOADED,
        function(_, data)
            if data.cache == BJI.Managers.Cache.CACHES.DERBY_DATA then
                updateCache()
            end
        end, W.name))

    if #W.cache.arenas == 1 then
        -- auto-display the only arena available
        reloadMarkers(1)
    end
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

local function save()
    W.cache.disableButtons = true
    ---@param a BJArena
    BJI.Tx.scenario.DerbySave(W.cache.arenas:map(function(a)
        return {
            name = a.name,
            enabled = a.enabled == true,
            previewPosition = math.roundPositionRotation(a.previewPosition),
            startPositions = a.startPositions:map(function(sp)
                return math.roundPositionRotation(sp)
            end),
            centerPosition = math.roundPositionRotation({ pos = a.centerPosition }).pos,
            radius = math.round(a.radius),
        }
    end), function(result)
        if result then
            W.changed = false
        else
            BJI.Managers.Toast.error(BJI.Managers.Lang.get("derby.edit.saveErrorToast"))
        end
        W.cache.disableButtons = false
    end)
end

---@param ctxt TickContext
local function header(ctxt)
    Text(W.labels.title)
    SameLine()
    if IconButton("addArena", BJI.Utils.Icon.ICONS.add,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
        W.cache.arenas:insert({
            name = "",
            enabled = false,
            previewPosition = nil,
            startPositions = Table(),
            radius = 10,
        })
        W.changed = true
        validateArenas()
    end
    TooltipText(W.labels.buttons.addArena)
end

---@param ctxt TickContext
---@param iArena integer
---@param arena BJArena
local function drawArena(ctxt, iArena, arena)
    if BeginTable("BJIScenarioEditorDerbyArena" .. tostring(iArena), {
            { label = "##scenarioeditor-derby-arenas-" .. tostring(iArena) .. "-labels" },
            { label = "##scenarioeditor-derby-arenas-" .. tostring(iArena) .. "-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        TableNewRow()
        Text(W.labels.name)
        TableNextColumn()
        nextValue = InputText("arenaName" .. tostring(iArena), arena.name,
            {
                disabled = W.cache.disableInputs,
                inputStyle = #arena.name:trim() == 0 and BJI.Utils.Style.INPUT_PRESETS.ERROR or
                    nil
            })
        if nextValue then
            arena.name = nextValue
            W.changed = true
            reloadMarkers(iArena)
            validateArenas()
        end

        TableNewRow()
        Text(W.labels.enabled)
        TooltipText(W.labels.enabledTooltip)
        TableNextColumn()
        if IconButton("toggleArenaEnabled" .. tostring(iArena), arena.enabled and BJI.Utils.Icon.ICONS.visibility or
                BJI.Utils.Icon.ICONS.visibility_off, { btnStyle = arena.enabled and BJI.Utils.Style.BTN_PRESETS.SUCCESS or
                    BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = W.cache.disableButtons }) then
            arena.enabled = not arena.enabled
            W.changed = true
            validateArenas()
        end
        TooltipText(W.labels.buttons.toggleArenaVisibility)

        TableNewRow()
        Text(W.labels.previewPosition, {
            color = not arena.previewPosition and
                BJI.Utils.Style.TEXT_COLORS.ERROR or nil
        })
        TooltipText(W.labels.previewPositionTooltip)
        TableNextColumn()
        if IconButton("setArenaPreviewPos" .. tostring(iArena), arena.previewPosition and
                BJI.Utils.Icon.ICONS.edit_location or BJI.Utils.Icon.ICONS.add_location,
                { btnStyle = arena.previewPosition and BJI.Utils.Style.BTN_PRESETS.WARNING or
                    BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = W.cache.disableButtons or
                    ctxt.camera ~= BJI.Managers.Cam.CAMERAS.FREE }) then
            arena.previewPosition = BJI.Managers.Cam.getPositionRotation(true)
            W.changed = true
            validateArenas()
        end
        TooltipText(W.labels.buttons.setPreviewPositionHere ..
            ((ctxt.camera ~= BJI.Managers.Cam.CAMERAS.FREE) and
                (" (" .. W.labels.buttons.errorMustBeFreecaming .. ")") or ""))
        if arena.previewPosition then
            SameLine()
            if IconButton("goToArenaPreviewPosition" .. tostring(iArena), BJI.Utils.Icon.ICONS.pin_drop) then
                reloadMarkers(iArena)
                BJI.Managers.Cam.setCamera(BJI.Managers.Cam.CAMERAS.FREE)
                BJI.Managers.Cam.setPositionRotation(arena.previewPosition.pos, arena.previewPosition.rot)
            end
            TooltipText(W.labels.buttons.showPreviewPosition)
        end

        TableNewRow()
        Text(W.labels.centerPosition, {
            color = not arena.centerPosition and BJI.Utils.Style.TEXT_COLORS.ERROR or nil
        })
        TableNextColumn()
        if IconButton("setArenaCenterPos" .. tostring(iArena), arena.centerPosition and
                BJI.Utils.Icon.ICONS.edit_location or BJI.Utils.Icon.ICONS.add_location,
                { btnStyle = arena.centerPosition and BJI.Utils.Style.BTN_PRESETS.WARNING or
                    BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = W.cache.disableButtons or
                    ctxt.camera ~= BJI.Managers.Cam.CAMERAS.FREE }) then
            arena.centerPosition = BJI.Managers.Cam.getPositionRotation().pos
            W.changed = true
            validateArenas()
            reloadMarkers(iArena)
        end
        TooltipText(W.labels.buttons.setCenterPositionHere ..
            ((ctxt.camera ~= BJI.Managers.Cam.CAMERAS.FREE) and
                (" (" .. W.labels.buttons.errorMustBeFreecaming .. ")") or ""))
        if arena.centerPosition then
            SameLine()
            if IconButton("goToArenaCenterPosition" .. tostring(iArena), BJI.Utils.Icon.ICONS.pin_drop) then
                reloadMarkers(iArena)
                if ctxt.camera ~= BJI.Managers.Cam.CAMERAS.FREE then
                    BJI.Managers.Cam.toggleFreeCam()
                end
                BJI.Managers.Cam.setPositionRotation(arena.centerPosition)
            end
            TooltipText(W.labels.buttons.showCenterPosition)
        end

        TableNewRow()
        Text(W.labels.radius)
        TableNextColumn()
        nextValue = SliderIntPrecision("arenaRadius" .. tostring(iArena), arena.radius, 10, 100,
            { disabled = W.cache.disableInputs, formatRender = "%dm" })
        if nextValue then
            arena.radius = nextValue
            W.changed = true
            validateArenas()
            reloadMarkers(iArena)
        end

        TableNewRow()
        Text(W.labels.startPositions)
        TableNextColumn()
        if IconButton("addStartPosition" .. tostring(iArena), BJI.Utils.Icon.ICONS.add_location,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = W.cache.disableInputs or
                    not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE }) then
            arena.startPositions:insert(math.roundPositionRotation({
                pos = ctxt.veh.position,
                rot = ctxt.veh.rotation,
            }))
            W.changed = true
            reloadMarkers(iArena)
            validateArenas()
        end
        TooltipText(W.labels.buttons.addStartPositionHere ..
            ((not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE) and
                (" (" .. W.labels.buttons.errorMustHaveVehicle .. ")") or ""))
        if #arena.startPositions < W.minStartPositions then
            SameLine()
            Text(W.labels.amountStartPositionsNeeded:var({ amount = W.minStartPositions - #arena.startPositions }),
                { color = BJI.Utils.Style.TEXT_COLORS.ERROR })
        end

        arena.startPositions:forEach(function(sp, i)
            TableNewRow()
            Indent()
            Text(W.labels.startPositionName:var({ index = i }))
            Unindent()
            TableNextColumn()
            if IconButton("goToArenaStartPos" .. tostring(iArena) .. tostring(i), BJI.Utils.Icon.ICONS.pin_drop) then
                if ctxt.isOwner then
                    BJI.Managers.Veh.setPositionRotation(arena.startPositions[i].pos, arena.startPositions[i].rot,
                        { safe = false })
                    if ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE then
                        BJI.Managers.Cam.toggleFreeCam()
                    end
                else
                    BJI.Managers.Cam.setCamera(BJI.Managers.Cam.CAMERAS.FREE)
                    BJI.Managers.Cam.setPositionRotation(sp.pos + vec3(0, 0, 1), sp.rot * quat(0, 0, 1, 0))
                end
            end
            TooltipText(W.labels.buttons.showStartPosition)
            SameLine()
            if IconButton("setArenaStartPos" .. tostring(iArena) .. tostring(i), BJI.Utils.Icon.ICONS.edit_location,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, disabled = W.cache.disableInputs or
                        not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE }) then
                arena.startPositions[i] = math.roundPositionRotation({
                    pos = ctxt.veh.position,
                    rot = ctxt.veh.rotation,
                })
                W.changed = true
                reloadMarkers(iArena)
                validateArenas()
            end
            TooltipText(W.labels.buttons.setStartPositionHere ..
                ((not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE) and
                    (" (" .. W.labels.buttons.errorMustHaveVehicle .. ")") or ""))
            SameLine()
            if IconButton("deleteArenaStartPos" .. tostring(iArena) .. tostring(i), BJI.Utils.Icon.ICONS.delete_forever,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = W.cache.disableInputs }) then
                arena.startPositions:remove(i)
                W.changed = true
                reloadMarkers(iArena)
                validateArenas()
            end
            TooltipText(W.labels.buttons.deleteStartPosition)
        end)
        EndTable()
    end

    if iArena < #W.cache.arenas then
        Separator()
    end
end

---@param ctxt TickContext
local function body(ctxt)
    W.cache.arenas:forEach(function(arena, i)
        opened = BeginTree(W.labels.arena:var({ index = i }),
            { color = W.markersArena == i and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or nil })
        SameLine()
        if IconButton("showMarkers" .. tostring(i), BJI.Utils.Icon.ICONS.visibility,
                { disabled = W.markersArena == i }) then
            reloadMarkers(i)
        end
        TooltipText(W.labels.buttons.showArena)
        SameLine()
        if IconButton("deleteArena" .. tostring(i), BJI.Utils.Icon.ICONS.delete_forever,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = W.cache.disableButtons }) then
            W.cache.arenas:remove(i)
            W.changed = true
            W.markersArena = nil
            reloadMarkers()
            validateArenas()
        end
        TooltipText(W.labels.buttons.deleteArena)
        if opened then
            drawArena(ctxt, i, arena)
            EndTree()
        elseif arena.name and #arena.name:trim() > 0 then
            SameLine()
            Text(string.format("(%s)", arena.name),
                { color = W.markersArena == i and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or nil })
        end
    end)
end

---@param ctxt TickContext
local function footer(ctxt)
    if IconButton("closeDerbyEdit", BJI.Utils.Icon.ICONS.exit_to_app,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
        BJI.Windows.ScenarioEditor.onClose()
    end
    TooltipText(W.labels.buttons.close)
    if W.changed then
        SameLine()
        if IconButton("saveDerbyEdit", BJI.Utils.Icon.ICONS.save,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                    disabled = W.cache.disableInputs or not W.valid }) then
            save()
        end
        TooltipText(W.labels.buttons.save ..
            (not W.valid and " (" .. W.labels.buttons.errorInvalidData .. ")" or ""))
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
