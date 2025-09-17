local logTag = "BJIDrawBuilders"
local lineHeight = 20

-- gc prevention
local _, windowOpen, scale, footerHeight, flags, ok, err
local val1, val2, val3, val4, val5, val6, val7

-- IMGUI
---@class ImBool

---@return ImBool
BoolTrue = ui_imgui.BoolTrue or function() return {} end
---@return ImBool
BoolFalse = ui_imgui.BoolFalse or function() return {} end
---@param val boolean
---@return {[0]: boolean}
BoolPtr = ui_imgui.BoolPtr or function(val) return {} end
---@param val integer
---@return {[0]: integer}
IntPtr = ui_imgui.IntPtr or function(val) return { [0] = 0 } end
---@param val number
---@return {[0]: number}
FloatPtr = ui_imgui.FloatPtr or function(val) return { [0] = 0 } end
---@param size integer
---@param val string
---@return {[0]: string}
StrPtr = function(val, size) return ui_imgui.ArrayChar(size, val) end
---@param strPtr {[0]: string}
---@return string
StrPtrValue = require('ffi').string or function(strPtr) return "" end
---@param values string[]
---@return {[0]: string}
ArrayCharPtr = ui_imgui.ArrayCharPtrByTbl or function(values) return {} end
---@param count integer
---@return {[0]: number}
ArrayFloatPtr = ui_imgui.ArrayFloat or function(count) return {} end
---@param content string
---@return boolean success
SetClipboardContent = function(content)
    ok, err = pcall(ui_imgui.SetClipboardText, content)
    if not ok then
        LogError("Error setting clipboard content : " .. err)
    end
    return ok
end
---@return string
GetClipboardContent = function()
    ok, err = pcall(ui_imgui.GetClipboardText)
    if not ok then
        LogError("Error getting clipboard content : " .. err)
    end
    return ok and StrPtrValue(err) or ""
end
---@return point
ImVec2 = ui_imgui.ImVec2 or function(x, y) return {} end
---@return vec4
ImVec4 = ui_imgui.ImVec4 or function(x, y, z, w) return {} end
---@param ... integer
---@return integer
Flags = ui_imgui.flags or function(...) return 0 end
---@return integer
GetCursorPosX = ui_imgui.GetCursorPosX or function() return 0 end
---@param x number
SetCursorPosX = ui_imgui.SetCursorPosX or function(x) end
---@param colIndex integer? 0-N
---@return integer
GetTableColumnWidth = function(colIndex)
    return ui_imgui.GetColumnWidth(colIndex or ui_imgui.TableGetColumnIndex())
end
---@return table
GetStyle = ui_imgui.GetStyle or function() return {} end
---@param text string
---@return point
CalcTextSize = ui_imgui.CalcTextSize or function(text) return {} end
---@return point
GetContentRegionAvail = ui_imgui.GetContentRegionAvail or function() return {} end
---@param column integer
---@param color vec4
PushStyleColor = function(column, color)
    if type(column) ~= "number" then
        LogError("style type is invalid")
        return
    elseif type(color) ~= "userdata" or not color.x then ---@diagnostic disable-line
        LogError("color must be a vec4")
        return
    end
    ok, err = pcall(ui_imgui.PushStyleColor2, column, color)
    if not ok then
        LogError(err)
    end
end
---@param amount integer
PopStyleColor = ui_imgui.PopStyleColor or function(amount) end
---@param wrapPosX number|0 regionAvail.x wrapping if ZERO
PushTextWrapPos = ui_imgui.PushTextWrapPos or function(wrapPosX) end
PopTextWrapPos = ui_imgui.PopTextWrapPos or function() end
---@return point
GetWindowSize = ui_imgui.GetWindowSize or function() return ImVec2(0, 0) end
---@param size point
SetNextWindowSize = ui_imgui.SetNextWindowSize or function(size) end
---@param minSize point?
---@param maxSize point?
SetNextWindowSizeConstraints = ui_imgui.SetNextWindowSizeConstraints or function(minSize, maxSize) end
---@param position point
SetNextWindowPos = ui_imgui.SetNextWindowPos or function(position) end
---@param alpha number 0-1
SetNextWindowBgAlpha = ui_imgui.SetNextWindowBgAlpha or function(alpha) end
---@param scale number
SetWindowFontScale = ui_imgui.SetWindowFontScale or function(scale) end
---@param width integer|-1
PushItemWidth = ui_imgui.PushItemWidth or function(width) end
PopItemWidth = ui_imgui.PopItemWidth or function() end
---@param width integer
SetNextItemWidth = ui_imgui.SetNextItemWidth or function(width) end
---@return boolean
IsItemHovered = ui_imgui.IsItemHovered or function() return false end
---@param mouseBtn integer
---@return boolean
IsItemClicked = ui_imgui.IsItemClicked or function(mouseBtn) return false end

local menuStarted, menuLevel = false, 0
BeginMenuBar = function()
    if menuStarted then
        LogError("BeginMenuBar already called", logTag)
        return
    end
    ui_imgui.BeginMenuBar()
    menuStarted = true
end
EndMenuBar = function()
    if not menuStarted then
        LogError("EndMenuBar called without BeginMenuBar", logTag)
        return
    end
    ui_imgui.EndMenuBar()
    menuStarted = false
end
---@param label string
---@return boolean isOpen
BeginMenu = function(label)
    if not menuStarted then
        LogError("BeginMenu called without BeginMenuBar", logTag)
        return false
    elseif menuLevel >= 2 then
        LogError("3rd level menu is not supported", logTag)
        return false
    end

    menuLevel = menuLevel + 1
    val1 = ui_imgui.BeginMenu(label)
    if val1 then
        if menuLevel == 1 then
            SetWindowFontScale(1)
        else
            scale = BJI_LocalStorage.get(BJI_LocalStorage.GLOBAL_VALUES.UI_SCALE)
            SetWindowFontScale(scale)
        end
    end
    return val1
end
--- call only if BeginMenu == true
---@param menuOpened boolean
EndMenu = function(menuOpened)
    if not menuStarted then
        LogError("EndMenu called without BeginMenuBar", logTag)
        return
    elseif menuLevel <= 0 then
        LogError("EndMenu called without BeginMenu", logTag)
        return
    end

    menuLevel = menuLevel - 1
    if menuOpened then
        ui_imgui.EndMenu()
    end
