local W = {
    name = "ScenarioEditorDeliveries",

    labels = {
        title = "",
        hubs = "",
        hub = "",
        positions = "",
        position = "",
        radius = "",

        buttons = {
            refreshMarkers = "",
            addHub = "",
            showHub = "",
            setHub = "",
            deleteHub = "",
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
        ---@type tablelib<integer, BJIPositionRotationRadius> index 1-N
        hubs = Table(),
        ---@type tablelib<integer, BJIPositionRotationRadius> index 1-N
        positions = Table(),
        disableInputs = false,
    },
    changed = false,
    valid = true,
}
--- gc prevention
local nextValue, opened

local function onClose()
    BJI_WaypointEdit.reset()
    W.changed = false
    W.valid = true
end

local function reloadMarkers()
    BJI_WaypointEdit.setWaypoints(W.cache.positions
        :map(function(position, i)
            return {
                name = W.labels.position:var({ index = i }),
                pos = position.pos,
                rot = position.rot,
                radius = position.radius,
                type = BJI_WaypointEdit.TYPES.CYLINDER,
            }
        end):addAll(W.cache.hubs:map(function(hub, i)
            return {
                name = W.labels.hub:var({ index = i }),
                pos = hub.pos,
                rot = hub.rot,
                radius = hub.radius,
                type = BJI_WaypointEdit.TYPES.SPHERE,
                color = BJI.Utils.ShapeDrawer.Color(1, 1, .33, .5),
            }
        end)))
end

local function updateLabels()
    W.labels.title = BJI_Lang.get("delivery.edit.title")
    W.labels.hubs = BJI_Lang.get("delivery.edit.hubs")
    W.labels.hub = BJI_Lang.get("delivery.edit.hub")
    W.labels.positions = BJI_Lang.get("delivery.edit.positions")
    W.labels.position = BJI_Lang.get("delivery.edit.position")
    W.labels.radius = BJI_Lang.get("delivery.edit.radius")

    W.labels.buttons.refreshMarkers = BJI_Lang.get("delivery.edit.buttons.refreshMarkers")
    W.labels.buttons.addHub = BJI_Lang.get("delivery.edit.buttons.addHub")
    W.labels.buttons.showHub = BJI_Lang.get("delivery.edit.buttons.showHub")
    W.labels.buttons.setHub = BJI_Lang.get("delivery.edit.buttons.setHub")
    W.labels.buttons.deleteHub = BJI_Lang.get("delivery.edit.buttons.deleteHub")
    W.labels.buttons.addPosition = BJI_Lang.get("delivery.edit.buttons.addPosition")
    W.labels.buttons.showPosition = BJI_Lang.get("delivery.edit.buttons.showPosition")
    W.labels.buttons.setPosition = BJI_Lang.get("delivery.edit.buttons.setPosition")
    W.labels.buttons.deletePosition = BJI_Lang.get("delivery.edit.buttons.deletePosition")
    W.labels.buttons.close = BJI_Lang.get("common.buttons.close")
    W.labels.buttons.save = BJI_Lang.get("common.buttons.save")
    W.labels.buttons.errorMustHaveVehicle = BJI_Lang.get("errors.mustHaveVehicle")
end

local function validate()
    W.valid = #W.cache.positions == 0 or
        W.cache.positions:every(function(g)
            return g.radius > 0 and g.pos ~= nil and g.rot ~= nil
        end)
end

local function updateCache()
    W.cache.hubs = BJI_Scenario.Data.Deliveries.Hubs:clone()
    W.cache.positions = BJI_Scenario.Data.Deliveries.Points:clone()
    validate()
    reloadMarkers()
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.LANG_CHANGED, updateLabels, W.name))

    updateCache()
    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.CACHE_LOADED,
        function(_, data)
            if data.cache == BJI_Cache.CACHES.DELIVERIES then
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
    BJI_Tx_scenario.DeliverySave({
        Hubs = W.cache.hubs:map(function(h)
            return math.roundPositionRotation(h)
        end),
        Points = W.cache.positions:map(function(p)
            return math.roundPositionRotation(p)
        end),
    }, function(result)
        if result then
            W.changed = false
        else
            BJI_Toast.error(BJI_Lang.get("delivery.edit.saveErrorToast"))
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
end

---@param ctxt TickContext
local function drawHubs(ctxt)
    if BeginTable("BJIScenarioEditorDeliveriesHubs", {
            { label = "##scenarioeditor-deliveries-hub-labels" },
            { label = "##scenarioeditor-deliveries-hub-data",  flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }, { flags = { TABLE_FLAGS.BORDERS_H } }) then
        W.cache.hubs:forEach(function(h, i)
            TableNewRow()
            Icon(BJI.Utils.Icon.ICONS.simobject_bng_waypoint)
            SameLine()
            Text(W.labels.hub:var({ index = i }))
            TableNextColumn()
            if IconButton("goToHub" .. tostring(i), BJI.Utils.Icon.ICONS.pin_drop) then
                if ctxt.isOwner then
                    BJI_Veh.setPositionRotation(h.pos, h.rot)
                    if BJI_Cam.getCamera() == BJI_Cam.CAMERAS.FREE then
                        BJI_Cam.toggleFreeCam()
                    end
                else
                    if BJI_Cam.getCamera() ~= BJI_Cam.CAMERAS.FREE then
                        BJI_Cam.toggleFreeCam()
                    end
                    BJI_Cam.setPositionRotation(h.pos, h.rot)
                end
            end
            TooltipText(W.labels.buttons.showHub)
            SameLine()
            if IconButton("moveHub" .. tostring(i), BJI.Utils.Icon.ICONS.edit_location,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, disabled = W.cache.disableInputs or
                        not ctxt.veh or ctxt.camera == BJI_Cam.CAMERAS.FREE }) then
                h.pos = ctxt.veh.position
                h.rot = ctxt.veh.rotation
                W.changed = true
                reloadMarkers()
                validate()
            end
            TooltipText(W.labels.buttons.setHub ..
                ((not ctxt.veh or ctxt.camera == BJI_Cam.CAMERAS.FREE) and
                    " (" .. W.labels.buttons.errorMustHaveVehicle .. ")" or ""))
            SameLine()
            if IconButton("deleteHub" .. tostring(i), BJI.Utils.Icon.ICONS.delete_forever,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = W.cache.disableInputs }) then
                W.cache.hubs:remove(i)
                W.changed = true
                reloadMarkers()
                validate()
            end
            TooltipText(W.labels.buttons.deleteHub)

            TableNewRow()
            Text(W.labels.radius)
            TableNextColumn()
            nextValue = SliderIntPrecision("radiusHub" .. tostring(i), h.radius, 1, 20,
                { disabled = W.cache.disableInputs })
            if nextValue then
                h.radius = nextValue
                W.changed = true
                reloadMarkers()
                validate()
            end
        end)
        EndTable()
    end
