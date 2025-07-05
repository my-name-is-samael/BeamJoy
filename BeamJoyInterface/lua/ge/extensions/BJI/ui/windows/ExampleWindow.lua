---@class BJIWindowExample
local W = {
    name = "Example",
    --size = ImVec2(150,300), -- fixed size
    --minSize = ImVec2(150,300), -- minimum size (if no fixed size)
    --maxSize = ImVec2(200,350), -- maximum size (if no fixed size)
    --position = ImVec2(275,483), -- fixed window position

    show = false,
}

W.onLoad = function()
    LogDebug("On window opening hook")
end
W.onUnload = function()
    LogDebug("On window closing hook")
end

local menuItemsWidth = 0                                            -- center menu feature
W.menu = function()
    SetCursorPosX((GetContentRegionAvail().x - menuItemsWidth) / 2) -- center menu feature
    local startX = GetCursorPosX()                                  -- center menu feature

    RenderMenuDropdown("Automatic dropdown", {
        {
            type = "menu",
            label = "Nested dropdown",
            color = ImVec4(.66, .1, .1, 1),
            elems = {
                { type = "item", label = "Nested dropdown entry 1" },
                { type = "item", label = "Nested dropdown entry 2", checked = true, color = ImVec4(.33, .66, .66, 1) },
            }
        },
        { type = "item",     label = "Menu entry" },
        { type = "item",     label = "Menu entry checked",                      checked = true },
        { type = "item",     label = "Menu entry disabled",                     disabled = true },
        { type = "item",     label = "Menu entry checked and disabled",         checked = true, disabled = true },
        { type = "item",     label = "Menu entry active",                       active = true },
        { type = "item",     label = "Menu entry active and checked",           active = true,  checked = true },
        { type = "item",     label = "Menu entry active and disabled",          active = true,  disabled = true },
        { type = "item",     label = "Menu entry active, checked and disabled", active = true,  checked = true, disabled = true },
        { type = "separator" },
        {
            type = "custom",
            label = "Menu entry custom",
            render = function()
                Text("Menu entry custom", { color = ImVec4(0, 1, 0, 1) })
                SameLine()
                Icon(BJI.Utils.Icon.ICONS.filter_list, { color = ImVec4(.66, .2, .66, 1) })
            end
        },
    })
    local opened = BeginMenu("Manual dropdown")
    if opened then
        PushStyleColor(BJI.Utils.Style.STYLE_COLS.TEXT_COLOR, ImVec4(.66, .1, .1, 1))
        local opened2 = BeginMenu("Nested dropdown")
        PopStyleColor(1)
        if opened2 then
            MenuItem("Nested dropdown entry 1")
            PushStyleColor(BJI.Utils.Style.STYLE_COLS.TEXT_COLOR, ImVec4(.33, .66, .66, 1))
            MenuItem("Nested dropdown entry 2", nil, true)
            PopStyleColor(1)
        end
        EndMenu(opened2)

        MenuItem("Menu entry")
        MenuItem("Menu entry checked", nil, true)
        MenuItem("Menu entry disabled", nil, false, false)
        MenuItem("Menu entry checked and disabled", nil, true, false)
        Separator()
        Text("Menu entry custom", { color = ImVec4(0, 1, 0, 1) })
        SameLine()
        Icon(BJI.Utils.Icon.ICONS.filter_list, { color = ImVec4(.66, .2, .66, 1) })
    end
    EndMenu(opened)

    MenuItem("Item checked", nil, true, true)
    MenuItem("Item disabled", nil, false, false)
    MenuItem("Item checked and disabled", nil, true, false)

    menuItemsWidth = GetCursorPosX() - startX -- center menu feature
end

