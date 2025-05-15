---@param TX BJITX
return function(TX)
    local event = BJI.CONSTANTS.EVENTS.VOTEMAP
    local votemap = {
        _name = "votemap"
    }

    function votemap.start(mapName)
        TX._send(event.EVENT, event.TX.START, mapName)
    end

    function votemap.vote()
        TX._send(event.EVENT, event.TX.VOTE)
    end

    function votemap.stop()
        TX._send(event.EVENT, event.TX.STOP)
    end

    return votemap
end
