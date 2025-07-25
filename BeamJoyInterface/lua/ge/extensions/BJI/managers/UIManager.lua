---@class BJIManagerUI : BJIManager
local M = {
    _name = "UI",

    callbackDelay = 500,
    ---@type fun(ctxt: TickContext)?
    callback = nil,
}

---@param state boolean
---@param callback? fun(ctxt: TickContext)
local function applyLoading(state, callback)
    guihooks.trigger('app:waiting', state)
    if type(callback) == "function" then
        M.callback = callback
    else
        M.callback = nil
    end
end

---@param keepMenuBar? boolean
local function hideGameMenu(keepMenuBar)
    guihooks.trigger('MenuHide', keepMenuBar == true)
end

local function onLayoutUpdate(layoutName)
    BJI_Async.removeTask("BJIPostLayoutUpdate")
    BJI_Async.delayTask(function()
        BJI_Message.postLayoutUpdate()
        BJI_RaceUI.postLayoutUpdate()
    end, 100, "BJIPostLayoutUpdate")
end

---@param ctxt TickContext
local function fastTick(ctxt)
    if type(M.callback) == "function" then
        M.callback(ctxt)
        M.callback = nil
    end
end

M.applyLoading = applyLoading
M.hideGameMenu = hideGameMenu

M.onLoad = function()
    BJI_Events.addListener(BJI_Events.EVENTS.SCENARIO_CHANGED, hideGameMenu, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.NG_UI_LAYOUT_LOADED, onLayoutUpdate, M._name)

    BJI_Events.addListener(BJI_Events.EVENTS.FAST_TICK, fastTick, M._name)
end

return M
