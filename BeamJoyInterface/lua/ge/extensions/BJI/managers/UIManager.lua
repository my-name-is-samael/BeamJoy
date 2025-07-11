---@class BJIManagerUI : BJIManager
local M = {
    _name = "UI",

    callbackDelay = 500,
}

---@param state boolean
---@param callbackFn? fun(ctxt: TickContext)
local function applyLoading(state, callbackFn)
    guihooks.trigger('app:waiting', state)
    if type(callbackFn) == "function" then
        BJI_Async.delayTask(callbackFn, M.callbackDelay, "ApplyUILoading-" .. UUID())
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

M.applyLoading = applyLoading
M.hideGameMenu = hideGameMenu

M.onLoad = function()
    BJI_Events.addListener(BJI_Events.EVENTS.SCENARIO_CHANGED, hideGameMenu, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.NG_UI_LAYOUT_LOADED, onLayoutUpdate, M._name)
end

return M
