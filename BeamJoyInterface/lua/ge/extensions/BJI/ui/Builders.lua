local im = ui_imgui
local ffi = require('ffi')

-- INPUTS

function InputInt(val)
    return ({
        _value = nil,
        get = function(self) return Round(self._value[0]) end,
        set = function(self, value)
            self._value = im.IntPtr(value)
            return self
        end,
        clamp = function(self, min, max)
            local value = self:get()
            if min ~= nil and value < min then
                value = min
            elseif max ~= nil and value > max then
                value = max
            end
            return self:set(value)
        end,
    }):set(tonumber(val) or 0)
end

function InputFloat(val, precision)
    precision = tonumber(precision) or 3
    return ({
        _value = nil,
        get = function(self) return Round(self._value[0], precision) end,
        set = function(self, value)
            self._value = im.FloatPtr(value)
            return self
        end,
        clamp = function(self, min, max)
            local value = self:get()
            if min ~= nil and value < min then
                value = min
            elseif max ~= nil and value > max then
                value = max
            end
            return self:set(value)
        end,
    }):set(tonumber(val) or 0)
end

function InputString(size, defaultValue)
    return ({
        _size = tonumber(size) or 128,
        _value = nil,
        get = function(self) return ffi.string(self._value) end,
        set = function(self, value)
            if type(value) == "string" then
                self._value = im.ArrayChar(self._size, value)
            elseif tincludes({ "number", "boolean" }, type(value)) then
                self._value = im.ArrayChar(self._size, tostring(value))
            else
                self._value = im.ArrayChar(self._size)
            end
            return self
        end
    }):set(defaultValue)
end

-- UI BUILDERS

local logTag = "BJIDrawBuilders"

local IndentCursor = 0
local lineHeight = 19

HELPMARKER_TEXT = " (?) "

Indent = function(amount)
    while amount > 0 do
        im.Indent()
        IndentCursor = IndentCursor + 1
        amount = amount - 1
    end
    while amount < 0 and IndentCursor > 0 do
        im.Unindent()
        IndentCursor = IndentCursor - 1
        amount = amount + 1
    end
end

Separator = function()
    im.Separator()
end

WindowBuilder = function(name, flags)
    if not name then
        LogError("Window is missing name", logTag)
    end
    local builder = {
        _name = name,
        _flags = flags,
        _opacity = 1,
        _title = nil,
        _menuBehavior = nil,
        _headerBehavior = nil,
        _bodyBehavior = nil,
        _footerBehavior = nil,
        _footerLines = 0,
    }

    builder.title = function(self, title)
        self._title = title
        return self
    end
    builder.opacity = function(self, opacity)
        self._opacity = opacity
        return self
    end
    builder.menu = function(self, renderBehavior)
        self._menuBehavior = renderBehavior
        return self
    end
    builder.header = function(self, renderBehavior)
        self._headerBehavior = renderBehavior
        return self
    end
    builder.body = function(self, renderBehavior)
        self._bodyBehavior = renderBehavior
        return self
    end
    builder.footer = function(self, renderBehavior, lines)
        self._footerBehavior = renderBehavior
        self._footerLines = lines
        return self
    end
    builder.onClose = function(self, onClose)
        self._onClose = onClose
        return self
    end

    builder.build = function(self)
        if self._bodyBehavior == nil then
            LogError("Window is missing content", logTag)
        end

        im.SetNextWindowBgAlpha(self._opacity)
        local closeable = type(self._onClose) == "function"
        local open = closeable and im.BoolPtr(true) or nil
        if im.Begin(self._title, open, self._flags) then
            im.SetWindowFontScale(BJIContext.UserSettings.UIScale)

            if self._menuBehavior then
                self._menuBehavior()
            end

            if self._headerBehavior then
                self._headerBehavior()
            end

            local footerHeight = self._footerLines == 0 and 0 or
                (self._footerLines * lineHeight + 2) * BJIContext.UserSettings.UIScale
            local bodyHeight = im.GetContentRegionAvail().y - math.ceil(footerHeight)
            im.BeginChild1(svar("##{1}Body", { self._name }), im.ImVec2(-1, bodyHeight))
            im.SetWindowFontScale(1) -- must scale to 1 in children
            self._bodyBehavior()
            im.EndChild()
            im.SetWindowFontScale(BJIContext.UserSettings.UIScale)

            if self._footerBehavior then
                self._footerBehavior()
            end
        end
        im.End()

        if open and not open[0] then
            self._onClose()
        end
    end

    return builder
