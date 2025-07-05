---@param TX BJITX
return function(TX)
    local event = BJI.CONSTANTS.EVENTS.VOTE
    local vote = {
        _name = "vote"
    }

    ---@param targetID integer
    function vote.KickStart(targetID)
        TX._send(event.EVENT, event.TX.KICK_START, targetID)
    end

    function vote.KickVote()
        TX._send(event.EVENT, event.TX.KICK_VOTE)
    end

    function vote.KickStop()
        TX._send(event.EVENT, event.TX.KICK_STOP)
    end

    ---@param mapName string
    function vote.MapStart(mapName)
        TX._send(event.EVENT, event.TX.MAP_START, mapName)
    end

    function vote.MapVote()
        TX._send(event.EVENT, event.TX.MAP_VOTE)
    end

    function vote.MapStop()
        TX._send(event.EVENT, event.TX.MAP_STOP)
    end

    ---@param raceID integer
    ---@param isVote boolean
    ---@param settings table
    function vote.RaceStart(raceID, isVote, settings)
        TX._send(event.EVENT, event.TX.RACE_START, { raceID, isVote, settings })
    end

    function vote.RaceVote()
        TX._send(event.EVENT, event.TX.RACE_VOTE)
    end

    function vote.RaceStop()
        TX._send(event.EVENT, event.TX.RACE_STOP)
    end

    ---@param isVote boolean
    function vote.SpeedStart(isVote)
        TX._send(event.EVENT, event.TX.SPEED_START, { isVote })
    end

    ---@param gameVehID integer?
    function vote.SpeedVote(gameVehID)
        TX._send(event.EVENT, event.TX.SPEED_VOTE, { gameVehID })
    end

    function vote.SpeedStop()
        TX._send(event.EVENT, event.TX.SPEED_STOP)
    end

    return vote
end
