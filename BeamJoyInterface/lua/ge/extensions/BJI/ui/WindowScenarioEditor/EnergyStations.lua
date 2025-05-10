local esEdit

local function reloadMarkers()
    BJIWaypointEdit.reset()

    local waypoints = {}
    for _, station in ipairs(esEdit.stations) do
        table.insert(waypoints, {
            name = station.name,
            pos = station.pos,
            radius = station.radius,
            type = BJIWaypointEdit.TYPES.SPHERE,
        })
    end

    if #waypoints > 0 then
        BJIWaypointEdit.setWaypoints(waypoints)
    end
end

local function save()
    local stations = {}
    for _, station in ipairs(esEdit.stations) do
        table.insert(stations, RoundPositionRotation({
            name = station.name,
            types = table.clone(station.types),
            radius = station.radius,
            pos = vec3(station.pos.x, station.pos.y, station.pos.z)
        }))
    end

    esEdit.processSave = true
    local _, err = pcall(BJITx.scenario.EnergyStationsSave, stations)
    if not err then
        BJIAsync.task(function()
            return esEdit.processSave and esEdit.saveSuccess ~= nil
        end, function()
            if esEdit.saveSuccess then
                esEdit.changed = false
            else
                -- error message
                BJIToast.error(BJILang.get("energyStations.edit.saveErrorToast"))
            end

            esEdit.processSave = nil
            esEdit.saveSuccess = nil
        end, "EnergyStationsSave")
    else
        esEdit.processSave = nil
    end
end

local function drawHeader(ctxt)
    esEdit = BJIContext.Scenario.EnergyStationsEdit or {}

    if not esEdit.init then
        esEdit.init = true
        reloadMarkers()
    end

    LineBuilder()
        :text(BJILang.get("energyStations.edit.title"))
        :btnIcon({
            id = "reloadMarkers",
            icon = ICONS.sync,
            style = BTN_PRESETS.INFO,
            onClick = reloadMarkers,
        })
        :build()

    local stations = {}
    for _, station in ipairs(esEdit.stations) do
        for _, energyType in ipairs(station.types) do
            if not stations[energyType] then
                stations[energyType] = 0
            end
            stations[energyType] = stations[energyType] + 1
        end
    end
    local line = LineBuilder()
    local i = 1
    for _, energyType in pairs(BJI_ENERGY_STATION_TYPES) do
        line:text(string.var("{1} : {2}", {
            BJILang.get(string.var("energy.energyTypes.{1}", { energyType })),
            stations[energyType] or 0
        }))
        if i < table.length(BJI_ENERGY_STATION_TYPES) then
            line:text(BJILang.get("common.vSeparator"))
        end
        i = i + 1
    end
    line:build()
end

