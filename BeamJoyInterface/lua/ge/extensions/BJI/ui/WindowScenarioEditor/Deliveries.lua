local dEdit

local function reloadMarkers()
    BJIWaypointEdit.reset()

    local waypoints = {}
    for i, position in ipairs(dEdit.positions) do
        table.insert(waypoints, {
            name = BJILang.get("delivery.edit.position"):var({ index = i }),
            pos = position.pos,
            rot = position.rot,
            radius = position.radius,
            type = BJIWaypointEdit.TYPES.CYLINDER,
        })
    end

    if #waypoints > 0 then
        BJIWaypointEdit.setWaypoints(waypoints)
    end
end

local function save()
    local positions = {}
    for _, position in ipairs(BJIContext.Scenario.DeliveryEdit.positions) do
        table.insert(positions, {
            radius = position.radius,
            pos = {
                x = position.pos.x,
                y = position.pos.y,
                z = position.pos.z,
            },
            rot = {
                x = position.rot.x,
                y = position.rot.y,
                z = position.rot.z,
                w = position.rot.w,
            }
        })
    end

    dEdit.processSave = true
    local _, err = pcall(BJITx.scenario.DeliverySave, positions)
    if not err then
        BJIAsync.task(function()
            return dEdit.processSave and dEdit.saveSuccess ~= nil
        end, function()
            if dEdit.saveSuccess then
                dEdit.changed = false
            else
                -- error message
                BJIToast.error(BJILang.get("delivery.edit.saveErrorToast"))
            end

            dEdit.processSave = nil
            dEdit.saveSuccess = nil
        end, "DeliveriesSave")
    else
        dEdit.processSave = nil
    end
end

local function drawHeader(ctxt)
    dEdit = BJIContext.Scenario.DeliveryEdit or {}

    if not dEdit.init then
        dEdit.init = true
        reloadMarkers()
    end

    LineBuilder()
        :text(BJILang.get("delivery.edit.title"))
        :btnIcon({
            id = "reloadMarkers",
            icon = ICONS.sync,
            style = BTN_PRESETS.INFO,
            onClick = reloadMarkers,
        })
        :build()
end

local function drawBody(ctxt)
    local vehPos = ctxt.isOwner and ctxt.vehPosRot or nil

    local labelWidth = GetTextWidth(BJILang.get("delivery.edit.radius") .. ":")
    for i in ipairs(dEdit.positions) do
        local w = GetColumnTextWidth(BJILang.get("delivery.edit.position")
            :var({ index = i })) + GetBtnIconSize()
        if w > labelWidth then
            labelWidth = w
        end
    end

    for i, position in ipairs(dEdit.positions) do
        ColumnsBuilder(string.var("BJIScenarioEditorDeliveries{1}", { i }), { labelWidth, -1 })
            :addRow({
                cells = {
                    function()
                        LineBuilder()
                            :icon({
                                icon = ICONS.simobject_bng_waypoint,
                            })
                            :text(BJILang.get("delivery.edit.position")
                                :var({ index = i }))
                            :build()
                    end,
                    function()
                        LineBuilder()
                            :btnIcon({
                                id = string.var("goTo{1}", { i }),
                                icon = ICONS.cameraFocusOnVehicle2,
                                style = BTN_PRESETS.INFO,
                                disabled = not ctxt.isOwner,
                                onClick = function()
                                    BJIVeh.setPositionRotation(position.pos, position.rot)
                                    if BJICam.getCamera() == BJICam.CAMERAS.FREE then
                                        BJICam.setCamera(BJICam.CAMERAS.ORBIT)
                                    end
                                end,
                            })
                            :btnIcon({
                                id = string.var("movePos{1}", { i }),
                                icon = ICONS.crosshair,
                                style = BTN_PRESETS.WARNING,
                                disabled = not vehPos or dEdit.processSave,
                                onClick = function()
                                    if vehPos then
                                        dEdit.positions[i].pos = vec3(vehPos.pos)
                                        dEdit.positions[i].rot = quat(vehPos.rot)
                                        dEdit.changed = true
                                        reloadMarkers()
                                    end
                                end,
                            })
                            :btnIcon({
                                id = string.var("delete{1}", { i }),
                                icon = ICONS.delete_forever,
                                style = BTN_PRESETS.ERROR,
                                disabled = dEdit.processSave,
                                onClick = function()
                                    table.remove(dEdit.positions, i)
                                    dEdit.changed = true
                                    reloadMarkers()
                                end
                            })
                            :build()
                    end
                }
            })
            :addRow({
                cells = {
                    function()
                        LineBuilder()
                            :text(string.var("{1}:", { BJILang.get("delivery.edit.radius") }))
                            :build()
                    end,
                    function()
                        LineBuilder()
                            :inputNumeric({
                                id = string.var("radius{1}", { i }),
                                type = "float",
                                precision = 1,
                                value = position.radius,
                                disabled = dEdit.processSave,
                                width = 120,
                                min = .5,
                                max = 50,
                                step = .5,
                                stepFast = 2,
                                onUpdate = function(val)
                                    position.radius = val
                                    dEdit.changed = true
                                    reloadMarkers()
                                end,
                            })
                            :build()
                    end
                }
            })
            :build()

        Separator()
    end

    LineBuilder()
        :btnIcon({
            id = "createPosition",
            icon = ICONS.addListItem,
            style = BTN_PRESETS.SUCCESS,
            disabled = not ctxt.isOwner or not vehPos or dEdit.processSave,
            onClick = function()
                if vehPos then
                    table.insert(dEdit.positions, {
                        pos = vec3(vehPos.pos),
                        rot = quat(vehPos.rot),
                        radius = 2.5,
                    })
                    dEdit.changed = true
                    reloadMarkers()
                end
            end,
        })
        :build()
end

local function drawFooter()
    local line = LineBuilder()
        :btnIcon({
            id = "cancel",
            icon = ICONS.exit_to_app,
            style = BTN_PRESETS.ERROR,
            onClick = function()
                BJIContext.Scenario.DeliveryEdit = nil
                BJIWaypointEdit.reset()
            end,
        })
    if dEdit.changed then
        line:btnIcon({
            id = "save",
            icon = ICONS.save,
            style = BTN_PRESETS.SUCCESS,
            disabled = dEdit.processSave,
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
        BJIContext.Scenario.DeliveryEdit = nil
        BJIWaypointEdit.reset()
    end,
}
