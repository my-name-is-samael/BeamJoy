local bm, configs

local function drawBody(ctxt)
    bm = BJIScenario.get(BJIScenario.TYPES.BUS_MISSION)

    LineBuilder()
        :text(BJILang.get("buslines.preparation.title"))
        :build()

    local labelWidth = 0
    for _, key in ipairs({
        "buslines.preparation.line",
        "buslines.preparation.config",
    }) do
        local label = BJILang.get(key)
        local w = GetColumnTextWidth(label)
        if w > labelWidth then
            labelWidth = w
        end
    end

    ColumnsBuilder("BJIBusMissionPreparation", { labelWidth, -1 })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(BJILang.get("buslines.preparation.line"))
                        :build()
                end,
                function()
                    local lines = {}
                    local selected
                    for i, line in ipairs(BJIContext.Scenario.Data.BusLines) do
                        local stops = table.clone(line.stops)
                        if line.loopable then
                            table.insert(stops, table.clone(stops[1]))
                        end
                        table.insert(lines, {
                            id = i,
                            label = string.var("{1} ({2})", { line.name, PrettyDistance(line.distance) }),
                            stops = stops,
                            loopable = line.loopable,
                        })
                        if bm.line.id == i then
                            selected = lines[#lines]
                        end
                    end
                    table.sort(lines, function(a, b)
                        return a.label < b.label
                    end)
                    if not selected then
                        selected = lines[1]
                        bm.line.id = selected.id
                        bm.line.name = selected.label
                        bm.line.stops = selected.stops
                        bm.line.loopable = selected.loopable
                    end
                    LineBuilder()
                        :inputCombo({
                            id = "busMissionLine",
                            items = lines,
                            value = selected,
                            getLabelFn = function(item)
                                return item.label
                            end,
                            onChange = function(item)
                                bm.line.id = item.id
                                bm.line.name = item.label
                                bm.line.loopable = item.loopable
                                bm.line.stops = item.stops
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
                        :text(BJILang.get("buslines.preparation.config"))
                        :build()
                end,
                function()
                    local modelLabel = BJIVeh.getModelLabel(bm.model)
                    if not configs then
                        configs = BJIVeh.getAllConfigsForModel(bm.model)
                    end
                    local items = {}
                    local selected
                    for _, config in pairs(configs) do
                        local label = string.var("{1} {2}", { modelLabel, config.label })
                        if config.custom then
                            label = string.var("{1} ({2})", { label, BJILang.get("buslines.preparation.customConfig") })
                        end
                        table.insert(items, {
                            key = config.key,
                            label = label
                        })
                        if bm.config == config.key then
                            selected = items[#items]
                        end
                    end
                    if not selected then
                        selected = items[1]
                        bm.config = selected.key
                    end
                    table.sort(items, function(a, b)
                        return a.label < b.label
                    end)
                    LineBuilder()
                        :inputCombo({
                            id = "busMissionVehicleConfig",
                            items = items,
                            value = selected,
                            getLabelFn = function(item)
                                return item.label
                            end,
                            onChange = function(item)
                                bm.config = item.key
                            end
                        })
                        :build()
                end,
            }
        })
        :build()
end

local function onClose()
    configs = nil
    BJIContext.Scenario.BusSettings = nil
end

local function drawFooter(ctxt)
    LineBuilder()
        :btnIcon({
            id = "cancelBusMission",
            icon = ICONS.exit_to_app,
            style = BTN_PRESETS.ERROR,
            onClick = onClose,
        })
        :btnIcon({
            id = "startBusMission",
            icon = ICONS.videogame_asset,
            style = BTN_PRESETS.SUCCESS,
            onClick = function()
                bm.start(ctxt)
                configs = nil
            end,
        })
        :build()
end

return {
    flags = {
        WINDOW_FLAGS.NO_COLLAPSE
    },
    body = drawBody,
    footer = drawFooter,
    onClose = onClose,
}
