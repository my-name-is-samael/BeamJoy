---@class BJIWindowTheme : BJIWindow
local W = {
    name = "Theme",
    w = 350,
    h = 750,

    show = false,
    changed = false,
    saveProcess = false,
    ---@type table<string, table>?
    data = nil,
    labels = {
        categoriesTitles = {},
        categoriesPresets = {},
        categoriesElements = {},
        buttons = {
            reset = "",
            resetAll = "",
            close = "",
            save = "",
        },
    },
    widths = {
        Button = 0,
        Input = 0,
    },
    BUTTON_ELEMENTS = { "baseColor", "hoveredColor", "activeColor", "overrideTextColor", "preview" },
    INPUT_ELEMENTS = { "baseColor", "overrideTextColor", "previewString", "previewNumeric" },
}

local function onClose(ctxt)
    if W.changed then
        BJI.Managers.Popup.createModal(BJI.Managers.Lang.get("themeEditor.cancelModal"), {
            BJI.Managers.Popup.createButton(BJI.Managers.Lang.get("common.buttons.cancel")),
            BJI.Managers.Popup.createButton(BJI.Managers.Lang.get("common.buttons.confirm"), function()
                BJI.Utils.Style.LoadTheme(BJI.Managers.Context.BJC.Server.Theme)
                W.show = false
            end),
        })
    else
        W.show = false
    end
end

local function updateLabels()
    Table({ "Fields", "Text", "Button", "Input" }):forEach(function(cat)
        W.labels.categoriesTitles[cat] = BJI.Managers.Lang.get(string.var("themeEditor.{1}.title", { cat }))
        W.labels.categoriesPresets[cat] = {}
        Table(W.data[cat]):forEach(function(_, key)
            W.labels.categoriesPresets[cat][key] = BJI.Managers.Lang.get(
                string.var("themeEditor.{1}.{2}", { cat, key })
            )
        end)
    end)

    W.labels.categoriesElements.Button = {}
    Table(W.BUTTON_ELEMENTS)
        :forEach(function(key)
            W.labels.categoriesElements.Button[key] = BJI.Managers.Lang.get(
                string.var("themeEditor.Button.{1}", { key }))
        end)

    W.labels.categoriesElements.Input = {}
    Table(W.INPUT_ELEMENTS)
        :forEach(function(key)
            W.labels.categoriesElements.Input[key] = BJI.Managers.Lang.get(
                string.var("themeEditor.Input.{1}", { key }))
        end)

    W.labels.buttons.reset = BJI.Managers.Lang.get("common.buttons.reset")
    W.labels.buttons.resetAll = BJI.Managers.Lang.get("common.buttons.resetAll")
    W.labels.buttons.close = BJI.Managers.Lang.get("common.buttons.close")
    W.labels.buttons.save = BJI.Managers.Lang.get("common.buttons.save")
end

local function updateWidths()
    W.widths.Button = Table(W.BUTTON_ELEMENTS)
        :reduce(function(acc, k)
            local w = BJI.Utils.UI.GetColumnTextWidth(W.labels.categoriesElements.Button[k])
            return w > acc and w or acc
        end, 0)

    W.widths.Input = Table(W.INPUT_ELEMENTS)
        :reduce(function(acc, k)
            local w = BJI.Utils.UI.GetColumnTextWidth(W.labels.categoriesElements.Input[k])
            return w > acc and w or acc
        end, 0)
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, function()
        updateLabels()
        updateWidths()
    end, W.name))

    updateWidths()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED,
    }, updateWidths, W.name))

    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.CACHE_LOADED,
        function(_, data)
            if W.saveProcess and data.cache == BJI.Managers.Cache.CACHES.BJC then
                W.open()
                W.changed = false
                W.saveProcess = false
            end
        end, W.name))
end
local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

local function updateTheme()
    BJI.Utils.Style.LoadTheme(W.data)
    if table.compare(W.data, BJI.Managers.Context.BJC.Server.Theme, true) then
        W.changed = false
    end
end

local function save()
    W.saveProcess = true
    BJI.Tx.config.bjc("Server.Theme", W.data)
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
        LineLabel(data.label, nil, sameLine == true)
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
                icon = BJI.Utils.Icon.ICONS.refresh,
                style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                tooltip = W.labels.buttons.reset,
                onClick = data.reset,
            })
        end
        line:build()
    end

    if data.reverse then
        drawInputs()
        drawLabel(true)
    else
        ColumnsBuilder(data.id, { data.labelWidth, -1 }):addRow({
            cells = { drawLabel, drawInputs }
        }):build()
    end
    Separator()
end

