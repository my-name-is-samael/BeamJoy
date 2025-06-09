---@param TX BJITX
return function(TX)
    local event = BJI.CONSTANTS.EVENTS.TOURNAMENT
    local tournament = {
        _name = "tournament"
    }

    function tournament.clear()
        TX._send(event.EVENT, event.TX.CLEAR)
    end

    ---@param state boolean
    function tournament.toggle(state)
        TX._send(event.EVENT, event.TX.TOGGLE, { state })
    end

    function tournament.endTournament()
        TX._send(event.EVENT, event.TX.END_TOURNAMENT)
    end

    ---@param state boolean
    function tournament.toggleWhitelist(state)
        TX._send(event.EVENT, event.TX.TOGGLE_WHITELIST, { state })
    end

    ---@param playerName string
    ---@param state boolean
    function tournament.togglePlayer(playerName, state)
        TX._send(event.EVENT, event.TX.TOGGLE_PLAYER, { playerName, state })
    end

    ---@param activityIndex integer
    function tournament.removeActivity(activityIndex)
        TX._send(event.EVENT, event.TX.REMOVE_ACTIVITY, { activityIndex })
    end

    ---@param playerName string
    ---@param activityIndex integer
    ---@param score? integer
    function tournament.editScore(playerName, activityIndex, score)
        TX._send(event.EVENT, event.TX.EDIT_SCORE, { playerName, activityIndex, score })
    end

    ---@param playerName string
    function tournament.removePlayer(playerName)
        TX._send(event.EVENT, event.TX.REMOVE_PLAYER, { playerName })
    end

    ---@param raceID integer
    ---@param timeoutMin integer
    function tournament.addSoloRace(raceID, timeoutMin)
        TX._send(event.EVENT, event.TX.ADD_SOLO_RACE, { raceID, timeoutMin })
    end

    function tournament.endSoloRace()
        TX._send(event.EVENT, event.TX.END_SOLO_RACE)
    end


    return tournament
end