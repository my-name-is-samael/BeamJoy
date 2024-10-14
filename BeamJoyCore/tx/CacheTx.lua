local eventName = BJC_EVENTS.CACHE.EVENT

BJCTx.cache = {}

function BJCTx.cache.invalidate(targetID, cacheType)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.CACHE.TX.INVALIDATE, targetID, cacheType)
end

function BJCTx.cache.invalidateByPermissions(cacheType, ...)
    BJCTx.sendByPermissions(eventName, BJC_EVENTS.CACHE.TX.INVALIDATE, cacheType, ...)
end

function BJCTx.cache.invalidateLang(lang)
    for targetID, target in pairs(BJCPlayers.Players) do
        if target.lang == lang then
            BJCTx.sendToPlayer(eventName, BJC_EVENTS.CACHE.TX.INVALIDATE, targetID, BJCCache.CACHES.LANG)
        end
    end
end

function BJCTx.cache.send(targetID, cacheType, data, hash)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.CACHE.TX.SEND, targetID, { cacheType, data, hash })
end

function BJCTx.cache.sendByPermission(cacheType, data, ...)
    BJCTx.sendByPermissions(eventName, BJC_EVENTS.CACHE.TX.SEND, { cacheType, data }, ...)
end