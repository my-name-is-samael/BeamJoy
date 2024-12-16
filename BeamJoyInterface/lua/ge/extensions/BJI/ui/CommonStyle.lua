local im = ui_imgui

function RGBA(r, g, b, a)
    return im.ImVec4(r, g, b, a)
end

RGBA_PRECISION = 3

WINDOW_FLAGS = {
    MENU_BAR = im.WindowFlags_MenuBar,
    NO_SCROLLBAR = im.WindowFlags_NoScrollbar,
    NO_SCROLL_WITH_MOUSE = im.WindowFlags_NoScrollWithMouse,
    NO_COLLAPSE = im.WindowFlags_NoCollapse,
    NO_FOCUS_ON_APPEARING = im.WindowFlags_NoFocusOnAppearing,
    NO_RESIZE = im.WindowFlags_NoResize,
}

STYLE_COLS = {
    WINDOW_BG = im.Col_WindowBg,
    POPUP_BG = im.Col_PopupBg,
    CHILD_BG = im.Col_ChildBg,
    MENUBAR_BG = im.Col_MenuBarBg,
    TEXT_COLOR = im.Col_Text,
    HELPMARKER = im.Col_TextDisabled,
    BORDER_COLOR = im.Col_Border,
    RESIZE_GRIP = im.Col_ResizeGrip,
    RESIZE_GRIP_HOVERED = im.Col_ResizeGripHovered,
    RESIZE_GRIP_ACTIVE = im.Col_ResizeGripActive,
    SCROLLBAR = im.Col_ScrollbarGrab,
    SCROLLBAR_HOVERED = im.Col_ScrollbarGrabHovered,
    SCROLLBAR_ACTIVE = im.Col_ScrollbarGrabActive,
    TITLE_BG = im.Col_TitleBg,
    TITLE_BG_ACTIVE = im.Col_TitleBgActive,
    TITLE_BG_COLLAPSED = im.Col_TitleBgCollapsed,
    TAB = im.Col_Tab,
    TAB_HOVERED = im.Col_TabHovered,
    TAB_ACTIVE = im.Col_TabActive,
    TAB_UNFOCUSED = im.Col_TabUnfocused,
    TAB_UNFOCUSED_ACTIVE = im.Col_TabUnfocusedActive,
    FRAME_BG = im.Col_FrameBg,
    FRAME_BG_HOVERED = im.Col_FrameBgHovered,
    FRAME_BG_ACTIVE = im.Col_FrameBgActive,
    HEADER = im.Col_Header,
    HEADER_HOVERED = im.Col_HeaderHovered,
    HEADER_ACTIVE = im.Col_HeaderActive,
    SEPARATOR = im.Col_Separator,
    SEPARATOR_HOVERED = im.Col_SeparatorHovered,
    SEPARATOR_ACTIVE = im.Col_SeparatorActive,
    BUTTON = im.Col_Button,
    BUTTON_HOVERED = im.Col_ButtonHovered,
    BUTTON_ACTIVE = im.Col_ButtonActive,
    TABLE_ROW_BG = im.Col_TableRowBg,
    TABLE_ROW_BG_ALT = im.Col_TableRowBgAlt,
    DOCKING_PREVIEW = im.Col_DockingPreview,
    PROGRESSBAR = im.Col_PlotHistogram,
}

function SetStyleColor(col, color)
    local found = false
    for _, v in pairs(STYLE_COLS) do
        if found then
            break
        end
        if col == v then
            found = true
        end
    end
    if not found then
        error(svar("Invalid style column: {1}", { col }))
        return
    end

    im.PushStyleColor2(col, color)
end

function PopStyleColor(amount)
    im.PopStyleColor(amount)
end

BJIStyles = {}
TEXT_COLORS = {}
BTN_PRESETS = {}
INPUT_PRESETS = {}

BJIThemeLoaded = false
function LoadTheme(data)
    if BJIThemeLoaded then
        PopStyleColor(2)
    end

    for k, v in pairs(data.Fields) do
        BJIStyles[STYLE_COLS[k]] = RGBA(v[1], v[2], v[3], v[4])
    end

    for k, v in pairs(data.Text) do
        TEXT_COLORS[k] = RGBA(v[1], v[2], v[3], v[4])
    end

    for k, v in pairs(data.Button) do
        local colors = {}
        for _, col in ipairs(v) do
            table.insert(colors, RGBA(col[1], col[2], col[3], col[4]))
        end
        BTN_PRESETS[k] = colors
    end

    for k, v in pairs(data.Input) do
        local colors = {}
        for _, col in ipairs(v) do
            table.insert(colors, RGBA(col[1], col[2], col[3], col[4]))
        end
        INPUT_PRESETS[k] = colors
    end

    -- pre-applying those to have multi-windows colors right
    SetStyleColor(STYLE_COLS.TITLE_BG, BJIStyles[STYLE_COLS.TITLE_BG])
    SetStyleColor(STYLE_COLS.TITLE_BG_ACTIVE, BJIStyles[STYLE_COLS.TITLE_BG_ACTIVE])
    BJIThemeLoaded = true
end

function InitDefaultStyles()
    for k, v in pairs(BJIStyles) do
        SetStyleColor(k, v)
    end
    SetStyleColor(STYLE_COLS.TEXT_COLOR, TEXT_COLORS.DEFAULT)
end

function ResetStyles()
    PopStyleColor(tlength(BJIStyles) + 1)
end
