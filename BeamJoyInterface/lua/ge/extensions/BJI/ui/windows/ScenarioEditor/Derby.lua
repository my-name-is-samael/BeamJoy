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
            moveUp = "",
            moveDown = "",
            close = "",
            save = "",
            errorMustHaveVehicle = "",
            errorMustBeFreecaming = "",
            errorInvalidData = "",
        },
    },
    cache = {
        labelsWidth = 0,
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

local function onClose()
    BJI.Managers.WaypointEdit.reset()
    W.markersArena = nil
    W.changed = false
    W.valid = true
end

local function reloadMarkers(indexArena)
    indexArena = indexArena or W.markersArena
    BJI.Managers.WaypointEdit.reset()

    if not W.cache.arenas[indexArena] then
        -- not drawn case
        W.markersArena = nil
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
        waypoints:insert({
            name = BJI.Managers.Lang.get("derby.edit.centerPosition"),
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
    W.labels.buttons.moveUp = BJI.Managers.Lang.get("common.buttons.moveUp")
    W.labels.buttons.moveDown = BJI.Managers.Lang.get("common.buttons.moveDown")
    W.labels.buttons.close = BJI.Managers.Lang.get("common.buttons.close")
    W.labels.buttons.save = BJI.Managers.Lang.get("common.buttons.save")
    W.labels.buttons.errorMustHaveVehicle = BJI.Managers.Lang.get("errors.mustHaveVehicle")
    W.labels.buttons.errorMustBeFreecaming = BJI.Managers.Lang.get("errors.mustBeFreecaming")
    W.labels.buttons.errorInvalidData = BJI.Managers.Lang.get("errors.someDataAreInvalid")
end

local function udpateWidths()
    W.cache.labelsWidth = Table({
        W.labels.name,
        W.labels.enabled,
        W.labels.previewPosition,
        W.labels.centerPosition,
        W.labels.radius,
        W.labels.startPositionName
    }):reduce(function(acc, l)
        local w = BJI.Utils.UI.GetColumnTextWidth(l)
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
    end, W.name))

    udpateWidths()
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED, udpateWidths, W.name))

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

local function validateArenas()
    ---@param a BJArena
    W.valid = #W.cache.arenas == 0 or not W.cache.arenas:any(function(a)
        return #a.name:trim() == 0 or
            not a.previewPosition or
            #a.startPositions < W.minStartPositions or not a.centerPosition
    end)
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
    LineBuilder():text(W.labels.title)
        :btnIcon({
            id = "addArena",
            icon = BJI.Utils.Icon.ICONS.add,
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            tooltip = W.labels.buttons.addArena,
            onClick = function()
                W.cache.arenas:insert({
                    name = "",
                    enabled = false,
                    previewPosition = nil,
                    startPositions = Table(),
                    radius = 10,
                })
                W.changed = true
                validateArenas()
            end,
        }):build()
end

