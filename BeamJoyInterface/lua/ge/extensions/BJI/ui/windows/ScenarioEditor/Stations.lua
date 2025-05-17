local W = {
    labels = {
        vSeparator = "",
        title = "",
        energyTypes = {},
        name = "",
        types = "",
        radius = "",
    },
    cache = {
        stationsCounts = {},
        labelsWidth = 0,
        stations = Table(),
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
    BJI.Managers.WaypointEdit.setWaypoints(Table(W.cache.stations)
        :map(function(s)
            return {
                name = s.name,
                pos = s.pos,
                radius = s.radius,
                type = BJI.Managers.WaypointEdit.TYPES.SPHERE,
            }
        end))
end

local function updateLabels()
    W.labels.vSeparator = BJI.Managers.Lang.get("common.vSeparator")

    W.labels.title = BJI.Managers.Lang.get("energyStations.edit.title")
    W.labels.energyTypes = Table(BJI.CONSTANTS.ENERGY_STATION_TYPES):reduce(function(res, energyType)
        res[energyType] = BJI.Managers.Lang.get(string.var("energy.energyTypes.{1}", { energyType }))
        return res
    end, Table())

    W.labels.name = BJI.Managers.Lang.get("energyStations.edit.name")
    W.labels.types = BJI.Managers.Lang.get("energyStations.edit.types")
    W.labels.radius = BJI.Managers.Lang.get("energyStations.edit.radius")
end

local function udpateWidths()
    W.cache.labelsWidth = Table({ W.labels.name, W.labels.types, W.labels.radius })
        :reduce(function(res, label)
            local w = BJI.Utils.Common.GetColumnTextWidth(label)
            return w > res and w or res
        end, 0)
end

local function updateCache()
    W.cache.stationsCounts = Table()
    Table(BJI.CONSTANTS.ENERGY_STATION_TYPES):forEach(function(energyType)
        W.cache.stationsCounts[energyType] = 0
    end)
    Table(W.cache.stations):forEach(function(s)
        s.types:forEach(function(energyType)
            W.cache.stationsCounts[energyType] = W.cache.stationsCounts[energyType] + 1
        end)
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
    end))

    udpateWidths()
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED, udpateWidths))

    updateCache()
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.CACHE_LOADED,
        function(_, data)
            if data.cache == BJI.Managers.Cache.CACHES.STATIONS then
                updateCache()
            end
        end))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
    BJI.Managers.WaypointEdit.reset()
end

local function validateStations()
    W.valid = #W.cache.stations == 0 or (
        W.cache.stations:every(function(s)
            return #s.name:trim() > 0 and #s.types > 0 and s.radius > 0 and s.pos ~= nil
        end) and
        not W.cache.stations:any(function(s1)
            return W.cache.stations:any(function(s2)
                return s1 ~= s2 and s1.name:trim() == s2.name:trim()
            end)
        end)
    )
end

local function save()
    W.cache.disableInputs = true
    BJI.Tx.scenario.EnergyStationsSave(W.cache.stations:map(function(s)
        return math.roundPositionRotation({
            name = s.name,
            types = table.clone(s.types),
            radius = s.radius,
            pos = vec3(s.pos.x, s.pos.y, s.pos.z)
        })
    end), function(result)
        if result then
            W.changed = false
        else
            BJI.Managers.Toast.error(BJI.Managers.Lang.get("energyStations.edit.saveErrorToast"))
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
        id = "createStation",
        icon = ICONS.add_location,
        style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
        disabled = W.cache.disableInputs or ctxt.camera ~= BJI.Managers.Cam.CAMERAS.FREE,
        onClick = function()
            table.insert(W.cache.stations, {
                name = "",
                types = Table(),
                radius = 2.5,
                pos = BJI.Managers.Cam.getPositionRotation().pos,
            })
            W.changed = true
            reloadMarkers()
            validateStations()
        end
    }):build()

    LineLabel(Table(BJI.CONSTANTS.ENERGY_STATION_TYPES):map(function(energyType)
        return string.var("{1} : {2}", {
            W.labels.energyTypes[energyType],
            W.cache.stationsCounts[energyType] or 0
        })
    end):values():sort():join(string.var(" {1} ", { W.labels.vSeparator })))
end

