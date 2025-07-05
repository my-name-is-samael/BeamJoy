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
        positions = Table(),
        disableInputs = false,
    },
    changed = false,
    valid = true,
}
--- gc prevention
local nextValue

local function onClose()
    BJI.Managers.WaypointEdit.reset()
    W.changed = false
    W.valid = true
end

local function reloadMarkers()
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
    W.labels.buttons.errorMustHaveVehicle = BJI.Managers.Lang.get("errors.mustHaveVehicle")
end

local function validatePositions()
    W.valid = #W.cache.positions == 0 or
        W.cache.positions:every(function(g)
            return g.radius > 0 and g.pos ~= nil and g.rot ~= nil
        end)
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
    validatePositions()
    reloadMarkers()
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.LANG_CHANGED, updateLabels, W.name))

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

local function save()
    W.cache.disableInputs = true
    BJI.Tx.scenario.DeliverySave(W.cache.positions:map(function(p)
        return math.roundPositionRotation(p)
    end), function(result)
        if result then
            W.changed = false
        else
            BJI.Managers.Toast.error(BJI.Managers.Lang.get("delivery.edit.saveErrorToast"))
        end
        W.cache.disableInputs = false
    end)
end

---@param ctxt TickContext
local function header(ctxt)
    Text(W.labels.title)
    SameLine()
    if IconButton("reloadMarkers", BJI.Utils.Icon.ICONS.sync) then
        reloadMarkers()
    end
    TooltipText(W.labels.buttons.refreshMarkers)
    SameLine()
    if IconButton("createPosition", BJI.Utils.Icon.ICONS.add_location,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = W.cache.disableInputs or
                not ctxt.veh }) then
        W.cache.positions:insert({
            pos = ctxt.veh.position,
            rot = ctxt.veh.rotation,
            radius = 2.5,
        })
        W.changed = true
        reloadMarkers()
        validatePositions()
    end
    TooltipText(W.labels.buttons.addPosition ..
        (not ctxt.veh and " (" .. W.labels.buttons.errorMustHaveVehicle .. ")" or ""))
end

---@param ctxt TickContext
local function body(ctxt)
    if BeginTable("BJIScenarioEditorDeliveries", {
            { label = "##scenarioeditor-deliveries-labels" },
            { label = "##scenarioeditor-deliveries-data",  flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        W.cache.positions:forEach(function(p, i)
            TableNewRow()
            Icon(BJI.Utils.Icon.ICONS.simobject_bng_waypoint)
            SameLine()
            Text(W.labels.position:var({ index = i }))
            TableNextColumn()
            if IconButton("goToPosition" .. tostring(i), BJI.Utils.Icon.ICONS.pin_drop) then
                if ctxt.isOwner then
                    BJI.Managers.Veh.setPositionRotation(p.pos, p.rot)
                    if BJI.Managers.Cam.getCamera() == BJI.Managers.Cam.CAMERAS.FREE then
                        BJI.Managers.Cam.toggleFreeCam()
                    end
                else
                    if BJI.Managers.Cam.getCamera() ~= BJI.Managers.Cam.CAMERAS.FREE then
                        BJI.Managers.Cam.toggleFreeCam()
                    end
                    BJI.Managers.Cam.setPositionRotation(p.pos, p.rot)
                end
            end
            TooltipText(W.labels.buttons.showPosition)
            SameLine()
            if IconButton("movePosition" .. tostring(i), BJI.Utils.Icon.ICONS.edit_location,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, disabled = W.cache.disableInputs or
                        not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE }) then
                W.cache.positions[i].pos = ctxt.veh.position
                W.cache.positions[i].rot = ctxt.veh.rotation
                W.changed = true
                reloadMarkers()
                validatePositions()
            end
            TooltipText(W.labels.buttons.setPosition ..
                ((not ctxt.veh or ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE) and
                    " (" .. W.labels.buttons.errorMustHaveVehicle .. ")" or ""))
            SameLine()
            if IconButton("deletePosition" .. tostring(i), BJI.Utils.Icon.ICONS.delete_forever,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = W.cache.disableInputs }) then
                W.cache.positions:remove(i)
                W.changed = true
                reloadMarkers()
                validatePositions()
            end
            TooltipText(W.labels.buttons.deletePosition)

            TableNewRow()
            Text(W.labels.radius)
            if i < #W.cache.positions then Separator() end
            TableNextColumn()
            nextValue = SliderFloatPrecision("radiusPosition" .. tostring(i), p.radius, .5, 50,
                { step = .5, stepFast = 2, disabled = W.cache.disableInputs, precision = 1 })
            if nextValue then
                p.radius = nextValue
                W.changed = true
                reloadMarkers()
                validatePositions()
            end
        end)

        EndTable()
    end
end

---@param ctxt TickContext
local function footer(ctxt)
    if IconButton("closeDeliveriesEdit", BJI.Utils.Icon.ICONS.exit_to_app,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
        BJI.Windows.ScenarioEditor.onClose()
    end
    TooltipText(W.labels.buttons.close)
    if W.changed then
        SameLine()
        if IconButton("saveDeliveriesEdit", BJI.Utils.Icon.ICONS.save,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                    disabled = W.cache.disableInputs }) then
            save()
        end
        TooltipText(W.labels.buttons.save)
    end
end

local function open()
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