end
---@param label string
---@param shortcut string?
---@param selected boolean? default false
---@param enabled boolean? default true
---@return boolean clicked
MenuItem = function(label, shortcut, selected, enabled)
    if not menuStarted then
        LogError("MenuItem called without BeginMenuBar", logTag)
        return false
    end

    val1 = selected == true and BoolTrue() or BoolFalse()
    val2 = enabled ~= false and BoolTrue() or BoolFalse()
    return ui_imgui.MenuItem1(label, shortcut, val1, val2)
end

---@class MenuDropdownElement
---@field type "item"|"separator"|"custom"|"menu"
---@field label string? -- item|menu
---@field color vec4? -- item|menu
---@field disabled boolean? -- item
---@field checked boolean? -- item
---@field active boolean? -- item|menu
---@field onClick fun()? -- item
---@field elems MenuDropdownElement[]? -- menu -- 2 levels deep maximum
---@field render fun()? -- custom

---@param label string
---@param elements MenuDropdownElement[]
---@param parentColor? vec4
RenderMenuDropdown = function(label, elements, parentColor)
    if not menuStarted then
        LogError("RenderMenuDropdown called without BeginMenuBar", logTag)
        return
    elseif menuLevel > 0 then
        LogError("RenderMenuDropdown called on a nested menu", logTag)
        return
    end

    ---@param lbl string
    ---@param els MenuDropdownElement[]
    ---@param col vec4?
    ---@param level integer?
    local function drawMenuWithElems(lbl, els, col, level)
        level = level or 0
        if level >= 2 then
            LogError("3rd level menu is not supported", logTag)
            return
        end

        if col then
            PushStyleColor(BJI.Utils.Style.STYLE_COLS.TEXT_COLOR, col)
        end
        local opened = BeginMenu(lbl)
        if col then
            PopStyleColor(1)
        end
        if opened then
            for _, el in ipairs(els) do
                if el.type == "item" then
                    if el.active then
                        val7 = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT
                    elseif el.disabled then
                        val7 = BJI.Utils.Style.TEXT_COLORS.DISABLED
                    else
                        val7 = el.color or BJI.Utils.Style.TEXT_COLORS.DEFAULT
                    end
                    PushStyleColor(BJI.Utils.Style.STYLE_COLS.TEXT_COLOR, val7)
                    if MenuItem(el.label, nil, el.checked, not el.disabled) and el.onClick then
                        el.onClick()
                    end
                    PopStyleColor(1)
                elseif el.type == "separator" then
                    Separator()
                elseif el.type == "custom" then
                    if el.render then
                        el.render()
                    else
                        LogError("Custom element has no render function", logTag)
                    end
                elseif el.type == "menu" then
                    val7 = el.active and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or el.color
                    drawMenuWithElems(el.label, el.elems, val7, level + 1)
                end
            end
        end
        EndMenu(opened)
    end
    drawMenuWithElems(label, elements, parentColor)
end