local function body(ctxt)
    W.cache.stations:reduce(function(cols, station, i)
        local invalidName = #station.name:trim() == 0
        return cols:addRow({
                cells = {
                    function() LineLabel(W.labels.name, invalidName and BJI.Utils.Style.TEXT_COLORS.ERROR or nil) end,
                    function()
                        LineBuilder():inputString({
                            id = string.var("nameStation{1}", { i }),
                            style = invalidName and BJI.Utils.Style.INPUT_PRESETS.ERROR or nil,
                            value = station.name,
                            disabled = W.cache.disableInputs,
                            onUpdate = function(val)
                                station.name = val
                                W.changed = true
                                reloadMarkers()
                                validateStations()
                            end
                        }):build()
                    end,
                }
            })
            :addRow({
                cells = {
                    function() LineLabel(W.labels.types, #station.types == 0 and BJI.Utils.Style.TEXT_COLORS.ERROR or nil) end,
                    function()
                        local line = LineBuilder()
                        Table(BJI.CONSTANTS.ENERGY_STATION_TYPES)
                            :forEach(function(energyType)
                                line:btnSwitch({
                                    id = string.var("typeStation{1}{2}", { i, energyType }),
                                    labelOn = W.labels.energyTypes[energyType],
                                    labelOff = W.labels.energyTypes[energyType],
                                    state = station.types:includes(energyType),
                                    disabled = W.cache.disableInputs,
                                    onClick = function()
                                        local pos = table.indexOf(station.types, energyType)
                                        if pos then
                                            W.cache.stationsCounts[energyType] = W.cache.stationsCounts[energyType] - 1
                                            table.remove(station.types, pos)
                                        else
                                            W.cache.stationsCounts[energyType] = W.cache.stationsCounts[energyType] + 1
                                            table.insert(station.types, energyType)
                                        end
                                        W.changed = true
                                        validateStations()
                                    end
                                })
                            end)
                        line:build()
                    end,
                }
            })
            :addRow({
                cells = {
                    function() LineLabel(W.labels.radius) end,
                    function()
                        LineBuilder():inputNumeric({
                            id = string.var("radiusStation{1}", { i }),
                            type = "float",
                            precision = 1,
                            value = station.radius,
                            disabled = W.cache.disableInputs,
                            min = 1,
                            max = 20,
                            step = 1,
                            onUpdate = function(val)
                                station.radius = val
                                W.changed = true
                                reloadMarkers()
                                validateStations()
                            end
                        }):build()
                    end,
                }
            }):addRow({
                cells = {
                    nil,
                    function()
                        LineBuilder()
                            :btnIcon({
                                id = string.var("goToStation{1}", { i }),
                                icon = ICONS.pin_drop,
                                style = BJI.Utils.Style.BTN_PRESETS.INFO,
                                onClick = function()
                                    if ctxt.camera ~= BJI.Managers.Cam.CAMERAS.FREE then
                                        BJI.Managers.Cam.toggleFreeCam()
                                    end
                                    BJI.Managers.Cam.setPositionRotation(station.pos)
                                end
                            })
                            :btnIcon({
                                id = string.var("moveStation{1}", { i }),
                                icon = ICONS.edit_location,
                                style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                                disabled = W.cache.disableInputs or ctxt.camera ~= BJI.Managers.Cam.CAMERAS.FREE,
                                onClick = function()
                                    station.pos = BJI.Managers.Cam.getPositionRotation().pos
                                    W.changed = true
                                    reloadMarkers()
                                    validateStations()
                                end
                            })
                            :btnIcon({
                                id = string.var("deleteStation{1}", { i }),
                                icon = ICONS.delete_forever,
                                style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                                disabled = W.cache.disableInputs,
                                onClick = function()
                                    station.types:forEach(function(energyType)
                                        W.cache.stationsCounts[energyType] = W.cache.stationsCounts[energyType] - 1
                                    end)
                                    W.cache.stations:remove(i)
                                    W.changed = true
                                    reloadMarkers()
                                    validateStations()
                                end
                            })
                            :build()
                    end,
                }
            }):addSeparator()
    end, ColumnsBuilder("BJIScenarioEditorEnergyStations", { W.cache.labelsWidth, -1 })):build()
end

local function footer(ctxt)
    local line = LineBuilder()
        :btnIcon({
            id = "closeEnergyStations",
            icon = ICONS.exit_to_app,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            onClick = BJI.Windows.ScenarioEditor.onClose,
        })
    if W.changed then
        line:btnIcon({
            id = "saveEnergyStations",
            icon = ICONS.save,
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            disabled = W.cache.disableInputs or not W.valid,
            onClick = save,
        })
    end
    line:build()
end

local function open()
    W.cache.stations = Table(BJI.Managers.Context.Scenario.Data.EnergyStations)
        :map(function(s)
            return {
                name = s.name,
                types = Table(s.types):clone(),
                radius = s.radius,
                pos = vec3(s.pos),
            }
        end)
    validateStations()
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
