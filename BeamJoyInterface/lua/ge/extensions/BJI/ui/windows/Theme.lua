---@class BJIWindowTheme : BJIWindow
local W = {
    name = "Theme",
    minSize = ImVec2(350, 300),
    maxSize = ImVec2(500, 2000),

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
            resetToFactory = "",
            resetAll = "",
            close = "",
            save = "",
        },
    },
    BUTTON_ELEMENTS = { "baseColor", "hoveredColor", "activeColor", "overrideTextColor", "preview" },
    INPUT_ELEMENTS = { "baseColor", "overrideTextColor", "hoveredColor", "activeColor", "sliderGrabColor",
        "sliderGrabActiveColor", "previewString", "previewNumeric" },
}
-- gc prevention
local value, default, changed, typeLabels, nextValue

local function onClose(ctxt)
    if W.changed then
        BJI_Popup.createModal(BJI_Lang.get("themeEditor.cancelModal"), {
            BJI_Popup.createButton(BJI_Lang.get("common.buttons.cancel")),
            BJI_Popup.createButton(BJI_Lang.get("common.buttons.confirm"), function()
                BJI.Utils.Style.LoadTheme(BJI_Context.BJC.Server.Theme)
                W.show = false
            end),
        })
    else
        W.show = false
    end
end

local function updateLabels()
    Table({ "Fields", "Text", "Button", "Input" }):forEach(function(cat)
        W.labels.categoriesTitles[cat] = BJI_Lang.get(string.var("themeEditor.{1}.title", { cat }))
        W.labels.categoriesPresets[cat] = {}
        Table(W.data[cat]):forEach(function(_, key)
            W.labels.categoriesPresets[cat][key] = BJI_Lang.get(
                string.var("themeEditor.{1}.{2}", { cat, key })
            )
        end)
    end)

    W.labels.categoriesElements.Button = {}
    Table(W.BUTTON_ELEMENTS)
        :forEach(function(key)
            W.labels.categoriesElements.Button[key] = BJI_Lang.get(
                string.var("themeEditor.Button.{1}", { key }))
        end)

    W.labels.categoriesElements.Input = {}
    Table(W.INPUT_ELEMENTS)
        :forEach(function(key)
            W.labels.categoriesElements.Input[key] = BJI_Lang.get(
                string.var("themeEditor.Input.{1}", { key }))
        end)

    W.labels.buttons.reset = BJI_Lang.get("common.buttons.reset")
    W.labels.buttons.resetToFactory = BJI_Lang.get("themeEditor.resetAllTooltip")
    W.labels.buttons.resetAll = BJI_Lang.get("common.buttons.resetAll")
    W.labels.buttons.close = BJI_Lang.get("common.buttons.close")
    W.labels.buttons.save = BJI_Lang.get("common.buttons.save")
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI_Events.addListener(
        BJI_Events.EVENTS.LANG_CHANGED, updateLabels, W.name)
    )

    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.CACHE_LOADED,
        function(_, data)
            if W.saveProcess and data.cache == BJI_Cache.CACHES.BJC then
                W.open()
                W.changed = false
                W.saveProcess = false
            end
        end, W.name))
end
local function onUnload()
    listeners:forEach(BJI_Events.removeListener)
end

local function updateTheme()
    BJI.Utils.Style.LoadTheme(W.data)
    if table.compare(W.data, BJI_Context.BJC.Server.Theme, true) then
        W.changed = false
    end
end