---@param entries MenuDropdownElement[]
MenuDropdownSanitize = function(entries)
    -- remove separators at the beginning
    while #entries > 0 and entries[1].type == "separator" do
        table.remove(entries, 1)
    end
    -- remove separators at the end
    while #entries > 0 and entries[#entries].type == "separator" do
        table.remove(entries, #entries)
    end
    -- remove following separators
    for i = 2, #entries - 2 do
        if entries[i].type == "separator" then
            while entries[i + 1] and entries[i + 1].type == "separator" do
                table.remove(entries, i + 1)
            end
        end
    end
end

---@param id string
---@return boolean isValid
BeginTabBar = ui_imgui.BeginTabBar or function(id) return false end
--- call only if BeginTabBar == true
EndTabBar = ui_imgui.EndTabBar or function() end
---@param label string
---@return boolean isSelected
BeginTabItem = ui_imgui.BeginTabItem or function(label) return false end
--- call only if BeginTabItem == true
EndTabItem = ui_imgui.EndTabItem or function() end
---@param label string
SetTabItemClosed = ui_imgui.SetTabItemClosed or function(label) end
local childLevel = 0
---@param id string
---@param data {size: point?, outsideSize: boolean?, border: boolean?, flags: integer[]?, bgColor: vec4?}?
---@return boolean isVisible
BeginChild = function(id, data)
    if childLevel > 10 then
        LogError("Too many nested children", logTag)
        return false
    end
    data = data or {}
    scale = BJI_LocalStorage.get(BJI_LocalStorage.GLOBAL_VALUES.UI_SCALE)
    if data.size then
        if data.size.x < -1 then                              -- substract from avail space
            data.size = ImVec2(GetContentRegionAvail().x + data.size.x, data.size.y)
        elseif data.size.x > -1 and not data.outsideSize then -- content size
            data.size = ImVec2(data.size.x + BJI.Utils.UI.MARGINS.CHILD * 2, data.size.y)
        end
        if data.size.y < -1 then                              -- substract from avail space
            data.size = ImVec2(data.size.x, GetContentRegionAvail().y + data.size.y)
        elseif data.size.y > -1 and not data.outsideSize then -- content size
            data.size = ImVec2(data.size.x, data.size.y + BJI.Utils.UI.MARGINS.CHILD * 2)
        end
    end
    data.size = data.size or ImVec2(-1, -1)

    if data.bgColor then
        PushStyleColor(BJI.Utils.Style.STYLE_COLS.HEADER, BJI.Utils.Style.RGBA(0, 0, 0, 0))
        PushStyleColor(BJI.Utils.Style.STYLE_COLS.CHILD_BG, data.bgColor)
    end

    val1 = table.length(data.flags) > 0 and Flags(table.unpack(data.flags or {})) or nil
    val2 = ui_imgui.BeginChild1("##" .. id, data.size, data.border, val1)

    if data.bgColor then
        PopStyleColor(2)
    end

    childLevel = childLevel + 1
    if val2 then
        if childLevel % 2 == 0 then
            SetWindowFontScale(scale)
        else
            SetWindowFontScale(1)
        end
    end

    return val2
end
EndChild = function()
    if childLevel <= 0 then
        LogError("EndChild called without BeginChild", logTag)
        return
    end
    ui_imgui.EndChild()

    childLevel = childLevel - 1
    if childLevel % 2 == 0 then
        scale = BJI_LocalStorage.get(BJI_LocalStorage.GLOBAL_VALUES.UI_SCALE)
        SetWindowFontScale(scale)
    else
        SetWindowFontScale(1)
    end
end

---@param label string
---@param data {color: vec4?}?
---@return boolean isOpen
BeginTree = function(label, data)
    data = data or {}
    data.color = data.color or BJI.Utils.Style.TEXT_COLORS.DEFAULT

    PushStyleColor(BJI.Utils.Style.STYLE_COLS.TEXT_COLOR, data.color)

    val1 = ui_imgui.TreeNode1(label)

    PopStyleColor(1)

    return val1
end
---@param label string
---@param flags integer
---@return boolean isOpen
BeginTreeFlags = ui_imgui.TreeNodeEx1 or function(label, flags) return false end
--- call only if BeginTree == true
EndTree = ui_imgui.TreePop or function() end

---@param width integer?
Indent = ui_imgui.Indent or function(width) end
---@param width integer?
Unindent = ui_imgui.Unindent or function(width) end
SameLine = ui_imgui.SameLine or function() end
NewLine = ui_imgui.NewLine or function() end
Separator = ui_imgui.Separator or function() end
---@param text any
---@param data {color: vec4?, align: "left"|"center"|"right"?, wrap: boolean?}?
Text = function(text, data)
    text = tostring(text)
    data = data or {}
    data.color = data.color or BJI.Utils.Style.TEXT_COLORS.DEFAULT
    data.align = data.align or "left"

    if data.align ~= "left" then
        val1 = GetCursorPosX()
        if data.align == "center" then    -- center
            SetCursorPosX(val1 + (GetContentRegionAvail().x - CalcTextSize(text).x) / 2)
        elseif data.align == "right" then -- right
            SetCursorPosX(val1 + GetContentRegionAvail().x - CalcTextSize(text).x)
        end
    end

    if data.wrap then
        PushTextWrapPos(0)
    end

    ui_imgui.TextColored(data.color, text)

    if data.wrap then
        PopTextWrapPos()
    end
end
EmptyLine = function() Text("") end

---@param text string?
TooltipText = function(text)
    -- ui_imgui.tooltip(text) -- cannot use because UIScale couldn't get updated
    if text and IsItemHovered() then
        BeginTooltip(); Text(text); EndTooltip()
    end
end
---@return boolean isValid
BeginTooltip = function()
    val2 = ui_imgui.BeginTooltip()
    if val2 then
        scale = BJI_LocalStorage.get(BJI_LocalStorage.GLOBAL_VALUES.UI_SCALE)
        SetWindowFontScale(scale)
    end
    return val2
end
EndTooltip = ui_imgui.EndTooltip or function() end
---@param text string
ShowHelpMarker = ui_imgui.ShowHelpMarker or function(text) end

local colsCount, currCol = 1, 1
---@param count integer 1-N
---@param id string?
---@param border boolean?
---@return boolean isCreated
Columns = function(count, id, border)
    EndColumns()
    ui_imgui.Columns(count, id, border)
    colsCount, currCol = count, 1
    return true
end
---@param width number|-1
ColumnSetWidth = function(width)
    ui_imgui.SetColumnWidth(currCol - 1, math.ceil(width))
end
ColumnNext = function()
    ui_imgui.NextColumn()
    -- increment and wrap if needed
    currCol = (currCol % colsCount) + 1
end
ColumnNextLine = function()
    ColumnNext()
    while currCol > 1 do
        ColumnNext()
    end
end
EndColumns = function()
    if colsCount > 1 then
        if currCol > 1 then
            ColumnNextLine()
        end
        ui_imgui.Columns(1)
        colsCount, currCol = 1, 1
    end
end

TABLE_FLAGS = {
    RESIZABLE = ui_imgui.TableFlags_Resizable,
    REORDERABLE = ui_imgui.TableFlags_Reorderable,
    HIDEABLE = ui_imgui.TableFlags_Hideable,
    SORTABLE = ui_imgui.TableFlags_Sortable,
    NO_SAVED_SETTINGS = ui_imgui.TableFlags_NoSavedSettings,
    CONTEXT_MENU_IN_BODY = ui_imgui.TableFlags_ContextMenuInBody,
    ALTERNATE_ROW_BG = ui_imgui.TableFlags_RowBg,
    BORDERS_INNER_H = ui_imgui.TableFlags_BordersInnerH,
    BORDERS_OUTER_H = ui_imgui.TableFlags_BordersOuterH,
    BORDERS_INNER_V = ui_imgui.TableFlags_BordersInnerV,
    BORDERS_OUTER_V = ui_imgui.TableFlags_BordersOuterV,
    BORDERS_H = ui_imgui.TableFlags_BordersH,
    BORDERS_V = ui_imgui.TableFlags_BordersV,
    BORDERS_INNER = ui_imgui.TableFlags_BordersInner,
    BORDERS_OUTER = ui_imgui.TableFlags_BordersOuter,
    BORDERS = ui_imgui.TableFlags_Borders,
    NO_BORDERS_IN_BODY = ui_imgui.TableFlags_NoBordersInBody,
    NO_BORDERS_IN_BODY_UNTIL_RESIZE = ui_imgui.TableFlags_NoBordersInBodyUntilResize,
    SIZING_FIXED_FIT = ui_imgui.TableFlags_SizingFixedFit,
    SIZING_FIXED_SAME = ui_imgui.TableFlags_SizingFixedSame,
    SIZING_STRETCH_PROP = ui_imgui.TableFlags_SizingStretchProp,
    SIZING_STRETCH_SAME = ui_imgui.TableFlags_SizingStretchSame,
    NO_HOST_EXTEND_X = ui_imgui.TableFlags_NoHostExtendX,
    NO_HOST_EXTEND_Y = ui_imgui.TableFlags_NoHostExtendY,
    NO_KEEP_COLUMNS_VISIBLE = ui_imgui.TableFlags_NoKeepColumnsVisible,
    PRECISE_WIDTHS = ui_imgui.TableFlags_PreciseWidths,
    NO_CLIP = ui_imgui.TableFlags_NoClip,
    PAD_OUTER_X = ui_imgui.TableFlags_PadOuterX,
    NO_PAD_OUTER_X = ui_imgui.TableFlags_NoPadOuterX,
    NO_PAD_INNER_X = ui_imgui.TableFlags_NoPadInnerX,
    SCROLL_X = ui_imgui.TableFlags_ScrollX,
    SCROLL_Y = ui_imgui.TableFlags_ScrollY,
}
TABLE_COLUMNS_FLAGS = {
    DISABLED = ui_imgui.TableColumnFlags_Disabled,
    DEFAULT_HIDE = ui_imgui.TableColumnFlags_DefaultHide,
    DEFAULT_SORT = ui_imgui.TableColumnFlags_DefaultSort,
    WIDTH_STRETCH = ui_imgui.TableColumnFlags_WidthStretch,
    WIDTH_FIXED = ui_imgui.TableColumnFlags_WidthFixed,
    NO_RESIZE = ui_imgui.TableColumnFlags_NoResize,
    NO_REORDER = ui_imgui.TableColumnFlags_NoReorder,
    NO_HIDE = ui_imgui.TableColumnFlags_NoHide,
    NO_CLIP = ui_imgui.TableColumnFlags_NoClip,
    NO_SORT = ui_imgui.TableColumnFlags_NoSort,
    NO_SORT_ASCENDING = ui_imgui.TableColumnFlags_NoSortAscending,
    NO_SORT_DESCENDING = ui_imgui.TableColumnFlags_NoSortDescending,
    NO_HEADER_LABEL = ui_imgui.TableColumnFlags_NoHeaderLabel,
    NO_HEADER_WIDTH = ui_imgui.TableColumnFlags_NoHeaderWidth,
    PREFER_SORT_ASCENDING = ui_imgui.TableColumnFlags_PreferSortAscending,
    PREFER_SORT_DESCENDING = ui_imgui.TableColumnFlags_PreferSortDescending,
    INDENT_ENABLE = ui_imgui.TableColumnFlags_IndentEnable,
    INDENT_DISABLE = ui_imgui.TableColumnFlags_IndentDisable,
    IS_ENABLED = ui_imgui.TableColumnFlags_IsEnabled,
    IS_VISIBLE = ui_imgui.TableColumnFlags_IsVisible,
    IS_SORTED = ui_imgui.TableColumnFlags_IsSorted,
    IS_HOVERED = ui_imgui.TableColumnFlags_IsHovered,
}
---@param id string
---@param columnsConfig {label: string, flags: integer[]?, width: integer?, userID: integer?}[]
---@param data {showHeader: boolean?, flags: integer[]?}?
---@return boolean isVisible
BeginTable = function(id, columnsConfig, data)
    if not table.isArray(columnsConfig) then
        LogError(string.var("Table {1} must be an array", { id }))
        return false
    elseif #columnsConfig < 1 then
        LogError(string.var("Table {1} must have at least one column", { id }))
        return false
    end

    data = data or {}
    data.flags = data.flags or {}
    if not table.any(data.flags, function(v)
            return Table({
                TABLE_FLAGS.SIZING_FIXED_FIT, TABLE_FLAGS.SIZING_FIXED_SAME,
                TABLE_FLAGS.SIZING_STRETCH_PROP, TABLE_FLAGS.SIZING_STRETCH_SAME
            }):includes(v)
        end) then -- fit max content size by default
        table.insert(data.flags, TABLE_FLAGS.SIZING_FIXED_FIT)
    end

    val1 = ui_imgui.BeginTable(id, #columnsConfig, Flags(table.unpack(data.flags)))
    if val1 then
        for _, conf in ipairs(columnsConfig) do
            conf.flags = conf.flags or {}
            ui_imgui.TableSetupColumn(conf.label, #conf.flags > 0 and
                Flags(table.unpack(conf.flags)) or nil, conf.width, conf.userID)
        end
        if data.showHeader then
            ui_imgui.TableHeadersRow()
        end
    end
    return val1
end
---@param isHeader boolean?
---@param minHeight number?
TableNewRow = function(isHeader, minHeight)
    ui_imgui.TableNextRow(isHeader and ui_imgui.TableRowFlags_Headers or nil, minHeight)
    TableNextColumn() -- auto set to first column
end
---@param colIndex integer 0-N
TableSetColumnIndex = ui_imgui.TableSetColumnIndex or function(colIndex) end
TableNextColumn = ui_imgui.TableNextColumn or function() end
EndTable = function()
    ui_imgui.EndTable()
end

---@param name string
SetupWindow = function(name)
    BJI_Context.GUI.setupWindow(name)
end
---@param title string
---@param openPtr {[0]: boolean}? window not closeable if nil
---@param flags integer?
---@return boolean isExpanded
BeginWindow = ui_imgui.Begin or function(title, openPtr, flags) return false end
EndWindow = ui_imgui.End or function() end
local baseFlagsWindow = Table({
    BJI.Utils.Style.WINDOW_FLAGS.NO_SCROLLBAR,
    BJI.Utils.Style.WINDOW_FLAGS.NO_SCROLL_WITH_MOUSE,
    BJI.Utils.Style.WINDOW_FLAGS.NO_FOCUS_ON_APPEARING,
})
---@param ctxt TickContext
---@param title string
---@param data BJIWindow
RenderWindow = function(ctxt, title, data)
    scale = BJI_LocalStorage.get(BJI_LocalStorage.GLOBAL_VALUES.UI_SCALE)
    data.flags = data.flags or {}

    SetupWindow(data.name)
    if not table.includes(data.flags, BJI.Utils.Style.WINDOW_FLAGS.ALWAYS_AUTO_RESIZE) then
        if data.size then
            SetNextWindowSize(ImVec2(data.size.x * scale, data.size.y * scale))
        else
            data.minSize = data.minSize or ImVec2(0, 0)
            data.maxSize = data.maxSize or ImVec2(ui_imgui.GetMainViewport().Size.x,
                ui_imgui.GetMainViewport().Size.y)
            SetNextWindowSizeConstraints(ImVec2(
                data.minSize.x * scale,
                data.minSize.y * scale
            ), ImVec2(
                data.maxSize.x >= 0 and data.maxSize.x * scale or -1,
                data.maxSize.y >= 0 and data.maxSize.y * scale or -1
            ))
        end
    end
    if data.position then
        SetNextWindowPos(data.position)
    end
    SetNextWindowBgAlpha(BJI.Utils.Style.BJIStyles[BJI.Utils.Style.STYLE_COLS.WINDOW_BG] and
        BJI.Utils.Style.BJIStyles[BJI.Utils.Style.STYLE_COLS.WINDOW_BG].w or .5)

    flags = Flags(table.unpack(
        baseFlagsWindow:clone():addAll(data.flags, true)
        :addAll({
            data.size and BJI.Utils.Style.WINDOW_FLAGS.NO_RESIZE or nil,
            data.menu and BJI.Utils.Style.WINDOW_FLAGS.MENU_BAR or nil
        }, true)
    ))

    windowOpen = data.onClose and BoolPtr(true) or nil
    if BeginWindow(title, windowOpen, flags) then
        SetWindowFontScale(scale)

        --menu
        if data.menu then
            BeginMenuBar()
            data.menu(ctxt)
            EndMenuBar()
        end

        if data.header then
            data.header(ctxt)
        end

        -- body
        if table.includes(data.flags, BJI.Utils.Style.WINDOW_FLAGS.ALWAYS_AUTO_RESIZE) then
            data.body(ctxt)
        else
            footerHeight = 0
            if data.footer then
                footerHeight = lineHeight + 5 -- 1 line
                if data.footerLines then
                    footerHeight = footerHeight * data.footerLines(ctxt)
                end
                footerHeight = footerHeight * scale
            end
            if BeginChild(data.name .. "_Body", { size = ImVec2(-1, -footerHeight), outsideSize = true }) then
                data.body(ctxt)
            end
            EndChild()
        end

        -- footer
        if data.footer then
            data.footer(ctxt)
        end
    end
    SetWindowFontScale(scale)
    EndWindow()
    if data.onClose and windowOpen and not windowOpen[0] then
        data.onClose()
    end
end

---@param id string
---@param label string
---@param data {disabled: boolean?, btnStyle: vec4[]?, width: integer|-1?, noSound: boolean?, sound: string?}?
---@return boolean clicked
Button = function(id, label, data)
    data = data or {}
    data.disabled = data.disabled or false

    if data.disabled then
        data.btnStyle = BJI.Utils.Style.BTN_PRESETS.DISABLED
        val1 = Table(data.btnStyle):map(function(e) return ImVec4(e.x, e.y, e.z, e.w) end)
        val1[4] = val1[4] or BJI.Utils.Style.TEXT_COLORS.DISABLED
    else
        data.btnStyle = data.btnStyle or BJI.Utils.Style.BTN_PRESETS.INFO
        val1 = Table(data.btnStyle):map(function(e) return ImVec4(e.x, e.y, e.z, e.w) end)
        val1[4] = val1[4] or BJI.Utils.Style.TEXT_COLORS.DEFAULT
    end
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.BUTTON, val1[1])
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.BUTTON_HOVERED, val1[2])
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.BUTTON_ACTIVE, val1[3])
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.TEXT_COLOR, val1[4])

    val2 = nil
    if data.width then
        if data.width == -1 then
            data.width = GetContentRegionAvail().x
        elseif data.width < -1 then
            data.width = data.width + GetContentRegionAvail().x
        end
        scale = BJI_LocalStorage.get(BJI_LocalStorage.GLOBAL_VALUES.UI_SCALE)
        val2 = ImVec2(data.width, 23 * scale)
    end

    data.sound = not data.noSound and
        (data.sound or BJI_Sound.SOUNDS.BIGMAP_HOVER) or nil

    val3 = ui_imgui.Button(string.var("{1}##{2}", { label, id }), val2)

    if val3 and data.sound then
        BJI_Sound.play(data.sound)
    end

    PopStyleColor(4)

    return val3 and not data.disabled
