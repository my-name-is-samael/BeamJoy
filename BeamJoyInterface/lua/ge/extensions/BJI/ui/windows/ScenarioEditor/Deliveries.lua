local W = {
    name = "ScenarioEditorDeliveries",

    labels = {
        title = "",
        position = "",
        radius = "",

        buttons = {
            refreshMarkers = "",
            addPosition = "",
            showPosition = "",
            setPosition = "",
            deletePosition = "",
            close = "",
            save = "",
            errorMustHaveVehicle = "",
        },
    },
    cache = {
        labelsWidth = 0,
        iconWidth = 0,
        positions = Table(),
        disableInputs = false,
    },
    changed = false,
    valid = true,
}

local function onClose()
    BJI.Managers.WaypointEdit.reset()
    W.changed = false
    W.valid = true
end

local function reloadMarkers()
    BJI.Managers.WaypointEdit.reset()
    BJI.Managers.WaypointEdit.setWaypoints(Table(W.cache.positions)
        :map(function(position, i)
            return {
                name = W.labels.position:var({ index = i }),
                pos = position.pos,
                rot = position.rot,
                radius = position.radius,
                type = BJI.Managers.WaypointEdit.TYPES.CYLINDER,
            }
        end))
end

local function updateLabels()
    W.labels.title = BJI.Managers.Lang.get("delivery.edit.title")
    W.labels.position = BJI.Managers.Lang.get("delivery.edit.position")
    W.labels.radius = BJI.Managers.Lang.get("delivery.edit.radius")

    W.labels.buttons.refreshMarkers = BJI.Managers.Lang.get("delivery.edit.buttons.refreshMarkers")
    W.labels.buttons.addPosition = BJI.Managers.Lang.get("delivery.edit.buttons.addPosition")
    W.labels.buttons.showPosition = BJI.Managers.Lang.get("delivery.edit.buttons.showPosition")
    W.labels.buttons.setPosition = BJI.Managers.Lang.get("delivery.edit.buttons.setPosition")
    W.labels.buttons.deletePosition = BJI.Managers.Lang.get("delivery.edit.buttons.deletePosition")
    W.labels.buttons.close = BJI.Managers.Lang.get("common.buttons.close")
    W.labels.buttons.save = BJI.Managers.Lang.get("common.buttons.save")
    W.labels.buttons.errorMustHaveVehicle = BJI.Managers.Lang.get("delivery.edit.buttons.errorMustHaveVehicle")
end

local function udpateWidths()
    W.cache.iconWidth = BJI.Utils.UI.GetBtnIconSize()
    W.cache.labelsWidth = Range(1, #W.cache.positions)
        :map(function(i)
            return W.labels.position:var({ index = i })
        end)
        :addAll({ W.labels.radius })
        :reduce(function(res, label)
            local w = BJI.Utils.UI.GetColumnTextWidth(label)
            return w > res and w or res
        end, 0)
end

local function updateCache()
    W.cache.positions = Table(BJI.Managers.Context.Scenario.Data.Deliveries)
        :map(function(g)
            return {
                radius = g.radius,
                pos = vec3(g.pos),
                rot = quat(g.rot),
            }
        end)
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
            if data.cache == BJI.Managers.Cache.CACHES.DELIVERIES then
                updateCache()
            end
        end, W.name))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
    BJI.Managers.WaypointEdit.reset()
end

local function validatePositions()
    W.valid = #W.cache.positions == 0 or
        W.cache.positions:every(function(g)
            return g.radius > 0 and g.pos ~= nil and g.rot ~= nil
        end)
end

local function save()
    W.cache.disableInputs = true
    BJI.Tx.scenario.DeliverySave(W.cache.positions:map(function(p)
        return {
            radius = p.radius,
            pos = {
                x = p.pos.x,
                y = p.pos.y,
                z = p.pos.z,
            },
            rot = {
                x = p.rot.x,
                y = p.rot.y,
                z = p.rot.z,
                w = p.rot.w,
            }
        }
    end), function(result)
        if result then
            W.changed = false
        else
            BJI.Managers.Toast.error(BJI.Managers.Lang.get("delivery.edit.saveErrorToast"))
        end
        W.cache.disableInputs = false
    end)
end

local function header(ctxt)
    LineBuilder():text(W.labels.title)
        :btnIcon({
            id = "reloadMarkers",
            icon = BJI.Utils.Icon.ICONS.sync,
            style = BJI.Utils.Style.BTN_PRESETS.INFO,
            tooltip = W.labels.buttons.refreshMarkers,
            onClick = reloadMarkers,
        }):btnIcon({
        id = "createPosition",
        icon = BJI.Utils.Icon.ICONS.add_location,
        style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
        disabled = W.cache.disableInputs or not ctxt.veh,
        tooltip = string.var("{1}{2}", {
            W.labels.buttons.addPosition,
            not ctxt.veh and " (" .. W.labels.buttons.errorMustHaveVehicle .. ")" or ""
        }),
        onClick = function()
            W.cache.positions:insert({
                pos = vec3(ctxt.vehPosRot.pos),
                rot = quat(ctxt.vehPosRot.rot),
                radius = 2.5,
            })
            W.changed = true
            reloadMarkers()
            validatePositions()
            udpateWidths()
        end,
    }):build()
