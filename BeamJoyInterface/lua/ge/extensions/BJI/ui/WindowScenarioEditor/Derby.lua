local dEdit
local drawnArena = nil
local valid

local function close()
    BJIContext.Scenario.DerbyEdit = nil
    drawnArena = nil
    BJIWaypointEdit.reset()
end

local function reloadMarkers(indexArena)
    indexArena = indexArena or drawnArena
    BJIWaypointEdit.reset()

    local waypoints = {}

    local arena = dEdit.arenas[indexArena]
    if arena then
        for i, target in ipairs(arena.startPositions) do
            table.insert(waypoints, {
                name = BJILang.get("derby.edit.startPositionName"):var({ index = i }),
                pos = target.pos,
                rot = target.rot,
                radius = 2,
                color = ShapeDrawer.Color(1, 1, 0, .5),
                type = BJIWaypointEdit.TYPES.ARROW,
            })
        end

        if #waypoints > 0 then
            BJIWaypointEdit.setWaypoints(waypoints)
            drawnArena = indexArena
            return
        end
    end

    -- not drawn case
    drawnArena = nil
end

local function save()
    local data = {}

    for _, arena in ipairs(dEdit.arenas) do
        local newArena = {
            name = arena.name,
            enabled = arena.enabled,
            previewPosition = RoundPositionRotation(arena.previewPosition),
            startPositions = {},
        }
        for _, sp in ipairs(arena.startPositions) do
            table.insert(newArena.startPositions, RoundPositionRotation(sp))
        end
        table.insert(data, newArena)
    end

    dEdit.processSave = true
    local _, err = pcall(BJITx.scenario.DerbySave, data)
    if not err then
        BJIAsync.task(function()
            return dEdit.processSave and dEdit.saveSuccess ~= nil
        end, function()
            if dEdit.saveSuccess then
                dEdit.changed = false
            else
                -- error message
                BJIToast.error(BJILang.get("derby.edit.saveErrorToast"))
            end

            dEdit.processSave = nil
            dEdit.saveSuccess = nil
        end, "DerbySave")
    else
        dEdit.processSave = nil
    end
end

local function drawHeader(ctxt)
    dEdit = BJIContext.Scenario.DerbyEdit or {}

    LineBuilder()
        :text(BJILang.get("derby.edit.title"))
        :build()

    valid = true
end

