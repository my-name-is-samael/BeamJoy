local te

local function updateTheme()
    LoadTheme(te.data)
end

local function save()
    BJITx.config.bjc("Server.Theme", te.data)
end

local function onClose(ctxt)
    if te.changed then
        BJIPopup.createModal(BJILang.get("themeEditor.cancelModal"), {
            {
                label = BJILang.get("common.buttons.cancel"),
            },
            {
                label = BJILang.get("common.buttons.confirm"),
                onClick = function()
                    LoadTheme(BJIContext.BJC.Theme)
                    BJIContext.ThemeEditor = nil
                end
            }
        })
    else
        BJIContext.ThemeEditor = nil
    end
end

local function drawColorLine(data)
    if not data.id or not data.label then
        LogError("drawLabelPicker requires id, label")
        return
    elseif not data.reverse and not data.labelWidth then
        LogError("drawLabelPicker requires reverse or labelWidth")
        return
    elseif not data.toggle and not data.color then
        LogError("drawLabelPicker requires toggle or color")
        return
    elseif data.toggle then
        if not data.toggle.onClick then
            LogError("drawLabelPicker requires toggle.onClick")
            return
        end

        if data.toggle.state and not data.color then
            LogError("drawLabelPicker requires color when toggle is true")
            return
        end
    else
        if not data.color.value or not data.color.onChange then
            LogError("drawLabelPicker requires color.value and color.onChange")
            return
        end

        if data.reset and type(data.reset) ~= "function" then
            LogError("drawLabelPicker requires reset to be a function")
            return
        end
    end

    local drawLabel = function(sameLine)
        LineBuilder(sameLine == true)
            :text(data.label)
            :build()
    end

    local drawInputs = function()
        local line = LineBuilder()
        if data.toggle then
            line:btnIconToggle({
                id = string.var("{1}-toggle", { data.id }),
                state = not not data.toggle.state,
                coloredIcon = true,
                onClick = data.toggle.onClick,
            })
        end
        if not data.toggle or data.toggle.state then
            line:colorPicker({
                id = string.var("{1}-color", { data.id }),
                value = data.color.value,
                alpha = true,
                onChange = data.color.onChange
            })
        end
        if data.reset then
            line:btnIcon({
                id = string.var("{1}-reset", { data.id }),
                icon = ICONS.refresh,
                style = BTN_PRESETS.WARNING,
                onClick = data.reset,
            })
        end
        line:build()
    end

    if data.reverse then
        drawInputs()
        drawLabel(true)
    else
        ColumnsBuilder(data.id, { data.labelWidth, -1 })
            :addRow({ cells = { drawLabel, drawInputs } })
            :build()
    end
    Separator()
end

local function compareColorToDefault(color, default)
    if not color or not default then
        return color ~= default
    end
    for i = 1, 4 do
        -- forced to round because direct comparison returns false after a database save :(
        if math.round(color[i], RGBA_PRECISION) ~= math.round(default[i], RGBA_PRECISION) then
            return false
        end
    end
    return true
end

local function drawThemeCategory(cat)
    AccordionBuilder()
        :label(BJILang.get(string.var("themeEditor.{1}.title", { cat })))
        :commonStart(Separator)
        :openedBehavior(function()
            local listInputs = {}
            for key, value in pairs(te.data[cat]) do
                local label = BJILang.get(string.var("themeEditor.{1}.{2}", { cat, key }))
                table.insert(listInputs, {
                    key = key,
                    value = value,
                    label = label,
                })
            end
            table.sort(listInputs, function(a, b) return a.label < b.label end)
            for _, data in ipairs(listInputs) do
                local changed = not compareColorToDefault(data.value, BJIContext.BJC.Server.Theme[cat][data.key])
                if changed then
                    te.changed = true
                end
                drawColorLine({
                    id = string.var("{1}-{2}", { cat, data.key }),
                    label = data.label,
                    reverse = true,
                    color = {
                        value = data.value,
                        onChange = function(color)
                            te.data[cat][data.key] = color
                            updateTheme()
                        end
                    },
                    reset = changed and function()
                        te.data[cat][data.key] = table.clone(BJIContext.BJC.Server.Theme[cat][data.key])
                        updateTheme()
                    end
                })
            end
        end)
        :build()
end

local function drawPreview(id, labelWidth, previewLabel, render)
    ColumnsBuilder(id, { labelWidth, -1 })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(previewLabel)
                        :build()
                end,
                render,
            }
        })
        :build()
    Separator()
