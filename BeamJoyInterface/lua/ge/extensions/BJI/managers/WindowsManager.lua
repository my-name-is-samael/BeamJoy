---@class BJIManagerWindows : BJIManager
local M = {
    _name = "Windows",

    BASE_FLAGS = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_SCROLLBAR,
        BJI.Utils.Style.WINDOW_FLAGS.NO_SCROLL_WITH_MOUSE,
        BJI.Utils.Style.WINDOW_FLAGS.NO_FOCUS_ON_APPEARING,
    },

    ---@type tablelib<BJIWindow>
    windows = Table(),
    ---@type tablelib<string, boolean>
    showStates = Table(),
}
-- gc prevention
local val1, val2

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

    BJI.Managers.Context.GUI.registerWindow(w.name, w.size or w.minSize)
    return w
end

---@param ctxt TickContext
---@param w BJIWindow
---@param fnName string
local function windowSubFnCall(ctxt, w, fnName)
    if type(w[fnName]) == "function" then
        val1, val2 = pcall(w[fnName], ctxt)
        if not val1 then
            LogError(string.var("Error executing \"{1}\" on window \"{2}\" : {3}",
                { fnName, w.name, val2 }), M._name)
        end
    end
end

--- gc prevention
local state

---@param ctxt TickContext
local function renderTick(ctxt)
    if not BJI.CLIENT_READY or not BJI.Managers.Cache.areBaseCachesFirstLoaded() or
        not BJI.Utils.Style.BJIThemeLoaded then
        return
    end

    BJI.Utils.Style.InitDefaultStyles()
    for _, w in pairs(M.windows) do
        if BJI.Bench.STATE == 2 then
            BJI.Bench.startGC()
        end
        state = extensions.ui_visibility.getImgui() and w.getState()
        if (M.showStates[w.name] and not state) or not MPGameNetwork.launcherConnected() then
            windowSubFnCall(ctxt, w, "onUnload")
            M.showStates[w.name] = false
            BJI.Managers.Context.GUI.hideWindow(w.name)
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.WINDOW_VISIBILITY_TOGGLED, {
                name = w.name,
                state = false,
            })
        elseif not M.showStates[w.name] and state then
            windowSubFnCall(ctxt, w, "onLoad")
            M.showStates[w.name] = true
            BJI.Managers.Context.GUI.showWindow(w.name)
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.WINDOW_VISIBILITY_TOGGLED, {
                name = w.name,
                state = true,
            })
        end

        val1 = w.name and BJI.Managers.Lang.get(string.var("windows.{1}", { w.name }), w.name) or nil
        if not val1 then
            LogError(string.var("Invalid name for window {1}", { w.name }))
        elseif M.showStates[w.name] then
            RenderWindow(ctxt, val1, w)
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
end

local function onLoad()
    Table(FS:directoryList("/lua/ge/extensions/BJI/ui/windows"))
        :filter(function(path)
            return path:endswith(".lua")
        end):map(function(el)
        return el:gsub("^/lua/", ""):gsub(".lua$", "")
    end):forEach(function(windowPath)
        val1, val2 = pcall(require, windowPath)
        if val1 then
            BJI.Windows[val2.name] = register(val2)
            LogInfo(string.var("BJI.Windows.{1} loaded", { val2.name }))
        else
            LogError(string.var("Error loading window \"{1}\" : {2}", { windowPath, val2 }))
        end
    end)

    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.ON_UNLOAD, onUnload, M._name)
end

M.onLoad = onLoad
M.renderTick = renderTick

return M
