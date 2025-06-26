local W = {
    name = "ScenarioEditorStations",

    labels = {
        vSeparator = "",
        title = "",
        energyTypes = {},
        name = "",
        types = "",
        radius = "",

        buttons = {
            refreshMarkers = "",
            addStationHere = "",
            showStation = "",
            setStationHere = "",
            deleteStation = "",
            close = "",
            save = "",
            errorMustBeFreecaming = "",
            errorInvalidData = "",
        },
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
    W.changed = false
    W.valid = true
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

    W.labels.buttons.refreshMarkers = BJI.Managers.Lang.get("energyStations.edit.buttons.refreshMarkers")
    W.labels.buttons.addStationHere = BJI.Managers.Lang.get("energyStations.edit.buttons.addStationHere")
    W.labels.buttons.showStation = BJI.Managers.Lang.get("energyStations.edit.buttons.showStation")
    W.labels.buttons.setStationHere = BJI.Managers.Lang.get("energyStations.edit.buttons.setStationHere")
    W.labels.buttons.deleteStation = BJI.Managers.Lang.get("energyStations.edit.buttons.deleteStation")
    W.labels.buttons.close = BJI.Managers.Lang.get("common.buttons.close")
    W.labels.buttons.save = BJI.Managers.Lang.get("common.buttons.save")
    W.labels.buttons.errorMustBeFreecaming = BJI.Managers.Lang.get("errors.mustBeFreecaming")
    W.labels.buttons.errorInvalidData = BJI.Managers.Lang.get("errors.someDataAreInvalid")
end

local function udpateWidths()
    W.cache.labelsWidth = Table({ W.labels.name, W.labels.types, W.labels.radius })
        :reduce(function(res, label)
            local w = BJI.Utils.UI.GetColumnTextWidth(label)
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

local function validateStations()
    W.valid = #W.cache.stations == 0 or (
        W.cache.stations:every(function(s)
            return #s.name:trim() > 0 and #s.types > 0 and s.radius > 0 and s.pos ~= nil
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
    LineBuilder():text(W.labels.title):btnIcon({
        id = "reloadMarkers",
        icon = BJI.Utils.Icon.ICONS.sync,
        style = BJI.Utils.Style.BTN_PRESETS.INFO,
        tooltip = W.labels.buttons.refreshMarkers,
        onClick = reloadMarkers,
    }):btnIcon({
        id = "createStation",
        icon = BJI.Utils.Icon.ICONS.add_location,
        style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
        disabled = W.cache.disableInputs or ctxt.camera ~= BJI.Managers.Cam.CAMERAS.FREE,
        tooltip = string.var("{1}{2}", {
            W.labels.buttons.addStationHere,
            (ctxt.camera ~= BJI.Managers.Cam.CAMERAS.FREE) and
            " (" .. W.labels.buttons.errorMustBeFreecaming .. ")" or ""
        }),
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
                        LineBuilder():btnIcon({
                            id = string.var("goToStation{1}", { i }),
                            icon = BJI.Utils.Icon.ICONS.pin_drop,
                            style = BJI.Utils.Style.BTN_PRESETS.INFO,
                            tooltip = W.labels.buttons.showStation,
                            onClick = function()
                                if ctxt.camera ~= BJI.Managers.Cam.CAMERAS.FREE then
                                    BJI.Managers.Cam.toggleFreeCam()
                                end
                                BJI.Managers.Cam.setPositionRotation(station.pos)
                            end
                        }):btnIcon({
                            id = string.var("moveStation{1}", { i }),
                            icon = BJI.Utils.Icon.ICONS.edit_location,
                            style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                            disabled = W.cache.disableInputs or ctxt.camera ~= BJI.Managers.Cam.CAMERAS.FREE,
                            tooltip = string.var("{1}{2}", {
                                W.labels.buttons.setStationHere,
                                (ctxt.camera ~= BJI.Managers.Cam.CAMERAS.FREE) and
                                " (" .. W.labels.buttons.errorMustBeFreecaming .. ")" or ""
                            }),
                            onClick = function()
                                station.pos = BJI.Managers.Cam.getPositionRotation().pos
                                W.changed = true
                                reloadMarkers()
                                validateStations()
                            end
                        }):btnIcon({
                            id = string.var("deleteStation{1}", { i }),
                            icon = BJI.Utils.Icon.ICONS.delete_forever,
                            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                            disabled = W.cache.disableInputs,
                            tooltip = W.labels.buttons.deleteStation,
                            onClick = function()
                                station.types:forEach(function(energyType)
                                    W.cache.stationsCounts[energyType] = W.cache.stationsCounts[energyType] - 1
                                end)
                                W.cache.stations:remove(i)
                                W.changed = true
                                reloadMarkers()
                                validateStations()
                            end
                        }):build()
                    end,
                }
            }):addSeparator()
    end, ColumnsBuilder("BJIScenarioEditorEnergyStations", { W.cache.labelsWidth, -1 })):build()
end

local function footer(ctxt)
    local line = LineBuilder():btnIcon({
        id = "closeEnergyStations",
        icon = BJI.Utils.Icon.ICONS.exit_to_app,
        style = BJI.Utils.Style.BTN_PRESETS.ERROR,
        tooltip = W.labels.buttons.close,
        onClick = BJI.Windows.ScenarioEditor.onClose,
    })
    if W.changed then
        line:btnIcon({
            id = "saveEnergyStations",
            icon = BJI.Utils.Icon.ICONS.save,
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            disabled = W.cache.disableInputs or not W.valid,
            tooltip = string.var("{1}{2}", { W.labels.buttons.save,
                not W.valid and " (" .. W.labels.buttons.errorInvalidData .. ")" or "" }),
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
