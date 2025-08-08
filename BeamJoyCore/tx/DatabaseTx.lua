local eventName = BJC_EVENTS.DATABASE.EVENT

BJCTx.database = {}

function BJCTx.database.playersGet(targetID, databasePlayers)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.DATABASE.TX.PLAYERS_GET, targetID, databasePlayers)
end

function BJCTx.database.playersUpdated()
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.DATABASE.TX.PLAYERS_UPDATED, BJCTx.ALL_PLAYERS)
end