local W = {
    name = "ScenarioEditorGarages",

    labels = {
        title = "",
        name = "",
        radius = "",
    },
    cache = {
        labelsWidth = 0,
        garages = Table(),
        disableInputs = false,
    },
    changed = false,
    valid = true,
}

local function onClose()
    BJI.Managers.WaypointEdit.reset()
end

local function reloadMarkers()
    BJI.Managers.WaypointEdit.reset()
    BJI.Managers.WaypointEdit.setWaypoints(Table(W.cache.garages)
        :map(function(g)
            return {
                name = g.name,
                pos = g.pos,
                radius = g.radius,
                type = BJI.Managers.WaypointEdit.TYPES.SPHERE
            }
        end))
end

local function updateLabels()
    W.labels.title = BJI.Managers.Lang.get("garages.edit.title")

    W.labels.name = BJI.Managers.Lang.get("garages.edit.name")
    W.labels.radius = BJI.Managers.Lang.get("garages.edit.radius")
end

local function udpateWidths()
    W.cache.labelsWidth = Table({ W.labels.name, W.labels.radius })
        :reduce(function(res, label)
            local w = BJI.Utils.Common.GetColumnTextWidth(label)
            return w > res and w or res
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
            if data.cache == BJI.Managers.Cache.CACHES.STATIONS then
                updateCache()
            end
        end, W.name))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
    BJI.Managers.WaypointEdit.reset()
end

local function validateGarages()
    W.valid = #W.cache.garages == 0 or (
        W.cache.garages:every(function(g)
            return #g.name:trim() > 0 and g.radius > 0 and g.pos ~= nil
        end) and
        not W.cache.garages:any(function(g1)
            return W.cache.garages:any(function(g2)
                return g1 ~= g2 and g1.name:trim() == g2.name:trim()
            end)
        end)
    )
end

local function save()
    W.cache.disableInputs = true
    BJI.Tx.scenario.GaragesSave(W.cache.garages:map(function(g)
        return math.roundPositionRotation({
            name = g.name,
            radius = g.radius,
            pos = vec3(g.pos.x, g.pos.y, g.pos.z),
        })
    end), function(result)
        if result then
            W.changed = false
        else
            BJI.Managers.Toast.error(BJI.Managers.Lang.get("garages.edit.saveErrorToast"))
        end
        W.cache.disableInputs = false
    end)
end

local function header(ctxt)
    LineBuilder():text(W.labels.title)
        :btnIcon({
            id = "reloadMarkers",
            icon = ICONS.sync,
            style = BJI.Utils.Style.BTN_PRESETS.INFO,
            onClick = reloadMarkers,
        }):btnIcon({
        id = "createGarage",
        icon = ICONS.add_location,
        style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
        disabled = W.cache.disableInputs or ctxt.camera ~= BJI.Managers.Cam.CAMERAS.FREE,
        onClick = function()
            W.cache.garages:insert({
                name = "",
                radius = 5,
                pos = BJI.Managers.Cam.getPositionRotation().pos,
            })
            W.changed = true
            reloadMarkers()
            validateGarages()
        end
    }):build()
end

local function body(ctxt)
    W.cache.garages:reduce(function(cols, garage, i)
        local invalidName = #garage.name:trim() == 0
        return cols
            :addRow({
                cells = {
                    function() LineLabel(W.labels.name, invalidName and BJI.Utils.Style.TEXT_COLORS.ERROR or nil) end,
                    function()
                        LineBuilder():inputString({
                            id = string.var("nameGarage{1}", { i }),
                            style = invalidName and BJI.Utils.Style.INPUT_PRESETS.ERROR or nil,
                            disabled = W.cache.disableInputs,
                            value = garage.name,
                            onUpdate = function(val)
                                garage.name = val
                                W.changed = true
                                reloadMarkers()
                                validateGarages()
                            end
                        }):build()
                    end,
                }
            })
            :addRow({
                cells = {
                    function() LineLabel(W.labels.radius) end,
                    function()
                        LineBuilder()
                            :inputNumeric({
                                id = string.var("radiusGarage{1}", { i }),
                                type = "float",
                                precision = 1,
                                value = garage.radius,
                                min = 1,
                                max = 50,
                                step = 1,
                                stepFast = 3,
                                disabled = W.cache.disableInputs,
                                onUpdate = function(val)
                                    garage.radius = val
                                    W.changed = true
                                    reloadMarkers()
                                    validateGarages()
                                end,
                            })
                            :build()
                    end,
                }
            })
            :addRow({
                cells = {
                    nil,
                    function()
                        LineBuilder()
                            :btnIcon({
                                id = string.var("goto{1}", { i }),
                                icon = ICONS.pin_drop,
                                style = BJI.Utils.Style.BTN_PRESETS.INFO,
                                onClick = function()
                                    if ctxt.camera ~= BJI.Managers.Cam.CAMERAS.FREE then
                                        BJI.Managers.Cam.toggleFreeCam()
                                    end
                                    BJI.Managers.Cam.setPositionRotation(garage.pos)
                                end
                            })
                            :btnIcon({
                                id = string.var("moveGarage{1}", { i }),
                                icon = ICONS.edit_location,
                                style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                                disabled = W.cache.disableInputs or ctxt.camera ~= BJI.Managers.Cam.CAMERAS.FREE,
                                onClick = function()
                                    garage.pos = BJI.Managers.Cam.getPositionRotation().pos
                                    W.changed = true
                                    reloadMarkers()
                                end
                            })
                            :btnIcon({
                                id = string.var("deleteGarage{1}", { i }),
                                icon = ICONS.delete_forever,
                                style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                                disabled = W.cache.disableInputs,
                                onClick = function()
                                    table.remove(W.cache.garages, i)
                                    W.changed = true
                                    reloadMarkers()
                                end
                            })
                            :build()
                    end,
                }
            }):addSeparator()
    end, ColumnsBuilder("BJIScenarioEditorGarages", { W.cache.labelsWidth, -1 })):build()
end

local function footer(ctxt)
    local line = LineBuilder()
        :btnIcon({
            id = "cancelGaragesEdit",
            icon = ICONS.exit_to_app,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            onClick = BJI.Windows.ScenarioEditor.onClose,
        })
    if W.changed then
        line:btnIcon({
            id = "saveGaragesEdit",
            icon = ICONS.save,
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            disabled = W.cache.disableInputs or not W.valid,
            onClick = save,
        })
    end
    line:build()
end

local function open()
    W.cache.garages = Table(BJI.Managers.Context.Scenario.Data.Garages)
        :map(function(g)
            return {
                name = g.name,
                radius = g.radius,
                pos = vec3(g.pos),
            }
        end)
    validateGarages()
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
