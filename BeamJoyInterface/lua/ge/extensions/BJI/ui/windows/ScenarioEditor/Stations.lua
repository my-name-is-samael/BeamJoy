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
        stations = Table(),
        disableInputs = false,
    },
    changed = false,
    valid = true,
}
--- gc prevention
local invalidName, nextValue

local function onClose()
    BJI_WaypointEdit.reset()
    W.changed = false
    W.valid = true
end

local function reloadMarkers()
    BJI_WaypointEdit.setWaypoints(Table(W.cache.stations)
        :map(function(s)
            return {
                name = s.name,
                pos = s.pos,
                radius = s.radius,
                type = BJI_WaypointEdit.TYPES.SPHERE,
            }
        end))
end

local function updateLabels()
    W.labels.vSeparator = BJI_Lang.get("common.vSeparator")

    W.labels.title = BJI_Lang.get("energyStations.edit.title")
    W.labels.energyTypes = Table(BJI.CONSTANTS.ENERGY_STATION_TYPES):reduce(function(res, energyType)
        res[energyType] = BJI_Lang.get(string.var("energy.energyTypes.{1}", { energyType }))
        return res
    end, Table())

    W.labels.name = BJI_Lang.get("energyStations.edit.name")
    W.labels.types = BJI_Lang.get("energyStations.edit.types")
    W.labels.radius = BJI_Lang.get("energyStations.edit.radius")

    W.labels.buttons.refreshMarkers = BJI_Lang.get("energyStations.edit.buttons.refreshMarkers")
    W.labels.buttons.addStationHere = BJI_Lang.get("energyStations.edit.buttons.addStationHere")
    W.labels.buttons.showStation = BJI_Lang.get("energyStations.edit.buttons.showStation")
    W.labels.buttons.setStationHere = BJI_Lang.get("energyStations.edit.buttons.setStationHere")
    W.labels.buttons.deleteStation = BJI_Lang.get("energyStations.edit.buttons.deleteStation")
    W.labels.buttons.close = BJI_Lang.get("common.buttons.close")
    W.labels.buttons.save = BJI_Lang.get("common.buttons.save")
    W.labels.buttons.errorMustBeFreecaming = BJI_Lang.get("errors.mustBeFreecaming")
    W.labels.buttons.errorInvalidData = BJI_Lang.get("errors.someDataAreInvalid")
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
    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.LANG_CHANGED, updateLabels, W.name))

    updateCache()
    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.CACHE_LOADED,
        function(_, data)
            if data.cache == BJI_Cache.CACHES.STATIONS then
                updateCache()
            end
        end, W.name))
end

local function onUnload()
    listeners:forEach(BJI_Events.removeListener)
    BJI_WaypointEdit.reset()
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
    BJI_Tx_scenario.EnergyStationsSave(W.cache.stations:map(function(s)
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
            BJI_Toast.error(BJI_Lang.get("energyStations.edit.saveErrorToast"))
        end
        W.cache.disableInputs = false
    end)
end

local function getPosition()
    local pos = BJI_Cam.getPositionRotation().pos + vec3(0, 0, 1)
    local surfaceDiff = be:getSurfaceHeightBelow(pos)
    return pos - vec3(0, 0, pos.z-surfaceDiff)
end

local function header(ctxt)
    Text(W.labels.title)
    SameLine()
    if IconButton("reloadMarkers", BJI.Utils.Icon.ICONS.sync,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.INFO }) then
        reloadMarkers()
    end
    TooltipText(W.labels.buttons.refreshMarkers)
    SameLine()
    if IconButton("createStation", BJI.Utils.Icon.ICONS.add_location,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                disabled = W.cache.disableInputs or ctxt.camera ~= BJI_Cam.CAMERAS.FREE }) then
        table.insert(W.cache.stations, {
            name = "",
            types = Table(),
            radius = 2.5,
            pos = getPosition(),
        })
        W.changed = true
        reloadMarkers()
        validateStations()
    end
    TooltipText(W.labels.buttons.addStationHere ..
        (ctxt.camera ~= BJI_Cam.CAMERAS.FREE and
            (" (" .. W.labels.buttons.errorMustBeFreecaming .. ")") or ""))

    Text(Table(BJI.CONSTANTS.ENERGY_STATION_TYPES):map(function(energyType)
        return string.var("{1} : {2}", {
            W.labels.energyTypes[energyType],
            W.cache.stationsCounts[energyType] or 0
        })
    end):values():sort():join(string.var(" {1} ", { W.labels.vSeparator })))
end