local function drawArena(index, arena, ctxt)
    LineBuilder()
        :text(BJILang.get("derby.edit.arena"):var({ index = index }))
        :btnIcon({
            id = string.var("reloadMarkersArena{1}", { index }),
            icon = ICONS.visibility,
            style = BTN_PRESETS.INFO,
            disabled = drawnArena == index or #arena.startPositions == 0,
            onClick = function()
                reloadMarkers(index)
            end,
        })
        :btnIcon({
            id = string.var("deleteArena{1}", { index }),
            icon = ICONS.delete_forever,
            style = BTN_PRESETS.ERROR,
            onClick = function()
                table.remove(dEdit.arenas, index)
                dEdit.changed = true
            end,
        })
        :build()
    Indent(1)
    local labelWidth = 0
    for _, k in ipairs({
        "derby.edit.name",
        "derby.edit.enabled",
        "derby.edit.previewPosition",
        "derby.edit.startPositions",
    }) do
        local label = BJILang.get(k)
        local w = GetColumnTextWidth(label .. HELPMARKER_TEXT)
        if w > labelWidth then
            labelWidth = w
        end
    end
    local cols = ColumnsBuilder(string.var("derbyEdit{1}", { index }), { labelWidth, -1 })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(BJILang.get("derby.edit.name"))
                        :build()
                end,
                function()
                    local validName = true
                    if #arena.name == 0 then
                        valid = false
                        validName = false
                    end
                    LineBuilder()
                        :inputString({
                            id = string.var("arenaName{1}", { index }),
                            value = arena.name,
                            disabled = dEdit.processSave,
                            style = not validName and INPUT_PRESETS.ERROR,
                            onUpdate = function(val)
                                arena.name = val
                                dEdit.changed = true
                            end,
                        })
                        :build()
                end,
            }
        })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(BJILang.get("derby.edit.enabled"))
                        :helpMarker(BJILang.get("derby.edit.enabledTooltip"))
                        :build()
                end,
                function()
                    LineBuilder()
                        :btnIconToggle({
                            id = string.var("toggleArenaEnabled{1}", { index }),
                            icon = arena.enabled and ICONS.visibility or ICONS.visibility_off,
                            state = arena.enabled,
                            onClick = function()
                                arena.enabled = not arena.enabled
                                dEdit.changed = true
                            end
                        })
                        :build()
                end,
            }
        })
        :addRow({
            cells = {
                function()
                    if not arena.previewPosition then
                        valid = false
                    end
                    LineBuilder()
                        :text(BJILang.get("derby.edit.previewPosition"),
                            arena.previewPosition and TEXT_COLORS.DEFAULT or TEXT_COLORS.ERROR)
                        :helpMarker(BJILang.get("derby.edit.previewPositionTooltip"))
                        :build()
                end,
                function()
                    local line = LineBuilder()
                        :btnIcon({
                            id = string.var("setArenaPreviewPos{1}", { index }),
                            icon = arena.previewPosition and ICONS.crosshair or ICONS.video_call,
                            style = arena.previewPosition and BTN_PRESETS.WARNING or BTN_PRESETS.SUCCESS,
                            disabled = dEdit.processSave,
                            onClick = function()
                                local campos = BJICam.getPositionRotation(true)
                                arena.previewPosition = {
                                    pos = campos.pos,
                                    rot = campos.rot
                                }
                                dEdit.changed = true
                            end
                        })
                    if arena.previewPosition then
                        line:btnIcon({
                            id = string.var("showArenaPreviePosition{1}", { index }),
                            icon = ICONS.visibility,
                            style = BTN_PRESETS.INFO,
                            disabled = not arena.previewPosition,
                            onClick = function()
                                if ctxt.camera ~= BJICam.CAMERAS.FREE then
                                    ctxt.camera = BJICam.CAMERAS.FREE
                                    BJICam.setCamera(ctxt.camera)
                                end
                                BJICam.setPositionRotation(arena.previewPosition.pos, arena.previewPosition.rot)
                            end,
                        })
                    end
                    line:build()
                end,
            }
        })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(BJILang.get("derby.edit.startPositions"))
                        :build()
                end,
                function()
                    local validStartPositions = true
                    if #arena.startPositions < 6 then
                        valid = false
                        validStartPositions = false
                    end
                    if not validStartPositions then
                        LineBuilder()
                            :text(
                                BJILang.get("derby.edit.amountStartPositionsNeeded")
                                :var({ amount = 6 - #arena.startPositions }),
                                TEXT_COLORS.ERROR)
                            :build()
                    end
                end,
            }
        })
    for i, sp in ipairs(arena.startPositions) do
        cols:addRow({
            cells = {
                nil,
                function()
                    LineBuilder()
                        :text(BJILang.get("derby.edit.startPositionName"):var({ index = i }))
                    -- add up, down, goto, moveHere and delete buttons
                        :btnIcon({
                            id = string.var("upArenaStartPos{1}{2}", { index, i }),
                            icon = ICONS.arrow_drop_up,
                            style = BTN_PRESETS.WARNING,
                            disabled = i == 1 or dEdit.processSave,
                            onClick = function()
                                table.insert(arena.startPositions, i - 1, sp)
                                table.remove(arena.startPositions, i + 1)
                                dEdit.changed = true
                                reloadMarkers(index)
                            end,
                        })
                        :btnIcon({
                            id = string.var("downArenaStartPos{1}{2}", { index, i }),
                            icon = ICONS.arrow_drop_down,
                            style = BTN_PRESETS.WARNING,
                            disabled = i == #arena.startPositions or dEdit.processSave,
                            onClick = function()
                                table.insert(arena.startPositions, i + 2, sp)
                                table.remove(arena.startPositions, i)
                                dEdit.changed = true
                                reloadMarkers(index)
                            end,
                        })
                        :btnIcon({
                            id = string.var("gotoArenaStartPos{1}{2}", { index, i }),
                            icon = ICONS.cameraFocusOnVehicle2,
                            style = BTN_PRESETS.INFO,
                            disabled = not ctxt.veh,
                            onClick = function()
                                local posRot = arena.startPositions[i]
                                BJIVeh.setPositionRotation(posRot.pos, posRot.rot, { safe = false })
                                if ctxt.camera == BJICam.CAMERAS.FREE then
                                    ctxt.camera = BJICam.CAMERAS.ORBIT
                                    BJICam.setCamera(ctxt.camera)
                                end
                            end,
                        })
                        :btnIcon({
                            id = string.var("moveHereArenaStartPos{1}{2}", { index, i }),
                            icon = ICONS.crosshair,
                            style = BTN_PRESETS.WARNING,
                            disabled = not ctxt.veh or dEdit.processSave,
                            onClick = function()
                                arena.startPositions[i] = RoundPositionRotation(ctxt.vehPosRot)
                                dEdit.changed = true
                                reloadMarkers(index)
                            end
                        })
                        :btnIcon({
                            id = string.var("deleteArenaStartPos{1}{2}", { index, i }),
                            icon = ICONS.delete_forever,
                            style = BTN_PRESETS.ERROR,
                            disabled = dEdit.processSave,
                            onClick = function()
                                table.remove(arena.startPositions, i)
                                dEdit.changed = true
                                reloadMarkers(index)
                            end,
                        })
                        :build()
                end,
            }
        })
    end
    cols:addRow({
        cells = {
            nil,
            function()
                LineBuilder()
                    :btnIcon({
                        id = string.var("addStartPos{1}", { index }),
                        icon = ICONS.addListItem,
                        style = BTN_PRESETS.SUCCESS,
                        disabled = not ctxt.veh or dEdit.processSave,
                        onClick = function()
                            table.insert(arena.startPositions, RoundPositionRotation(ctxt.vehPosRot))
                            dEdit.changed = true
                            reloadMarkers(index)
                        end,
                    })
                    :build()
            end,
        }
    })
    cols:build()
    Indent(-1)
    Separator()
end

local function drawBody(ctxt)
    for i, arena in ipairs(dEdit.arenas) do
        drawArena(i, arena, ctxt)
    end
    LineBuilder()
        :btnIcon({
            id = "addArena",
            icon = ICONS.addListItem,
            style = BTN_PRESETS.SUCCESS,
            onClick = function()
                table.insert(dEdit.arenas, {
                    name = "",
                    enabled = false,
                    previewPosition = nil,
                    startPositions = {},
                })
            end,
        })
        :build()
end

local function drawFooter(ctxt)
    local line = LineBuilder()
        :btnIcon({
            id = "cancelDerbyEdit",
            icon = ICONS.exit_to_app,
            style = BTN_PRESETS.ERROR,
            onClick = close,
        })
    if dEdit.changed then
        line:btnIcon({
            id = "saveDerbyEdit",
            icon = ICONS.save,
            style = BTN_PRESETS.SUCCESS,
            disabled = not valid or dEdit.processSave,
            onClick = save,
        })
    end
    line:build()
end

return {
    flags = {
        WINDOW_FLAGS.NO_COLLAPSE
    },
    header = drawHeader,
    body = drawBody,
    footer = drawFooter,
    onClose = close,
}