end

---@param id string
---@param value integer
---@param data {step: integer?, stepFast: integer?, disabled: boolean?, inputStyle: vec4[]?, btnStyle: vec4[]?, width: integer|-1?, min: integer?, max: integer?}?
---@return integer? changed
InputInt = function(id, value, data)
    data = data or {}
    data.disabled = data.disabled or false
    data.step = data.step or 1
    data.stepFast = data.stepFast or data.step * 2

    if data.disabled then
        data.inputStyle = BJI.Utils.Style.INPUT_PRESETS.DISABLED
        val2 = Table(data.inputStyle):map(function(e) return ImVec4(e.x, e.y, e.z, e.w) end)
        val2[2] = val2[2] or BJI.Utils.Style.TEXT_COLORS.DISABLED
        data.btnStyle = BJI.Utils.Style.BTN_PRESETS.DISABLED
        val3 = Table(data.btnStyle):map(function(e) return ImVec4(e.x, e.y, e.z, e.w) end)
    else
        data.inputStyle = data.inputStyle or BJI.Utils.Style.INPUT_PRESETS.DEFAULT
        val2 = Table(data.inputStyle):map(function(e) return ImVec4(e.x, e.y, e.z, e.w) end)
        val2[2] = val2[2] or BJI.Utils.Style.TEXT_COLORS.DEFAULT
        data.btnStyle = data.btnStyle or BJI.Utils.Style.BTN_PRESETS.INFO
        val3 = Table(data.btnStyle):map(function(e) return ImVec4(e.x, e.y, e.z, e.w) end)
    end
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.FRAME_BG, val2[1])
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.TEXT_COLOR, val2[2])
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.BUTTON, val3[1])
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.BUTTON_HOVERED, val3[2])
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.BUTTON_ACTIVE, val3[3])

    data.width = data.width or -1
    if data.width < -1 then
        data.width = data.width + GetContentRegionAvail().x
    end
    SetNextItemWidth(data.width)

    val1 = IntPtr(value)
    val5 = ui_imgui.InputInt("##" .. id, val1, data.step, data.stepFast)

    PopStyleColor(5)

    val4 = nil
    if val5 and not data.disabled then
        val4 = val1[0]
        if data.min or data.max then
            val4 = math.clamp(val4, data.min, data.max)
        end
    end

    return val4 ~= value and val4 or nil