end

local function body(ctxt)
    W.cache.positions:reduce(function(cols, position, i)
        return cols:addRow({
                cells = {
                    function()
                        LineBuilder():icon({
                            icon = BJI.Utils.Icon.ICONS.simobject_bng_waypoint,
                        }):build()
                    end,
                    function() LineLabel(W.labels.position:var({ index = i })) end,
                    function()
                        LineBuilder()
                            :btnIcon({
                                id = string.var("goTo{1}", { i }),
                                icon = BJI.Utils.Icon.ICONS.pin_drop,
                                style = BJI.Utils.Style.BTN_PRESETS.INFO,
                                tooltip = W.labels.buttons.showPosition,
                                onClick = function()
                                    if ctxt.isOwner then
                                        BJI.Managers.Veh.setPositionRotation(position.pos, position.rot)
                                        if BJI.Managers.Cam.getCamera() == BJI.Managers.Cam.CAMERAS.FREE then
                                            BJI.Managers.Cam.toggleFreeCam()
                                        end
                                    else
                                        if BJI.Managers.Cam.getCamera() ~= BJI.Managers.Cam.CAMERAS.FREE then
                                            BJI.Managers.Cam.toggleFreeCam()
                                        end
                                        BJI.Managers.Cam.setPositionRotation(position.pos, position.rot)
                                    end
                                end,
                            })
                            :btnIcon({
                                id = string.var("movePos{1}", { i }),
                                icon = BJI.Utils.Icon.ICONS.edit_location,
                                style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                                disabled = W.cache.disableInputs or not ctxt.vehPosRot or
                                    ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE,
                                tooltip = string.var("{1}{2}", {
                                    W.labels.buttons.setPosition,
                                    (not ctxt.vehPosRot or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE) and
                                    " (" .. W.labels.buttons.errorMustHaveVehicle .. ")" or ""
                                }),
                                onClick = function()
                                    W.cache.positions[i].pos = ctxt.vehPosRot.pos
                                    W.cache.positions[i].rot = ctxt.vehPosRot.rot
                                    W.changed = true
                                    reloadMarkers()
                                    validatePositions()
                                end,
                            })
                            :btnIcon({
                                id = string.var("delete{1}", { i }),
                                icon = BJI.Utils.Icon.ICONS.delete_forever,
                                style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                                disabled = W.cache.disableInputs,
                                tooltip = W.labels.buttons.deletePosition,
                                onClick = function()
                                    W.cache.positions:remove(i)
                                    W.changed = true
                                    reloadMarkers()
                                    validatePositions()
                                    udpateWidths()
                                end
                            })
                            :build()
                    end
                }
            })
            :addRow({
                cells = {
                    nil,
                    function() LineLabel(W.labels.radius) end,
                    function()
                        LineBuilder():inputNumeric({
                            id = string.var("radius{1}", { i }),
                            type = "float",
                            precision = 1,
                            value = position.radius,
                            width = 120,
                            min = .5,
                            max = 50,
                            step = .5,
                            stepFast = 2,
                            disabled = W.cache.disableInputs,
                            onUpdate = function(val)
                                position.radius = val
                                W.changed = true
                                reloadMarkers()
                                validatePositions()
                            end,
                        }):build()
                    end
                }
            }):addSeparator()
    end, ColumnsBuilder("BJIScenarioEditorDeliveries", { W.cache.iconWidth, W.cache.labelsWidth, -1 })):build()
end

local function footer()
    local line = LineBuilder()
        :btnIcon({
            id = "cancel",
            icon = BJI.Utils.Icon.ICONS.exit_to_app,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            tooltip = W.labels.buttons.close,
            onClick = BJI.Windows.ScenarioEditor.onClose,
        })
    if W.changed then
        line:btnIcon({
            id = "save",
            icon = BJI.Utils.Icon.ICONS.save,
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            disabled = W.cache.disableInputs,
            tooltip = W.labels.buttons.save,
            onClick = save,
        })
    end
    line:build()
end

local function open()
    W.cache.positions = Table(BJI.Managers.Context.Scenario.Data.Deliveries)
        :map(function(g)
            return {
                radius = g.radius,
                pos = vec3(g.pos),
                rot = quat(g.rot),
            }
        end)
    validatePositions()
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
