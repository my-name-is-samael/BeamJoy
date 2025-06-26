local hEdit
local valid

local function close()
    BJIContext.Scenario.HunterEdit = nil
    BJIWaypointEdit.reset()
end

local function reloadMarkers()
    BJIWaypointEdit.reset()

    local waypoints = {}

    for i, target in ipairs(hEdit.targets) do
        table.insert(waypoints, {
            name = BJILang.get("hunter.edit.targetName"):var({ index = i }),
            pos = target.pos,
            radius = target.radius,
            type = BJIWaypointEdit.TYPES.CYLINDER,
        })
    end

    local hunterColor = ShapeDrawer.Color(1, 1, 0, .5)
    for i, hunter in ipairs(hEdit.hunterPositions) do
        table.insert(waypoints, {
            name = BJILang.get("hunter.edit.hunterPositionName"):var({ index = i }),
            pos = hunter.pos,
            rot = hunter.rot,
            radius = 2,
            color = hunterColor,
            textColor = hunterColor,
            textBg = ShapeDrawer.Color(0, 0, 0, .5),
            type = BJIWaypointEdit.TYPES.ARROW,
        })
    end

    local huntedColor = ShapeDrawer.Color(1, 0, 0, .5)
    for i, hunted in ipairs(hEdit.huntedPositions) do
        table.insert(waypoints, {
            name = BJILang.get("hunter.edit.huntedPositionName"):var({ index = i }),
            pos = hunted.pos,
            rot = hunted.rot,
            radius = 2,
            color = huntedColor,
            textColor = huntedColor,
            textBg = ShapeDrawer.Color(0, 0, 0, .5),
            type = BJIWaypointEdit.TYPES.ARROW,
        })
    end

    if #waypoints > 0 then
        BJIWaypointEdit.setWaypoints(waypoints)
    end
end

local function save()
    local data = {
        enabled = hEdit.enabled and
            #hEdit.targets >= 2 and
            #hEdit.hunterPositions >= 5 and
            #hEdit.huntedPositions >= 2,
        targets = {},
        hunterPositions = {},
        huntedPositions = {},
    }

    for _, waypoint in ipairs(hEdit.targets) do
        table.insert(data.targets, {
            pos = waypoint.pos,
            radius = waypoint.radius,
        })
    end

    for _, hunter in ipairs(hEdit.hunterPositions) do
        table.insert(data.hunterPositions, RoundPositionRotation(hunter))
    end

    for _, hunted in ipairs(hEdit.huntedPositions) do
        table.insert(data.huntedPositions, RoundPositionRotation(hunted))
    end

    hEdit.processSave = true
    local _, err = pcall(BJITx.scenario.HunterSave, data)
    if not err then
        BJIAsync.task(function()
            return hEdit.processSave and hEdit.saveSuccess ~= nil
        end, function()
            if hEdit.saveSuccess then
                hEdit.changed = false
            else
                -- error message
                BJIToast.error(BJILang.get("hunter.edit.saveErrorToast"))
            end

            hEdit.processSave = nil
            hEdit.saveSuccess = nil
        end, "HunterSave")
    else
        hEdit.processSave = nil
    end
end

local function checkEnabled()
    if hEdit.enabled then
        if #hEdit.targets < 2 or
            #hEdit.hunterPositions < 5 or
            #hEdit.huntedPositions < 2 then
            hEdit.enabled = false
        end
    end
end

local function drawHeader(ctxt)
    hEdit = BJIContext.Scenario.HunterEdit or {}

    if not hEdit.init then
        hEdit.init = true
        reloadMarkers()
    end

    LineBuilder()
        :text(BJILang.get("hunter.edit.title"))
        :btnIcon({
            id = "reloadMarkers",
            icon = ICONS.sync,
            style = BTN_PRESETS.INFO,
            onClick = reloadMarkers,
        })
        :build()

    LineBuilder()
        :text(string.var("{1}:", { BJILang.get("hunter.edit.enabled") }))
        :btnIconToggle({
            id = "toggleEnabled",
            icon = hEdit.enabled and ICONS.visibility or ICONS.visibility_off,
            state = hEdit.enabled == true,
            disabled = hEdit.processSave,
            onClick = function()
                local origin = hEdit.enabled
                hEdit.enabled = not hEdit.enabled
                checkEnabled()
                if origin ~= hEdit.enabled then
                    hEdit.changed = true
                end
            end
        })
        :build()

    valid = not hEdit.enabled or (
        #hEdit.targets >= 2 and
        #hEdit.hunterPositions >= 5 and
        #hEdit.huntedPositions > 0
    )