end

local function drawButtonsPresets()
    AccordionBuilder()
        :label(BJILang.get("themeEditor.Button.title"))
        :commonStart(Separator)
        :openedBehavior(function()
            local btnPresets = {}
            for key, value in pairs(te.data.Button) do
                table.insert(btnPresets, {
                    key = key,
                    value = value,
                    default = BJIContext.BJC.Server.Theme.Button[key],
                    label = BJILang.get(string.var("themeEditor.Button.{1}", { key })),
                })
            end
            table.sort(btnPresets, function(a, b) return a.label < b.label end)
            local previewLabel = 0
            local labelWidth = GetColumnTextWidth(previewLabel)
            local btnTypes = {}
            if #btnPresets > 0 then
                for _, k in ipairs({
                    "baseColor",
                    "hoveredColor",
                    "activeColor",
                    "overrideTextColor",
                    "preview",
                }) do
                    local label = BJILang.get(string.var("themeEditor.Button.{1}", { k }))
                    local w = GetColumnTextWidth(label)
                    if w > labelWidth then
                        labelWidth = w
                    end
                    table.insert(btnTypes, {
                        key = k,
                        label = label,
                    })
                end
            end
            for _, btnPreset in ipairs(btnPresets) do
                AccordionBuilder()
                    :label(btnPreset.label)
                    :commonStart(Separator)
                    :openedBehavior(function()
                        -- Preview
                        drawPreview(
                            string.var("Button-{1}-cols-preview", { btnPreset.key }),
                            labelWidth,
                            btnTypes[5].label,
                            function()
                                LineBuilder()
                                    :btn({
                                        id = string.var("Button-{1}-preview-text", { btnPreset.key }),
                                        label = "ABC123",
                                        style = BTN_PRESETS[btnPreset.key],
                                        onClick = function() end,
                                    })
                                    :btnIcon({
                                        id = string.var("Button-{1}-preview-icon", { btnPreset.key }),
                                        icon = ICONS.bug_report,
                                        style = BTN_PRESETS[btnPreset.key],
                                        onClick = function() end,
                                    })
                                    :build()
                            end
                        )

                        -- Base Color
                        local value = btnPreset.value[1]
                        local default = BJIContext.BJC.Server.Theme.Button[btnPreset.key][1]
                        local changed = not compareColorToDefault(value, default)
                        if changed then
                            te.changed = true
                        end
                        drawColorLine({
                            id = string.var("Button-{1}-{2}", { btnPreset.key, btnTypes[1].key }),
                            label = btnTypes[1].label,
                            labelWidth = labelWidth,
                            color = {
                                value = value,
                                onChange = function(color)
                                    te.data.Button[btnPreset.key][1] = color
                                    updateTheme()
                                end,
                            },
                            reset = changed and function()
                                te.data.Button[btnPreset.key][1] = table.clone(default)
                                updateTheme()
                            end
                        })

                        -- Hovered Color
                        value = btnPreset.value[2]
                        default = BJIContext.BJC.Server.Theme.Button[btnPreset.key][2]
                        changed = not compareColorToDefault(value, default)
                        if changed then
                            te.changed = true
                        end
                        drawColorLine({
                            id = string.var("Button-{1}-{2}", { btnPreset.key, btnTypes[2].key }),
                            label = btnTypes[2].label,
                            labelWidth = labelWidth,
                            color = {
                                value = value,
                                onChange = function(color)
                                    te.data.Button[btnPreset.key][2] = color
                                    updateTheme()
                                end,
                            },
                            reset = changed and function()
                                te.data.Button[btnPreset.key][2] = table.clone(default)
                                updateTheme()
                            end
                        })

                        -- Active Color
                        value = btnPreset.value[3]
                        default = BJIContext.BJC.Server.Theme.Button[btnPreset.key][3]
                        changed = not compareColorToDefault(value, default)
                        if changed then
                            te.changed = true
                        end
                        drawColorLine({
                            id = string.var("Button-{1}-{2}", { btnPreset.key, btnTypes[3].key }),
                            label = btnTypes[3].label,
                            labelWidth = labelWidth,
                            color = {
                                value = value,
                                onChange = function(color)
                                    te.data.Button[btnPreset.key][3] = color
                                    updateTheme()
                                end,
                            },
                            reset = changed and function()
                                te.data.Button[btnPreset.key][3] = table.clone(default)
                                updateTheme()
                            end
                        })

                        -- Override Text Color
                        value = btnPreset.value[4]
                        default = BJIContext.BJC.Server.Theme.Button[btnPreset.key][4]
                        if value and default then
                            changed = not compareColorToDefault(value, default)
                        else
                            changed = value ~= default
                        end
                        if changed then
                            te.changed = true
                        end
                        drawColorLine({
                            id = string.var("Button-{1}-{2}", { btnPreset.key, btnTypes[4].key }),
                            label = btnTypes[4].label,
                            labelWidth = labelWidth,
                            toggle = {
                                state = not not value,
                                onClick = function()
                                    if value then
                                        te.data.Button[btnPreset.key][4] = nil
                                    else
                                        te.data.Button[btnPreset.key][4] = table.clone(te.data.Text.DEFAULT)
                                    end
                                    updateTheme()
                                end
                            },
                            color = value and {
                                value = value,
                                onChange = function(color)
                                    te.data.Button[btnPreset.key][4] = color
                                    updateTheme()
                                end,
                            } or nil,
                            reset = changed and function()
                                te.data.Button[btnPreset.key][4] = table.clone(default)
                                updateTheme()
                            end
                        })
                    end)
                    :build()
            end
        end)
        :build()
