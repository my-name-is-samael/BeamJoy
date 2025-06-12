local eventName = BJC_EVENTS.PLAYER.EVENT

BJCTx.player = {}

---@param targetID integer
---@param data table
function BJCTx.player.tick(targetID, data)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.PLAYER.TX.SERVER_TICK, targetID, data)
end

---@param targetID integer
---@param type string
---@param msgKey string
---@param msgData table?
---@param delay integer?
function BJCTx.player.toast(targetID, type, msgKey, msgData, delay)
    msgData = msgData or {}
    if targetID == BJCTx.ALL_PLAYERS then
        for playerID, player in pairs(BJCPlayers.Players) do
            local msg = BJCLang.getServerMessage(player.lang, msgKey):var(msgData)
            BJCTx.sendToPlayer(eventName, BJC_EVENTS.PLAYER.TX.TOAST, playerID, { type, msg, tonumber(delay) })
        end
    else
        local player = BJCPlayers.Players[targetID]
        if player then
            local msg = BJCLang.getServerMessage(player.lang, msgKey):var(msgData)
            BJCTx.sendToPlayer(eventName, BJC_EVENTS.PLAYER.TX.TOAST, targetID, { type, msg, tonumber(delay) })
        end
    end
end

---@param targetID integer
---@param msgKey string
---@param msgData table?
---@param delay integer?
function BJCTx.player.flash(targetID, msgKey, msgData, delay)
    msgData = msgData or {}
    if targetID == BJCTx.ALL_PLAYERS then
        for playerID, player in pairs(BJCPlayers.Players) do
            local msg = BJCLang.getServerMessage(player.lang, msgKey):var(msgData)
            BJCTx.sendToPlayer(eventName, BJC_EVENTS.PLAYER.TX.FLASH, playerID, { msg, tonumber(delay) })
        end
    else
        local player = BJCPlayers.Players[targetID]
        if player then
            local msg = BJCLang.getServerMessage(player.lang, msgKey):var(msgData)
            BJCTx.sendToPlayer(eventName, BJC_EVENTS.PLAYER.TX.FLASH, targetID, { msg, tonumber(delay) })
        end
    end
end

-- color is not working for now
---@param targetID integer
---@param event string
---@param data table
function BJCTx.player.chat(targetID, event, data)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.PLAYER.TX.CHAT, targetID, { event, data })
end

---@param targetID integer
---@param senderID integer
function BJCTx.player.teleportToPlayer(targetID, senderID)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.PLAYER.TX.TELEPORT_TO_PLAYER, targetID, senderID)
end

---@param targetID integer
---@param pos BJIPositionRotation
function BJCTx.player.teleportToPos(targetID, pos)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.PLAYER.TX.TELEPORT_TO_POS, targetID, pos)
end

---@param gameVehID integer
function BJCTx.player.explodeVehicle(gameVehID)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.PLAYER.TX.EXPLODE_VEHICLE, BJCTx.ALL_PLAYERS, gameVehID)
end

---@param targetID integer
---@param vid integer
---@param paintIndex integer
---@param paintData NGPaint
function BJCTx.player.syncPaint(targetID, vid, paintIndex, paintData)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.PLAYER.TX.SYNC_PAINT, targetID, { vid, paintIndex, paintData })
end
