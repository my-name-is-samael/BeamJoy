---@class BJCScenarioDeliveryMulti: BJCScenarioHybrid
local M = {
    name = "DeliveryMulti",

    participants = Table(),
    ---@type BJIPositionRotation?
    target = nil,
}

local function initTarget(pos)
    M.target = Table(BJCScenarioData.Deliveries):map(function(delivery)
        return {
            target = table.deepcopy(delivery),
            distance = math.horizontalDistance(pos, delivery.pos),
        }
    end):sort(function(a, b)
        return a.distance > b.distance
    end):values():filter(function(_, i)
        return i < math.round(Table(BJCScenarioData.Deliveries):length() * .66) + 1 -- keep only 66% furthest
    end):random().target
end

local function join(playerID, gameVehID, pos)
    if #BJCScenarioData.Deliveries == 0 then
        return
    elseif M.participants[playerID] then
        return
    elseif BJCScenario.isServerScenarioInProgress() then
        return
    end

    local isStarting = false
    if M.participants:length() == 0 then
        initTarget(pos)
        isStarting = true
    end

    M.participants[playerID] = {
        gameVehID = gameVehID,
        streak = 0,
        nextTargetReward = isStarting,
        reached = false,
    }
    BJCChat.sendChatEvent("chat.events.gamemodeJoin", {
        playerName = BJCPlayers.Players[playerID].playerName,
        gamemode = "chat.events.gamemodes.delivery",
    })
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
    if M.participants:length() == 0 then
        return
    end
    if not M.participants:every(function(p) return p.reached end) then
        return
    end

    -- all participants reached target
    initTarget(M.target.pos)
    M.participants:forEach(function(playerData, playerID)
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
    end)
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
    if M.participants:length() == 0 then
        M.target = nil
    end
end

local function leave(playerID)
    if not M.participants[playerID] then
        return
    end

    M.participants[playerID] = nil
    checkEnd()
    BJCChat.sendChatEvent("chat.events.gamemodeLeave", {
        playerName = BJCPlayers.Players[playerID].playerName,
        gamemode = "chat.events.gamemodes.delivery",
    })
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DELIVERY_MULTI)
end

---@param player BJCPlayer
---@return boolean
local function isParticipant(player)
    return M.participants[player.playerID] ~= nil
end

---@param player BJCPlayer
local function onPlayerDisconnect(player)
    if M.participants[player.playerID] then
        M.participants[player.playerID] = nil
        checkEnd()
        if M.participants:length() > 0 then
            checkNextTarget()
        end
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DELIVERY_MULTI)
    end
end

local function stop()
    if M.participants:length() > 0 then
        M.participants = Table()
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

M.isParticipant = isParticipant
M.onPlayerDisconnect = onPlayerDisconnect

M.stop = stop

M.getCache = getCache
M.getCacheHash = getCacheHash

return M
