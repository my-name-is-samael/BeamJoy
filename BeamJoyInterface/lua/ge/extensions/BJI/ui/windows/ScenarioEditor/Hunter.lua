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

local function onClose()
    BJI.Managers.WaypointEdit.reset()
    W.changed = false
    W.valid = true
end

local function reloadMarkers()
    local hunterColor = BJI.Utils.ShapeDrawer.Color(1, 1, 0, .5)
    local huntedColor = BJI.Utils.ShapeDrawer.Color(1, 0, 0, .5)
    BJI.Managers.WaypointEdit.reset()
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
    W.labels.buttons.errorMustHaveVehicle = BJI.Managers.Lang.get("hunter.edit.buttons.errorMustHaveVehicle")
    W.labels.buttons.errorInvalidData = BJI.Managers.Lang.get("hunter.edit.buttons.errorInvalidData")
end

local function udpateWidths()
    W.cache.labelsWidth = 0
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
            if data.cache == BJI.Managers.Cache.CACHES.HUNTER_DATA then
                updateCache()
            end
        end, W.name))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

local function validateData()
    W.valid = not W.cache.enabled or (
        #W.cache.targets >= 2 and
        #W.cache.hunterPositions >= 5 and
        #W.cache.huntedPositions > 0
    )
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
    LineBuilder():text(W.labels.title):btnIcon({
        id = "reloadMarkers",
        icon = ICONS.sync,
        style = BJI.Utils.Style.BTN_PRESETS.INFO,
        tooltip = W.labels.buttons.refreshMarkers,
        onClick = reloadMarkers,
    }):build()

    LineBuilder():text(W.labels.enabled):btnIconToggle({
        id = "toggleEnabled",
        icon = W.cache.enabled and ICONS.visibility or ICONS.visibility_off,
        state = W.cache.enabled == true,
        disabled = W.cache.disableButtons,
        tooltip = W.labels.buttons.toggleModeVisibility,
        onClick = function()
            local origin = W.cache.enabled
            W.cache.enabled = not W.cache.enabled
            checkEnabled()
            if origin ~= W.cache.enabled then
                W.changed = true
            end
        end
    }):build()
end

---@param ctxt TickContext
local function drawHunters(ctxt)
    W.cache.hunterPositions:forEach(function(hunterPoint, i)
        LineBuilder():text(W.labels.hunterPositionName:var({ index = i })):btnIcon({
            id = string.var("gotoHunter{1}", { i }),
            icon = ICONS.pin_drop,
            style = BJI.Utils.Style.BTN_PRESETS.INFO,
            tooltip = W.labels.buttons.showHunterStartPosition,
            onClick = function()
                if ctxt.isOwner then
                    if ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE then
                        BJI.Managers.Cam.toggleFreeCam()
                    end
                    BJI.Managers.Veh.setPositionRotation(hunterPoint.pos, hunterPoint.rot, { safe = false })
                else
                    if ctxt.camera ~= BJI.Managers.Cam.CAMERAS.FREE then
                        BJI.Managers.Cam.toggleFreeCam()
                    end
                    local pos = vec3(
                        hunterPoint.pos.x,
                        hunterPoint.pos.y,
                        hunterPoint.pos.z + 1
                    )
                    BJI.Managers.Cam.setPositionRotation(pos, hunterPoint.rot * quat(0, 0, 1, 0))
                end
            end,
        }):btnIcon({
            id = string.var("moveHunter{1}", { i }),
            icon = ICONS.edit_location,
            style = BJI.Utils.Style.BTN_PRESETS.WARNING,
            disabled = W.cache.disableButtons or not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE,
            tooltip = string.var("{1}{2}", {
                W.labels.buttons.setHunterStartPositionHere,
                (not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE) and
                " (" .. W.labels.buttons.errorMustHaveVehicle .. ")" or ""
            }),
            onClick = function()
                W.cache.hunterPositions[i] = ctxt.vehPosRot
                W.changed = true
                reloadMarkers()
                validateData()
            end,
        }):btnIcon({
            id = string.var("deleteHunter{1}", { i }),
            icon = ICONS.delete_forever,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            disabled = W.cache.disableButtons,
            tooltip = W.labels.buttons.deleteHunterStartPosition,
            onClick = function()
                W.cache.hunterPositions:remove(i)
                W.changed = true
                reloadMarkers()
                validateData()
            end,
        }):build()
    end)
end

