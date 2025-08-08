local ctrl = {
    tag = "DatabaseRx"
}

local playersGetCallbackFn
---@param callback fun(raceData: table)
function ctrl.playersGetCallback(callback)
    playersGetCallbackFn = callback
end

---@param data table[]
function ctrl.playersGet(data)
    if type(playersGetCallbackFn) == "function" then
        playersGetCallbackFn(data)
    end
    playersGetCallbackFn = nil
end

function ctrl.playersUpdated()
    BJI_Events.trigger(BJI_Events.EVENTS.DATABASE_PLAYERS_UPDATED)
end

return ctrl