end

local function drawHunters(ctxt)
    local freecaming = ctxt.camera == BJICam.CAMERAS.FREE
    for i, hunterPoint in ipairs(hEdit.hunterPositions) do
        LineBuilder()
            :text(BJILang.get("hunter.edit.hunterPositionName"):var({ index = i }))
            :btnIcon({
                id = string.var("gotoHunter{1}", { i }),
                icon = ICONS.cameraFocusTopDown,
                style = BTN_PRESETS.INFO,
                disabled = not ctxt.isOwner,
                onClick = function()
                    if freecaming then
                        BJICam.setCamera(BJICam.CAMERAS.ORBIT)
                    end
                    BJIVeh.setPositionRotation(hunterPoint.pos, hunterPoint.rot)
                end,
            })
            :btnIcon({
                id = string.var("moveHunter{1}", { i }),
                icon = ICONS.crosshair,
                style = BTN_PRESETS.WARNING,
                disabled = not ctxt.veh or freecaming or hEdit.processSave,
                onClick = function()
                    hEdit.hunterPositions[i] = ctxt.vehPosRot
                    hEdit.changed = true
                    reloadMarkers()
                end,
            })
            :btnIcon({
                id = string.var("deleteHunter{1}", { i }),
                icon = ICONS.delete_forever,
                style = BTN_PRESETS.ERROR,
                disabled = hEdit.processSave,
                onClick = function()
                    table.remove(hEdit.hunterPositions, i)
                    hEdit.changed = true
                    reloadMarkers()
                end,
            })
            :build()
    end
    LineBuilder()
        :btnIcon({
            id = "addHunterPosition",
            icon = ICONS.addListItem,
            style = BTN_PRESETS.SUCCESS,
            disabled = not ctxt.veh or freecaming or hEdit.processSave,
            onClick = function()
                table.insert(hEdit.hunterPositions, ctxt.vehPosRot)
                reloadMarkers()
                hEdit.changed = true
            end
        })
        :build()
end

local function drawHunted(ctxt)
    local freecaming = ctxt.camera == BJICam.CAMERAS.FREE
    for i, huntedPoint in ipairs(hEdit.huntedPositions) do
        LineBuilder()
            :text(BJILang.get("hunter.edit.huntedPositionName"):var({ index = i }))
            :btnIcon({
                id = string.var("gotoHunted{1}", { i }),
                icon = ICONS.cameraFocusTopDown,
                style = BTN_PRESETS.INFO,
                disabled = not ctxt.isOwner,
                onClick = function()
                    if freecaming then
                        BJICam.setCamera(BJICam.CAMERAS.ORBIT)
                    end
                    BJIVeh.setPositionRotation(huntedPoint.pos, huntedPoint.rot)
                end,
            })
            :btnIcon({
                id = string.var("moveHunted{1}", { i }),
                icon = ICONS.crosshair,
                style = BTN_PRESETS.WARNING,
                disabled = not ctxt.veh or freecaming or hEdit.processSave,
                onClick = function()
                    hEdit.huntedPositions[i] = ctxt.vehPosRot
                    hEdit.changed = true
                    reloadMarkers()
                end,
            })
            :btnIcon({
                id = string.var("deleteHunted{1}", { i }),
                icon = ICONS.delete_forever,
                style = BTN_PRESETS.ERROR,
                disabled = hEdit.processSave,
                onClick = function()
                    table.remove(hEdit.huntedPositions, i)
                    hEdit.changed = true
                    reloadMarkers()
                end,
            })
            :build()
    end
    LineBuilder()
        :btnIcon({
            id = "addHuntedPosition",
            icon = ICONS.addListItem,
            style = BTN_PRESETS.SUCCESS,
            disabled = not ctxt.veh or freecaming or hEdit.processSave,
            onClick = function()
                table.insert(hEdit.huntedPositions, ctxt.vehPosRot)
                reloadMarkers()
                hEdit.changed = true
            end
        })
        :build()
end

