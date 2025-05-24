local im = ui_imgui

---@class BJIManagerWindows : BJIManager
local M = {
    _name = "Windows",

    BASE_FLAGS = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_SCROLLBAR,
        BJI.Utils.Style.WINDOW_FLAGS.NO_SCROLL_WITH_MOUSE,
        BJI.Utils.Style.WINDOW_FLAGS.NO_FOCUS_ON_APPEARING,
    },

    loaded = false,
    ---@type tablelib<BJIWindow>
    windows = Table(),
    ---@type tablelib<string, boolean>
    showStates = Table(),
}

--[[local function initWindows()
    -- TAG
    M.register({
        name = "BJITag",
        showConditionFn = function()
            return (BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.TAG_DUO) and
                    BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.TAG_DUO)) or
                (BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.TAG_SERVER) and
                    BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.TAG_SERVER))
        end,
        draw = require("ge/extensions/BJI/ui/WindowTag/DrawWindowTag"),
        w = 300,
        h = 250,
    })
end]]

---@param w BJIWindow
---@return BJIWindow
local function register(w)
    if not w.name or not w.getState or not w.body then
        LogError("Window requires name, getState and body")
        return w
    end
    if M.windows:any(function(w2) return w2.name == w.name end) then
        LogWarn("Window with name " .. w.name .. " already exists, skipping ...")
        return w
    end

    M.windows:insert(w)
    M.showStates[w.name] = false
    BJI.Managers.Context.GUI.registerWindow(w.name, im.ImVec2(w.w or -1, w.h or -1))
    return w
end

---@param ctxt TickContext
local function renderTick(ctxt)
    if not BJI.CLIENT_READY or not BJI.Managers.Cache.areBaseCachesFirstLoaded() or not BJI.Utils.Style.BJIThemeLoaded then
        return
    end

    ---@param w BJIWindow
    ---@param fnName string
    local function windowSubFnCall(w, fnName)
        if M.showStates[w.name] then
            -- apply min height (fixes moved out collapsed size issue)
            local size = im.GetWindowSize()
            local scale = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.UI_SCALE)
            if w.h and size.y < w.h * scale then
                im.SetWindowSize1(im.ImVec2(size.x, math.floor(w.h * scale)), im.Cond_Always)
            end
        end
        if type(w[fnName]) == "function" then
            local _, err = pcall(w[fnName], ctxt)
            if err then
                LogError(string.var("Error executing \"{1}\" on window \"{2}\" : {3}",
                    { fnName, w.name, err }), M._name)
            end
        end
    end

    BJI.Utils.Style.InitDefaultStyles()
    for _, w in pairs(M.windows) do
        if (M.showStates[w.name] and not w.getState()) or
            --not M.loaded or
            not MPGameNetwork.launcherConnected() then
            windowSubFnCall(w, "onUnload")
            M.showStates[w.name] = false
            BJI.Managers.Context.GUI.hideWindow(w.name)
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.WINDOW_VISIBILITY_TOGGLED, {
                name = w.name,
                state = false,
            })
        elseif not M.showStates[w.name] and w.getState() then
            windowSubFnCall(w, "onLoad")
            M.showStates[w.name] = true
            BJI.Managers.Context.GUI.showWindow(w.name)
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.WINDOW_VISIBILITY_TOGGLED, {
                name = w.name,
                state = true,
            })
        end

        local title = w.name and
            BJI.Managers.Lang.get(string.var("windows.{1}", { w.name }), w.name) or
            nil
        if M.showStates[w.name] then
            if w.w and w.h then
                local scale = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.UI_SCALE)
                im.SetNextWindowSize(im.ImVec2(
                    math.floor(w.w * scale),
                    math.floor(w.h * scale)
                ))
            end
            if w.x and w.y then
                im.SetNextWindowPos(im.ImVec2(w.x, w.y))
            end

            local flagsToApply = Table(M.BASE_FLAGS):clone()
                :addAll(w.flags or {}, true)
                :addAll(type(w.menu) == "function" and { BJI.Utils.Style.WINDOW_FLAGS.MENU_BAR } or {}, true)

            BJI.Managers.Context.GUI.setupWindow(w.name)
            local alpha = BJI.Utils.Style.BJIStyles[BJI.Utils.Style.STYLE_COLS.WINDOW_BG] and
                BJI.Utils.Style.BJIStyles[BJI.Utils.Style.STYLE_COLS.WINDOW_BG].w or .5
            local window = WindowBuilder(w.name, im.flags(table.unpack(flagsToApply)))
                :title(title)
                :opacity(alpha)

            if w.menu then
                window = window:menu(function()
                    windowSubFnCall(w, "menu")
                end)
            end

            if w.header then
                window:header(function()
                    windowSubFnCall(w, "header")
                end)
            end

            if w.body then
                window:body(function()
                    windowSubFnCall(w, "body")
                end)
            end

            if w.footer then
                local lines = 1
                if w.footerLines then
                    lines = w.footerLines(ctxt)
                end
                window:footer(function()
                    windowSubFnCall(w, "footer")
                end, lines)
            end

            if w.onClose then
                window:onClose(function()
                    w.onClose(ctxt)
                    BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.MAIN_CANCEL)
                end)
            end
            window:build()
        elseif not title then
            LogError(string.var("Invalid name for window {1}", { w.name }))
        end
    end
    BJI.Utils.Style.ResetStyles()
end

local function onUnload()
    M.windows:filter(function(w) return M.showStates[w.name] end)
        :forEach(function(w)
            if w.onUnload then
                w.onUnload()
            end
            M.showStates[w.name] = nil
            M.windows[w.name] = nil
            BJI.Managers.Context.GUI.hideWindow(w.name)
        end)
    M.loaded = false
end

local function onLoad()
    Table(FS:directoryList("/lua/ge/extensions/BJI/ui/windows"))
        :filter(function(path)
            return path:endswith(".lua")
        end):map(function(el)
        return el:gsub("^/lua/", ""):gsub(".lua$", "")
    end):forEach(function(windowPath)
        local ok, w = pcall(require, windowPath)
        if ok then
            BJI.Windows[w.name] = register(w)
            LogInfo(string.var("BJI.Windows.{1} loaded", { w.name }))
        else
            LogError(string.var("Error loading window \"{1}\" : {2}", { windowPath, w }))
        end
    end)

    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.ON_UNLOAD, onUnload, M._name)

    M.loaded = true
end

M.onLoad = onLoad
M.renderTick = renderTick

return M