end

---@param ctxt TickContext
local function drawPositions(ctxt)
    if BeginTable("BJIScenarioEditorDeliveriesPoints", {
            { label = "##scenarioeditor-deliveries-points-labels" },
            { label = "##scenarioeditor-deliveries-points-data",  flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }, { flags = { TABLE_FLAGS.BORDERS_H } }) then
        W.cache.positions:forEach(function(p, i)
            TableNewRow()
            Icon(BJI.Utils.Icon.ICONS.simobject_bng_waypoint)
            SameLine()
            Text(W.labels.position:var({ index = i }))
            TableNextColumn()
            if IconButton("goToPosition" .. tostring(i), BJI.Utils.Icon.ICONS.pin_drop) then
                if ctxt.isOwner then
                    BJI_Veh.setPositionRotation(p.pos, p.rot)
                    if BJI_Cam.getCamera() == BJI_Cam.CAMERAS.FREE then
                        BJI_Cam.toggleFreeCam()
                    end
                else
                    if BJI_Cam.getCamera() ~= BJI_Cam.CAMERAS.FREE then
                        BJI_Cam.toggleFreeCam()
                    end
                    BJI_Cam.setPositionRotation(p.pos, p.rot)
                end
            end
            TooltipText(W.labels.buttons.showPosition)
            SameLine()
            if IconButton("movePosition" .. tostring(i), BJI.Utils.Icon.ICONS.edit_location,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, disabled = W.cache.disableInputs or
                        not ctxt.veh or ctxt.camera == BJI_Cam.CAMERAS.FREE }) then
                p.pos = ctxt.veh.position
                p.rot = ctxt.veh.rotation
                W.changed = true
                reloadMarkers()
                validate()
            end
            TooltipText(W.labels.buttons.setPosition ..
                ((not ctxt.veh or ctxt.camera == BJI_Cam.CAMERAS.FREE) and
                    " (" .. W.labels.buttons.errorMustHaveVehicle .. ")" or ""))
            SameLine()
            if IconButton("deletePosition" .. tostring(i), BJI.Utils.Icon.ICONS.delete_forever,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = W.cache.disableInputs }) then
                W.cache.positions:remove(i)
                W.changed = true
                reloadMarkers()
                validate()
            end
            TooltipText(W.labels.buttons.deletePosition)

            TableNewRow()
            Text(W.labels.radius)
            TableNextColumn()
            nextValue = SliderFloatPrecision("radiusPosition" .. tostring(i), p.radius, .5, 50,
                { step = .5, stepFast = 2, disabled = W.cache.disableInputs, precision = 1 })
            if nextValue then
                p.radius = nextValue
                W.changed = true
                reloadMarkers()
                validate()
            end
        end)

        EndTable()
    end
end

---@param ctxt TickContext
local function body(ctxt)
    opened = BeginTree(W.labels.hubs)
    SameLine()
    Text(string.format("(%d)", #W.cache.hubs))
    if opened then
        SameLine()
        if IconButton("createHub", BJI.Utils.Icon.ICONS.add_location,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = W.cache.disableInputs or
                    not ctxt.veh }) then
            W.cache.hubs:insert({
                pos = ctxt.veh.position,
                rot = ctxt.veh.rotation,
                radius = 2.5,
            })
            W.changed = true
            reloadMarkers()
            validate()
        end
        TooltipText(W.labels.buttons.addHub ..
            (not ctxt.veh and " (" .. W.labels.buttons.errorMustHaveVehicle .. ")" or ""))

        drawHubs(ctxt)

        EndTree()
    end

    opened = BeginTree(W.labels.positions)
    SameLine()
    Text(string.format("(%d)", #W.cache.positions))
    if opened then
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
            validate()
        end
        TooltipText(W.labels.buttons.addPosition ..
            (not ctxt.veh and " (" .. W.labels.buttons.errorMustHaveVehicle .. ")" or ""))

        drawPositions(ctxt)

        EndTree()
    end
end

---@param ctxt TickContext
local function footer(ctxt)
    if IconButton("closeDeliveriesEdit", BJI.Utils.Icon.ICONS.exit_to_app,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
        BJI_Win_ScenarioEditor.onClose()
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