end

---@param id string
---@param value number
---@param data {step: integer?, stepFast: integer?, disabled: boolean?, inputStyle: vec4[]?, btnStyle: vec4[]?, width: integer|-1?, min: number?, max: number?, precision: integer?}?
---@return number? changed
InputFloat = function(id, value, data)
    data = data or {}
    data.disabled = data.disabled or false
    data.step = data.step or (1 / ((data.precision or 1) ^ 10))
    data.stepFast = data.stepFast or data.step * 10

    if data.disabled then
        data.inputStyle = BJI.Utils.Style.INPUT_PRESETS.DISABLED
        val2 = Table(data.inputStyle):map(function(e) return ImVec4(e.x, e.y, e.z, e.w) end)
        val2[2] = val2[2] or BJI.Utils.Style.TEXT_COLORS.DISABLED
        data.btnStyle = BJI.Utils.Style.BTN_PRESETS.DISABLED
        val3 = Table(data.btnStyle):map(function(e) return ImVec4(e.x, e.y, e.z, e.w) end)
    else
        data.inputStyle = data.inputStyle or BJI.Utils.Style.INPUT_PRESETS.DEFAULT
        val2 = Table(data.inputStyle):map(function(e) return ImVec4(e.x, e.y, e.z, e.w) end)
        val2[2] = val2[2] or BJI.Utils.Style.TEXT_COLORS.DEFAULT
        data.btnStyle = data.btnStyle or BJI.Utils.Style.BTN_PRESETS.INFO
        val3 = Table(data.btnStyle):map(function(e) return ImVec4(e.x, e.y, e.z, e.w) end)
    end
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.FRAME_BG, val2[1])
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.TEXT_COLOR, val2[2])
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.BUTTON, val3[1])
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.BUTTON_HOVERED, val3[2])
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.BUTTON_ACTIVE, val3[3])

    data.width = data.width or -1
    if data.width < -1 then
        data.width = data.width + GetContentRegionAvail().x
    end
    SetNextItemWidth(data.width)

    val1 = FloatPtr(value)
    val5 = ui_imgui.InputFloat("##" .. id, val1, data.step, data.stepFast)

    PopStyleColor(5)

    val4 = nil
    if val5 and not data.disabled then
        val4 = val1[0]
        if data.min or data.max then
            val4 = math.clamp(math.round(val4, data.precision or 3), data.min, data.max)
        end
    end

    return val4 ~= value and val4 or nil
