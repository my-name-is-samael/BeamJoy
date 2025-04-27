local M = {
    _name = "BJIToast",
    TOAST_TYPES = {
        SUCCESS = "success",
        INFO = "info",
        WARNING = "warning",
        ERROR = "error"
    },
}
M.TOAST_TITLES = {
    success = "Success",
    info = "Info",
    warning = "Warning",
    error = "ERROR"
}

local function toast(type, msg, timeoutSec)
    if not table.includes(M.TOAST_TYPES, type) then
        error(string.var("Invalid toast type: {1}", { type }))
        return
    end
    if not timeoutSec then
        timeoutSec = 5
    end
    guihooks.trigger(
        "toastrMsg",
        {
            type = type,
            title = M.TOAST_TITLES[type],
            msg = msg,
            config = {
                timeOut = timeoutSec * 1000
            }
        }
    )
end

M.toast = toast
M.success = function(msg, timeoutSec)
    M.toast(M.TOAST_TYPES.SUCCESS, msg, timeoutSec)
end
M.info = function(msg, timeoutSec)
    M.toast(M.TOAST_TYPES.INFO, msg, timeoutSec)
end
M.warning = function(msg, timeoutSec)
    M.toast(M.TOAST_TYPES.WARNING, msg, timeoutSec)
end
M.error = function(msg, timeoutSec)
    M.toast(M.TOAST_TYPES.ERROR, msg, timeoutSec)
end

RegisterBJIManager(M)
return M
