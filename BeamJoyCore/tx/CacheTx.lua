local eventName = BJC_EVENTS.CACHE.EVENT

BJCTx.cache = {}

---@param targetID integer
---@param cacheType string
function BJCTx.cache.invalidate(targetID, cacheType)
    local _send = function(playerID)
        local ctxt = table.assign(BJCInitContext(), {
            senderID = playerID,
            sender = BJCPlayers.Players[playerID] or {},
        })
        BJCCache.getCache(ctxt, cacheType)
    end
    if targetID == BJCTx.ALL_PLAYERS then
        for pid in pairs(BJCPlayers.Players) do
            _send(pid)
        end
    else
        _send(targetID)
    end
end

---@param cacheType string
---@param ... string permissions
function BJCTx.cache.invalidateByPermissions(cacheType, ...)
    if #{ ... } == 0 then
        return BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, cacheType)
    end
    for playerID in pairs(BJCPlayers.Players) do
        if table.any({ ... }, function(permissionName)
                return BJCPerm.hasPermission(playerID, permissionName)
            end) then
            BJCTx.cache.invalidate(playerID, cacheType)
        end
    end
end

---@param lang string
function BJCTx.cache.invalidateLang(lang)
    for targetID, target in pairs(BJCPlayers.Players) do
        if target.lang == lang then
            BJCTx.cache.invalidate(targetID, BJCCache.CACHES.LANG)
        end
    end
end

---@param targetID integer
---@param cacheType string
---@param data any
---@param hash string
function BJCTx.cache.send(targetID, cacheType, data, hash)
    BJCTx.sendToPlayer(eventName, BJC_EVENTS.CACHE.TX.SEND, targetID, { cacheType, data, hash })
end

---@param cacheType string
---@param data any
---@param ... string permissions
function BJCTx.cache.sendByPermission(cacheType, data, ...)
    BJCTx.sendByPermissions(eventName, BJC_EVENTS.CACHE.TX.SEND, { cacheType, data }, ...)
end