local function drawBody(ctxt)
    esEdit.valid = true

    local labelWidth = 0
    for _, key in ipairs({
        "energyStations.edit.name",
        "energyStations.edit.types",
        "energyStations.edit.radius",
    }) do
        local label = BJILang.get(key)
        local w = GetColumnTextWidth(label)
        if w > labelWidth then
            labelWidth = w
        end
    end

    for i, station in ipairs(esEdit.stations) do
        local invalidName = #station.name:trim() == 0
        if invalidName then
            esEdit.valid = false
        elseif #station.types == 0 then
            esEdit.valid = false
        end

        ColumnsBuilder(string.var("BJIScenarioEditorEnergyStation{1}", { i }), { labelWidth, -1 })
            :addRow({
                cells = {
                    function()
                        LineBuilder()
                            :text(BJILang.get("energyStations.edit.name"),
                                invalidName and TEXT_COLORS.ERROR or TEXT_COLORS.DEFAULT)
                            :build()
                    end,
                    function()
                        LineBuilder()
                            :inputString({
                                id = string.var("nameStation{1}", { i }),
                                style = invalidName and INPUT_PRESETS.ERROR or INPUT_PRESETS.DEFAULT,
                                disabled = esEdit.processSave,
                                value = station.name,
                                size = station.name._size,
                                onUpdate = function(val)
                                    station.name = val
                                    esEdit.changed = true
                                    reloadMarkers()
                                end
                            })
                            :build()
                    end,
                }
            })
            :addRow({
                cells = {
                    function()
                        LineBuilder()
                            :text(BJILang.get("energyStations.edit.types"),
                                #station.types == 0 and TEXT_COLORS.ERROR or TEXT_COLORS.DEFAULT)
                            :build()
                    end,
                    function()
                        local line = LineBuilder()
                        for _, energyType in pairs(BJI_ENERGY_STATION_TYPES) do
                            local label = BJILang.get(string.var("energy.energyTypes.{1}", { energyType }))
                            line:btnSwitch({
                                id = string.var("typeStation{1}{2}", { i, energyType }),
                                labelOn = label,
                                labelOff = label,
                                state = table.includes(station.types, energyType),
                                disabled = esEdit.processSave,
                                onClick = function()
                                    local pos = table.indexOf(station.types, energyType)
                                    if pos then
                                        table.remove(station.types, pos)
                                    else
                                        table.insert(station.types, energyType)
                                    end
                                    esEdit.changed = true
                                end
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
                            :text(BJILang.get("energyStations.edit.radius"))
                            :build()
                    end,
                    function()
                        LineBuilder()
                            :inputNumeric({
                                id = string.var("radiusStation{1}", { i }),
                                type = "float",
                                precision = 1,
                                value = station.radius,
                                disabled = esEdit.processSave,
                                min = 1,
                                max = 20,
                                step = 1,
                                onUpdate = function(val)
                                    station.radius = val
                                    esEdit.changed = true
                                    reloadMarkers()
                                end
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
                                id = string.var("goToStation{1}", { i }),
                                icon = ICONS.cameraFocusTopDown,
                                style = BTN_PRESETS.INFO,
                                onClick = function()
                                    if ctxt.camera ~= BJICam.CAMERAS.FREE then
                                        BJICam.setCamera(BJICam.CAMERAS.FREE)
                                    end
                                    BJICam.setPositionRotation(station.pos)
                                end
                            })
                            :btnIcon({
                                id = string.var("moveStation{1}", { i }),
                                icon = ICONS.crosshair,
                                style = BTN_PRESETS.WARNING,
                                disabled = ctxt.camera ~= BJICam.CAMERAS.FREE or esEdit.processSave,
                                onClick = function()
                                    station.pos = BJICam.getPositionRotation().pos
                                    esEdit.changed = true
                                    reloadMarkers()
                                end
                            })
                            :btnIcon({
                                id = string.var("deleteStation{1}", { i }),
                                icon = ICONS.delete_forever,
                                style = BTN_PRESETS.ERROR,
                                disabled = esEdit.processSave,
                                onClick = function()
                                    table.remove(esEdit.stations, i)
                                    esEdit.changed = true
                                    reloadMarkers()
                                end
                            })
                            :build()
                    end,
                }
            })
            :build()
        Separator()
    end
    LineBuilder()
        :btnIcon({
            id = "createStation",
            icon = ICONS.addListItem,
            style = BTN_PRESETS.SUCCESS,
            disabled = ctxt.camera ~= BJICam.CAMERAS.FREE or esEdit.processSave,
            onClick = function()
                table.insert(esEdit.stations, {
                    name = "",
                    types = {},
                    radius = 2.5,
                    pos = BJICam.getPositionRotation().pos,
                })
                esEdit.changed = true
                reloadMarkers()
            end
        })
        :build()
end

local function drawFooter(ctxt)
    local line = LineBuilder()
        :btnIcon({
            id = "cancelEnergyStationsEdit",
            icon = ICONS.exit_to_app,
            style = BTN_PRESETS.ERROR,
            onClick = function()
                BJIContext.Scenario.EnergyStationsEdit = nil
                BJIWaypointEdit.reset()
            end,
        })
    if esEdit.changed then
        line:btnIcon({
            id = "saveEnergyStationsEdit",
            icon = ICONS.save,
            style = BTN_PRESETS.SUCCESS,
            disabled = not esEdit.valid or esEdit.processSave,
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
    onClose = function()
        BJIContext.Scenario.EnergyStationsEdit = nil
        BJIWaypointEdit.reset()
    end,
}
