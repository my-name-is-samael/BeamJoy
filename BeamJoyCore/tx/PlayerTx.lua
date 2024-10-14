local eventName = BJC_EVENTS.PLAYER.EVENT

BJCTx.player = {}

function BJCTx.player.tick(targetID, data)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.PLAYER.TX.SERVER_TICK, targetID, data)
end

function BJCTx.player.toast(targetID, type, msgKey, msgData, delay)
    msgData = msgData or {}
    if targetID == BJCTx.ALL_PLAYERS then
        for playerID, player in pairs(BJCPlayers.Players) do
            local msg = svar(BJCLang.getServerMessage(player.lang, msgKey), msgData)
            BJCTx.sendToPlayer(eventName, BJC_EVENTS.PLAYER.TX.TOAST, playerID, { type, msg, tonumber(delay) })
        end
    else
        local player = BJCPlayers.Players[targetID]
        local msg = svar(BJCLang.getServerMessage(player.lang, msgKey), msgData)
        BJCTx.sendToPlayer(eventName, BJC_EVENTS.PLAYER.TX.TOAST, targetID, { type, msg, tonumber(delay) })
    end
end

function BJCTx.player.flash(targetID, msgKey, msgData, delay)
    msgData = msgData or {}
    if targetID == BJCTx.ALL_PLAYERS then
        for playerID, player in pairs(BJCPlayers.Players) do
            local msg = svar(BJCLang.getServerMessage(player.lang, msgKey), msgData)
            BJCTx.sendToPlayer(eventName, BJC_EVENTS.PLAYER.TX.FLASH, playerID, { msg, tonumber(delay) })
        end
    else
        local player = BJCPlayers.Players[targetID]
        local msg = svar(BJCLang.getServerMessage(player.lang, msgKey), msgData)
        BJCTx.sendToPlayer(eventName, BJC_EVENTS.PLAYER.TX.FLASH, targetID, { msg, tonumber(delay) })
    end
end

-- color is not working for now
function BJCTx.player.chat(targetID, event, data)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.PLAYER.TX.CHAT, targetID, { event, data })
end

function BJCTx.player.teleportToPlayer(targetID, senderID)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.PLAYER.TX.TELEPORT_TO_PLAYER, targetID, senderID)
end

function BJCTx.player.teleportToPos(targetID, pos)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.PLAYER.TX.TELEPORT_TO_POS, targetID, pos)
end

function BJCTx.player.explodeVehicle(gameVehID)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.PLAYER.TX.EXPLODE_VEHICLE, BJCTx.ALL_PLAYERS, gameVehID)
end
