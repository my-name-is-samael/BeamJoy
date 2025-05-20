local im = ui_imgui
local ffi = require('ffi')
BTN_NO_SOUND = "no_sound"

---@return vec4
local function convertColorToVec4(color)
    if type(color) == "table" then
        if color.r then
            color = BJI.Utils.Style.RGBA(color.r, color.g, color.b, color.a)
        elseif color[1] then
            color = BJI.Utils.Style.RGBA(color[1], color[2], color[3], color[4] or 1)
        end
    end
    return color
end

-- INPUTS

function InputInt(val)
    return ({
        _value = nil,
        get = function(self) return math.round(self._value[0]) end,
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
        get = function(self) return math.round(self._value[0], precision) end,
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
            elseif table.includes({ "number", "boolean" }, type(value)) then
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

---@param amount integer
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

---@class WindowBuilder
---@field title fun(self, title: string): WindowBuilder
---@field opacity fun(self, opacity: number): WindowBuilder
---@field menu fun(self, renderBehavior: fun()): WindowBuilder
---@field header fun(self, renderBehavior: fun()): WindowBuilder
---@field body fun(self, renderBehavior: fun()): WindowBuilder
---@field footer fun(self, renderBehavior: fun(), lines: integer): WindowBuilder
---@field onClose fun(self, onClose: fun()): WindowBuilder
---@field build fun(self)

---@param name string
---@param flags number[]
---@return WindowBuilder
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
        local scale = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.UI_SCALE)
        if im.Begin(self._title, open, self._flags) then
            im.SetWindowFontScale(scale)

            if self._menuBehavior then
                self._menuBehavior()
            end

            if self._headerBehavior then
                self._headerBehavior()
            end

            local footerHeight = self._footerLines == 0 and 0 or
                (self._footerLines * (lineHeight + 5)) * scale
            local bodyHeight = im.GetContentRegionAvail().y - math.ceil(footerHeight)
            im.BeginChild1(string.var("##{1}Body", { self._name }), im.ImVec2(-1, bodyHeight))
            im.SetWindowFontScale(1) -- must scale to 1 in children
            self._bodyBehavior()
            im.EndChild()
            im.SetWindowFontScale(scale)

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

---@class MenuBarElem
---@field label? string
---@field separator? boolean
---@field render? fun()
---@field onClick? fun()
---@field color? vec4
---@field active? boolean
---@field disabled? boolean
---@field elems? MenuBarElem[] recursive (2 levels max)


---@class MenuBarBuilder
---@field addEntry fun(self, label: string, elems: MenuBarElem[]): MenuBarBuilder
---@field build fun(self)

---@return MenuBarBuilder
MenuBarBuilder = function()
    local builder = {
        _entries = {}
    }

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
                            if subElem.sound == BTN_NO_SOUND then
                                subElem.sound = nil
                            else
                                subElem.sound = subElem.sound or BJI.Managers.Sound.SOUNDS.BIGMAP_HOVER
                            end

                            table.insert(subElems, {
                                label = subElem.label,
                                onClick = type(subElem.onClick) == "function" and subElem.onClick or nil,
                                sound = subElem.sound,
                                color = subElem.color,
                                active = subElem.active,
                                disabled = subElem.disabled,
                            })
                        end
                    end
                else
                    if elem.sound == BTN_NO_SOUND then
                        elem.sound = nil
                    else
                        elem.sound = elem.sound or BJI.Managers.Sound.SOUNDS.BIGMAP_HOVER
                    end
                end
                table.insert(entry.elems, {
                    label = elem.label,
                    onClick = type(elem.onClick) == "function" and elem.onClick or nil,
                    sound = elem.sound,
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
            local scale = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.UI_SCALE)
            local function drawMenu(label, elems, level)
                level = level or 0
                if im.BeginMenu(label) then
                    im.SetWindowFontScale(level == 0 and 1 or scale)
                    for _, elem in ipairs(elems) do
                        if elem.separator then
                            Separator()
                        elseif elem.render then
                            elem.render()
                        elseif type(elem.elems) == "table" and level < 2 then
                            drawMenu(elem.label, elem.elems, level + 1)
                        elseif elem.onClick then
                            if elem.active then
                                BJI.Utils.Style.SetStyleColor(BJI.Utils.Style.STYLE_COLS.TEXT_COLOR,
                                    BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT)
                            end
                            local enabled = elem.disabled and im.BoolFalse() or im.BoolTrue()
                            if im.MenuItem1(elem.label, nil, im.BoolFalse(), enabled) then
                                if elem.sound then
                                    BJI.Managers.Sound.play(elem.sound)
                                end
                                elem.onClick()
                            end
                            if elem.active then
                                BJI.Utils.Style.PopStyleColor(1)
                            end
                        else
                            local color = elem.color
                            if not color then
                                if elem.disabled then
                                    color = BJI.Utils.Style.TEXT_COLORS.DISABLED
                                elseif elem.active then
                                    color = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT
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
            im.SetWindowFontScale(scale)
        end
    end

    return builder
end

---@class TabBarBuilder
---@field addTab fun(self, label: string, behavior: fun()): TabBarBuilder
---@field build fun(self)

---@param name string unique name for the tab bar
---@return TabBarBuilder
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

---@class AccordionBuilder
---@field label fun(self, label: string, labelColor: number[]|table<string, number>?): AccordionBuilder
---@field commonStart fun(self, startFn: fun(isOpen: boolean)): AccordionBuilder
---@field openedBehavior fun(self, openedFn: fun()): AccordionBuilder
---@field closedBehavior fun(self, closedFn: fun()): AccordionBuilder
---@field commonEnd fun(self, endFn: fun(isOpen: boolean)): AccordionBuilder
---@field build fun(self)

---@param indentAmount? integer
---@return AccordionBuilder
AccordionBuilder = function(indentAmount)
    if indentAmount == nil or type(indentAmount) ~= "number" then
        indentAmount = 1
    end
    local builder = {
        _indent = indentAmount,
        _label = nil,
        _labelColor = nil,
        _commonStart = nil,
        _openedBehavior = nil,
        _closedBehavior = nil,
        _commonEnd = nil
    }

    builder.label = function(self, label, labelColor)
        self._label = label
        if labelColor then
            self._labelColor = convertColorToVec4(labelColor)
        end
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

        if self._labelColor then
            BJI.Utils.Style.SetStyleColor(BJI.Utils.Style.STYLE_COLS.TEXT_COLOR, self._labelColor)
        end
        im.SetNextItemWidth(im.GetContentRegionAvail().x)
        local isOpen = im.TreeNode1(self._label)
        if self._labelColor then
            BJI.Utils.Style.PopStyleColor(1)
        end
        if isOpen then
            Indent(self._indent)
            if self._commonStart ~= nil then
                self._commonStart(isOpen)
            end

            if self._openedBehavior ~= nil then
                self._openedBehavior()
            end

            if self._commonEnd ~= nil then
                self._commonEnd(isOpen)
            end
            Indent(-self._indent)
            im.TreePop()
        else
            if self._commonStart ~= nil then
                self._commonStart(isOpen)
            end

            if self._closedBehavior ~= nil then
                self._closedBehavior()
            end

            if self._commonEnd ~= nil then
                self._commonEnd(isOpen)
            end
        end
    end

    return builder
end

---@class LineBuilder
---@field text fun(self, text: string|any?, color: number[]|table<string, number>?): LineBuilder
---@field bgText fun(self, id: string, text: string|any, color: number[]|table<string, number>, bgColor: number[]|table<string, number>): LineBuilder
---@field btn fun(self, data: {id: string, label: string, onClick: fun(), style: number[][]?}, active: boolean?, sound: string?, disabled: boolean?): LineBuilder
---@field btnSwitch fun(self, data: {id: string, labelOn: string, labelOff: string, state: boolean, onClick: fun(), style: number[][]?, active: boolean?, sound: string?, disabled: boolean?})
---@field btnToggle fun(self, data: {id: string, state: boolean, onClick: fun(), disabled: boolean?, sound: string?}): LineBuilder
---@field btnSwitchAllowBlocked fun(self, data: {id: string, state: boolean, onClick: fun(), disabled: boolean?, sound: string?}): LineBuilder
---@field btnSwitchEnabledDisabled fun(self, data: {id: string, state: boolean, onClick: fun(), disabled: boolean?, sound: string?}): LineBuilder
---@field btnSwitchPlayStop fun(self, data: {id: string, state: boolean, onClick: fun(), disabled: boolean?, sound: string?}): LineBuilder
---@field btnSwitchYesNo fun(self, data: {id: string, state: boolean, onClick: fun(), disabled: boolean?, sound: string?}): LineBuilder
---@field inputNumeric fun(self, data: {id: string, type: "int"|"float", value: number, precision: integer?, step: number?, stepFast: number?, width: integer?, disabled: boolean?, style: number[][]?, onUpdate: fun(value: number)?}): LineBuilder
---@field inputString fun(self, data: {id: string, value: string, placeholder: string?, width: integer?, disabled: boolean?, style: number[][]?, multiline: boolean?, onUpdate: fun(value: string)?, autoheight: boolean?, lines: integer?}): LineBuilder
---@field inputCombo fun(self, data: {id: string, items: string[]|table[], value: string|table?, label: string?, getLabelFn: (fun(item: string|table): string), width: integer?, onChange: fun(item: string|table)?}?): LineBuilder
---@field helpMarker fun(self, text: string): LineBuilder
---@field icon fun(self, data: {icon: string, big: boolean?, border: vec4?, style: vec4[]?, coloredIcon: boolean?}): LineBuilder
---@field btnIcon fun(self, data: {id: string, icon: string, onClick: fun(), big: boolean?, style: vec4[]?, disabled: boolean?, coloredIcon: boolean?, sound: string?}): LineBuilder
---@field btnIconToggle fun(self, data: {id: string, state: boolean, onClick: fun(), icon: string?, big: boolean?, style: vec4[]?, disabled: boolean?, coloredIcon: boolean?, sound: string?}): LineBuilder
---@field colorPicker fun(self, data: {id: string, value: number[]|table<string, number>, onChange: fun(value: number[]), alpha: boolean?, disabled: boolean?}): LineBuilder
---@field slider fun(self, data: {id: string, type: "int"|"float", value: number, min: number, max: number, onUpdate: fun(value: number), precision: number?, width: number?, disabled: boolean?, style: number[][]?, renderFormat: string?}): LineBuilder
---@field build fun(self)

---@param startSameLine? boolean
---@return LineBuilder
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

    builder.text = function(self, text, color)
        text = text or ""
        self:_commonStartElem()
        BJI.Utils.Style.SetStyleColor(BJI.Utils.Style.STYLE_COLS.HEADER, BJI.Utils.Style.RGBA(1, 0, 0, 1))
        color = color and convertColorToVec4(color) or BJI.Utils.Style.TEXT_COLORS.DEFAULT
        im.TextColored(color, tostring(text))
        BJI.Utils.Style.PopStyleColor(1)
        self._elemCount = self._elemCount + 1
        return self
    end
    builder.bgText = function(self, id, text, color, bgColor)
        if not id or not text or not color or not bgColor then
            LogError("bgText requires id, text, color and bgColor", logTag)
            return
        end
        self:_commonStartElem()
        bgColor = bgColor and convertColorToVec4(bgColor)
        color = color and convertColorToVec4(color)
        local size = im.CalcTextSize(tostring(text))
        local scale = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.UI_SCALE)
        size.x = size.x + 4 * scale
        size.y = size.y + 4 * scale

        BJI.Utils.Style.SetStyleColor(BJI.Utils.Style.STYLE_COLS.HEADER, BJI.Utils.Style.RGBA(0, 0, 0, 0))
        BJI.Utils.Style.SetStyleColor(BJI.Utils.Style.STYLE_COLS.CHILD_BG, bgColor)
        im.BeginChild1(id, size)
        im.SetWindowFontScale(scale)
        im.TextColored(color, tostring(text))
        im.EndChild()
        BJI.Utils.Style.PopStyleColor(2)
        self._elemCount = self._elemCount + 1
        return self
    end

    local function btnStylePreset(preset)
        BJI.Utils.Style.SetStyleColor(BJI.Utils.Style.STYLE_COLS.BUTTON, preset[1])
        BJI.Utils.Style.SetStyleColor(BJI.Utils.Style.STYLE_COLS.BUTTON_HOVERED, preset[2])
        BJI.Utils.Style.SetStyleColor(BJI.Utils.Style.STYLE_COLS.BUTTON_ACTIVE, preset[3])
        BJI.Utils.Style.SetStyleColor(BJI.Utils.Style.STYLE_COLS.TEXT_COLOR, preset[4])
    end
    local function resetBtnStyle()
        im.PopStyleColor(4)
    end
    builder.btn = function(self, data)
        if not data or not data.id or not data.label or
            not data.onClick then
            LogError("btn requires id, label and onClick", logTag)
            return self
        end

        if table.includes({ "table", "userdata", "cdata" }, type(data.style)) then
            local status = pcall(function() return data.style[1] end)
            if not status then
                LogError(string.var("({1}) btn.style has invalid type", { data.id }))
                return self
            end
        end

        self:_commonStartElem()
        data.style = data.style and table.clone(data.style) or nil

        if data.disabled == true then
            data.style = table.clone(BJI.Utils.Style.BTN_PRESETS.DISABLED)
        end
        if not data.style then
            data.style = table.clone(BJI.Utils.Style.BTN_PRESETS.INFO)
        end
        if data.active then
            data.style[4] = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT
        elseif not data.style[4] then
            data.style[4] = BJI.Utils.Style.TEXT_COLORS.DEFAULT
        end
        btnStylePreset(data.style)

        if data.sound == BTN_NO_SOUND then
            data.sound = nil
        else
            data.sound = data.sound or BJI.Managers.Sound.SOUNDS.BIGMAP_HOVER
        end

        if im.SmallButton(string.var("{1}##{2}", { data.label, data.id })) and data.disabled ~= true then
            if data.sound then
                BJI.Managers.Sound.play(data.sound)
            end
            data.onClick()
        end
        resetBtnStyle()

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
            data.style = BJI.Utils.Style.BTN_PRESETS.SUCCESS
            data.label = data.labelOn
        else
            data.style = BJI.Utils.Style.BTN_PRESETS.ERROR
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
        local label = BJI.Managers.Lang.get("common.buttons.toggle")
        -- invert state to print in Red when active
        return self:btnSwitch({
            id = data.id,
            labelOn = label,
            labelOff = label,
            state = not data.state,
            disabled = data.disabled,
            onClick = data.onClick,
            sound = data.sound,
        })
    end
    builder.btnSwitchAllowBlocked = function(self, data)
        if not data or not data.id or data.state == nil or not data.onClick then
            LogError("btnSwitchAllowBlocked requires id, state and onClick", logTag)
            return self
        end
        return self:btnSwitch({
            id = data.id,
            labelOn = BJI.Managers.Lang.get("common.buttons.allowed"),
            labelOff = BJI.Managers.Lang.get("common.buttons.blocked"),
            state = data.state,
            disabled = data.disabled,
            onClick = data.onClick,
            sound = data.sound,
        })
    end
    builder.btnSwitchEnabledDisabled = function(self, data)
        if not data or not data.id or data.state == nil or not data.onClick then
            LogError("btnSwitchEnabledDisabled requires id, state and onClick", logTag)
            return self
        end
        return self:btnSwitch({
            id = data.id,
            labelOn = BJI.Managers.Lang.get("common.enabled"),
            labelOff = BJI.Managers.Lang.get("common.disabled"),
            state = data.state,
            disabled = data.disabled,
            onClick = data.onClick,
            sound = data.sound,
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
            labelOn = BJI.Managers.Lang.get("common.buttons.play"),
            labelOff = BJI.Managers.Lang.get("common.buttons.stop"),
            state = not data.state,
            disabled = data.disabled,
            onClick = data.onClick,
            sound = data.sound,
        })
    end
    builder.btnSwitchYesNo = function(self, data)
        if not data or not data.id or data.state == nil or not data.onClick then
            LogError("btnSwitchYesNo requires id, state and onClick", logTag)
            return self
        end
        return self:btnSwitch({
            id = data.id,
            labelOn = BJI.Managers.Lang.get("common.yes"),
            labelOff = BJI.Managers.Lang.get("common.no"),
            state = data.state,
            disabled = data.disabled,
            onClick = data.onClick,
            sound = data.sound,
        })
    end

    local function inputStylePreset(preset, numeric)
        BJI.Utils.Style.SetStyleColor(BJI.Utils.Style.STYLE_COLS.FRAME_BG, preset[1])
        BJI.Utils.Style.SetStyleColor(BJI.Utils.Style.STYLE_COLS.TEXT_COLOR, preset[2])
        if numeric then
            BJI.Utils.Style.SetStyleColor(BJI.Utils.Style.STYLE_COLS.BUTTON, preset[1])
            BJI.Utils.Style.SetStyleColor(BJI.Utils.Style.STYLE_COLS.BUTTON_HOVERED, preset[1])
            BJI.Utils.Style.SetStyleColor(BJI.Utils.Style.STYLE_COLS.BUTTON_ACTIVE, preset[1])
        end
    end
    local function resetInputStyle(numeric)
        im.PopStyleColor(numeric and 5 or 2)
    end
    builder.inputNumeric = function(self, data)
        if not data or not data.id or not data.type or type(data.value) ~= "number" then
            LogError("inputNumeric requires id, type and value", logTag)
            return self
        elseif not table.includes({ "int", "float" }, data.type) then
            LogError("inputNumeric requires type to be 'int' or 'float'", logTag)
            return self
        end

        data.precision = data.precision or 3
        data.step = data.step or 1
        data.stepFast = data.stepFast or data.step

        self:_commonStartElem()

        -- WIDTH
        if data.width then
            im.PushItemWidth(data.width * BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.UI_SCALE))
        else
            im.PushItemWidth(-1)
        end

        -- DISABLED / STYLE
        if data.disabled then
            data.style = {
                BJI.Utils.Style.INPUT_PRESETS.DISABLED[1],
                BJI.Utils.Style.INPUT_PRESETS.DISABLED[2],
            }
        end
        if not data.style then
            data.style = {
                BJI.Utils.Style.INPUT_PRESETS.DEFAULT[1],
                BJI.Utils.Style.INPUT_PRESETS.DEFAULT[2],
            }
        end
        if not data.style[2] then
            data.style[2] = BJI.Utils.Style.TEXT_COLORS.DEFAULT
        end
        inputStylePreset(data.style, true)

        local input = InputInt(math.round(data.value))
        local drawFn = im.InputInt
        if data.type == "float" then
            input = InputFloat(data.value, data.precision)
            drawFn = im.InputFloat
        end

        if drawFn(string.var("##{1}", { data.id }), input._value, data.step, data.stepFast) and
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
        resetInputStyle(true)

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

        local scale = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.UI_SCALE)

        -- WIDTH
        if data.width then
            im.PushItemWidth(data.width * scale)
        else
            im.PushItemWidth(-1)
        end

        -- DISABLED / STYLE
        if data.disabled then
            data.style = {
                BJI.Utils.Style.INPUT_PRESETS.DISABLED[1],
                BJI.Utils.Style.INPUT_PRESETS.DISABLED[2],
            }
        end
        if not data.style then
            data.style = {
                BJI.Utils.Style.INPUT_PRESETS.DEFAULT[1],
                BJI.Utils.Style.INPUT_PRESETS.DEFAULT[2],
            }
        end
        if not data.style[2] then
            data.style[2] = BJI.Utils.Style.TEXT_COLORS.DEFAULT
        end
        inputStylePreset(data.style)

        -- DRAW
        local input = InputString(data.size or 100, data.value)
        if not data.multiline then
            --[[im.InputTextWithHint(
                string.var("##{1}", { data.id }),
                data.placeholder,
                input._value,
                input._size
            )]]
            -- TODO find a placeholder fix
            if data.placeholder and #data.placeholder:trim() > 0 then
                im.ShowHelpMarker(data.placeholder)
                im.SameLine()
            end
            if im.InputText(string.var("##{1}", { data.id }), input._value, input._size) and
                not data.disabled and type(data.onUpdate) == "function" then
                data.onUpdate(input:get())
            end
        else
            local w = -1
            if data.width then
                w = data.width * scale
            end

            local lines = 3
            if data.autoheight then
                local _, count = input:get():gsub("\n", "")
                lines = count + 1
            elseif data.lines then
                lines = data.lines
            end
            local h = (lineHeight * scale * lines) + 2
            if h < 0 then
                h = -1
            end
            im.SetWindowFontScale(scale) -- update scale for multiline inputs
            if im.InputTextMultiline(
                    string.var("##{1}", { data.id }),
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
        resetInputStyle()

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
        local initRequired = data.value == nil
        data.value = data.value or data.items[1]

        local valuePos = 1
        if stringValues then
            valuePos = table.indexOf(data.items, data.value) or valuePos
        else
            for i, v in ipairs(data.items) do
                if data.getLabelFn(v) == data.getLabelFn(data.value) then
                    valuePos = i
                    break
                end
            end
        end
        local input = InputInt(valuePos - 1)

        local parsedValues = table.clone(data.items)
        if not stringValues then
            for i, v in ipairs(parsedValues) do
                parsedValues[i] = data.getLabelFn(v)
            end
        end

        -- WIDTH
        if data.width then
            im.PushItemWidth(data.width * BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.UI_SCALE))
        else
            im.PushItemWidth(-1)
        end

        if im.Combo1(string.var("{1}##{2}", { data.label, data.id }), input._value, im.ArrayCharPtrByTbl(parsedValues)) and
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

        if initRequired then
            data.onChange(data.items[1])
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

        if table.includes({ "table", "userdata", "cdata" }, type(data.style)) then
            local status = pcall(function() return data.style[1] end)
            if not status then
                LogError("icon.style has invalid type")
                return self
            end
        end

        local icon = GetIcon(data.icon)
        if not icon then
            return self
        end

        local size = GetIconSize(data.big)
        local border = data.border or nil

        data.style = data.style and table.clone(data.style) or
            table.clone(BJI.Utils.Style.BTN_PRESETS.TRANSPARENT)
        local iconColor
        if data.coloredIcon then
            iconColor = data.style[1]
        else
            if not data.style[4] then
                data.style[4] = table.clone(BJI.Utils.Style.TEXT_COLORS.DEFAULT)
            end
            iconColor = data.style[4]
        end

        self:_commonStartElem()
        BJI.Managers.Context.GUI.uiIconImage(icon, -- ICON
            im.ImVec2(size, size),                 -- SIZE
            iconColor,                             -- ICON COLOR
            border,                                -- BORDER COLOR
            nil                                    -- LABEL
        )
        self._elemCount = self._elemCount + 1
        return self
    end
    builder.btnIcon = function(self, data)
        if not data.id or not data.icon or type(data.onClick) ~= "function" then
            LogError("btnIcon requires id, icon and onClick", logTag)
            return self
        end

        if table.includes({ "table", "userdata", "cdata" }, type(data.style)) then
            local status = pcall(function() return data.style[1] end)
            if not status then
                LogError(string.var("({1}) btnIcon.style has invalid type", { data.id }))
                return self
            end
        end

        local icon = GetIcon(data.icon)
        if not icon then
            -- error already logged inside GetIcon(str)
            return self
        end
        self:_commonStartElem()
        data.style = data.style and table.clone(data.style) or nil

        local size = GetIconSize(data.big)
        if data.disabled then
            data.style = table.clone(BJI.Utils.Style.BTN_PRESETS.DISABLED)
        end
        data.style = data.style or table.clone(BJI.Utils.Style.BTN_PRESETS.INFO)
        local iconColor
        if data.active then
            iconColor = table.clone(BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT)
        else
            iconColor = data.style[4] and table.clone(data.style[4]) or table.clone(BJI.Utils.Style.TEXT_COLORS.DEFAULT)
        end
        local bgColor = table.clone(data.style[1])
        local hoveredColor = table.clone(data.style[2])
        local activeColor = table.clone(data.style[3])
        if data.coloredIcon then
            iconColor = bgColor
            bgColor = BJI.Utils.Style.BTN_PRESETS.TRANSPARENT[1]
            hoveredColor = BJI.Utils.Style.BTN_PRESETS.TRANSPARENT[2]
            activeColor = BJI.Utils.Style.BTN_PRESETS.TRANSPARENT[3]
        end

        if data.sound == BTN_NO_SOUND then
            data.sound = nil
        else
            data.sound = data.sound or BJI.Managers.Sound.SOUNDS.BIGMAP_HOVER
        end

        BJI.Utils.Style.SetStyleColor(BJI.Utils.Style.STYLE_COLS.BUTTON_HOVERED, hoveredColor)
        BJI.Utils.Style.SetStyleColor(BJI.Utils.Style.STYLE_COLS.BUTTON_ACTIVE, activeColor)
        if BJI.Managers.Context.GUI.uiIconImageButton(icon, -- ICON
                im.ImVec2(size, size),                      -- SIZE
                iconColor,                                  -- ICON COLOR
                nil,                                        -- LABEL
                bgColor,                                    -- ICON BG COLOR
                data.id,                                    -- ID
                nil,                                        -- TEXT COLOR
                nil,                                        -- TEXT BG FLAG
                false,                                      -- ON RELEASE
                nil                                         -- HIGHLIGHT TEXT
            ) and not data.disabled then
            if data.sound then
                BJI.Managers.Sound.play(data.sound)
            end
            data.onClick()
        end
        im.PopStyleColor(2)
        self._elemCount = self._elemCount + 1
        return self
    end
    builder.btnIconToggle = function(self, data)
        if not data.id or data.state == nil or not data.onClick then
            LogError("btnIconToggle requires id, state and onClick", logTag)
            return self
        end

        data.icon = data.icon or (data.state and ICONS.check_circle or ICONS.cancel)
        data.style = data.style or
            (data.state and BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR)

        return self:btnIcon(data)
    end

    builder.colorPicker = function(self, data)
        if not data.id or not data.value or not data.onChange then
            LogError("colorPicker requires id, value and onChange", logTag)
            return self
        end
        self:_commonStartElem()

        local flags = {
            im.ColorEditFlags_NoInputs
        }
        if data.disabled then
            table.insert(flags, im.ColorEditFlags_NoPicker)
        end
        local color = im.ArrayFloat(4)
        if data.value.r then
            color[0] = data.value.r
            color[1] = data.value.g
            color[2] = data.value.b
            color[3] = data.alpha and data.value.a or 1
        elseif data.value[4] then
            color[0] = data.value[1]
            color[1] = data.value[2]
            color[2] = data.value[3]
            color[3] = data.alpha and data.value[4] or 1
        elseif data.value[0] then
            color[3] = color[3] or 1
        end
        local fn = im.ColorEdit3
        if data.alpha then
            fn = im.ColorEdit4
        end
        if fn(string.var("##{1}", { data.id }), color, im.flags(table.unpack(flags))) and not data.disabled then
            data.onChange({
                math.round(color[0], BJI.Utils.Style.RGBA_PRECISION),
                math.round(color[1], BJI.Utils.Style.RGBA_PRECISION),
                math.round(color[2], BJI.Utils.Style.RGBA_PRECISION),
                math.round(color[3], BJI.Utils.Style.RGBA_PRECISION),
            })
        end
        self._elemCount = self._elemCount + 1
        return self
    end

    builder.slider = function(self, data)
        if not data.id or not data.type or not data.value or not data.min or not data.max or not data.onUpdate then
            LogError("slider requires id, type, value, min, max and onChange", logTag)
            return self
        elseif not table.includes({ "int", "float" }, data.type) then
            LogError("slider type must be int or float", logTag)
            return self
        end

        if data.type == "int" then
            data.precision = 0
            data.renderFormat = data.renderFormat or "%d"
        else
            data.precision = data.precision and math.round(math.clamp(data.precision, 0)) or 3
            data.renderFormat = data.renderFormat or string.var("%.{1}f", { data.precision })
        end

        self:_commonStartElem()

        local flags = { im.SliderFlags_AlwaysClamp }
        local scale = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.UI_SCALE)
        -- WIDTH
        if data.width then
            im.PushItemWidth(data.width * scale)
        else
            im.PushItemWidth(-1)
        end

        -- DISABLED / STYLE
        if data.disabled then
            data.style = {
                BJI.Utils.Style.INPUT_PRESETS.DISABLED[1],
                BJI.Utils.Style.INPUT_PRESETS.DISABLED[2],
            }
        end
        if not data.style then
            data.style = {
                BJI.Utils.Style.INPUT_PRESETS.DEFAULT[1],
                BJI.Utils.Style.INPUT_PRESETS.DEFAULT[2],
            }
        end
        if not data.style[2] then
            data.style[2] = BJI.Utils.Style.TEXT_COLORS.DEFAULT
        end
        inputStylePreset(data.style, true)

        local drawFn, val = im.SliderInt, im.IntPtr(data.value)
        if data.type == "float" then
            drawFn = im.SliderFloat
            val = im.FloatPtr(data.value)
        end
        if drawFn("##" .. tostring(data.id), val, data.min, data.max, data.renderFormat, im.flags(table.unpack(flags))) and
            not data.disabled then
            local parsed = math.round(val[0], data.precision)
            if data.parsed ~= math.round(data.value, data.precision) then
                data.onUpdate(parsed)
            end
        end

        -- REMOVE STYLE
        resetInputStyle(true)

        -- REMOVE WIDTH
        im.PopItemWidth()

        self._elemCount = self._elemCount + 1
        return self
    end

    builder.build = function(self)
        -- normalization
    end

    return builder