end

MenuBarBuilder = function()
    local builder = {
        _entries = {}
    }

    --[[
    <ul>
        <li>label: string</li>
        <li>elems: array (must have render or separator or label)</li>
        <li>
            <ul>
                <li>render: function NULLABLE</li>
                <li>separator: bool NULLABLE</li>
                <li>label: string NULLABLE</li>
                <li>onClick: function NULLABLE</li>
                <li>color: RGBA() NULLABLE</li>
                <li>active: bool NULLABLE</li>
                <li>disabled: bool NULLABLE</li>
                <li>elems: recursive array NULLABLE (2 levels max)</li>
            </ul>
        </li>
    </ul>
    ]]
    builder.addEntry = function(self, label, elems)
        if not label then
            LogError("Menu entry is missing label", logTag)
            return self
        end
        local entry = {
            label = label,
            elems = {}
        }
        for _, elem in ipairs(elems) do
            if type(elem.render) ~= "function" and
                elem.separator ~= true and
                type(elem.label) ~= "string" then
                LogError("Menu element is missing render, separator and label", logTag)
                return self
            end

            if elem.separator == true then
                table.insert(entry.elems, { separator = true })
            elseif type(elem.render) == "function" then
                table.insert(entry.elems, {
                    render = elem.render,
                })
            else
                local subElems
                if type(elem.elems) == "table" then
                    subElems = {}
                    for _, subElem in ipairs(elem.elems) do
                        if type(subElem.render) ~= "function" and
                            subElem.separator ~= true and
                            type(subElem.label) ~= "string" then
                            LogError("Menu sub element is missing render, separator and label", logTag)
                            return self
                        end
                        if subElem.render then
                            table.insert(subElems, {
                                render = subElem.render,
                            })
                        elseif subElem.separator then
                            table.insert(subElems, { separator = true })
                        else
                            table.insert(subElems, {
                                label = subElem.label,
                                onClick = type(subElem.onClick) == "function" and subElem.onClick or nil,
                                color = subElem.color,
                                active = subElem.active,
                                disabled = subElem.disabled,
                            })
                        end
                    end
                end
                table.insert(entry.elems, {
                    label = elem.label,
                    onClick = type(elem.onClick) == "function" and elem.onClick or nil,
                    color = elem.color,
                    active = elem.active,
                    disabled = elem.disabled,
                    elems = subElems,
                })
            end
        end
        table.insert(self._entries, entry)
        return self
    end

    builder.build = function(self)
        if #self._entries > 0 then
            local function drawMenu(label, elems, level)
                level = level or 0
                if im.BeginMenu(label) then
                    im.SetWindowFontScale(level == 0 and 1 or BJIContext.UserSettings.UIScale)
                    for i, elem in ipairs(elems) do
                        if elem.separator then
                            Separator()
                        elseif elem.render then
                            elem.render()
                        elseif type(elem.elems) == "table" and level < 2 then
                            drawMenu(elem.label, elem.elems, level + 1)
                        elseif elem.onClick then
                            if elem.active then
                                SetStyleColor(STYLE_COLS.TEXT_COLOR, TEXT_COLORS.HIGHLIGHT)
                            end
                            local enabled = elem.disabled and im.BoolFalse() or im.BoolTrue()
                            if im.MenuItem1(elem.label, nil, im.BoolFalse(), enabled) then
                                elem.onClick()
                            end
                            if elem.active then
                                PopStyleColor(1)
                            end
                        else
                            local color = elem.color
                            if not color then
                                if elem.disabled then
                                    color = TEXT_COLORS.DISABLED
                                elseif elem.active then
                                    color = TEXT_COLORS.HIGHLIGHT
                                end
                            end
                            LineBuilder()
                                :text(elem.label, color)
                                :build()
                        end
                    end
                    im.EndMenu()
                end
            end

            im.BeginMenuBar()
            for _, entry in ipairs(self._entries) do
                drawMenu(entry.label, entry.elems)
            end
            im.EndMenuBar()
            im.SetWindowFontScale(BJIContext.UserSettings.UIScale)
        end
    end

    return builder
