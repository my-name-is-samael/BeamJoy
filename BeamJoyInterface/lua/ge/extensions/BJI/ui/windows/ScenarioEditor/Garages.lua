local W = {
    name = "ScenarioEditorGarages",

    labels = {
        title = "",
        name = "",
        radius = "",

        buttons = {
            refreshMarkers = "",
            addGarageHere = "",
            showGarage = "",
            setGarageHere = "",
            deleteGarage = "",
            close = "",
            save = "",
            errorMustBeFreecaming = "",
            errorInvalidData = "",
        },
    },
    cache = {
        garages = Table(),
        disableInputs = false,
    },
    changed = false,
    valid = true,
}
--- gc prevention
local nextValue, invalidName

local function onClose()
    BJI_WaypointEdit.reset()
    W.changed = false
    W.valid = true
end

local function reloadMarkers()
    BJI_WaypointEdit.setWaypoints(Table(W.cache.garages)
        :map(function(g)
            return {
                name = g.name,
                pos = g.pos,
                radius = g.radius,
                type = BJI_WaypointEdit.TYPES.SPHERE
            }
        end))
end

local function updateLabels()
    W.labels.title = BJI_Lang.get("garages.edit.title")
    W.labels.name = BJI_Lang.get("garages.edit.name")
    W.labels.radius = BJI_Lang.get("garages.edit.radius")

    W.labels.buttons.refreshMarkers = BJI_Lang.get("garages.edit.buttons.refreshMarkers")
    W.labels.buttons.addGarageHere = BJI_Lang.get("garages.edit.buttons.addGarageHere")
    W.labels.buttons.showGarage = BJI_Lang.get("garages.edit.buttons.showGarage")
    W.labels.buttons.setGarageHere = BJI_Lang.get("garages.edit.buttons.setGarageHere")
    W.labels.buttons.deleteGarage = BJI_Lang.get("garages.edit.buttons.deleteGarage")
    W.labels.buttons.close = BJI_Lang.get("common.buttons.close")
    W.labels.buttons.save = BJI_Lang.get("common.buttons.save")
    W.labels.buttons.errorMustBeFreecaming = BJI_Lang.get("errors.mustBeFreecaming")
    W.labels.buttons.errorInvalidData = BJI_Lang.get("errors.someDataAreInvalid")
end

local function validateGarages()
    W.valid = #W.cache.garages == 0 or (
        W.cache.garages:every(function(g)
            return #g.name:trim() > 0 and g.radius > 0 and g.pos ~= nil
        end)
    )
end

local function updateCache()
    W.cache.garages = Table(BJI_Stations.Data.Garages)
        :map(function(g)
            return {
                name = g.name,
                radius = g.radius,
                pos = vec3(g.pos),
            }
        end)
    validateGarages()
    reloadMarkers()
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

local function save()
    W.cache.disableInputs = true
    BJI_Tx_scenario.GaragesSave(W.cache.garages:map(function(g)
        return math.roundPositionRotation({
            name = g.name,
            radius = g.radius,
            pos = vec3(g.pos.x, g.pos.y, g.pos.z),
        })
    end), function(result)
        if result then
            W.changed = false
        else
            BJI_Toast.error(BJI_Lang.get("garages.edit.saveErrorToast"))
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
    if IconButton("reloadMarkers", BJI.Utils.Icon.ICONS.sync) then
        reloadMarkers()
    end
    TooltipText(W.labels.buttons.refreshMarkers)
    SameLine()
    if IconButton("createGarage", BJI.Utils.Icon.ICONS.add_location,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = W.cache.disableInputs or
                ctxt.camera ~= BJI_Cam.CAMERAS.FREE }) then
        W.cache.garages:insert({
            name = "",
            radius = 5,
            pos = getPosition(),
        })
        W.changed = true
        reloadMarkers()
        validateGarages()
    end
    TooltipText(W.labels.buttons.addGarageHere ..
        (ctxt.camera ~= BJI_Cam.CAMERAS.FREE and
            (" (" .. W.labels.buttons.errorMustBeFreecaming .. ")") or ""))
end

local function body(ctxt)
    if BeginTable("BJIScenarioEditorGarages", {
            { label = "##scenarioeditor-garages-labels" },
            { label = "##scenarioeditor-garages-data",  flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        W.cache.garages:forEach(function(g, i)
            TableNewRow()
            Icon(BJI.Utils.Icon.ICONS.build)
            TableNextColumn()
            if IconButton("goToGarage" .. tostring(i), BJI.Utils.Icon.ICONS.pin_drop) then
                if ctxt.camera ~= BJI_Cam.CAMERAS.FREE then
                    BJI_Cam.toggleFreeCam()
                end
                BJI_Cam.setPositionRotation(g.pos)
            end
            TooltipText(W.labels.buttons.showGarage)
            SameLine()
            if IconButton("moveGarage" .. tostring(i), BJI.Utils.Icon.ICONS.edit_location,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, disabled = W.cache.disableInputs or
                        ctxt.camera ~= BJI_Cam.CAMERAS.FREE }) then
                g.pos = getPosition()
                W.changed = true
                reloadMarkers()
            end
            TooltipText(W.labels.buttons.setGarageHere ..
                (ctxt.camera ~= BJI_Cam.CAMERAS.FREE and
                    " (" .. W.labels.buttons.errorMustBeFreecaming .. ")" or ""))
            SameLine()
            if IconButton("deleteGarage" .. tostring(i), BJI.Utils.Icon.ICONS.delete_forever,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = W.cache.disableInputs }) then
                table.remove(W.cache.garages, i)
                W.changed = true
                reloadMarkers()
            end
            TooltipText(W.labels.buttons.deleteGarage)

            invalidName = #g.name:trim() == 0
            TableNewRow()
            Text(W.labels.name, { color = invalidName and BJI.Utils.Style.TEXT_COLORS.ERROR or nil })
            TableNextColumn()
            nextValue = InputText("nameGarage" .. tostring(i), g.name, {
                inputStyle = invalidName and BJI.Utils.Style.INPUT_PRESETS.ERROR or nil,
                disabled = W.cache.disableInputs
            })
            if nextValue then
                g.name = nextValue
                W.changed = true
                reloadMarkers()
                validateGarages()
            end

            TableNewRow()
            Text(W.labels.radius)
            if i < #W.cache.garages then Separator() end
            TableNextColumn()
            nextValue = SliderFloatPrecision("radiusGarage" .. tostring(i), g.radius, 1, 50,
                { precision = 1, stepFast = 3, disabled = W.cache.disableInputs })
            if nextValue then
                g.radius = nextValue
                W.changed = true
                reloadMarkers()
                validateGarages()
            end
        end)

        EndTable()
    end
end

local function footer(ctxt)
    if IconButton("closeGaragesEdit", BJI.Utils.Icon.ICONS.exit_to_app,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
        BJI_Win_ScenarioEditor.onClose()
    end
    TooltipText(W.labels.buttons.close)
    if W.changed then
        SameLine()
        if IconButton("saveGaragesEdit", BJI.Utils.Icon.ICONS.save,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                    disabled = W.cache.disableInputs or not W.valid }) then
            save()
        end
        TooltipText(W.labels.buttons.save ..
            (not W.valid and " (" .. W.labels.buttons.errorInvalidData .. ")" or ""))
    end
end

local function open()
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