end

---@param id string
---@param value string
---@param data {size: integer?, disabled: boolean?, inputStyle: vec4[]?, width: integer|-1?}?
---@return string? changed
InputText = function(id, value, data)
    data = data or {}
    data.size = data.size or 64
    data.disabled = data.disabled or false

    if data.disabled then
        data.inputStyle = BJI.Utils.Style.INPUT_PRESETS.DISABLED
        val2 = Table(data.inputStyle):map(function(e) return ImVec4(e.x, e.y, e.z, e.w) end)
        val2[2] = val2[2] or BJI.Utils.Style.TEXT_COLORS.DISABLED
    else
        data.inputStyle = data.inputStyle or BJI.Utils.Style.INPUT_PRESETS.DEFAULT
        val2 = Table(data.inputStyle):map(function(e) return ImVec4(e.x, e.y, e.z, e.w) end)
        val2[2] = val2[2] or BJI.Utils.Style.TEXT_COLORS.DEFAULT
    end
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.FRAME_BG, val2[1])
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.TEXT_COLOR, val2[2])

    data.width = data.width or -1
    if data.width < -1 then
        data.width = data.width + GetContentRegionAvail().x
    end
    SetNextItemWidth(data.width)

    val1 = StrPtr(value, data.size)
    val3 = ui_imgui.InputText("##" .. id, val1, data.size)

    val4 = nil
    if val3 and not data.disabled then
        val4 = StrPtrValue(val1)
    end

    PopStyleColor(2)

    return val4 ~= value and val4 or nil
end

---@param id string
---@param value string
---@param data {size: integer?, width: integer|-1?, disabled: boolean?, inputStyle: vec4[]?}?
---@return string? changed
InputTextMultiline = function(id, value, data)
    data = data or {}
    data.size = data.size or 128
    data.disabled = data.disabled or false

    if data.disabled then
        data.inputStyle = BJI.Utils.Style.INPUT_PRESETS.DISABLED
        val2 = Table(data.inputStyle):map(function(e) return ImVec4(e.x, e.y, e.z, e.w) end)
        val2[2] = val2[2] or BJI.Utils.Style.TEXT_COLORS.DISABLED
    else
        data.inputStyle = data.inputStyle or BJI.Utils.Style.INPUT_PRESETS.DEFAULT
        val2 = Table(data.inputStyle):map(function(e) return ImVec4(e.x, e.y, e.z, e.w) end)
        val2[2] = val2[2] or BJI.Utils.Style.TEXT_COLORS.DEFAULT
    end
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.FRAME_BG, val2[1])
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.TEXT_COLOR, val2[2])

    val1 = StrPtr(value, data.size)
    val2 = table.length(value:split2("\n"))
    val2 = val2 >= 2 and val2 or 2
    scale = BJI_LocalStorage.get(BJI_LocalStorage.GLOBAL_VALUES.UI_SCALE)

    data.width = data.width or -1
    if data.width < -1 then
        data.width = data.width + GetContentRegionAvail().x
    end
    val3 = ImVec2(data.width, math.ceil(val2 * lineHeight * scale))

    SetWindowFontScale(scale)
    val4 = ui_imgui.InputTextMultiline("##" .. id, val1, data.size, val3)

    PopStyleColor(2)

    val5 = nil
    if val4 and not data.disabled then
        val5 = StrPtrValue(val1)
    end

    SetWindowFontScale(scale)
    return val5 ~= value and val5 or nil
end

---@class ComboOption
---@field value any
---@field label string

---@param id string
---@param value any
---@param options ComboOption[]
---@param data {disabled: boolean?, width: integer|-1?, inputStyle: vec4[]?}?
---@return any? changed
Combo = function(id, value, options, data)
    data = data or {}
    data.disabled = data.disabled or #options < 2

    if data.disabled then
        data.inputStyle = BJI.Utils.Style.INPUT_PRESETS.DISABLED
        val2 = Table(data.inputStyle):map(function(e) return ImVec4(e.x, e.y, e.z, e.w) end)
        val2[2] = val2[2] or BJI.Utils.Style.TEXT_COLORS.DISABLED
    else
        data.inputStyle = data.inputStyle or BJI.Utils.Style.INPUT_PRESETS.DEFAULT
        val2 = Table(data.inputStyle):map(function(e) return ImVec4(e.x, e.y, e.z, e.w) end)
        val2[2] = val2[2] or BJI.Utils.Style.TEXT_COLORS.DEFAULT
    end
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.FRAME_BG, val2[1])
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.TEXT_COLOR, val2[2])

    if data.disabled then
        ---@type integer
        val3 = 1
        ---@type string[]
        val4 = table.filter(options, function(el)
            return el.value == value
        end):map(function(el)
            return el.label
        end)
        if #val4 == 0 then
            val4 = { "" }
        elseif #val4 > 1 then
            val4 = { val4[1] }
        end
    else
        ---@type integer
        val3 = 1
        ---@type string[]
        val4 = table.map(options, function(el, i)
            if el.value == value then
                val3 = i
            end
            return el.label
        end)
    end

    if data.width then
        if data.width < -1 then
            data.width = data.width + GetContentRegionAvail().x
        end
    else
        data.width = 0
        for _, v in ipairs(val4) do
            val5 = BJI.Utils.UI.GetComboWidthByContent(v)
            if val5 > data.width then
                data.width = val5
            end
        end
    end
    SetNextItemWidth(data.width)

    val3 = IntPtr(val3 - 1)
    val5 = ui_imgui.Combo1("##" .. id, val3, ArrayCharPtr(val4))

    PopStyleColor(2)

    val6 = nil
    if val5 and not data.disabled then
        val6 = options[val3[0] + 1].value
    end

    return val6 ~= value and val6 or nil
