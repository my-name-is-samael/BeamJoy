local event = BJI_EVENTS.CACHE

BJITx.cache = {}

---@param caches string[]
function BJITx.cache.require(caches)
    BJITx._send(event.EVENT, event.TX.REQUIRE, caches)
end