end

local function drawInputsPresets()
    AccordionBuilder()
        :label(BJILang.get("themeEditor.Input.title"))
        :commonStart(Separator)
        :openedBehavior(function()
            local inputPresets = {}
            for key, value in pairs(te.data.Input) do
                table.insert(inputPresets, {
                    key = key,
                    value = value,
                    label = BJILang.get(string.var("themeEditor.Input.{1}", { key })),
                })
            end
            table.sort(inputPresets, function(a, b) return a.label < b.label end)
            local previewLabel = 0
            local labelWidth = GetColumnTextWidth(previewLabel)
            local inputTypes = {}
            if #inputPresets > 0 then
                for _, k in ipairs({
                    "baseColor",
                    "overrideTextColor",
                    "previewString",
                    "previewNumeric",
                }) do
                    local label = BJILang.get(string.var("themeEditor.Input.{1}", { k }))
                    local w = GetColumnTextWidth(label)
                    if w > labelWidth then
                        labelWidth = w
                    end
                    table.insert(inputTypes, {
                        key = k,
                        label = label,
                    })
                end
            end
            for _, inputPreset in ipairs(inputPresets) do
                AccordionBuilder()
                    :label(inputPreset.label)
                    :commonStart(Separator)
                    :openedBehavior(function()
                        -- Preview String
                        drawPreview(
                            string.var("Input-{1}-cols-preview", { inputPreset.key }),
                            labelWidth,
                            inputTypes[3].label,
                            function()
                                LineBuilder()
                                    :inputString({
                                        id = string.var("Input-{1}-string-preview", { inputPreset.key }),
                                        value = "ABC123",
                                        style = INPUT_PRESETS[inputPreset.key],
                                        onChange = function() end,
                                    })
                                    :build()
                            end
                        )

                        -- Preview Numeric
                        drawPreview(
                            string.var("Input-{1}-cols-preview", { inputPreset.key }),
                            labelWidth,
                            inputTypes[4].label,
                            function()
                                LineBuilder()
                                    :inputNumeric({
                                        id = string.var("Input-{1}-numeric-preview", { inputPreset.key }),
                                        type = "float",
                                        value = 123.456,
                                        precision = 3,
                                        style = INPUT_PRESETS[inputPreset.key],
                                        onChange = function() end,
                                    })
                                    :build()
                            end
                        )

                        -- Base Color
                        local value = inputPreset.value[1]
                        local default = BJIContext.BJC.Server.Theme.Input[inputPreset.key][1]
                        local changed = not compareColorToDefault(value, default)
                        if changed then
                            te.changed = true
                        end
                        drawColorLine({
                            id = string.var("Input-{1}-{2}", { inputPreset.key, inputTypes[1].key }),
                            label = inputTypes[1].label,
                            labelWidth = labelWidth,
                            color = {
                                value = value,
                                onChange = function(color)
                                    te.data.Input[inputPreset.key][1] = color
                                    updateTheme()
                                end,
                            },
                            reset = changed and function()
                                te.data.Input[inputPreset.key][1] = table.clone(default)
                                updateTheme()
                            end
                        })

                        -- Override Text Color
                        value = inputPreset.value[2]
                        default = BJIContext.BJC.Server.Theme.Input[inputPreset.key][2]
                        if value and default then
                            changed = not compareColorToDefault(value, default)
                        else
                            changed = value ~= default
                        end
                        if changed then
                            te.changed = true
                        end
                        drawColorLine({
                            id = string.var("Input-{1}-{2}", { inputPreset.key, inputTypes[2].key }),
                            label = inputTypes[2].label,
                            labelWidth = labelWidth,
                            toggle = {
                                state = not not value,
                                onClick = function()
                                    if value then
                                        te.data.Input[inputPreset.key][2] = nil
                                    else
                                        te.data.Input[inputPreset.key][2] = table.clone(te.data.Text.DEFAULT)
                                    end
                                    updateTheme()
                                end
                            },
                            color = value and {
                                value = value,
                                onChange = function(color)
                                    te.data.Input[inputPreset.key][2] = color
                                    updateTheme()
                                end,
                            } or nil,
                            reset = changed and function()
                                te.data.Input[inputPreset.key][2] = table.clone(default)
                                updateTheme()
                            end
                        })
                    end)
                    :build()
            end
        end)
        :build()
end

local function drawBody(ctxt)
    te = BJIContext.ThemeEditor
    te.changed = false
    if not BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CORE) then
        BJIContext.ThemeEditor = nil
        return
    end


    drawThemeCategory("Fields")
    drawThemeCategory("Text")
    drawButtonsPresets()
    drawInputsPresets()
end

local function drawFooter(ctxt)
    local line = LineBuilder()
        :btnIcon({
            id = "cancel",
            icon = ICONS.exit_to_app,
            style = BTN_PRESETS.ERROR,
            onClick = onClose,
        })
    if te.changed then
        line:btnIcon({
            id = "reset",
            icon = ICONS.refresh,
            style = BTN_PRESETS.WARNING,
            onClick = function()
                te.data = table.clone(BJIContext.BJC.Server.Theme)
                te.changed = false
                updateTheme()
            end,
        })
            :btnIcon({
                id = "save",
                icon = ICONS.save,
                style = BTN_PRESETS.SUCCESS,
                onClick = save,
            })
    end
    line:build()
end

return {
    body = drawBody,
    footer = drawFooter,
    onClose = onClose,
}
