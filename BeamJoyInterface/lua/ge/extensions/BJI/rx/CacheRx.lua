local ctrl = {
    tag = "CacheRx"
}

function ctrl.invalidate(data)
    local cacheType = data[1]
    BJI_Cache.invalidate(cacheType)
end

function ctrl.send(data)
    local cacheType, cacheData, cacheHash = data[1], data[2], data[3]
    BJI_Cache.handleRx(cacheType, cacheData, cacheHash)
end

return ctrl