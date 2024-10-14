local event = BJI_EVENTS.CACHE

BJITx.cache = {}

function BJITx.cache.require(cacheType)
    BJITx._send(event.EVENT, event.TX.REQUIRE, cacheType)
end