end

---@param floatPercent number 0-1
---@param data {width: integer?, height: integer?, text: string?, color: vec4?}?
ProgressBar = function(floatPercent, data)
    scale = BJI_LocalStorage.get(BJI_LocalStorage.GLOBAL_VALUES.UI_SCALE)
    data = data or {}
    if data.width then
        val1 = tonumber(data.width)
        if val1 then
            data.width = math.round(val1) * scale
        elseif tostring(data.width):find("%d+%%") then
            data.width = tonumber(tostring(data.width):match("^%d+")) / 100 * GetContentRegionAvail().x
        end
    end
    if not data.width then
        data.width = -1
    end
    if data.height then
        data.height = data.height * scale
    else
        if data.text then
            data.height = CalcTextSize(data.text).y + 2
        else
            data.height = 5 * scale
        end
    end

    if data.color then
        PushStyleColor(BJI.Utils.Style.STYLE_COLS.PROGRESSBAR, data.color)
    end

    ui_imgui.ProgressBar(floatPercent, ImVec2(data.width, data.height), data.text or "")

    if data.color then
        PopStyleColor(1)
    end
end

---@param icon string
---@param data {big: boolean?, color: vec4?, borderColor: vec4?}?
Icon = function(icon, data)
    data = data or {}
    data.color = data.color or BJI.Utils.Style.TEXT_COLORS.DEFAULT

    val1 = ImVec2(BJI.Utils.UI.GetIconSize(data.big), 0)
    val1.y = val1.x

    BJI_Context.GUI.uiIconImage(BJI.Utils.Icon.GetIcon(icon), val1, data.color, data.borderColor, nil)
end

---@param id string
---@param icon string
---@param data {big: boolean?, btnStyle: vec4[]?, onRelease: boolean?, disabled: boolean?, bgLess: boolean?, noSound: boolean?, sound: string?}?
---@return boolean clicked
IconButton = function(id, icon, data)
    data = data or {}
    data.disabled = data.disabled or false

    if data.disabled then
        data.btnStyle = BJI.Utils.Style.BTN_PRESETS.DISABLED
        if data.bgLess then
            val1 = Table(BJI.Utils.Style.BTN_PRESETS.TRANSPARENT):map(function(e) return ImVec4(e.x, e.y, e.z, e.w) end)
            val1[4] = data.btnStyle[1]
        else
            val1 = Table(data.btnStyle):map(function(e) return ImVec4(e.x, e.y, e.z, e.w) end)
            val1[4] = val1[4] or BJI.Utils.Style.TEXT_COLORS.DISABLED
        end
    else
        if data.bgLess then
            val1 = Table(BJI.Utils.Style.BTN_PRESETS.TRANSPARENT):map(function(e) return ImVec4(e.x, e.y, e.z, e.w) end)
            val1[4] = data.btnStyle and data.btnStyle[1] or BJI.Utils.Style.TEXT_COLORS.DEFAULT
        else
            data.btnStyle = data.btnStyle or BJI.Utils.Style.BTN_PRESETS.INFO
            val1 = Table(data.btnStyle):map(function(e) return ImVec4(e.x, e.y, e.z, e.w) end)
            val1[4] = val1[4] or BJI.Utils.Style.TEXT_COLORS.DEFAULT
        end
    end
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.BUTTON_HOVERED, val1[2])
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.BUTTON_ACTIVE, val1[3])

    val2 = ImVec2(BJI.Utils.UI.GetIconSize(data.big), 0)
    val2.y = val2.x

    data.sound = not data.noSound and
        (data.sound or BJI_Sound.SOUNDS.BIGMAP_HOVER) or nil

    val3 = BJI_Context.GUI.uiIconImageButton(BJI.Utils.Icon.GetIcon(icon), val2, val1[4], nil, val1[1],
        id, nil, nil, data.onRelease == true)

    if val3 and data.sound then
        BJI_Sound.play(data.sound)
    end

    PopStyleColor(2)

    return val3 and not data.disabled
end

local baseFlagsColorPicker = Table({
    ui_imgui.ColorEditFlags_NoInputs,
})
---@param id string
---@param value vec4
---@param data {disabled: boolean?, flags: integer[]?}?
---@param alpha boolean?
---@return vec4? changed
local CommonColorPicker = function(id, value, data, alpha)
    data = data or {}

    val1 = Flags(table.unpack(
        baseFlagsColorPicker:clone()
        :addAll({ data.disabled and ui_imgui.ColorEditFlags_NoPicker or nil })
    ))

    val2 = ArrayFloatPtr(4)
    val2[0] = value.x
    val2[1] = value.y
    val2[2] = value.z
    val2[3] = alpha and value.w or 1

    val3 = alpha and ui_imgui.ColorEdit4 or ui_imgui.ColorEdit3
    val4 = val3("##" .. id, val2, val1)

    val5 = nil
    if val4 and not data.disabled then
        val5 = ImVec4(val2[0], val2[1], val2[2], alpha and val2[3] or 1)
    end

    return not math.compareVec4(value, val5) and val5 or nil
end
---@param id string
---@param value vec4
---@param data {disabled: boolean?, flags: integer[]?}?
---@return vec4? changed
ColorPicker = function(id, value, data)
    return CommonColorPicker(id, value, data)
end
---@param id string
---@param value vec4
---@param data {disabled: boolean?, flags: integer[]?}?
---@return vec4? changed
ColorPickerAlpha = function(id, value, data)
    return CommonColorPicker(id, value, data, true)
end

