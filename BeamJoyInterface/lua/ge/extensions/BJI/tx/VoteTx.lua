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

    ---@param scenario string
    ---@param isVote boolean
    ---@param data any
    function vote.ScenarioStart(scenario, isVote, data)
        if not table.includes(BJI_Votes.SCENARIO_TYPES, scenario) then
            LogError("Invalid scenario type " .. scenario)
            return
        end
        TX._send(event.EVENT, event.TX.SCENARIO_START, { scenario, isVote, data })
    end

    ---@param data any
    function vote.ScenarioVote(data)
        TX._send(event.EVENT, event.TX.SCENARIO_VOTE, {data})
    end

    function vote.ScenarioStop()
        TX._send(event.EVENT, event.TX.SCENARIO_STOP)
    end

    return vote
end
