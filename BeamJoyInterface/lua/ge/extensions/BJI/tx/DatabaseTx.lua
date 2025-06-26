---@param TX BJITX
return function(TX)
    local event = BJI.CONSTANTS.EVENTS.DATABASE
    local database = {
        _name = "database"
    }

    ---@param callback fun(players: table)
    function database.playersGet(callback)
        BJI.Rx.ctrls.DATABASE.playersGetCallback(callback)
        TX._send(event.EVENT, event.TX.PLAYERS_GET)
    end

    function database.vehicle(modelName, state)
        TX._send(event.EVENT, event.TX.VEHICLE, { modelName, state })
    end

    return database
end
