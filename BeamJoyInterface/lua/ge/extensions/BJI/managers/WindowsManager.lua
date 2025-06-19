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
-- gc prevention
local size, scale, ok, err, title, flagsToApply, alpha, window, lines

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
---@param w BJIWindow
---@param fnName string
local function windowSubFnCall(ctxt, w, fnName)
    if M.showStates[w.name] then
        -- apply min height (fixes moved out collapsed size issue)
        size = im.GetWindowSize()
        scale = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.UI_SCALE)
        if w.h and size.y < w.h * scale then
            im.SetWindowSize1(im.ImVec2(size.x, math.floor(w.h * scale)), im.Cond_Always)
        end
    end
    if type(w[fnName]) == "function" then
        ok, err = pcall(w[fnName], ctxt)
        if not ok then
            LogError(string.var("Error executing \"{1}\" on window \"{2}\" : {3}",
                { fnName, w.name, err }), M._name)
        end
    end
end

---@param ctxt TickContext
local function renderTick(ctxt)
    if not BJI.CLIENT_READY or not BJI.Managers.Cache.areBaseCachesFirstLoaded() or not BJI.Utils.Style.BJIThemeLoaded then
        return
    end

    BJI.Utils.Style.InitDefaultStyles()
    for _, w in pairs(M.windows) do
        if BJI.Bench.STATE == 2 then
            BJI.Bench.startGC()
        end
        if (M.showStates[w.name] and not w.getState()) or
            --not M.loaded or
            not MPGameNetwork.launcherConnected() then
            windowSubFnCall(ctxt, w, "onUnload")
            M.showStates[w.name] = false
            BJI.Managers.Context.GUI.hideWindow(w.name)
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.WINDOW_VISIBILITY_TOGGLED, {
                name = w.name,
                state = false,
            })
        elseif not M.showStates[w.name] and w.getState() then
            windowSubFnCall(ctxt, w, "onLoad")
            M.showStates[w.name] = true
            BJI.Managers.Context.GUI.showWindow(w.name)
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.WINDOW_VISIBILITY_TOGGLED, {
                name = w.name,
                state = true,
            })
        end

        title = w.name and
            BJI.Managers.Lang.get(string.var("windows.{1}", { w.name }), w.name) or
            nil
        if M.showStates[w.name] then
            if w.w and w.h then
                scale = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.UI_SCALE)
                im.SetNextWindowSize(im.ImVec2(
                    math.floor(w.w * scale),
                    math.floor(w.h * scale)
                ))
            end
            if w.x and w.y then
                im.SetNextWindowPos(im.ImVec2(w.x, w.y))
            end

            flagsToApply = Table(M.BASE_FLAGS):clone()
                :addAll(w.flags or {}, true)
                :addAll(type(w.menu) == "function" and { BJI.Utils.Style.WINDOW_FLAGS.MENU_BAR } or {}, true)

            BJI.Managers.Context.GUI.setupWindow(w.name)
            alpha = BJI.Utils.Style.BJIStyles[BJI.Utils.Style.STYLE_COLS.WINDOW_BG] and
                BJI.Utils.Style.BJIStyles[BJI.Utils.Style.STYLE_COLS.WINDOW_BG].w or .5
            window = WindowBuilder(w.name, im.flags(table.unpack(flagsToApply)))
                :title(title)
                :opacity(alpha)

            Table({ "menu", "header", "body" }):forEach(function(part)
                if w[part] then
                    window[part](window, function()
                        windowSubFnCall(ctxt, w, part)
                    end)
                end
            end)

            if w.footer then
                lines = 1
                if w.footerLines then
                    lines = w.footerLines(ctxt)
                end
                window:footer(function()
                    windowSubFnCall(ctxt, w, "footer")
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
        if BJI.Bench.STATE == 2 then
            BJI.Bench.saveGC(w.name)
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
