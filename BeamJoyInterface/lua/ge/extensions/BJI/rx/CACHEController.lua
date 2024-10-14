local ctrl = {
    tag = "BJICacheController"
}

function ctrl.invalidate(data)
    local cacheType = data[1]
    BJICache.invalidate(cacheType)
end

function ctrl.send(data)
    local cacheType, cacheData, cacheHash = data[1], data[2], data[3]
    BJICache.parseCache(cacheType, cacheData, cacheHash)
end

return ctrl