local baseFlagsSlider = Table({
    ui_imgui.SliderFlags_AlwaysClamp,
})
---@param id string
---@param value integer
---@param min integer
---@param max integer
---@param data {disabled: boolean?, inputStyle: vec4[]?, width: integer?, formatRender: string?, flags: integer[]?}?
---@return integer? changed
SliderInt = function(id, value, min, max, data)
    data = data or {}
    scale = BJI_LocalStorage.get(BJI_LocalStorage.GLOBAL_VALUES.UI_SCALE)

    if data.disabled then
        val1 = table.clone(BJI.Utils.Style.INPUT_PRESETS.DISABLED)
        val1[2] = val1[2] or BJI.Utils.Style.TEXT_COLORS.DISABLED
    else
        val1 = data.inputStyle or table.clone(BJI.Utils.Style.INPUT_PRESETS.DEFAULT)
        val1[2] = val1[2] or BJI.Utils.Style.TEXT_COLORS.DEFAULT
    end
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.FRAME_BG, val1[1])
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.TEXT_COLOR, val1[2])
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.FRAME_BG_HOVERED, val1[3])
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.FRAME_BG_ACTIVE, val1[4])
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.SLIDER_GRAB, val1[5])
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.SLIDER_GRAB_ACTIVE, val1[6])

    data.width = data.width or -1
    if data.width < -1 then
        data.width = data.width + GetContentRegionAvail().x
    end
    SetNextItemWidth(data.width)

    val2 = IntPtr(value)
    val3 = Flags(table.unpack(
        baseFlagsSlider:clone():addAll(data.flags or {}, true)
    ))
    val4 = ui_imgui.SliderInt("##" .. id, val2, min, max, data.formatRender, val3)

    PopStyleColor(6)

    val5 = nil
    if val4 and not data.disabled then
        val5 = val2[0]
    end

    return val5 ~= value and val5 or nil
end

---@param id string
---@param value number
---@param min number
---@param max number
---@param data {disabled: boolean?, inputStyle: vec4[]?, width: integer?, formatRender: string?, flags: integer[]?, precision: integer?}?
---@return number? changed
SliderFloat = function(id, value, min, max, data)
    data = data or {}
    scale = BJI_LocalStorage.get(BJI_LocalStorage.GLOBAL_VALUES.UI_SCALE)

    if data.disabled then
        val1 = table.clone(BJI.Utils.Style.INPUT_PRESETS.DISABLED)
        val1[2] = val1[2] or BJI.Utils.Style.TEXT_COLORS.DISABLED
    else
        val1 = data.inputStyle or table.clone(BJI.Utils.Style.INPUT_PRESETS.DEFAULT)
        val1[2] = val1[2] or BJI.Utils.Style.TEXT_COLORS.DEFAULT
    end
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.FRAME_BG, val1[1])
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.TEXT_COLOR, val1[2])
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.FRAME_BG_HOVERED, val1[3])
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.FRAME_BG_ACTIVE, val1[4])
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.SLIDER_GRAB, val1[5])
    PushStyleColor(BJI.Utils.Style.STYLE_COLS.SLIDER_GRAB_ACTIVE, val1[6])

    data.width = data.width or -1
    if data.width < -1 then
        data.width = data.width + GetContentRegionAvail().x
    end
    SetNextItemWidth(data.width)

    if not data.formatRender and data.precision then
        data.formatRender = "%." .. data.precision .. "f"
    end

    val2 = FloatPtr(value)
    val3 = Flags(table.unpack(
        baseFlagsSlider:clone():addAll(data.flags or {}, true)
    ))
    val4 = ui_imgui.SliderFloat("##" .. id, val2, min, max, data.formatRender, val3)

    PopStyleColor(6)

    val5 = nil
    if val4 and not data.disabled then
        val5 = math.round(val2[0], data.precision or 3)
    end

    return val5 ~= value and val5 or nil
end

-- keep track of slider states (switch between slider and number input)
local sliderPrecisionStates = {
    int = {},
    float = {},
}

---@param id string
---@param value integer
---@param min integer
---@param max integer
---@param data {step: integer?, stepFast: integer?, disabled: boolean?, inputStyle: vec4[]?, btnStyle: vec4[]?, width: integer?, formatRender: string?, flags: integer[]?}?
---@return integer? changed
SliderIntPrecision = function(id, value, min, max, data)
    if not sliderPrecisionStates.int[id] then
        val1 = SliderInt(id, value, min, max, data)
        if max - min > 20 then
            TooltipText(BJI_Lang.get("common.precisionInputTooltip"))
            if IsItemClicked(BJI.Utils.Style.MOUSE_BUTTONS.RIGHT) then
                sliderPrecisionStates.int[id] = true
            end
        end
    else
        data = data or {}
        val1 = InputInt(id, value, {
            min = min,
            max = max,
            step = data.step,
            stepFast = data.stepFast,
            disabled = data.disabled,
            width = data.width,
            inputStyle = data.inputStyle,
            btnStyle = data.btnStyle,
        })
        TooltipText(BJI_Lang.get("common.precisionInputTooltip"))
        if IsItemClicked(BJI.Utils.Style.MOUSE_BUTTONS.RIGHT) then
            sliderPrecisionStates.int[id] = nil
        end
    end

    return val1 ~= value and val1 or nil
end

---@param id string
---@param value number
---@param min number
---@param max number
---@param data {step: integer?, stepFast: integer?, disabled: boolean?, inputStyle: vec4[]?, btnStyle: vec4[]?, width: integer?, formatRender: string?, flags: integer[]?, precision: integer?}?
---@return number? changed
SliderFloatPrecision = function(id, value, min, max, data)
    if not sliderPrecisionStates.float[id] then
        val1 = SliderFloat(id, value, min, max, data)
        TooltipText(BJI_Lang.get("common.precisionInputTooltip"))
        if IsItemClicked(BJI.Utils.Style.MOUSE_BUTTONS.RIGHT) then
            sliderPrecisionStates.float[id] = true
        end
    else
        data = data or {}
        val1 = InputFloat(id, value, {
            min = min,
            max = max,
            step = data.step,
            stepFast = data.stepFast,
            disabled = data.disabled,
            width = data.width,
            inputStyle = data.inputStyle,
            btnStyle = data.btnStyle,
            precision = data.precision,
        })
        TooltipText(BJI_Lang.get("common.precisionInputTooltip"))
        if IsItemClicked(BJI.Utils.Style.MOUSE_BUTTONS.RIGHT) then
            sliderPrecisionStates.float[id] = nil
        end
    end

    return val1 ~= value and val1 or nil
end

---@param texId any
---@param size point
Image = function(texId, size)
    ui_imgui.Image(texId, size,
        ui_imgui.ImVec2Zero, ui_imgui.ImVec2One,
        ui_imgui.ImColorByRGB(255, 255, 255, 255).Value,
        ui_imgui.ImColorByRGB(255, 255, 255, 255).Value
    )
end
