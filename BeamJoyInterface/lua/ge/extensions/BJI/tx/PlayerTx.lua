local event = BJI_EVENTS.PLAYER

BJITx.player = {}

function BJITx.player.connected()
    BJITx._send(event.EVENT, event.TX.CONNECTED)
end

function BJITx.player.settings(key, value)
    BJITx._send(event.EVENT, event.TX.SETTINGS, { key, value })
end

function BJITx.player.switchVehicle(gameVehID)
    BJITx._send(event.EVENT, event.TX.SWITCH_VEHICLE, { gameVehID })
end

function BJITx.player.lang(newLang)
    BJITx._send(event.EVENT, event.TX.LANG, { newLang })
end

function BJITx.player.drift(driftScore)
    BJITx._send(event.EVENT, event.TX.DRIFT, { driftScore })
end

function BJITx.player.KmReward()
    BJITx._send(event.EVENT, event.TX.KM_REWARD)
end

function BJITx.player.explodeVehicle(gameVehID)
    BJITx._send(event.EVENT, event.TX.EXPLODE_VEHICLE, { gameVehID })
end

function BJITx.player.UpdateAI(listGameVehID)
    BJITx._send(event.EVENT, event.TX.UPDATE_AI, { listGameVehID })
end