local function save()
    W.saveProcess = true
    BJI_Tx_config.bjc("Server.Theme", W.data)
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
    if BeginTree(W.labels.categoriesTitles[cat]) then
        if BeginTable("BJITheme-" .. cat, {
                { label = "##theme-" .. cat .. "-labels" },
                { label = "##theme-" .. cat .. "-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } }
            }, { flags = { TABLE_FLAGS.BORDERS_INNER_H, TABLE_FLAGS.ALTERNATE_ROW_BG } }) then
            Table(W.data[cat]):map(function(v, k)
                return { v = v, k = k }
            end):sort(function(a, b)
                return W.labels.categoriesPresets[cat][a.k] < W.labels.categoriesPresets[cat][b.k]
            end):forEach(function(el)
                TableNewRow()
                nextValue = ColorPickerAlpha(cat .. "-" .. el.k .. "-color", ImVec4(table.unpack(el.v)))
                if nextValue then
                    W.data[cat][el.k] = math.vec4ColorToStorage(nextValue)
                    updateTheme()
                end
                TableNextColumn()
                if not table.compare(W.data[cat][el.k], BJI_Context.BJC.Server.Theme[cat][el.k]) then
                    W.changed = true
                    if IconButton(cat .. "-" .. el.k .. "-reset", BJI.Utils.Icon.ICONS.refresh, { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING }) then
                        W.data[cat][el.k] = table.clone(BJI_Context.BJC.Server.Theme[cat][el.k])
                        updateTheme()
                    end
                    TooltipText(W.labels.buttons.reset)
                    SameLine()
                end
                Text(W.labels.categoriesPresets[cat][el.k])
            end)

            EndTable()
        end
        EndTree()
    end
end

local function drawButtonsPresets()
    if BeginTree(W.labels.categoriesTitles.Button) then
        typeLabels = Table(W.BUTTON_ELEMENTS)
            :map(function(k)
                return W.labels.categoriesElements.Button[k]
            end)
        Table(W.data.Button):map(function(v, k)
            return { v = v, k = k }
        end):sort(function(a, b)
            return W.labels.categoriesPresets.Button[a.k] < W.labels.categoriesPresets.Button[b.k]
        end):forEach(function(el)
            Separator()
            if BeginTree(W.labels.categoriesPresets.Button[el.k]) then
                Indent()
                if BeginTable("BJITheme-Button", {
                        { label = "##theme-Button-labels" },
                        { label = "##theme-Button-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } }
                    }, { flags = { TABLE_FLAGS.BORDERS_INNER_H } }) then
                    -- preview
                    TableNewRow()
                    Text(typeLabels[5])
                    TableNextColumn()
                    Button("theme-Button-preview-btn", "ABC123", { btnStyle = BJI.Utils.Style.BTN_PRESETS[el.k] })
                    IconButton("theme-Button-preview-iconbtn", BJI.Utils.Icon.ICONS.bug_report,
                        { btnStyle = BJI.Utils.Style.BTN_PRESETS[el.k] })

                    -- other sections
                    Range(1, 4):forEach(function(i)
                        value = el.v[i]
                        default = BJI_Context.BJC.Server.Theme.Button[el.k][i]
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

                        TableNewRow()
                        Text(typeLabels[i])
                        TableNextColumn()
                        if i == 4 then
                            if IconButton("theme-button-" .. el.k .. "-" .. tostring(i) .. "-toggle", value and
                                    BJI.Utils.Icon.ICONS.check_circle or BJI.Utils.Icon.ICONS.cancel, { btnStyle = value and BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR, bgLess = true }) then
                                if value then
                                    W.data.Button[el.k][4] = nil
                                else
                                    W.data.Button[el.k][4] = table.clone(W.data.Text.DEFAULT)
                                end
                                updateTheme()
                            end
                            SameLine()
                        end
                        if i ~= 4 or value then
                            nextValue = ColorPickerAlpha("theme-button-" .. el.k .. "-" .. tostring(i) .. "-color",
                                ImVec4(table.unpack(value)))
                            if nextValue then
                                W.data.Button[el.k][i] = math.vec4ColorToStorage(nextValue)
                                updateTheme()
                            end
                            SameLine()
                        end
                        if changed then
                            if IconButton("theme-button-" .. el.k .. "-" .. tostring(i) .. "-reset",
                                    BJI.Utils.Icon.ICONS.refresh, { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING }) then
                                W.data.Button[el.k][i] = table.clone(default)
                                updateTheme()
                            end
                            TooltipText(W.labels.buttons.reset)
                        end
                    end)

                    EndTable()
                end
                Unindent()

                EndTree()
            end
        end)
        EndTree()
    end
end

local function drawInputsPresets()
    if BeginTree(W.labels.categoriesTitles.Input) then
        typeLabels = Table(W.INPUT_ELEMENTS)
            :map(function(k)
                return W.labels.categoriesElements.Input[k]
            end)
        Table(W.data.Input):map(function(v, k)
            return { v = v, k = k }
        end):sort(function(a, b)
            return W.labels.categoriesPresets.Input[a.k] < W.labels.categoriesPresets.Input[b.k]
        end):forEach(function(el)
            Separator()
            if BeginTree(W.labels.categoriesPresets.Input[el.k]) then
                Indent()
                if BeginTable("BJITheme-Input", {
                        { label = "##theme-Input-labels" },
                        { label = "##theme-Input-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } }
                    }, { flags = { TABLE_FLAGS.BORDERS_INNER_H } }) then
                    -- preview string
                    TableNewRow()
                    Text(typeLabels[7])
                    TableNextColumn()
                    InputText("theme-Input-" .. el.k .. "-7-preview-string", "ABC123",
                        { inputStyle = BJI.Utils.Style.INPUT_PRESETS[el.k] })

                    -- preview numeric
                    TableNewRow()
                    Text(typeLabels[8])
                    TableNextColumn()
                    SliderFloatPrecision("theme-Input-" .. el.k .. "-8-preview-numeric", 50, 0, 100,
                        { inputStyle = BJI.Utils.Style.INPUT_PRESETS[el.k], btnStyle = BJI.Utils.Style.BTN_PRESETS[el.k] })

                    Range(1, 6):filter(function(i) return i ~= 2 end):forEach(function(i)
                        value = el.v[i]
                        default = BJI_Context.BJC.Server.Theme.Input[el.k][i]
                        changed = not compareColorToDefault(value, default)
                        if changed then
                            W.changed = true
                        end
                        TableNewRow()
                        Text(typeLabels[i])
                        TableNextColumn()
                        nextValue = ColorPickerAlpha("theme-Input-" .. el.k .. "-" .. tostring(i),
                            ImVec4(table.unpack(value)))
                        if nextValue then
                            W.data.Input[el.k][i] = math.vec4ColorToStorage(nextValue)
                            updateTheme()
                        end
                        if changed then
                            SameLine()
                            if IconButton("theme-Input-" .. el.k .. "-" .. tostring(i) .. "-reset", BJI.Utils.Icon.ICONS.refresh, { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING }) then
                                W.data.Input[el.k][i] = table.clone(default)
                                updateTheme()
                            end
                            TooltipText(W.labels.buttons.reset)
                        end
                    end)

                    -- Override Text Color
                    value = el.v[2]
                    default = BJI_Context.BJC.Server.Theme.Input[el.k][2]
                    if value and default then
                        changed = not compareColorToDefault(value, default)
                    else
                        changed = value ~= default
                    end
                    if changed then
                        W.changed = true
                    end
                    TableNewRow()
                    Text(typeLabels[2])
                    TableNextColumn()
                    if IconButton("theme-Input-" .. el.k .. "-text-" .. "-toggle", value and
                            BJI.Utils.Icon.ICONS.check_circle or BJI.Utils.Icon.ICONS.cancel, { btnStyle = value and BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR, bgLess = true }) then
                        if value then
                            W.data.Input[el.k][2] = nil
                        else
                            W.data.Input[el.k][2] = table.clone(W.data.Text.DEFAULT)
                        end
                        updateTheme()
                    end
                    if value then
                        SameLine()
                        nextValue = ColorPickerAlpha("theme-Input-" .. el.k .. "-text-color", ImVec4(table.unpack(value)))
                        if nextValue then
                            W.data.Input[el.k][2] = math.vec4ColorToStorage(nextValue)
                            updateTheme()
                        end
                    end
                    if changed then
                        SameLine()
                        if IconButton("theme-Input-" .. el.k .. "-text-color-reset", BJI.Utils.Icon.ICONS.refresh, { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING }) then
                            W.data.Input[el.k][2] = table.clone(default)
                            updateTheme()
                        end
                        TooltipText(W.labels.buttons.reset)
                    end

                    EndTable()
                end
                Unindent()

                EndTree()
            end
        end)

        EndTree()
    end
end

---@param ctxt TickContext
local function drawBody(ctxt)
    Table({ "Fields", "Text" }):forEach(function(cat)
        drawThemeCategory(cat)
        Separator()
    end)
    drawButtonsPresets()
    Separator()
    drawInputsPresets()
end

---@param ctxt TickContext
local function drawFooter(ctxt)
    if IconButton("theme-cancel", BJI.Utils.Icon.ICONS.exit_to_app, { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
        onClose()
    end
    TooltipText(W.labels.buttons.close)
    SameLine()
    if IconButton("theme-resetAll", BJI.Utils.Icon.ICONS.delete_forever, { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
        BJI_Popup.createModal(BJI_Lang.get("themeEditor.resetAllModal"), {
            BJI_Popup.createButton(BJI_Lang.get("common.buttons.cancel")),
            BJI_Popup.createButton(BJI_Lang.get("common.buttons.confirm"), function()
                W.saveProcess = true
                BJI_Tx_config.bjc("Server.Theme")
            end)
        })
    end
    TooltipText(W.labels.buttons.resetToFactory)
    if W.changed then
        SameLine()
        if IconButton("theme-reset", BJI.Utils.Icon.ICONS.refresh, { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING }) then
            W.data = table.clone(BJI_Context.BJC.Server.Theme)
            W.changed = false
            updateTheme()
        end
        TooltipText(W.labels.buttons.resetAll)
        SameLine()
        if IconButton("theme-save", BJI.Utils.Icon.ICONS.save, { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
            save()
        end
        TooltipText(W.labels.buttons.save)
    end
end

local function open()
    W.data = Table(BJI_Context.BJC.Server.Theme):clone()
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
