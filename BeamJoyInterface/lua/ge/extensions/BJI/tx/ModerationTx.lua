---@param TX BJITX
return function(TX)
    local event = BJI.CONSTANTS.EVENTS.MODERATION
    local moderation = {
        _name = "moderation"
    }

    function moderation.mute(playerName, reason)
        TX._send(event.EVENT, event.TX.MUTE, { playerName, reason })
    end

    function moderation.freeze(targetID, vehID)
        TX._send(event.EVENT, event.TX.FREEZE, { targetID, vehID })
    end

    function moderation.engine(targetID, vehID)
        TX._send(event.EVENT, event.TX.ENGINE, { targetID, vehID })
    end

    function moderation.kick(targetID, reason)
        TX._send(event.EVENT, event.TX.KICK, { targetID, reason })
    end

    function moderation.tempban(playerName, duration, reason)
        TX._send(event.EVENT, event.TX.TEMPBAN, { playerName, duration, reason })
    end

    function moderation.ban(playerName, reason)
        TX._send(event.EVENT, event.TX.BAN, { playerName, reason })
    end

    function moderation.unban(playerName)
        TX._send(event.EVENT, event.TX.UNBAN, playerName)
    end

    function moderation.teleportFrom(targetID)
        TX._send(event.EVENT, event.TX.TELEPORT_FROM, targetID)
    end

    function moderation.setGroup(playerName, group)
        TX._send(event.EVENT, event.TX.SET_GROUP, { playerName, group })
    end

    function moderation.deleteVehicle(targetID, gameVehID)
        TX._send(event.EVENT, event.TX.DELETE_VEHICLE, { targetID, gameVehID })
    end

    function moderation.whitelist(playerName)
        TX._send(event.EVENT, event.TX.WHITELIST, playerName)
    end

    return moderation
end