---@param ctxt TickContext
---@param iArena integer
---@param arena BJArena
local function drawArena(ctxt, iArena, arena)
    LineBuilder():text(W.labels.arena:var({ index = iArena })):btnIcon({
        id = string.var("reloadMarkersArena{1}", { iArena }),
        icon = BJI.Utils.Icon.ICONS.visibility,
        style = BJI.Utils.Style.BTN_PRESETS.INFO,
        disabled = W.markersArena == iArena or #arena.startPositions == 0,
        tooltip = W.labels.buttons.showArena,
        onClick = function()
            reloadMarkers(iArena)
        end,
    }):btnIcon({
        id = string.var("deleteArena{1}", { iArena }),
        icon = BJI.Utils.Icon.ICONS.delete_forever,
        style = BJI.Utils.Style.BTN_PRESETS.ERROR,
        disabled = W.cache.disableButtons,
        tooltip = W.labels.buttons.deleteArena,
        onClick = function()
            W.cache.arenas:remove(iArena)
            W.changed = true
            validateArenas()
        end,
    }):build()
    Indent(1)
    local cols = ColumnsBuilder(string.var("derbyEdit{1}", { iArena }), { W.cache.labelsWidth, -1 }):addRow({
        cells = {
            function() LineLabel(W.labels.name) end,
            function()
                LineBuilder()
                    :inputString({
                        id = string.var("arenaName{1}", { iArena }),
                        value = arena.name,
                        disabled = W.cache.disableButtons,
                        style = #arena.name:trim() == 0 and BJI.Utils.Style.INPUT_PRESETS.ERROR or nil,
                        onUpdate = function(val)
                            arena.name = val
                            W.changed = true
                            validateArenas()
                        end,
                    })
                    :build()
            end,
        }
    }):addRow({
        cells = {
            function()
                LineLabel(W.labels.enabled, nil, false, W.labels.enabledTooltip)
            end,
            function()
                LineBuilder()
                    :btnIconToggle({
                        id = string.var("toggleArenaEnabled{1}", { iArena }),
                        icon = arena.enabled and BJI.Utils.Icon.ICONS.visibility or BJI.Utils.Icon.ICONS.visibility_off,
                        state = arena.enabled,
                        disabled = W.cache.disableButtons,
                        tooltip = W.labels.buttons.toggleArenaVisibility,
                        onClick = function()
                            arena.enabled = not arena.enabled
                            W.changed = true
                            validateArenas()
                        end
                    })
                    :build()
            end,
        }
    }):addRow({
        cells = {
            function()
                LineLabel(W.labels.previewPosition, not arena.previewPosition and
                    BJI.Utils.Style.TEXT_COLORS.ERROR or nil, false,
                    W.labels.previewPositionTooltip)
            end,
            function()
                local line = LineBuilder():btnIcon({
                    id = string.var("setArenaPreviewPos{1}", { iArena }),
                    icon = arena.previewPosition and BJI.Utils.Icon.ICONS.edit_location or BJI.Utils.Icon.ICONS.add_location,
                    style = arena.previewPosition and BJI.Utils.Style.BTN_PRESETS.WARNING or
                        BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                    disabled = W.cache.disableButtons,
                    tooltip = W.labels.buttons.setPreviewPositionHere,
                    onClick = function()
                        arena.previewPosition = BJI.Managers.Cam.getPositionRotation(true)
                        W.changed = true
                        validateArenas()
                    end
                })
                if arena.previewPosition then
                    line:btnIcon({
                        id = string.var("showArenaPreviePosition{1}", { iArena }),
                        icon = BJI.Utils.Icon.ICONS.visibility,
                        style = BJI.Utils.Style.BTN_PRESETS.INFO,
                        tooltip = W.labels.buttons.showPreviewPosition,
                        onClick = function()
                            reloadMarkers(iArena)
                            if ctxt.camera ~= BJI.Managers.Cam.CAMERAS.FREE then
                                BJI.Managers.Cam.toggleFreeCam()
                            end
                            BJI.Managers.Cam.setPositionRotation(arena.previewPosition.pos,
                                arena.previewPosition.rot)
                        end,
                    })
                end
                line:build()
            end,
        }
    }):addRow({
        cells = {
            function()
                LineLabel(W.labels.centerPosition, not arena.centerPosition and
                    BJI.Utils.Style.TEXT_COLORS.ERROR or nil)
            end,
            function()
                local line = LineBuilder():btnIcon({
                    id = string.var("setArenaCenterPos{1}", { iArena }),
                    icon = arena.centerPosition and BJI.Utils.Icon.ICONS.edit_location or BJI.Utils.Icon.ICONS.add_location,
                    style = arena.centerPosition and BJI.Utils.Style.BTN_PRESETS.WARNING or
                        BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                    disabled = W.cache.disableButtons or ctxt.camera ~= BJI.Managers.Cam.CAMERAS.FREE,
                    tooltip = string.var("{1}{2}", { W.labels.buttons.setCenterPositionHere,
                        (ctxt.camera ~= BJI.Managers.Cam.CAMERAS.FREE) and
                        (" (" .. W.labels.buttons.errorMustBeFreecaming .. ")") or ""
                    }),
                    onClick = function()
                        arena.centerPosition = BJI.Managers.Cam.getPositionRotation().pos
                        W.changed = true
                        validateArenas()
                        reloadMarkers(iArena)
                    end
                })
                if arena.centerPosition then
                    line:btnIcon({
                        id = string.var("showArenaCenterPos{1}", { iArena }),
                        icon = BJI.Utils.Icon.ICONS.visibility,
                        style = BJI.Utils.Style.BTN_PRESETS.INFO,
                        tooltip = W.labels.buttons.showCenterPosition,
                        onClick = function()
                            reloadMarkers(iArena)
                            if ctxt.camera ~= BJI.Managers.Cam.CAMERAS.FREE then
                                BJI.Managers.Cam.toggleFreeCam()
                            end
                            BJI.Managers.Cam.setPositionRotation(arena.centerPosition)
                        end,
                    })
                end
                line:build()
            end,
        }
    }):addRow({
        cells = {
            function() LineLabel(W.labels.radius) end,
            function()
                LineBuilder():slider({
                    id = string.var("arenaRadius{1}", { iArena }),
                    type = "int",
                    value = arena.radius,
                    min = 10,
                    max = 100,
                    disabled = W.cache.disableButtons,
                    renderFormat = "%dm",
                    onUpdate = function(val)
                        arena.radius = math.round(val)
                        W.changed = true
                        validateArenas()
                        reloadMarkers(iArena)
                    end
                }):build()
            end,
        }
    }):addRow({
        cells = {
            function() LineLabel(W.labels.startPositions) end,
            function()
                local line = LineBuilder():btnIcon({
                    id = string.var("addStartPos{1}", { iArena }),
                    icon = BJI.Utils.Icon.ICONS.add_location,
                    style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                    disabled = W.cache.disableInputs or not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE,
                    tooltip = string.var("{1}{2}", {
                        W.labels.buttons.addStartPositionHere,
                        (not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE) and
                        (" (" .. W.labels.buttons.errorMustHaveVehicle .. ")") or ""
                    }),
                    onClick = function()
                        arena.startPositions:insert(math.roundPositionRotation(ctxt.vehPosRot))
                        W.changed = true
                        reloadMarkers(iArena)
                        validateArenas()
                    end,
                })
                if #arena.startPositions < 6 then
                    line:text(
                        W.labels.amountStartPositionsNeeded:var({
                            amount = W.minStartPositions -
                                #arena.startPositions
                        }),
                        BJI.Utils.Style.TEXT_COLORS.ERROR)
                end
                line:build()
            end,
        }
    })
    arena.startPositions:reduce(function(c, sp, i)
        return c:addRow({
            cells = {
                nil,
                function()
                    LineBuilder():text(W.labels.startPositionName:var({ index = i })):btnIcon({
                        id = string.var("upArenaStartPos{1}{2}", { iArena, i }),
                        icon = BJI.Utils.Icon.ICONS.arrow_drop_up,
                        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        disabled = W.cache.disableButtons or i == 1,
                        tooltip = W.labels.buttons.moveUp,
                        onClick = function()
                            arena.startPositions:insert(i - 1, sp)
                            arena.startPositions:remove(i + 1)
                            W.changed = true
                            reloadMarkers(iArena)
                        end,
                    }):btnIcon({
                        id = string.var("downArenaStartPos{1}{2}", { iArena, i }),
                        icon = BJI.Utils.Icon.ICONS.arrow_drop_down,
                        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        disabled = W.cache.disableButtons or i == #arena.startPositions,
                        tooltip = W.labels.buttons.moveDown,
                        onClick = function()
                            arena.startPositions:insert(i + 2, sp)
                            arena.startPositions:remove(i)
                            W.changed = true
                            reloadMarkers(iArena)
                        end,
                    }):btnIcon({
                        id = string.var("gotoArenaStartPos{1}{2}", { iArena, i }),
                        icon = BJI.Utils.Icon.ICONS.pin_drop,
                        style = BJI.Utils.Style.BTN_PRESETS.INFO,
                        tooltip = W.labels.buttons.showStartPosition,
                        onClick = function()
                            if ctxt.isOwner then
                                local posRot = arena.startPositions[i]
                                BJI.Managers.Veh.setPositionRotation(posRot.pos, posRot.rot, { safe = false })
                                if ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE then
                                    BJI.Managers.Cam.toggleFreeCam()
                                end
                            else
                                if not ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE then
                                    BJI.Managers.Cam.toggleFreeCam()
                                end
                                local pos = vec3(
                                    sp.pos.x,
                                    sp.pos.y,
                                    sp.pos.z + 1
                                )
                                BJI.Managers.Cam.setPositionRotation(pos, sp.rot * quat(0, 0, 1, 0))
                            end
                        end,
                    }):btnIcon({
                        id = string.var("moveHereArenaStartPos{1}{2}", { iArena, i }),
                        icon = BJI.Utils.Icon.ICONS.edit_location,
                        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        disabled = W.cache.disableInputs or not ctxt.veh or
                            ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE,
                        tooltip = string.var("{1}{2}", {
                            W.labels.buttons.setStartPositionHere,
                            (not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE) and
                            " (" .. W.labels.buttons.errorMustHaveVehicle .. ")" or ""
                        }),
                        onClick = function()
                            arena.startPositions[i] = math.roundPositionRotation(ctxt.vehPosRot)
                            W.changed = true
                            reloadMarkers(iArena)
                            validateArenas()
                        end
                    }):btnIcon({
                        id = string.var("deleteArenaStartPos{1}{2}", { iArena, i }),
                        icon = BJI.Utils.Icon.ICONS.delete_forever,
                        style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                        disabled = W.cache.disableInputs,
                        tooltip = W.labels.buttons.deleteStartPosition,
                        onClick = function()
                            arena.startPositions:remove(i)
                            W.changed = true
                            reloadMarkers(iArena)
                            validateArenas()
                        end,
                    }):build()
                end,
            }
        })
    end, cols):build()
    Indent(-1)
    Separator()
end

---@param ctxt TickContext
local function body(ctxt)
    W.cache.arenas:forEach(function(arena, i)
        drawArena(ctxt, i, arena)
    end)
end

---@param ctxt TickContext
local function footer(ctxt)
    local line = LineBuilder()
        :btnIcon({
            id = "cancelDerbyEdit",
            icon = BJI.Utils.Icon.ICONS.exit_to_app,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            tooltip = W.labels.buttons.close,
            onClick = BJI.Windows.ScenarioEditor.onClose,
        })
    if W.changed then
        line:btnIcon({
            id = "saveDerbyEdit",
            icon = BJI.Utils.Icon.ICONS.save,
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            disabled = W.cache.disableInputs or not W.valid,
            tooltip = string.var("{1}{2}", {
                W.labels.buttons.save,
                not W.valid and " (" .. W.labels.buttons.errorInvalidData .. ")" or ""
            }),
            onClick = save,
        })
    end
    line:build()
end

local function open()
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
