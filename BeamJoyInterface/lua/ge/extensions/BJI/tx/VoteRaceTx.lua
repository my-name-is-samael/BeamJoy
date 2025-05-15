---@param TX BJITX
return function(TX)
    local event = BJI.CONSTANTS.EVENTS.VOTERACE
    local voterace = {
        _name = "voterace"
    }

    function voterace.start(raceID, isVote, settings)
        TX._send(event.EVENT, event.TX.START, { raceID, isVote, settings })
    end

    function voterace.vote()
        TX._send(event.EVENT, event.TX.VOTE)
    end

    function voterace.stop()
        TX._send(event.EVENT, event.TX.STOP)
    end

    return voterace
end