---@param ctxt TickContext
local function drawHunted(ctxt)
    W.cache.huntedPositions:forEach(function(huntedPoint, i)
        LineBuilder():text(W.labels.huntedPositionName:var({ index = i })):btnIcon({
            id = string.var("gotoHunted{1}", { i }),
            icon = ICONS.pin_drop,
            style = BJI.Utils.Style.BTN_PRESETS.INFO,
            tooltip = W.labels.buttons.showHuntedStartPosition,
            onClick = function()
                if ctxt.isOwner then
                    if ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE then
                        BJI.Managers.Cam.toggleFreeCam()
                    end
                    BJI.Managers.Veh.setPositionRotation(huntedPoint.pos, huntedPoint.rot, { safe = false })
                else
                    if ctxt.camera ~= BJI.Managers.Cam.CAMERAS.FREE then
                        BJI.Managers.Cam.toggleFreeCam()
                    end
                    local pos = vec3(
                        huntedPoint.pos.x,
                        huntedPoint.pos.y,
                        huntedPoint.pos.z + 1
                    )
                    BJI.Managers.Cam.setPositionRotation(pos, huntedPoint.rot * quat(0, 0, 1, 0))
                end
            end,
        }):btnIcon({
            id = string.var("moveHunted{1}", { i }),
            icon = ICONS.edit_location,
            style = BJI.Utils.Style.BTN_PRESETS.WARNING,
            disabled = W.cache.disableButtons or not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE,
            tooltip = string.var("{1}{2}", {
                W.labels.buttons.setHuntedStartPositionHere,
                (not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE) and
                " (" .. W.labels.buttons.errorMustHaveVehicle .. ")" or ""
            }),
            onClick = function()
                W.cache.huntedPositions[i] = ctxt.vehPosRot
                W.changed = true
                reloadMarkers()
                validateData()
            end,
        }):btnIcon({
            id = string.var("deleteHunted{1}", { i }),
            icon = ICONS.delete_forever,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            disabled = W.cache.disableButtons,
            tooltip = W.labels.buttons.deleteHuntedStartPosition,
            onClick = function()
                W.cache.huntedPositions:remove(i)
                W.changed = true
                reloadMarkers()
                validateData()
            end,
        }):build()
    end)
end

---@param ctxt TickContext
local function drawWaypoints(ctxt)
    W.cache.targets:forEach(function(waypoint, i)
        LineBuilder():text(W.labels.targetName:var({ index = i })):btnIcon({
            id = string.var("gotoWaypoint{1}", { i }),
            icon = ICONS.pin_drop,
            style = BJI.Utils.Style.BTN_PRESETS.INFO,
            tooltip = W.labels.buttons.showWaypoint,
            onClick = function()
                if ctxt.isOwner then
                    if ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE then
                        BJI.Managers.Cam.toggleFreeCam()
                    end
                    BJI.Managers.Veh.setPositionRotation(waypoint.pos, ctxt.vehPosRot.rot, { safe = false })
                else
                    if ctxt.camera ~= BJI.Managers.Cam.CAMERAS.FREE then
                        BJI.Managers.Cam.toggleFreeCam()
                    end
                    local pos = vec3(
                        waypoint.pos.x,
                        waypoint.pos.y,
                        waypoint.pos.z + 1
                    )
                    BJI.Managers.Cam.setPositionRotation(pos)
                end
            end,
        }):btnIcon({
            id = string.var("moveWaypoint{1}", { i }),
            icon = ICONS.edit_location,
            style = BJI.Utils.Style.BTN_PRESETS.WARNING,
            disabled = W.cache.disableInputs or not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE,
            tooltip = string.var("{1}{2}", {
                W.labels.buttons.setWaypointHere,
                (not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE) and
                " (" .. W.labels.buttons.errorMustHaveVehicle .. ")" or ""
            }),
            onClick = function()
                waypoint.pos = ctxt.vehPosRot.pos
                W.changed = true
                reloadMarkers()
                validateData()
            end,
        }):btnIcon({
            id = string.var("deleteWaypoint{1}", { i }),
            icon = ICONS.delete_forever,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            disabled = W.cache.disableInputs,
            tooltip = W.labels.buttons.deleteWaypoint,
            onClick = function()
                W.cache.targets:remove(i)
                W.changed = true
                reloadMarkers()
                validateData()
            end,
        }):build()

        Indent(1)
        LineBuilder():text(W.labels.radius):inputNumeric({
            id = string.var("radiusWaypoint{1}", { i }),
            type = "float",
            precision = 1,
            value = waypoint.radius,
            min = 1,
            max = 50,
            step = .5,
            stepFast = 2,
            disabled = W.cache.disableInputs,
            onUpdate = function(val)
                waypoint.radius = val
                W.changed = true
                reloadMarkers()
                validateData()
            end
        }):build()
        Indent(-1)
    end)