-- optional, to render top-sticked content
W.header = function()
    if BeginChild("header", {
            size = ImVec2(-1, 50),
            bgColor = ImVec4(1, 0, 0, .2)
        }) then
        if BeginTable("scaleLine", {
                { label = "left", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
                { label = "right" },
            }) then
            TableNewRow()
            Text("Header", { align = "center" })

            TableNextColumn()
            ShowHelpMarker("Example helpmarker")
            SameLine()
            local scale = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.UI_SCALE)
            Text(string.format("Zoom : %.2f", scale))
            SameLine()
            if IconButton("zoomout", BJI.Utils.Icon.ICONS.zoom_out, { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING }) then
                scale = scale - .25
                BJI.Managers.LocalStorage.set(BJI.Managers.LocalStorage.GLOBAL_VALUES.UI_SCALE, scale)
            end
            SameLine()
            if IconButton("zoomin", BJI.Utils.Icon.ICONS.zoom_in, { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
                scale = scale + .25
                BJI.Managers.LocalStorage.set(BJI.Managers.LocalStorage.GLOBAL_VALUES.UI_SCALE, scale)
            end

            EndTable()
        end
    end
    EndChild()
end

local function drawColumns()
    if Columns(3, "columns1", true) then -- borders and no widths make columns resizable
        Text("Columns with borders")
        ColumnNext()
        Text("2nd column")
        ColumnNext()
        Text("3rd column")
        EndColumns()
    end
    Separator()

    if Columns(3, "columns2", false) then -- no borders make widths mandatory (otherwise only last column is visible)
        Text("Columns without borders")
        ColumnNext()
        Text("2nd column")
        ColumnNext()
        Text("3rd column")
        EndColumns()
    end
    Separator()

    if Columns(3, "columns3", false) then
        ColumnSetWidth(GetWindowSize().x / 3)
        Text("Columns without borders and with fixed widths")
        ColumnNext()
        ColumnSetWidth(GetWindowSize().x / 3)
        Text("2nd column (fixed width)")
        ColumnNext()
        Text("3rd column (floating)")
        EndColumns()
    end
    Separator()

    if Columns(4, "columns4") then
        ColumnSetWidth(GetWindowSize().x / 4)
        Text("Columns with some floating columns")
        ColumnNext()
        ColumnSetWidth(GetWindowSize().x / 4)
        Text("2nd column (fixed width)")
        ColumnNext()
        Text("3rd column (floating)")
        ColumnNext()
        Text("4th column (floating)")
        EndColumns()
    end
    Separator()

    Columns(1)
end

local function drawTables()
    Text("Mixed table", { align = "center" })
    if BeginTable("table1", {
                { label = "Header 1", flags = { TABLE_COLUMNS_FLAGS.NO_RESIZE } },
                { label = "Header 2", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
                { label = "Header 3" },
            },
            { showHeader = true, flags = { TABLE_FLAGS.ALTERNATE_ROW_BG, TABLE_FLAGS.BORDERS_INNER_H, TABLE_FLAGS.RESIZABLE } }) then
        TableNewRow()
        Text("1st line 1st column")
        TableNextColumn()
        Text("1st line 2nd column")
        TableNextColumn()
        Text("1st line 3rd column")

        TableNewRow()
        Text("2nd line 1st column")
        TableNextColumn()
        SliderIntPrecision("tableSliderInt1", 50, 0, 100,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, formatRender = "Hello Slider !" })
        TableNextColumn()
        Text("2nd line 3rd column")

        EndTable()
    end
    EmptyLine()

    Text("No header fixed table", { align = "center" })
    if BeginTable("table2", {
            { label = "Header 1" },
            { label = "Header 2" },
            { label = "Header 3" },
        }, { flags = { TABLE_FLAGS.BORDERS_INNER, TABLE_FLAGS.PRECISE_WIDTHS } }) then
        TableNewRow()
        Text("1st line 1st column")
        TableNextColumn()
        Text("1st line 2nd column longer")
        TableNextColumn()
        Text("1st line 3rd column")

        TableNewRow()
        Text("2nd line 1st column")
        TableNextColumn()
        Text("2nd line 2nd column")
        TableNextColumn()
        Text("2nd line 3rd column longer")
        EndTable()
    end
end

local ml1, ml2, ml3, ml4 = "test multiline", "test multiline\nwith 2 lines",
    "test multiline\nwith 3 lines\nand its a lot", ""
W.body = function()
    if BeginChild("body", {
            bgColor = ImVec4(0, 1, 0, .2)
        }) then
        drawColumns()
        EmptyLine()

        drawTables()
        EmptyLine()

        Icon(BJI.Utils.Icon.ICONS.build, { color = ImVec4(1, 1, 0, 1) })
        if IsItemHovered() then
            BeginTooltip()
            Text("My awesome custom tooltip !")
            Text("Even with a second line and an icon =>")
            SameLine()
            Icon(BJI.Utils.Icon.ICONS.AIRace, { big = true, color = ImVec4(.33, 1, .33, 1) })
            EndTooltip()
        end
        SameLine()
        Text("<= Icon with a custom tooltip")
        EmptyLine()

        Text("Buttons", { align = "center" })
        Button("btn1", "My long name button", { disabled = true })
        Button("btn2", "My long name button", { width = -1 })
        Button("btn3", "My long name button that will get cropped", { width = 100 })
        Button("btn4", "My long name button", { width = -100 })
        EmptyLine()

        Text("IntInputs", { align = "center" })
        InputInt("inputint1", 50, { disabled = true })
        InputInt("inputint2", 50, { width = -1 })
        InputInt("inputint3", 50, { width = 200 })
        InputInt("inputint4", 50, { width = -200 })
        EmptyLine()

        Text("FloatInputs", { align = "center" })
        InputFloat("inputfloat1", 50, { disabled = true })
        InputFloat("inputfloat2", 50, { width = -1 })
        InputFloat("inputfloat3", 50, { width = 200 })
        InputFloat("inputfloat4", 50, { width = -200 })
        EmptyLine()

        Text("IntSlider", { align = "center" })
        SliderInt("sliderint1", 50, 0, 100, { disabled = true })
        SliderInt("sliderint2", 50, 0, 100, { width = -1 })
        SliderInt("sliderint3", 50, 0, 100, { width = 200 })
        SliderInt("sliderint4", 50, 0, 100, { width = -200 })
        EmptyLine()

        Text("FloatSlider", { align = "center" })
        SliderFloat("sliderfloat1", 50, 0, 100, { disabled = true })
        SliderFloat("sliderfloat2", 50, 0, 100, { width = -1, precision = 0 })
        SliderFloat("sliderfloat3", 50, 0, 100, { width = 200, precision = 2 })
        SliderFloat("sliderfloat4", 50, 0, 100, { width = -200, precision = 3 })
        EmptyLine()

        Text("PrecisionIntSlider", { align = "center" })
        SliderIntPrecision("sliderint1", 50, 0, 100, { disabled = true })
        SliderIntPrecision("sliderint2", 50, 0, 100, { width = -1 })
        SliderIntPrecision("sliderint3", 50, 0, 100, { width = 200 })
        SliderIntPrecision("sliderint4", 50, 0, 100, { width = -200 })
        EmptyLine()

        Text("PrecisionFloatSlider", { align = "center" })
        SliderFloatPrecision("sliderfloat1", 50, 0, 100, { disabled = true })
        SliderFloatPrecision("sliderfloat2", 50, 0, 100, { width = -1, precision = 0 })
        SliderFloatPrecision("sliderfloat3", 50, 0, 100, { width = 200, precision = 2 })
        SliderFloatPrecision("sliderfloat4", 50, 0, 100, { width = -200, precision = 3 })
        EmptyLine()

        Text("TextInputs", { align = "center" })
        InputText("inputtext1", "test", { disabled = true })
        InputText("inputtext2", "test", { width = -1 })
        InputText("inputtext3", "test", { width = 200 })
        InputText("inputtext4", "test", { width = -200 })
        EmptyLine()

        Text("TextMultilineInputs", { align = "center" })
        ml1 = InputTextMultiline("inputtextmultiline1", ml1, { disabled = true }) or ml1
        ml2 = InputTextMultiline("inputtextmultiline2", ml2, { width = -1 }) or ml2
        ml3 = InputTextMultiline("inputtextmultiline3", ml3, { width = 200 }) or ml3
        ml4 = InputTextMultiline("inputtextmultiline4", ml4, { width = -200 }) or ml4
        EmptyLine()

        Text("Combos", { align = "center" })
        Combo("combo1", "test", { { value = "test", label = "TEST" }, { value = "test2", label = "TEST 2" } },
            { disabled = true })
        Combo("combo2", nil, { { value = "test", label = "TEST" }, { value = "test2", label = "TEST 2" } },
            { width = -1 })
        Combo("combo3", "invalid", { { value = "test", label = "TEST" }, { value = "test2", label = "TEST 2" } },
            { width = 200 })
        Combo("combo4", "test2", { { value = "test", label = "TEST" }, { value = "test2", label = "TEST 2" } },
            { width = -200 })
        EmptyLine()

        Text("Accordions", { align = "center" })
        if BeginTree("My accordion 1") then
            Text("Nested content")
            if BeginTree("Accordion 1.1") then
                Text("Deep nested content (aligned to the right)", { align = "right" })
                EndTree()
            else
                Text("Deep nested content is hidden")
            end
            EndTree()
        else
            Text("Nested content is hidden")
        end
        EmptyLine()

        local lineHeight = CalcTextSize("H").y + 10 -- padding
        local function recursChild(level, text)
            if BeginChild("recurs-child-" .. tostring(level), {
                    size = ImVec2(math.max(GetContentRegionAvail().x * .8, 250), lineHeight * (6 - level)),
                    bgColor = level % 2 == 0 and ImVec4(1, 1, 1, .5) or ImVec4(0, 0, 0, .5)
                }) then
                Indent()
                Text(text .. tostring(level), { color = level % 2 ~= 0 and ImVec4(1, 1, 1, 1) or ImVec4(0, 0, 0, 1) })
                if level < 5 then
                    recursChild(level + 1, text)
                end
                Unindent()
            end
            EndChild()
        end
        recursChild(1, "Child level ")
    end
    EndChild()
end

-- optional, to render bottom-sticked content
W.footer = function()
    if BeginChild("footer", {
            bgColor = ImVec4(0, 0, 1, .2)
        }) then
        Text("Footer", { align = "center" })
        Text("With a second line")
    end
    EndChild()
end

-- optional, return the amount of lines in footer for custom rendering, default 1
W.footerLines = function()
    return 2
end

W.getState = function()
    return W.show
end

-- optional, when set, the window closing button will be visible
W.onClose = function()
    W.show = false
end

return W
