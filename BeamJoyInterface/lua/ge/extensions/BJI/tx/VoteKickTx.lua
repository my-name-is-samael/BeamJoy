---@param TX BJITX
return function(TX)
    local event = BJI.CONSTANTS.EVENTS.VOTEKICK
    local votekick = {
        _name = "votekick"
    }

    function votekick.start(targetID)
        TX._send(event.EVENT, event.TX.START, targetID)
    end

    function votekick.vote()
        TX._send(event.EVENT, event.TX.VOTE)
    end

    function votekick.stop()
        TX._send(event.EVENT, event.TX.STOP)
    end

    return votekick
end
