local M = {
    participants = {},
    ---@type BJIPositionRotation?
    target = nil,
}

local function initTarget(pos)
    local targets = {}
    for _, delivery in pairs(BJCScenario.Deliveries) do
        table.insert(targets, {
            target = table.deepcopy(delivery),
            distance = GetHorizontalDistance(pos, delivery.pos),
        })
    end

    table.sort(targets, function(a, b)
        return a.distance > b.distance
    end)
    if #targets > 1 then
        local threhsholdPos = math.ceil(#targets * .66) + 1 -- 66% furthest
        while targets[threhsholdPos] do
            table.remove(targets, threhsholdPos)
        end
    end
    M.target = table.random(targets).target
end

local function join(playerID, gameVehID, pos)
    if #BJCScenario.Deliveries == 0 then
        return
    elseif M.participants[playerID] then
        return
    elseif BJCScenario.isServerScenarioInProgress() then
        return
    end

    local isStarting = false
    if table.length(M.participants) == 0 then
        initTarget(pos)
        isStarting = true
    end

    M.participants[playerID] = {
        gameVehID = gameVehID,
        streak = 0,
        nextTargetReward = isStarting,
        reached = false,
    }
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DELIVERY_MULTI)
end

local function resetted(playerID)
    local playerData = M.participants[playerID]
    if not playerData then
        return
    end

    playerData.nextTargetReward = false
    playerData.streak = 0
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DELIVERY_MULTI)
end

local function checkNextTarget()
    if table.length(M.participants) == 0 then
        return
    end
    for _, playerData in pairs(M.participants) do
        if not playerData.reached then
            return
        end
    end

    -- all participants reached target
    initTarget(M.target.pos)
    for playerID, playerData in pairs(M.participants) do
        playerData.reached = false
        if playerData.nextTargetReward then
            local reward = BJCConfig.Data.Reputation.DeliveryPackageReward +
                playerData.streak * BJCConfig.Data.Reputation.DeliveryPackageStreakReward
            local player = BJCPlayers.Players[playerID]
            player.stats.delivery = player.stats.delivery + 1
            BJCPlayers.reward(playerID, reward)
            playerData.streak = playerData.streak + 1
        end
        playerData.nextTargetReward = true
    end
end

local function reached(playerID)
    if not M.participants[playerID] then
        return
    end

    M.participants[playerID].reached = true
    checkNextTarget()
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DELIVERY_MULTI)
end

local function checkEnd()
    if table.length(M.participants) == 0 then
        M.target = nil
    end
end

local function leave(playerID)
    if not M.participants[playerID] then
        return
    end

    M.participants[playerID] = nil
    checkEnd()
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DELIVERY_MULTI)
end

local function onPlayerDisconnect(playerID)
    if M.participants[playerID] then
        M.participants[playerID] = nil
        checkEnd()
        if table.length(M.participants) > 0 then
            checkNextTarget()
        end
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DELIVERY_MULTI)
    end
end

local function stop()
    if table.length(M.participants) > 0 then
        M.participants = {}
        M.target = nil
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DELIVERY_MULTI)
    end
end

local function getCache()
    return {
        participants = M.participants,
        target = M.target,
    }, M.getCacheHash()
end

local function getCacheHash()
    return Hash({
        M.participants,
        M.target,
    })
end

M.join = join
M.resetted = resetted
M.reached = reached
M.leave = leave

BJCEvents.addListener(BJCEvents.EVENTS.PLAYER_DISCONNECT, onPlayerDisconnect)

M.stop = stop

M.getCache = getCache
M.getCacheHash = getCacheHash

return M
