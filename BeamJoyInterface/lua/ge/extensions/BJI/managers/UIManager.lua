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

M.applyLoading = applyLoading

return M