local function compareColorToDefault(color, default)
    if not color or not default then
        return color ~= default
    end
    for i = 1, 4 do
        -- forced to round because direct comparison returns false after a database save :(
        if math.round(color[i], BJI.Utils.Style.RGBA_PRECISION) ~= math.round(default[i], BJI.Utils.Style.RGBA_PRECISION) then
            return false
        end
    end
    return true
end

---@param cat string
local function drawThemeCategory(cat)
    AccordionBuilder():label(W.labels.categoriesTitles[cat]):commonStart(Separator):openedBehavior(function()
        local listInputs = {}
        for key, value in pairs(W.data[cat]) do
            local label = W.labels.categoriesPresets[cat][key]
            table.insert(listInputs, {
                key = key,
                value = value,
                label = label,
            })
        end
        table.sort(listInputs, function(a, b) return a.label < b.label end)
        for _, data in ipairs(listInputs) do
            local changed = not compareColorToDefault(data.value,
                BJI.Managers.Context.BJC.Server.Theme[cat][data.key])
            if changed then
                W.changed = true
            end
            drawColorLine({
                id = string.var("{1}-{2}", { cat, data.key }),
                label = data.label,
                reverse = true,
                color = {
                    value = data.value,
                    onChange = function(color)
                        W.data[cat][data.key] = color
                        updateTheme()
                    end
                },
                reset = changed and function()
                    W.data[cat][data.key] = table.clone(BJI.Managers.Context.BJC.Server.Theme[cat][data.key])
                    updateTheme()
                end
            })
        end
    end):build()
end

---@param id string
---@param labelWidth integer
---@param previewLabel string
---@param render fun()
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
        :label(W.labels.categoriesTitles.Button)
        :commonStart(Separator)
        :openedBehavior(function()
            local btnPresets = Table(W.data.Button):map(function(v, k)
                return {
                    key = k,
                    value = v,
                    default = BJI.Managers.Context.BJC.Server.Theme.Button[k],
                    label = W.labels.categoriesPresets.Button[k],
                }
            end):sort(function(a, b) return a.label < b.label end) or Table()

            local btnTypes = Table(W.BUTTON_ELEMENTS)
                :map(function(k)
                    return {
                        key = k,
                        label = W.labels.categoriesElements.Button[k],
                    }
                end)

            btnPresets:forEach(function(btnPreset)
                AccordionBuilder():label(btnPreset.label):commonStart(Separator):openedBehavior(function()
                    -- Preview
                    drawPreview(
                        string.var("Button-{1}-cols-preview", { btnPreset.key }),
                        W.widths.Button,
                        btnTypes[5].label,
                        function()
                            LineBuilder():btn({
                                id = string.var("Button-{1}-preview-text", { btnPreset.key }),
                                label = "ABC123",
                                style = BJI.Utils.Style.BTN_PRESETS[btnPreset.key],
                                onClick = function() end,
                            }):btnIcon({
                                id = string.var("Button-{1}-preview-icon", { btnPreset.key }),
                                icon = BJI.Utils.Icon.ICONS.bug_report,
                                style = BJI.Utils.Style.BTN_PRESETS[btnPreset.key],
                                onClick = function() end,
                            }):build()
                        end
                    )

                    local value, default, changed
                    Range(1, 4):forEach(function(i)
                        value = btnPreset.value[i]
                        default = BJI.Managers.Context.BJC.Server.Theme.Button[btnPreset.key][i]
                        if i < 4 then
                            changed = not compareColorToDefault(value, default)
                        else
                            if value and default then
                                changed = not compareColorToDefault(value, default)
                            else
                                changed = value ~= default
                            end
                        end
                        if changed then
                            W.changed = true
                        end
                        drawColorLine({
                            id = string.var("Button-{1}-{2}", { btnPreset.key, btnTypes[i].key }),
                            label = btnTypes[i].label,
                            labelWidth = W.widths.Button,
                            color = {
                                value = value,
                                onChange = function(color)
                                    W.data.Button[btnPreset.key][i] = color
                                    updateTheme()
                                end,
                            },
                            reset = changed and function()
                                W.data.Button[btnPreset.key][i] = table.clone(default)
                                updateTheme()
                            end,
                            toggle = i == 4 and {
                                state = not not value,
                                onClick = function()
                                    if value then
                                        W.data.Button[btnPreset.key][4] = nil
                                    else
                                        W.data.Button[btnPreset.key][4] = table.clone(W.data.Text.DEFAULT)
                                    end
                                    updateTheme()
                                end
                            } or nil,
                        })
                    end)
                end):build()
            end)
        end):build()
end

local function drawInputsPresets()
    AccordionBuilder()
        :label(W.labels.categoriesTitles.Input)
        :commonStart(Separator)
        :openedBehavior(function()
            local inputPresets = Table(W.data.Input)
                :map(function(value, key)
                    return {
                        key = key,
                        value = value,
                        label = W.labels.categoriesPresets.Input[key],
                    }
                end):sort(function(a, b) return a.label < b.label end) or Table()

            local inputTypes = Table(W.INPUT_ELEMENTS)
                :map(function(k)
                    return {
                        key = k,
                        label = W.labels.categoriesElements.Input[k],
                    }
                end)

            inputPresets:forEach(function(inputPreset)
                AccordionBuilder()
                    :label(inputPreset.label)
                    :commonStart(Separator)
                    :openedBehavior(function()
                        -- Preview String
                        drawPreview(
                            string.var("Input-{1}-cols-preview", { inputPreset.key }),
                            W.widths.Input,
                            inputTypes[3].label,
                            function()
                                LineBuilder()
                                    :inputString({
                                        id = string.var("Input-{1}-string-preview", { inputPreset.key }),
                                        value = "ABC123",
                                        style = BJI.Utils.Style.INPUT_PRESETS[inputPreset.key],
                                        onChange = function() end,
                                    })
                                    :build()
                            end
                        )

                        -- Preview Numeric
                        drawPreview(
                            string.var("Input-{1}-cols-preview", { inputPreset.key }),
                            W.widths.Input,
                            inputTypes[4].label,
                            function()
                                LineBuilder()
                                    :inputNumeric({
                                        id = string.var("Input-{1}-numeric-preview", { inputPreset.key }),
                                        type = "float",
                                        value = 123.456,
                                        precision = 3,
                                        style = BJI.Utils.Style.INPUT_PRESETS[inputPreset.key],
                                        onChange = function() end,
                                    })
                                    :build()
                            end
                        )

                        -- Base Color
                        local value = inputPreset.value[1]
                        local default = BJI.Managers.Context.BJC.Server.Theme.Input[inputPreset.key][1]
                        local changed = not compareColorToDefault(value, default)
                        if changed then
                            W.changed = true
                        end
                        drawColorLine({
                            id = string.var("Input-{1}-{2}", { inputPreset.key, inputTypes[1].key }),
                            label = inputTypes[1].label,
                            labelWidth = W.widths.Input,
                            color = {
                                value = value,
                                onChange = function(color)
                                    W.data.Input[inputPreset.key][1] = color
                                    updateTheme()
                                end,
                            },
                            reset = changed and function()
                                W.data.Input[inputPreset.key][1] = table.clone(default)
                                updateTheme()
                            end
                        })

                        -- Override Text Color
                        value = inputPreset.value[2]
                        default = BJI.Managers.Context.BJC.Server.Theme.Input[inputPreset.key][2]
                        if value and default then
                            changed = not compareColorToDefault(value, default)
                        else
                            changed = value ~= default
                        end
                        if changed then
                            W.changed = true
                        end
                        drawColorLine({
                            id = string.var("Input-{1}-{2}", { inputPreset.key, inputTypes[2].key }),
                            label = inputTypes[2].label,
                            labelWidth = W.widths.Input,
                            toggle = {
                                state = not not value,
                                onClick = function()
                                    if value then
                                        W.data.Input[inputPreset.key][2] = nil
                                    else
                                        W.data.Input[inputPreset.key][2] = table.clone(W.data.Text.DEFAULT)
                                    end
                                    updateTheme()
                                end
                            },
                            color = value and {
                                value = value,
                                onChange = function(color)
                                    W.data.Input[inputPreset.key][2] = color
                                    updateTheme()
                                end,
                            } or nil,
                            reset = changed and function()
                                W.data.Input[inputPreset.key][2] = table.clone(default)
                                updateTheme()
                            end
                        })
                    end)
                    :build()
            end)
        end)
        :build()
end

---@param ctxt TickContext
local function drawBody(ctxt)
    Table({ "Fields", "Text" }):forEach(function(cat)
        drawThemeCategory(cat)
    end)
    drawButtonsPresets()
    drawInputsPresets()
end

---@param ctxt TickContext
local function drawFooter(ctxt)
    local line = LineBuilder():btnIcon({
        id = "cancel",
        icon = BJI.Utils.Icon.ICONS.exit_to_app,
        style = BJI.Utils.Style.BTN_PRESETS.ERROR,
        tooltip = W.labels.buttons.close,
        onClick = onClose,
    })
    if W.changed then
        line:btnIcon({
            id = "reset",
            icon = BJI.Utils.Icon.ICONS.refresh,
            style = BJI.Utils.Style.BTN_PRESETS.WARNING,
            tooltip = W.labels.buttons.resetAll,
            onClick = function()
                W.data = table.clone(BJI.Managers.Context.BJC.Server.Theme)
                W.changed = false
                updateTheme()
            end,
        }):btnIcon({
            id = "save",
            icon = BJI.Utils.Icon.ICONS.save,
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            tooltip = W.labels.buttons.save,
            onClick = save,
        })
    end
    line:build()
end

local function open()
    W.data = Table(BJI.Managers.Context.BJC.Server.Theme):clone()
    W.show = true
end

W.onLoad = onLoad
W.onUnload = onUnload
W.body = drawBody
W.footer = drawFooter
W.onClose = onClose
W.open = open
W.getState = function() return W.show end

return W