end

TabBarBuilder = function(name)
    if name == nil then
        LogError("TabBar is missing name", logTag)
    end

    local builder = {
        _name = name,
        _tabs = {},
    }

    builder.addTab = function(self, label, behavior)
        if type(label) ~= "string" or #label == 0 or type(behavior) ~= "function" then
            LogError("TabBar is missing label or behavior", logTag)
            return self
        end

        table.insert(self._tabs, {
            label = label,
            behavior = behavior
        })
        return self
    end

    builder.build = function(self)
        if #self._tabs == 0 then
            LogError("TabBar is missing content", logTag)
            return
        end

        if im.BeginTabBar(self._name) then
            for _, tab in ipairs(self._tabs) do
                if im.BeginTabItem(tab.label) then
                    tab.behavior()
                    im.EndTabItem()
                end
            end
            im.EndTabBar()
        end
    end

    return builder
end

AccordionBuilder = function(indentAmount)
    if indentAmount == nil or type(indentAmount) ~= "number" then
        indentAmount = 1
    end
    local builder = {
        _indent = indentAmount,
        _label = nil,
        _commonStart = nil,
        _openedBehavior = nil,
        _closedBehavior = nil,
        _commonEnd = nil
    }

    builder.label = function(self, label)
        self._label = label
        return self
    end
    builder.commonStart = function(self, startFn)
        self._commonStart = startFn
        return self
    end
    builder.openedBehavior = function(self, openedFn)
        self._openedBehavior = openedFn
        return self
    end
    builder.closedBehavior = function(self, closedFn)
        self._closedBehavior = closedFn
        return self
    end
    builder.commonEnd = function(self, endFn)
        self._commonEnd = endFn
        return self
    end

    builder.build = function(self)
        if self._commonStart == nil and
            self._openedBehavior == nil and
            self._closedBehavior == nil and
            self._commonEnd == nil then
            LogError("TreeNode is empty", logTag)
        end

        if self._label == nil then
            self._label = ""
        end

        if im.TreeNode1(self._label) then
            Indent(self._indent)
            if self._commonStart ~= nil then
                self._commonStart()
            end

            if self._openedBehavior ~= nil then
                self._openedBehavior()
            end

            if self._commonEnd ~= nil then
                self._commonEnd()
            end
            Indent(-self._indent)
            im.TreePop()
        else
            if self._commonStart ~= nil then
                self._commonStart()
            end

            if self._closedBehavior ~= nil then
                self._closedBehavior()
            end

            if self._commonEnd ~= nil then
                self._commonEnd()
            end
        end
    end

    return builder
end