end

---@param ctxt TickContext
local function body(ctxt)
    AccordionBuilder():label(BJI.Managers.Lang.get("hunter.edit.hunters")):commonStart(function(isOpen)
        local line = LineBuilder(true):text(string.var("({1})", { #W.cache.hunterPositions }))
        if isOpen then
            line:btnIcon({
                id = "addHunterPosition",
                icon = ICONS.add_location,
                style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                disabled = W.cache.disableInputs or not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE,
                tooltip = string.var("{1}{2}", {
                    W.labels.buttons.addHunterStartPositionHere,
                    (not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE) and
                    " (" .. W.labels.buttons.errorMustHaveVehicle .. ")" or ""
                }),
                onClick = function()
                    W.cache.hunterPositions:insert(ctxt.vehPosRot)
                    W.changed = true
                    reloadMarkers()
                    validateData()
                end
            })
        end
        if #W.cache.hunterPositions < 5 then
            line:text(W.labels.missingPoints:var({ amount = 5 - #W.cache.hunterPositions }),
                BJI.Utils.Style.TEXT_COLORS.ERROR)
        end
        line:build()
    end):openedBehavior(function()
        drawHunters(ctxt)
    end):build()

    AccordionBuilder():label(BJI.Managers.Lang.get("hunter.edit.hunted")):commonStart(function(isOpen)
        local line = LineBuilder(true):text(string.var("({1})", { #W.cache.huntedPositions }))
        if isOpen then
            line:btnIcon({
                id = "addHuntedPosition",
                icon = ICONS.add_location,
                style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                disabled = W.cache.disableInputs or not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE,
                tooltip = string.var("{1}{2}", {
                    W.labels.buttons.addHuntedStartPositionHere,
                    (not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE) and
                    " (" .. W.labels.buttons.errorMustHaveVehicle .. ")" or ""
                }),
                onClick = function()
                    W.cache.huntedPositions:insert(ctxt.vehPosRot)
                    W.changed = true
                    reloadMarkers()
                    validateData()
                end
            })
        end
        if #W.cache.huntedPositions < 2 then
            line:text(W.labels.missingPoints:var({ amount = 2 - #W.cache.huntedPositions }),
                BJI.Utils.Style.TEXT_COLORS.ERROR)
        end
        line:build()
    end):openedBehavior(function()
        drawHunted(ctxt)
    end):build()

    AccordionBuilder():label(BJI.Managers.Lang.get("hunter.edit.waypoints")):commonStart(function(isOpen)
        local line = LineBuilder(true):text(string.var("({1})", { #W.cache.targets }))
        if isOpen then
            line:btnIcon({
                id = "addWaypoint",
                icon = ICONS.add_location,
                style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                disabled = W.cache.disableInputs or not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE,
                tooltip = string.var("{1}{2}", {
                    W.labels.buttons.addWaypointHere,
                    (not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE) and
                    " (" .. W.labels.buttons.errorMustHaveVehicle .. ")" or ""
                }),
                onClick = function()
                    W.cache.targets:insert({
                        pos = ctxt.vehPosRot.pos,
                        radius = 2,
                    })
                    W.changed = true
                    reloadMarkers()
                    validateData()
                end
            })
        end
        if #W.cache.targets < 2 then
            line:text(W.labels.missingPoints:var({ amount = 2 - #W.cache.targets }),
                BJI.Utils.Style.TEXT_COLORS.ERROR)
        end
        line:build()
    end):openedBehavior(function()
        drawWaypoints(ctxt)
    end):build()
end

---@param ctxt TickContext
local function footer(ctxt)
    local line = LineBuilder():btnIcon({
        id = "cancelHunterEdit",
        icon = ICONS.exit_to_app,
        style = BJI.Utils.Style.BTN_PRESETS.ERROR,
        tooltip = W.labels.buttons.close,
        onClick = BJI.Windows.ScenarioEditor.onClose,
    })
    if W.changed then
        line:btnIcon({
            id = "saveHunterEdit",
            icon = ICONS.save,
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            disabled = W.cache.disableButtons or not W.valid,
            tooltip = string.var("{1}{2}", {
                W.labels.buttons.save,
                not W.valid and " (" .. W.labels.buttons.errorMustHaveVehicle .. ")" or ""
            }),
            onClick = save,
        })
    end
    line:build()
end

local function open()
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
