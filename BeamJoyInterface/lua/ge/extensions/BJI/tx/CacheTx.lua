---@param TX BJITX
return function(TX)
    local event = BJI.CONSTANTS.EVENTS.CACHE
    local cache = {
        _name = "cache"
    }

    ---@param caches string[]
    function cache.require(caches)
        TX._send(event.EVENT, event.TX.REQUIRE, caches)
    end

    return cache
end