LineBuilder = function(startSameLine)
    local builder = {
        _elemCount = 0,
    }
    if startSameLine then
        builder._elemCount = 1
    end

    builder._commonStartElem = function(self)
        if (self._elemCount > 0) then
            im.SameLine()
        end
    end

    builder.text = function(self, text, color, bgColor)
        self:_commonStartElem()
        SetStyleColor(STYLE_COLS.HEADER, RGBA(1, 0, 0, 1))
        if color ~= nil then
            im.TextColored(color, tostring(text))
        else
            im.Text(tostring(text))
        end
        PopStyleColor(1)
        self._elemCount = self._elemCount + 1
        return self
    end

    local function btnStylePreset(preset)
        SetStyleColor(STYLE_COLS.BUTTON, preset[1])
        SetStyleColor(STYLE_COLS.BUTTON_HOVERED, preset[2])
        SetStyleColor(STYLE_COLS.BUTTON_ACTIVE, preset[3])
        if preset[4] then
            SetStyleColor(STYLE_COLS.TEXT_COLOR, preset[4])
        end
    end
    local function resetBtnStyle()
        im.PopStyleColor(3)
    end
    builder.btn = function(self, data)
        if not data or not data.id or not data.label or
            not data.onClick then
            LogError("btn requires id, label and onClick", logTag)
            return self
        end
        self:_commonStartElem()

        if data.disabled == true then
            btnStylePreset(BTN_PRESETS.DISABLED)
        elseif data.style then
            btnStylePreset(data.style)
        end
        if im.SmallButton(svar("{1}##{2}", { data.label, data.id })) and data.disabled ~= true then
            data.onClick()
        end
        if data.disabled or data.style then
            resetBtnStyle()
        end

        self._elemCount = self._elemCount + 1
        return self
    end
    builder.btnSwitch = function(self, data)
        if not data or not data.id or not data.labelOn or
            not data.labelOff or data.state == nil or not data.onClick then
            LogError("btnSwitch requires id, labelOn, labelOff, state and onClick", logTag)
            return self
        end
        if data.state then
            data.style = BTN_PRESETS.SUCCESS
            data.label = data.labelOn
        else
            data.style = BTN_PRESETS.ERROR
            data.label = data.labelOff
        end
        self = self:btn(data)
        return self
    end
    builder.btnToggle = function(self, data)
        if not data or not data.id or data.state == nil or not data.onClick then
            LogError("btnToggle requires id, state and onClick", logTag)
            return self
        end
        local label = "Toggle"
        -- invert state to print in Red when active
        return self:btnSwitch({
            id = data.id,
            labelOn = label,
            labelOff = label,
            state = not data.state,
            disabled = data.disabled,
            onClick = data.onClick
        })
    end
    builder.btnSwitchAllowBlocked = function(self, data)
        if not data or not data.id or data.state == nil or not data.onClick then
            LogError("btnSwitchAllowBlocked requires id, state and onClick", logTag)
            return self
        end
        return self:btnSwitch({
            id = data.id,
            labelOn = BJILang.get("common.buttons.allowed"),
            labelOff = BJILang.get("common.buttons.blocked"),
            state = data.state,
            disabled = data.disabled,
            onClick = data.onClick
        })
    end
    builder.btnSwitchEnabledDisabled = function(self, data)
        if not data or not data.id or data.state == nil or not data.onClick then
            LogError("btnSwitchEnabledDisabled requires id, state and onClick", logTag)
            return self
        end
        return self:btnSwitch({
            id = data.id,
            labelOn = BJILang.get("common.enabled"),
            labelOff = BJILang.get("common.disabled"),
            state = data.state,
            disabled = data.disabled,
            onClick = data.onClick
        })
    end
    builder.btnSwitchPlayStop = function(self, data)
        if not data or not data.id or data.state == nil or not data.onClick then
            LogError("btnSwitchPlayStop requires id, state and onClick", logTag)
            return self
        end
        -- invert state to show "Stop" when active
        return self:btnSwitch({
            id = data.id,
            labelOn = BJILang.get("common.buttons.play"),
            labelOff = BJILang.get("common.buttons.stop"),
            state = not data.state,
            disabled = data.disabled,
            onClick = data.onClick
        })
    end
    builder.btnSwitchYesNo = function(self, data)
        if not data or not data.id or data.state == nil or not data.onClick then
            LogError("btnSwitchYesNo requires id, state and onClick", logTag)
            return self
        end
        return self:btnSwitch({
            id = data.id,
            labelOn = BJILang.get("common.yes"),
            labelOff = BJILang.get("common.no"),
            state = data.state,
            disabled = data.disabled,
            onClick = data.onClick
        })
    end

    builder.inputNumeric = function(self, data)
        if not data or not data.id or not data.type or type(data.value) ~= "number" then
            LogError("inputNumeric requires id, type and value", logTag)
            return self
        elseif not tincludes({ "int", "float" }, data.type) then
            LogError("inputNumeric requires type to be 'int' or 'float'", logTag)
            return self
        end

        data.precision = data.precision or 3
        data.step = data.step or 1
        data.stepFast = data.stepFast or data.step

        self:_commonStartElem()

        -- WIDTH
        if data.width then
            im.PushItemWidth(data.width * BJIContext.UserSettings.UIScale)
        else
            im.PushItemWidth(-1)
        end

        -- DISABLED / STYLE
        if data.disabled then
            SetStyleColor(STYLE_COLS.FRAME_BG, INPUT_PRESETS.DISABLED[1])
            SetStyleColor(STYLE_COLS.TEXT_COLOR, INPUT_PRESETS.DISABLED[2])
        elseif data.style then
            SetStyleColor(STYLE_COLS.FRAME_BG, data.style[1])
            if data.style[2] then
                SetStyleColor(STYLE_COLS.TEXT_COLOR, data.style[2])
            end
        end

        local input = InputInt(Round(data.value))
        local drawFn = im.InputInt
        if data.type == "float" then
            input = InputFloat(data.value, data.precision)
            drawFn = im.InputFloat
        end

        if drawFn(svar("##{1}", { data.id }), input._value, data.step, data.stepFast) and
            not data.disabled then
            local valid = true
            if data.min or data.max then
                if data.min and input:get() < data.min then
                    valid = false
                elseif data.max and input:get() > data.max then
                    valid = false
                end
                input = input:clamp(data.min, data.max)
            end
            if valid and type(data.onUpdate) == "function" then
                data.onUpdate(input:get())
            end
        end

        -- REMOVE STYLE
        if data.disabled then
            PopStyleColor(2)
        elseif data.style then
            if data.style[2] then
                PopStyleColor(2)
            else
                PopStyleColor(1)
            end
        end

        -- REMOVE WIDTH
        im.PopItemWidth()

        self._elemCount = self._elemCount + 1
        return self
    end

    builder.inputString = function(self, data)
        if not data or not data.id or type(data.value) ~= "string" then
            LogError("inputString requires id and value", logTag)
            return self
        end

        if not data.placeholder then
            data.placeholder = ""
        end
        self:_commonStartElem()

        -- WIDTH
        if data.width then
            im.PushItemWidth(data.width * BJIContext.UserSettings.UIScale)
        else
            im.PushItemWidth(-1)
        end

        -- DISABLED / STYLE
        if data.disabled then
            SetStyleColor(STYLE_COLS.FRAME_BG, INPUT_PRESETS.DISABLED[1])
            SetStyleColor(STYLE_COLS.TEXT_COLOR, INPUT_PRESETS.DISABLED[2])
        elseif data.style then
            SetStyleColor(STYLE_COLS.FRAME_BG, data.style[1])
            if data.style[2] then
                SetStyleColor(STYLE_COLS.TEXT_COLOR, data.style[2])
            end
        end

        -- DRAW
        local input = InputString(data.size or 100, data.value)
        if not data.multiline then
            --[[im.InputTextWithHint(
                svar("##{1}", { data.id }),
                data.placeholder,
                input._value,
                input._size
            )]]
            -- TODO wait for fix answer
            if data.placeholder and #strim(data.placeholder) > 0 then
                im.ShowHelpMarker(data.placeholder)
                im.SameLine()
            end
            if im.InputText(svar("##{1}", { data.id }), input._value, input._size) and
                not data.disabled and type(data.onUpdate) == "function" then
                data.onUpdate(input:get())
            end
        else
            local w = -1
            if data.width then
                w = data.width * BJIContext.UserSettings.UIScale
            end

            local lines = 3
            if data.autoheight then
                local _, count = input:get():gsub("\n", "")
                lines = count + 1
            elseif data.lines then
                lines = data.lines
            end
            local h = (lineHeight * BJIContext.UserSettings.UIScale * lines) + 2
            if h < 0 then
                h = -1
            end
            im.SetWindowFontScale(BJIContext.UserSettings.UIScale) -- update scale for multiline inputs
            if im.InputTextMultiline(
                    svar("##{1}", { data.id }),
                    input._value,
                    input._size,
                    im.ImVec2(w, h)
                ) and
                not data.disabled and type(data.onUpdate) == "function" then
                data.onUpdate(input:get())
            end
            im.SetWindowFontScale(1)
        end

        -- REMOVE STYLE
        if data.disabled then
            PopStyleColor(2)
        elseif data.style then
            if data.style[2] then
                PopStyleColor(2)
            else
                PopStyleColor(1)
            end
        end

        -- REMOVE WIDTH
        im.PopItemWidth()

        self._elemCount = self._elemCount + 1
        return self
    end

    builder.inputCombo = function(self, data)
        if not data or not data.id or type(data.items) ~= "table" then
            LogError("combo requires id, items", logTag)
            return self
        end
        data.items = #data.items > 0 and data.items or { "" }
        local stringValues = type(data.items[1]) == "string"
        if not stringValues and type(data.items[1]) ~= "table" then
            LogError("combo requires items to be strings or tables", logTag)
            return self
        elseif not stringValues and not data.getLabelFn then
            LogError("combo with table items requires getLabelFn", logTag)
            return self
        end

        self:_commonStartElem()
        data.label = data.label or ""
        data.value = data.value or data.items[1]

        local valuePos = 1
        if stringValues then
            valuePos = tpos(data.items, data.value) or valuePos
        else
            for i, v in ipairs(data.items) do
                if data.getLabelFn(v) == data.getLabelFn(data.value) then
                    valuePos = i
                    break
                end
            end
        end
        local input = InputInt(valuePos - 1)

        local parsedValues = tdeepcopy(data.items)
        if not stringValues then
            for i, v in ipairs(parsedValues) do
                parsedValues[i] = data.getLabelFn(v)
            end
        end

        -- WIDTH
        if data.width then
            im.PushItemWidth(data.width * BJIContext.UserSettings.UIScale)
        else
            im.PushItemWidth(-1)
        end

        if im.Combo1(svar("{1}##{2}", { data.label, data.id }), input._value, im.ArrayCharPtrByTbl(parsedValues)) and
            type(data.onChange) == "function" then
            local newString = parsedValues[input:get() + 1]
            local newValue
            if stringValues then
                newValue = newString
            else
                for _, v in ipairs(data.items) do
                    if data.getLabelFn(v) == newString then
                        newValue = v
                        break
                    end
                end
            end
            data.onChange(newValue)
        end

        -- REMOVE WIDTH
        im.PopItemWidth()

        self._elemCount = self._elemCount + 1
        return self
    end

    builder.helpMarker = function(self, text)
        self:_commonStartElem()

        im.ShowHelpMarker(text)

        self._elemCount = self._elemCount + 1
        return self
    end

    builder.icon = function(self, data)
        if not data.icon then
            LogError("icon requires icon", logTag)
            return self
        end

        local icon = GetIcon(data.icon)
        if not icon then
            return self
        end

        local size = GetIconSize(data.big)
        local style = data.style or TEXT_COLORS.DEFAULT
        local border = data.border or nil

        self:_commonStartElem()
        BJIContext.GUI.uiIconImage(icon, -- ICON
            im.ImVec2(size, size),       -- SIZE
            style,                       -- ICON COLOR
            border,                      -- BORDER COLOR
            nil                          -- LABEL
        )
        self._elemCount = self._elemCount + 1
        return self
    end
    builder.btnIcon = function(self, data)
        if not data.id or not data.icon or type(data.onClick) ~= "function" then
            LogError("btnIcon requires id, icon and onClick", logTag)
            return self
        end

        local icon = GetIcon(data.icon)
        if not icon then
            return self
        end

        local size = GetIconSize(data.big)
        local style = data.style or TEXT_COLORS.DEFAULT
        if type(style) == "table" then
            style = style[1]
        end
        local bg = data.background or BTN_PRESETS.TRANSPARENT
        if type(bg) == "table" then
            bg = bg[1]
        end

        if data.disabled then
            style = TEXT_COLORS.DEFAULT
            bg = BTN_PRESETS.DISABLED[1]
        end

        self:_commonStartElem()
        if BJIContext.GUI.uiIconImageButton(icon, -- ICON
                im.ImVec2(size, size),            -- SIZE
                style,                            -- ICON COLOR
                nil,                              -- LABEL
                bg,                               -- ICON BG COLOR
                data.id,                          -- ID
                nil,                              -- TEXT COLOR
                nil,                              -- TEXT BG FLAG
                false,                            -- ON RELEASE
                nil                               -- HIGHLIGHT TEXT
            ) and not data.disabled then
            data.onClick()
        end
        self._elemCount = self._elemCount + 1
        return self
    end
    builder.btnIconSwitch = function(self, data)
        if not data.id or not data.iconEnabled or data.state == nil or not data.onClick then
            LogError("btnIconSwitch requires id, iconEnabled, state and onClick", logTag)
            return self
        end

        data.iconDisabled = data.iconDisabled or data.iconEnabled
        data.icon = data.state and data.iconEnabled or data.iconDisabled
        data.style = TEXT_COLORS.DEFAULT
        data.background = data.state and BTN_PRESETS.SUCCESS or BTN_PRESETS.ERROR

        return self:btnIcon(data)
    end

    builder.build = function(self)
        -- normalization
    end

    return builder