end

EmptyLine = function()
    LineBuilder():text(" "):build()
end

---@param label string
---@param color? table
---@param startSameLine? boolean
LineLabel = function(label, color, startSameLine)
    LineBuilder(startSameLine):text(label, color):build()
end

---@param data {floatPercent: number, width: number|string?, text: string?}
ProgressBar = function(data)
    data.floatPercent = data.floatPercent or 0
    if tonumber(data.width) then
        data.width = math.floor(tonumber(data) or 0) *
            BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.UI_SCALE)
    elseif tostring(data.width):find("%d+%%") then
        data.width = tonumber(tostring(data.width):match("^%d+")) / 100 * im.GetContentRegionAvail().x
    else
        data.width = -1
    end
    data.width = data.width or -1
    local text = data.text or ""
    local height = #text == 0 and 5 or (im.CalcTextSize(text).y + 2)

    local size = im.ImVec2(data.width, height)

    im.ProgressBar(data.floatPercent, size, text)
end

---@class ColumnsBuilder
---@field addRow fun(self, data: {cells: function[]}): ColumnsBuilder
---@field addSeparator fun(self): ColumnsBuilder
---@field build fun(self)

local COLUMNS_SEPARATOR = "column_separator"

---@param name string unique name
---@param colsWidths integer[]
---@param borders? boolean
---@return ColumnsBuilder
ColumnsBuilder = function(name, colsWidths, borders)
    colsWidths = colsWidths or { -1 }
    local builder = {
        _name = name,
        _cols = #colsWidths,
        _widths = Table(colsWidths):clone(),
        _currentCol = 0,
        _rows = Table(),
        _borders = borders == true,
    }

    builder.addRow = function(self, data)
        self._rows:insert(Table(data.cells):map(function(c)
            return type(c) == "function" and c or EmptyLine
        end))
        return self
    end

    builder.addSeparator = function(self)
        self._rows:insert(COLUMNS_SEPARATOR)
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

        local function initCols()
            im.Columns(self._cols, self._name, self._borders)
            for i, w in ipairs(widths) do
                im.SetColumnWidth(i - 1, w)
            end
        end
        local function resetCols()
            im.Columns(1)
        end

        initCols()
        self._rows:forEach(function(row)
            if row == COLUMNS_SEPARATOR then
                resetCols()
                Separator()
                initCols()
            else
                self._widths:forEach(function(_, i)
                    if type(row[i]) == "function" then
                        row[i]()
                    end
                    im.NextColumn()
                end)
            end
        end)
        resetCols()
    end

    return builder
end
