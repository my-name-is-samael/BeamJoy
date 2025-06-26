---@param TX BJITX
return function(TX)
    local event = BJI.CONSTANTS.EVENTS.PLAYER
    local player = {
        _name = "player"
    }

    function player.connected()
        TX._send(event.EVENT, event.TX.CONNECTED)
    end

    ---@param gameVehID integer?
    function player.switchVehicle(gameVehID)
        TX._send(event.EVENT, event.TX.SWITCH_VEHICLE, { gameVehID })
    end

    ---@param newLang string
    function player.lang(newLang)
        TX._send(event.EVENT, event.TX.LANG, { newLang })
    end

    ---@param driftScore integer
    function player.drift(driftScore)
        TX._send(event.EVENT, event.TX.DRIFT, { driftScore })
    end

    function player.KmReward()
        TX._send(event.EVENT, event.TX.KM_REWARD)
    end

    ---@param gameVehID integer
    function player.explodeVehicle(gameVehID)
        TX._send(event.EVENT, event.TX.EXPLODE_VEHICLE, { gameVehID })
    end

    ---@param listVehIDs integer[]
    function player.markInvalidVehs(listVehIDs)
        TX._send(event.EVENT, event.TX.MARK_INVALID_VEHS, { listVehIDs })
    end

    ---@param gameVehID integer
    ---@param paintIndex integer
    ---@param paint NGPaint
    function player.syncPaint(gameVehID, paintIndex, paint)
        TX._send(event.EVENT, event.TX.SYNC_PAINT, { gameVehID, paintIndex, paint })
    end

    return player
end
