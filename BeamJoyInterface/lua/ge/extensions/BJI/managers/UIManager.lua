local M = {
    _name = "BJIUI",
    callbackDelay = 500,
}

local function applyLoading(state, callbackFn)
    guihooks.trigger('app:waiting', state)
    if type(callbackFn) == "function" then
        BJIAsync.delayTask(callbackFn, M.callbackDelay)
    end
end

M.applyLoading = applyLoading

RegisterBJIManager(M)
return M