local function body(ctxt)
    if BeginTable("BJIScenarioEditorEnergyStations", {
            { label = "##scenarioeditor-energystations-labels" },
            { label = "##scenarioeditor-energystations-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } }
        }) then
        W.cache.stations:forEach(function(s, i)
            TableNewRow()
            Icon(BJI.Utils.Icon.ICONS.local_gas_station)
            TableNextColumn()
            if IconButton("goToStation-" .. tostring(i), BJI.Utils.Icon.ICONS.pin_drop,
                    { disabled = W.cache.disableInputs }) then
                if ctxt.camera ~= BJI_Cam.CAMERAS.FREE then
                    BJI_Cam.toggleFreeCam()
                end
                BJI_Cam.setPositionRotation(s.pos)
            end
            TooltipText(W.labels.buttons.showStation)
            SameLine()
            if IconButton("moveStation-" .. tostring(i), BJI.Utils.Icon.ICONS.edit_location,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, disabled = W.cache.disableInputs or
                        ctxt.camera ~= BJI_Cam.CAMERAS.FREE }) then
                s.pos = getPosition()
                W.changed = true
                reloadMarkers()
                validateStations()
            end
            TooltipText(W.labels.buttons.setStationHere ..
                (ctxt.camera ~= BJI_Cam.CAMERAS.FREE and
                    " (" .. W.labels.buttons.errorMustBeFreecaming .. ")" or ""))
            SameLine()
            if IconButton("deleteStation-" .. tostring(i), BJI.Utils.Icon.ICONS.delete_forever,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = W.cache.disableInputs }) then
                s.types:forEach(function(energyType)
                    W.cache.stationsCounts[energyType] = W.cache.stationsCounts[energyType] - 1
                end)
                W.cache.stations:remove(i)
                W.changed = true
                reloadMarkers()
                validateStations()
            end
            TooltipText(W.labels.buttons.deleteStation)

            invalidName = #s.name:trim() == 0
            TableNewRow()
            Text(W.labels.name, { color = invalidName and BJI.Utils.Style.TEXT_COLORS.ERROR or nil })
            TableNextColumn()
            nextValue = InputText("nameStation" .. tostring(i), s.name, {
                disabled = W.cache.disableInputs,
                inputStyle = invalidName and BJI.Utils.Style.INPUT_PRESETS.ERROR or nil
            })
            if nextValue then
                s.name = nextValue
                W.changed = true
                reloadMarkers()
                validateStations()
            end

            TableNewRow()
            Text(W.labels.types, { color = #s.types == 0 and BJI.Utils.Style.TEXT_COLORS.ERROR or nil })
            TableNextColumn()
            Table(BJI.CONSTANTS.ENERGY_STATION_TYPES):values()
                :forEach(function(energyType, j)
                    if j > 1 then SameLine() end
                    if Button("type-station-" .. tostring(i) .. "-" .. energyType, W.labels.energyTypes[energyType],
                            { btnStyle = s.types:includes(energyType) and BJI.Utils.Style.BTN_PRESETS.SUCCESS or
                                BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = W.cache.disableInputs }) then
                        local pos = s.types:indexOf(energyType)
                        if pos then
                            W.cache.stationsCounts[energyType] = W.cache.stationsCounts[energyType] - 1
                            s.types:remove(pos)
                        else
                            W.cache.stationsCounts[energyType] = W.cache.stationsCounts[energyType] + 1
                            s.types:insert(energyType)
                        end
                        W.changed = true
                        validateStations()
                    end
                end)

            TableNewRow()
            Text(W.labels.radius)
            if i < #W.cache.stations then Separator() end
            TableNextColumn()
            nextValue = SliderFloatPrecision("radiusStation" .. tostring(i), s.radius, 1, 20,
                { precision = 1, disabled = W.cache.disableInputs, formatRender = "%.1fm" })
            if nextValue then
                s.radius = nextValue
                W.changed = true
                reloadMarkers()
                validateStations()
            end
        end)
        EndTable()
    end
end

local function footer(ctxt)
    if IconButton("closeEnergyStations", BJI.Utils.Icon.ICONS.exit_to_app,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
        BJI_Win_ScenarioEditor.onClose()
    end
    if W.changed then
        SameLine()
        if IconButton("saveEnergyStations", BJI.Utils.Icon.ICONS.save,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                    disabled = W.cache.disableInputs or not W.valid }) then
            save()
        end
        TooltipText(W.labels.buttons.save ..
            (not W.valid and " (" .. W.labels.buttons.errorInvalidData .. ")" or ""))
    end
end

local function open()
    W.cache.stations = Table(BJI_Stations.Data.EnergyStations)
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
    BJI_Win_ScenarioEditor.view = W
end

W.onLoad = onLoad
W.onUnload = onUnload
W.header = header
W.body = body
W.footer = footer
W.onClose = onClose
W.open = open

return W