local function drawWaypoints(ctxt)
    local freecaming = ctxt.camera == BJICam.CAMERAS.FREE
    for i, waypoint in ipairs(hEdit.targets) do
        LineBuilder()
            :text(BJILang.get("hunter.edit.targetName"):var({ index = i }))
            :btnIcon({
                id = string.var("gotoWaypoint{1}", { i }),
                icon = ICONS.cameraFocusTopDown,
                style = BTN_PRESETS.INFO,
                disabled = not ctxt.isOwner,
                onClick = function()
                    if freecaming then
                        BJICam.setCamera(BJICam.CAMERAS.ORBIT)
                    end
                    BJIVeh.setPositionRotation(waypoint.pos)
                end,
            })
            :btnIcon({
                id = string.var("moveWaypoint{1}", { i }),
                icon = ICONS.crosshair,
                style = BTN_PRESETS.WARNING,
                disabled = not ctxt.veh or freecaming or hEdit.processSave,
                onClick = function()
                    waypoint.pos = ctxt.vehPosRot.pos
                    hEdit.changed = true
                    reloadMarkers()
                end,
            })
            :btnIcon({
                id = string.var("deleteWaypoint{1}", { i }),
                icon = ICONS.delete_forever,
                style = BTN_PRESETS.ERROR,
                disabled = hEdit.processSave,
                onClick = function()
                    table.remove(hEdit.targets, i)
                    hEdit.changed = true
                    reloadMarkers()
                end,
            })
            :build()

        LineBuilder()
            :text(BJILang.get("hunter.edit.radius"))
            :inputNumeric({
                id = string.var("radiusWaypoint{1}", { i }),
                type = "float",
                precision = 1,
                value = waypoint.radius,
                disabled = hEdit.processSave,
                min = 1,
                max = 50,
                step = .5,
                stepFast = 2,
                wisth = 300,
                onUpdate = function(val)
                    waypoint.radius = val
                    hEdit.changed = true
                    reloadMarkers()
                end
            })
            :build()
    end
    LineBuilder()
        :btnIcon({
            id = "addWaypoint",
            icon = ICONS.addListItem,
            style = BTN_PRESETS.SUCCESS,
            disabled = not ctxt.veh or freecaming or hEdit.processSave,
            onClick = function()
                table.insert(hEdit.targets, {
                    pos = ctxt.vehPosRot.pos,
                    radius = 2,
                })
                reloadMarkers()
                hEdit.changed = true
            end
        })
        :build()
end

local function drawBody(ctxt)
    AccordionBuilder()
        :label(BJILang.get("hunter.edit.hunters"))
        :commonStart(function()
            local line = LineBuilder(true)
                :text(string.var("({1})", { #hEdit.hunterPositions }))
            if #hEdit.hunterPositions < 5 then
                line:text(BJILang.get("hunter.edit.missingPoints"):var({ amount = 5 - #hEdit.hunterPositions }),
                    TEXT_COLORS.ERROR)
            end
            line:build()
        end)
        :openedBehavior(function()
            drawHunters(ctxt)
        end)
        :build()

    AccordionBuilder()
        :label(BJILang.get("hunter.edit.hunted"))
        :commonStart(function()
            local line = LineBuilder(true)
                :text(string.var("({1})", { #hEdit.huntedPositions }))
            if #hEdit.huntedPositions < 2 then
                line:text(BJILang.get("hunter.edit.missingPoints"):var({ amount = 2 - #hEdit.huntedPositions }),
                    TEXT_COLORS.ERROR)
            end
            line:build()
        end)
        :openedBehavior(function()
            drawHunted(ctxt)
        end)
        :build()

    AccordionBuilder()
        :label(BJILang.get("hunter.edit.waypoints"))
        :commonStart(function()
            local line = LineBuilder(true)
                :text(string.var("({1})", { #hEdit.targets }))
            if #hEdit.targets < 2 then
                line:text(BJILang.get("hunter.edit.missingPoints"):var({ amount = 2 - #hEdit.targets }),
                    TEXT_COLORS.ERROR)
            end
            line:build()
        end)
        :openedBehavior(function()
            drawWaypoints(ctxt)
        end)
        :build()
end

local function drawFooter(ctxt)
    local line = LineBuilder()
        :btnIcon({
            id = "cancelHunterEdit",
            icon = ICONS.exit_to_app,
            style = BTN_PRESETS.ERROR,
            onClick = close,
        })
    if hEdit.changed then
        line:btnIcon({
            id = "saveHunterEdit",
            icon = ICONS.save,
            style = BTN_PRESETS.SUCCESS,
            disabled = not valid or hEdit.processSave,
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
