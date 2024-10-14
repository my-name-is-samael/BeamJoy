local M = {
    isEvent = false,
    startTime = nil,
    participants = {},
    leaderboard = {},
    speed = 0,
    endTimeout = 0,

    stepSpeed = 0,
    stepCounter = 0,
}

local function getCache()
    return {
        isEvent = M.isEvent,
        startTime = M.startTime,
        participants = M.participants,
        leaderboard = M.leaderboard,
        minSpeed = M.speed,
        eliminationDelay = M.endTimeout,
    }, M.getCacheHash()
end

local function getCacheHash()
    return Hash({
        M.startTime,
        M.participants,
        M.leaderboard,
        M.speed,
    })
end

local function start(participants, isEvent)
    if tlength(participants) < 1 then -- DEBUG
        return
    end
    if isEvent then
        BJCScenario.stopServerScenarii()
    end
    for playerID in pairs(participants) do
        BJCPlayers.Players[playerID].scenario = nil
    end
    M.isEvent = isEvent == true
    M.participants = participants
    M.leaderboard = {}
    M.speed = BJCConfig.Data.Speed.BaseSpeed
    M.endTimeout = BJCConfig.Data.Speed.EndTimeout

    M.stepSpeed = BJCConfig.Data.Speed.StepSpeed
    M.startTime = GetCurrentTime()
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.SPEED)
end

local function checkEnd()
    if tlength(M.participants) == 1 or M.leaderboard[2] then
        for pid in pairs(M.participants) do
            local found = false
            for _, lb in pairs(M.leaderboard) do
                if lb.playerID == pid then
                    found = true
                    break
                end
            end
            if not found then
                M.leaderboard[1] = {
                    playerID = pid,
                    speed = M.speed,
                }
                BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.SPEED)
            end
        end
    end

    if tlength(M.participants) == tlength(M.leaderboard) then
        BJCAsync.delayTask(function()
            for i, lb in ipairs(M.leaderboard) do
                local playerID = lb.playerID
                BJCPlayers.reward(playerID, math.ceil(BJCConfig.Data.Reputation.SpeedReward / i))
            end
            M.stop()
        end, BJCConfig.Data.Speed.EndTimeout, "BJCSpeedEnd")
    end
end

local function fail(playerID, time)
    if M.startTime then
        for i = tlength(M.participants), 1, -1 do
            if M.leaderboard[i] and
                M.leaderboard[i].playerID == playerID then
                return
            elseif not M.leaderboard[i] then
                M.leaderboard[i] = {
                    playerID = playerID,
                    speed = M.speed,
                    time = time,
                }
                break
            end
        end
        local gameVehID = M.participants[playerID]
        if tonumber(gameVehID) then
            BJCTx.player.explodeVehicle(gameVehID)
        end
        checkEnd()
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.SPEED)
    end
end

local function stop()
    BJCAsync.removeTask("BJCSpeedStart")
    BJCAsync.removeTask("BJCSpeedEnd")
    M.startTime = nil
    M.participants = {}
    M.leaderboard = {}
    M.speed = 0
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.SPEED)
end

local function slowTick(ctxt)
    if M.startTime and M.startTime <= GetCurrentTime() and
        tlength(M.participants) > tlength(M.leaderboard) then
        M.stepCounter = M.stepCounter + 1
        if M.stepCounter >= BJCConfig.Data.Speed.StepDelay then
            M.stepCounter = 0
            M.speed = M.speed + M.stepSpeed
            BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.SPEED)
        end
    end
end

local function canSpawnOrEditVehicle(playerID, vehID, vehData)
    return not M.participants[playerID]
end

local function onPlayerDisconnect(targetID)
    if not M.participants[targetID] then
        return
    end

    for i = 1, tlength(M.participants) do
        if M.leaderboard[i] and M.leaderboard[i].playerID == targetID then
            for j = i, tlength(M.participants) do
                if M.leaderboard[j + 1] then
                    M.leaderboard[j] = M.leaderboard[j + 1]
                else
                    M.leaderboard[j] = nil
                end
            end
            break
        end
    end

    if M.participants[targetID] then
        M.participants[targetID] = nil
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.SPEED)
        checkEnd()
    end
end

local function onVehicleDeleted(playerID, vehID)
    if not M.startTime or M.startTime > GetCurrentTime() then
        return
    end

    local eliminated = false
    for i = 1, tlength(M.participants) do
        if M.leaderboard[i] and M.leaderboard[i].playerID == playerID then
            eliminated = true
        end
    end

    if not eliminated and M.participants[playerID] then
        M.participants[playerID] = nil
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.SPEED)
        checkEnd()
    end
end

M.getCache = getCache
M.getCacheHash = getCacheHash

M.start = start
M.fail = fail
M.stop = stop

M.slowTick = slowTick

M.canSpawnVehicle = canSpawnOrEditVehicle
M.canEditVehicle = canSpawnOrEditVehicle

M.onPlayerDisconnect = onPlayerDisconnect

M.postVehicleDeleted = onVehicleDeleted

RegisterBJCManager(M)
return M
