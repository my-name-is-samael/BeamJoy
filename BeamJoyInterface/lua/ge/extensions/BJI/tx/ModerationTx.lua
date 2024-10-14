local event = BJI_EVENTS.MODERATION

BJITx.moderation = {}

function BJITx.moderation.mute(playerName, reason)
    BJITx._send(event.EVENT, event.TX.MUTE, { playerName, reason })
end

function BJITx.moderation.freeze(targetID, vehID)
    BJITx._send(event.EVENT, event.TX.FREEZE,  { targetID, vehID })
end

function BJITx.moderation.engine(targetID, vehID)
    BJITx._send(event.EVENT, event.TX.ENGINE, { targetID, vehID })
end

function BJITx.moderation.kick(targetID, reason)
    BJITx._send(event.EVENT, event.TX.KICK, { targetID, reason })
end

function BJITx.moderation.tempban(playerName, duration, reason)
    BJITx._send(event.EVENT, event.TX.TEMPBAN, { playerName, duration, reason })
end

function BJITx.moderation.ban(playerName, reason)
    BJITx._send(event.EVENT, event.TX.BAN, { playerName, reason })
end

function BJITx.moderation.unban(playerName)
    BJITx._send(event.EVENT, event.TX.UNBAN, playerName)
end

function BJITx.moderation.teleportFrom(targetID)
    BJITx._send(event.EVENT, event.TX.TELEPORT_FROM, targetID)
end

function BJITx.moderation.setGroup(playerName, group)
    BJITx._send(event.EVENT, event.TX.SET_GROUP, { playerName, group })
end

function BJITx.moderation.deleteVehicle(targetID, gameVehID)
    BJITx._send(event.EVENT, event.TX.DELETE_VEHICLE, { targetID, gameVehID })
end

function BJITx.moderation.whitelist(playerName)
    BJITx._send(event.EVENT, event.TX.WHITELIST, playerName)
end
