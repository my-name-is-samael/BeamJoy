---@param TX BJITX
return function(TX)
    local event = BJI.CONSTANTS.EVENTS.PLAYER
    local player = {
        _name = "player"
    }

    function player.connected()
        TX._send(event.EVENT, event.TX.CONNECTED)
    end

    function player.switchVehicle(gameVehID)
        TX._send(event.EVENT, event.TX.SWITCH_VEHICLE, { gameVehID })
    end

    function player.lang(newLang)
        TX._send(event.EVENT, event.TX.LANG, { newLang })
    end

    function player.drift(driftScore)
        TX._send(event.EVENT, event.TX.DRIFT, { driftScore })
    end

    function player.KmReward()
        TX._send(event.EVENT, event.TX.KM_REWARD)
    end

    function player.explodeVehicle(gameVehID)
        TX._send(event.EVENT, event.TX.EXPLODE_VEHICLE, { gameVehID })
    end

    function player.UpdateAI(listGameVehID)
        TX._send(event.EVENT, event.TX.UPDATE_AI, { listGameVehID })
    end

    return player
end
