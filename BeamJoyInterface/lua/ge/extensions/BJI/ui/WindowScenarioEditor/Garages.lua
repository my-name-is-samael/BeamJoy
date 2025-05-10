local gEdit

local function reloadMarkers()
    BJIWaypointEdit.reset()

    local waypoints = {}
    for _, garage in ipairs(gEdit.garages) do
        table.insert(waypoints, {
            name = garage.name,
            pos = garage.pos,
            radius = garage.radius,
            type = BJIWaypointEdit.TYPES.SPHERE,
        })
    end

    if #waypoints > 0 then
        BJIWaypointEdit.setWaypoints(waypoints)
    end
end

local function save()
    local garages = {}
    for _, garage in ipairs(gEdit.garages) do
        table.insert(garages, RoundPositionRotation({
            name = garage.name,
            radius = garage.radius,
            pos = vec3(garage.pos.x, garage.pos.y, garage.pos.z),
        }))
    end

    gEdit.processSave = true
    local _, err = pcall(BJITx.scenario.GaragesSave, garages)
    if not err then
        BJIAsync.task(function()
            return gEdit.processSave and gEdit.saveSuccess ~= nil
        end, function()
            if gEdit.saveSuccess then
                gEdit.changed = false
            else
                -- error message
                BJIToast.error(BJILang.get("garages.edit.saveErrorToast"))
            end

            gEdit.processSave = nil
            gEdit.saveSuccess = nil
        end, "GaragesSave")
    else
        gEdit.processSave = nil
    end
end

local function drawHeader(ctxt)
    gEdit = BJIContext.Scenario.GaragesEdit or {}

    if not gEdit.init then
        gEdit.init = true
        reloadMarkers()
    end

    LineBuilder()
        :text(BJILang.get("garages.edit.title"))
        :btnIcon({
            id = "reloadMarkers",
            icon = ICONS.sync,
            style = BTN_PRESETS.INFO,
            onClick = reloadMarkers,
        })
        :build()
end

local function drawBody(ctxt)
    gEdit.valid = true

    local labelWidth = 0
    for _, key in ipairs({
        "garages.edit.name",
        "garages.edit.radius",
    }) do
        local label = BJILang.get(key)
        local w = GetColumnTextWidth(label)
        if w > labelWidth then
            labelWidth = w
        end
    end

    for i, garage in ipairs(gEdit.garages) do
        local invalidName = #garage.name:trim() == 0
        if invalidName then
            gEdit.valid = false
        end

        ColumnsBuilder(string.var("BJIScenarioEditorGarage{1}", { i }), { labelWidth, -1 })
            :addRow({
                cells = {
                    function()
                        LineBuilder()
                            :text(BJILang.get("garages.edit.name"),
                                invalidName and TEXT_COLORS.ERROR or TEXT_COLORS.DEFAULT)
                            :build()
                    end,
                    function()
                        LineBuilder()
                            :inputString({
                                id = string.var("nameGarage{1}", { i }),
                                style = invalidName and INPUT_PRESETS.ERROR or INPUT_PRESETS.DEFAULT,
                                disabled = gEdit.processSave,
                                value = garage.name,
                                size = garage.name._size,
                                onUpdate = function(val)
                                    garage.name = val
                                    gEdit.changed = true
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
                            :text(BJILang.get("garages.edit.radius"))
                            :build()
                    end,
                    function()
                        LineBuilder()
                            :inputNumeric({
                                id = string.var("radiusGarage{1}", { i }),
                                type = "float",
                                precision = 1,
                                value = garage.radius,
                                disabled = gEdit.processSave,
                                min = 1,
                                max = 50,
                                step = 1,
                                stepFast = 3,
                                onUpdate = function(val)
                                    garage.radius = val
                                    gEdit.changed = true
                                    reloadMarkers()
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
                                icon = ICONS.cameraFocusTopDown,
                                style = BTN_PRESETS.INFO,
                                onClick = function()
                                    if ctxt.camera ~= BJICam.CAMERAS.FREE then
                                        BJICam.setCamera(BJICam.CAMERAS.FREE)
                                    end
                                    BJICam.setPositionRotation(garage.pos)
                                end
                            })
                            :btnIcon({
                                id = string.var("moveGarage{1}", { i }),
                                icon = ICONS.crosshair,
                                style = BTN_PRESETS.WARNING,
                                disabled = ctxt.camera ~= BJICam.CAMERAS.FREE or gEdit.processSave,
                                onClick = function()
                                    garage.pos = BJICam.getPositionRotation().pos
                                    gEdit.changed = true
                                    reloadMarkers()
                                end
                            })
                            :btnIcon({
                                id = string.var("deleteGarage{1}", { i }),
                                icon = ICONS.delete_forever,
                                style = BTN_PRESETS.ERROR,
                                disabled = gEdit.processSave,
                                onClick = function()
                                    table.remove(gEdit.garages, i)
                                    gEdit.changed = true
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
            id = "createGarage",
            icon = ICONS.addListItem,
            style = BTN_PRESETS.SUCCESS,
            disabled = ctxt.camera ~= BJICam.CAMERAS.FREE or gEdit.processSave,
            onClick = function()
                table.insert(gEdit.garages, {
                    name = "",
                    radius = 5,
                    pos = BJICam.getPositionRotation().pos,
                })
                gEdit.changed = true
                reloadMarkers()
            end
        })
        :build()
end

local function drawFooter(ctxt)
    local line = LineBuilder()
        :btnIcon({
            id = "cancelGaragesEdit",
            icon = ICONS.exit_to_app,
            style = BTN_PRESETS.ERROR,
            onClick = function()
                BJIContext.Scenario.GaragesEdit = nil
                BJIWaypointEdit.reset()
            end,
        })
    if gEdit.changed then
        line:btnIcon({
            id = "saveGaragesEdit",
            icon = ICONS.save,
            style = BTN_PRESETS.SUCCESS,
            disabled = not gEdit.valid or gEdit.processSave,
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
        BJIContext.Scenario.GaragesEdit = nil
        BJIWaypointEdit.reset()
    end,
}
