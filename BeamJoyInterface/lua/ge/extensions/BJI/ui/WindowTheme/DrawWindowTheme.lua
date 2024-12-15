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
    if not data.id or not data.label or not data.labelWidth then
        LogError("drawLabelPicker requires id, label and labelWidth")
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

    ColumnsBuilder(data.id, { data.labelWidth, -1 })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(data.label)
                        :build()
                end,
                function()
                    local line = LineBuilder()
                    if data.toggle then
                        line:btnIconSwitch({
                            id = svar("{1}-toggle", { data.id }),
                            iconEnabled = ICONS.check_circle,
                            iconDisabled = ICONS.cancel,
                            style = data.toggle.state and BTN_PRESETS.SUCCESS[1] or BTN_PRESETS.ERROR[1],
                            background = INPUT_PRESETS.TRANSPARENT[1],
                            state = not not data.toggle.state,
                            onClick = data.toggle.onClick,
                        })
                    end
                    if not data.toggle or data.toggle.state then
                        line:colorPicker({
                            id = svar("{1}-color", { data.id }),
                            value = data.color.value,
                            alpha = true,
                            onChange = data.color.onChange
                        })
                    end
                    if data.reset then
                        line:btnIcon({
                            id = svar("{1}-reset", { data.id }),
                            icon = ICONS.refresh,
                            background = BTN_PRESETS.WARNING,
                            onClick = data.reset,
                        })
                    end
                    line:build()
                end
            }
        })
        :build()
    Separator()
end

