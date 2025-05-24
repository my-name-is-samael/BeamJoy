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
        BJI.Managers.Async.delayTask(callbackFn, M.callbackDelay)
    end
end

---@param keepMenuBar? boolean
local function hideGameMenu(keepMenuBar)
    guihooks.trigger('MenuHide', keepMenuBar == true)
end

M.applyLoading = applyLoading
M.hideGameMenu = hideGameMenu

M.onLoad = function()
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.SCENARIO_CHANGED, hideGameMenu, M._name)
end

return M