end

EmptyLine = function()
    LineBuilder():text(" "):build()
end

ProgressBar = function(data)
    data.floatPercent = data.floatPercent or 0
    data.width = data.width or -1
    local text = data.text or ""
    local height = #text == 0 and 5 or (im.CalcTextSize(text).y + 2)

    local size = im.ImVec2(data.width * BJIContext.UserSettings.UIScale, height)

    im.ProgressBar(data.floatPercent, size, text)
end

--[[
<ul>
    <li>name: string</li>
    <li>colsWidths: int[]</li>
    <li>borders: bool</li>
</ul>
]]
ColumnsBuilder = function(name, colsWidths, borders)
    colsWidths = colsWidths or { -1 }
    local builder = {
        _name = name,
        _cols = #colsWidths,
        _widths = tdeepcopy(colsWidths),
        _currentCol = 0,
        _rows = {},
        _borders = borders == true,
    }

    --[[
    <ul>
        <li>data: object</li>
        <li>
            <ul>
                <li>cells: function[](calling LineBuilders)</li>
            </ul>
        </li>
    </ul>
    ]]
    builder.addRow = function(self, data)
        local colFns = {}
        for i = 1, self._cols do
            if type(data.cells[i]) == "function" then
                colFns[i] = data.cells[i]
            else
                colFns[i] = function() EmptyLine() end
            end
        end
        table.insert(self._rows, colFns)
        return self
    end

    local function calculateTableWidths(widths)
        local countWidths, countEmpties = 0, 0
        for _, w in ipairs(widths) do
            if w > -1 then
                countWidths = countWidths + (w)
            else
                countEmpties = countEmpties + 1
            end
        end

        if countEmpties == 0 then
            return widths
        end

        local res = {}
        local regionW = im.GetContentRegionAvail().x
        local avail = regionW - countWidths
        for _, w in ipairs(widths) do
            if w > -1 then
                table.insert(res, w)
            else
                table.insert(res, math.floor(avail / countEmpties))
            end
        end
        return res
    end

    builder.build = function(self)
        local widths = calculateTableWidths(self._widths)
        im.Columns(self._cols, self._name, self._borders)
        for i, w in ipairs(widths) do
            im.SetColumnWidth(i - 1, w)
        end
        if #self._rows > 0 then
            for _, row in ipairs(self._rows) do
                for _, cellFn in ipairs(row) do
                    cellFn()
                    im.NextColumn()
                end
            end
        end
        im.Columns(1)
    end

    return builder
end

ColorPicker = function(data)
    if not data.id or not data.label or not data.value or not data.onChange then
        LogError("ColorPicker requires id, label, value and onChange", logTag)
        return
    end
    local flags = im.flags(tunpack({
        im.ColorEditFlags_NoSmallPreview,
        im.ColorEditFlags_NoSidePreview,
        im.ColorEditFlags_AlphaBar,
    }))

    AccordionBuilder()
        :label(svar("{1}##{2}", { data.label, data.id }))
        :openedBehavior(function()
            local color = im.ArrayFloat(4)
            color[0] = data.value.x
            color[1] = data.value.y
            color[2] = data.value.z
            color[3] = data.alpha and data.value.w or 1

            if data.alpha then
                if im.ColorPicker4(svar("##{1}", { data.id }), color, flags) then
                    local updated = RGBA(color[0], color[1], color[2], color[3])
                    data.onChange(updated)
                end
            else
                if im.ColorPicker3(svar("##{1}", { data.id }), color, flags) then
                    local updated = RGBA(color[0], color[1], color[2], color[3])
                    data.onChange(updated)
                end
            end
        end)
        :build()
end