local function compareColorToDefault(color, default)
    if not color or not default then
        return color ~= default
    end
    for i = 1, 4 do
        -- forced to round because direct comparison returns false after a database save :(
        if Round(color[i], RGBA_PRECISION) ~= Round(default[i], RGBA_PRECISION) then
            return false
        end
    end
    return true
end

local function drawThemeCategory(cat)
    AccordionBuilder()
        :label(BJILang.get(svar("themeEditor.{1}.title", { cat })))
        :commonStart(Separator)
        :openedBehavior(function()
            local listInputs = {}
            local labelWidth = 0
            for key, value in pairs(te.data[cat]) do
                local label = BJILang.get(svar("themeEditor.{1}.{2}", { cat, key }))
                local w = GetColumnTextWidth(label)
                if w > labelWidth then
                    labelWidth = w
                end
                table.insert(listInputs, {
                    key = key,
                    value = value,
                    label = label,
                    default = BJIContext.BJC.Server.Theme[cat][key],
                })
            end
            table.sort(listInputs, function(a, b) return a.label < b.label end)
            for _, data in ipairs(listInputs) do
                local changed = not compareColorToDefault(data.value, data.default)
                if changed then
                    te.changed = true
                end
                drawColorLine({
                    id = svar("{1}-{2}", { cat, data.key }),
                    label = data.label,
                    labelWidth = labelWidth,
                    color = {
                        value = data.value,
                        onChange = function(color)
                            te.data[cat][data.key] = color
                            updateTheme()
                        end
                    },
                    reset = changed and function()
                        te.data[cat][data.key] = tdeepcopy(data.default)
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
                    label = BJILang.get(svar("themeEditor.Button.{1}", { key })),
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
                    local label = BJILang.get(svar("themeEditor.Button.{1}", { k }))
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
            for i, btnPreset in ipairs(btnPresets) do
                AccordionBuilder()
                    :label(btnPreset.label)
                    :commonStart(Separator)
                    :openedBehavior(function()
                        -- Preview
                        drawPreview(
                            svar("Button-{1}-cols-preview", { btnPreset.key }),
                            labelWidth,
                            btnTypes[5].label,
                            function()
                                LineBuilder()
                                    :btn({
                                        id = svar("Button-{1}-preview", { btnPreset.key }),
                                        label = "ABC123",
                                        style = BTN_PRESETS[btnPreset.key],
                                        onClick = function() end,
                                    })
                                    :build()
                            end
                        )

                        -- Base Color
                        local value = btnPreset.value[1]
                        local default = btnPreset.default[1]
                        local changed = not compareColorToDefault(value, default)
                        if changed then
                            te.changed = true
                        end
                        drawColorLine({
                            id = svar("Button-{1}-{2}", { btnPreset.key, btnTypes[1].key }),
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
                                te.data.Button[btnPreset.key][1] = tdeepcopy(default)
                                updateTheme()
                            end
                        })

                        -- Hovered Color
                        value = btnPreset.value[2]
                        default = btnPreset.default[2]
                        changed = not compareColorToDefault(value, default)
                        if changed then
                            te.changed = true
                        end
                        drawColorLine({
                            id = svar("Button-{1}-{2}", { btnPreset.key, btnTypes[2].key }),
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
                                te.data.Button[btnPreset.key][2] = tdeepcopy(default)
                                updateTheme()
                            end
                        })

                        -- Active Color
                        value = btnPreset.value[3]
                        default = btnPreset.default[3]
                        changed = not compareColorToDefault(value, default)
                        if changed then
                            te.changed = true
                        end
                        drawColorLine({
                            id = svar("Button-{1}-{2}", { btnPreset.key, btnTypes[3].key }),
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
                                te.data.Button[btnPreset.key][3] = tdeepcopy(default)
                                updateTheme()
                            end
                        })

                        -- Override Text Color
                        value = btnPreset.value[4]
                        default = btnPreset.default[4]
                        if value and default then
                            changed = not compareColorToDefault(value, default)
                        else
                            changed = value ~= default
                        end
                        if changed then
                            te.changed = true
                        end
                        drawColorLine({
                            id = svar("Button-{1}-{2}", { btnPreset.key, btnTypes[4].key }),
                            label = btnTypes[4].label,
                            labelWidth = labelWidth,
                            toggle = {
                                state = not not value,
                                onClick = function()
                                    if value then
                                        te.data.Button[btnPreset.key][4] = nil
                                    else
                                        te.data.Button[btnPreset.key][4] = tdeepcopy(te.data.Text.DEFAULT)
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
                                te.data.Button[btnPreset.key][4] = tdeepcopy(default)
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
                    default = BJIContext.BJC.Server.Theme.Input[key],
                    label = BJILang.get(svar("themeEditor.Input.{1}", { key })),
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
                    local label = BJILang.get(svar("themeEditor.Input.{1}", { k }))
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
            for i, btnPreset in ipairs(inputPresets) do
                AccordionBuilder()
                    :label(btnPreset.label)
                    :commonStart(Separator)
                    :openedBehavior(function()
                        -- Preview String
                        drawPreview(
                            svar("Input-{1}-cols-preview", { btnPreset.key }),
                            labelWidth,
                            inputTypes[3].label,
                            function()
                                LineBuilder()
                                    :inputString({
                                        id = svar("Input-{1}-string-preview", { btnPreset.key }),
                                        value = "ABC123",
                                        --width = math.floor(w),
                                        style = INPUT_PRESETS[btnPreset.key],
                                        onChange = function() end,
                                    })
                                    :build()
                            end
                        )

                        -- Preview Numeric
                        drawPreview(
                            svar("Input-{1}-cols-preview", { btnPreset.key }),
                            labelWidth,
                            inputTypes[4].label,
                            function()
                                LineBuilder()
                                    :inputNumeric({
                                        id = svar("Input-{1}-numeric-preview", { btnPreset.key }),
                                        type = "float",
                                        value = 123.456,
                                        precision = 3,
                                        --width = math.floor(w / 2) - numericButtonsWidth,
                                        style = INPUT_PRESETS[btnPreset.key],
                                        onChange = function() end,
                                    })
                                    :build()
                            end
                        )

                        -- Base Color
                        local value = btnPreset.value[1]
                        local default = btnPreset.default[1]
                        local changed = not compareColorToDefault(value, default)
                        if changed then
                            te.changed = true
                        end
                        drawColorLine({
                            id = svar("Input-{1}-{2}", { btnPreset.key, inputTypes[1].key }),
                            label = inputTypes[1].label,
                            labelWidth = labelWidth,
                            color = {
                                value = value,
                                onChange = function(color)
                                    te.data.Input[btnPreset.key][1] = color
                                    updateTheme()
                                end,
                            },
                            reset = changed and function()
                                te.data.Input[btnPreset.key][1] = tdeepcopy(default)
                                updateTheme()
                            end
                        })

                        -- Override Text Color
                        value = btnPreset.value[2]
                        default = btnPreset.default[2]
                        if value and default then
                            changed = not compareColorToDefault(value, default)
                        else
                            changed = value ~= default
                        end
                        if changed then
                            te.changed = true
                        end
                        drawColorLine({
                            id = svar("Input-{1}-{2}", { btnPreset.key, inputTypes[2].key }),
                            label = inputTypes[2].label,
                            labelWidth = labelWidth,
                            toggle = {
                                state = not not value,
                                onClick = function()
                                    if value then
                                        te.data.Input[btnPreset.key][2] = nil
                                    else
                                        te.data.Input[btnPreset.key][2] = tdeepcopy(te.data.Text.DEFAULT)
                                    end
                                    updateTheme()
                                end
                            },
                            color = value and {
                                value = value,
                                onChange = function(color)
                                    te.data.Input[btnPreset.key][2] = color
                                    updateTheme()
                                end,
                            } or nil,
                            reset = changed and function()
                                te.data.Input[btnPreset.key][2] = tdeepcopy(default)
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
            background = BTN_PRESETS.ERROR,
            onClick = onClose,
        })
    if te.changed then
        line:btnIcon({
            id = "reset",
            icon = ICONS.refresh,
            background = BTN_PRESETS.WARNING,
            onClick = function()
                te.data = tdeepcopy(BJIContext.BJC.Server.Theme)
                te.changed = false
                updateTheme()
            end,
        })
            :btnIcon({
                id = "save",
                icon = ICONS.save,
                background = BTN_PRESETS.SUCCESS,
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
