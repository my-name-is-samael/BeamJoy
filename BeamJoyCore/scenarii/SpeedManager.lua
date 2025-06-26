---@class BJCScenarioSpeed: BJCScenario
local M = {
    name = "Speed",

    MINIMUM_PARTICIPANTS = function()
        if BJCCore.Data.Debug then
            return 1
        end
        return 2
    end,
    isEvent = false,
    startTime = nil,
    ---@type tablelib<integer, integer> index playerIDs, value gameVehID
    participants = Table(),
    ---@type tablelib<integer, {playerID: integer, speed: integer?, time: integer?}>
    leaderboard = Table(),
    speed = 0,
    endTimeout = 0,

    stepSpeed = 0,
    stepCounter = 0,
}

local function getCache()
    return {
        minimumParticipants = M.MINIMUM_PARTICIPANTS(),
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
        M.MINIMUM_PARTICIPANTS(),
        M.startTime,
        M.participants,
        M.leaderboard,
        M.speed,
    })
end

local function updateTournamentScores()
    if BJCTournament.state then
        local activityIndex = #BJCTournament.activities
        local firsts = M.participants:keys():filter(function(pid)
            return not M.leaderboard:any(function(lb, i) return i > 1 and lb.playerID == pid end)
        end)
        local nexts = Range(1, #M.leaderboard):map(function(i)
            return (i > 1 and M.leaderboard[i]) and M.leaderboard[i].playerID or nil
        end)
        local pos = 1
        firsts:forEach(function(pid)
            local player = BJCPlayers.Players[pid]
            if player then
                BJCTournament.editPlayerScore(player.playerName, activityIndex, pos)
            end
        end)
        pos = 2
        nexts:forEach(function(pid)
            local player = BJCPlayers.Players[pid]
            if player then
                BJCTournament.editPlayerScore(player.playerName, activityIndex, pos)
            end
            pos = pos + 1
        end)
    end
end

local function start(participants, isEvent)
    if table.length(participants) < M.MINIMUM_PARTICIPANTS() then
        return
    end
    if isEvent then
        BJCScenario.stopServerScenarii()
    end
    for playerID in pairs(participants) do
        BJCPlayers.Players[playerID].scenario = nil
    end
    M.isEvent = isEvent == true
    M.participants = Table(participants)
    M.leaderboard = Table()
    M.speed = BJCConfig.Data.Speed.BaseSpeed
    M.endTimeout = BJCConfig.Data.Speed.EndTimeout

    M.stepSpeed = BJCConfig.Data.Speed.StepSpeed
    M.startTime = GetCurrentTime()

    BJCScenario.CurrentScenario = M
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.SPEED)

    if BJCTournament.state then
        BJCTournament.addActivity(BJCTournament.ACTIVITIES_TYPES.SPEED)
        updateTournamentScores()
    end
end

local function checkEnd()
    if M.participants:length() == 1 or M.leaderboard[2] then
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
                BJCChat.sendChatEvent("chat.events.gamemodeFinished", {
                    playerName = BJCPlayers.Players[pid].playerName,
                    gamemode = "chat.events.gamemodes.speed",
                    gamemodePosition = 1,
                })
                BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.SPEED)
            end
        end
    end

    if M.participants:length() == M.leaderboard:length() then
        BJCAsync.delayTask(function()
            for i, lb in ipairs(M.leaderboard) do
                local playerID = lb.playerID
                BJCPlayers.reward(playerID, math.ceil(BJCConfig.Data.Reputation.SpeedReward / i))
            end
            M.stop(true)
        end, BJCConfig.Data.Speed.EndTimeout, "BJCSpeedEnd")
    end
end

local function onPlayerFail(playerID, time)
    if M.startTime then
        local position = -1
        for i = M.participants:length(), 1, -1 do
            if M.leaderboard[i] and
                M.leaderboard[i].playerID == playerID then
                return
            elseif not M.leaderboard[i] then
                position = i
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
        BJCChat.sendChatEvent("chat.events.gamemodeFinished", {
            playerName = BJCPlayers.Players[playerID].playerName,
            gamemode = "chat.events.gamemodes.speed",
            gamemodePosition = position,
        })
        checkEnd()
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.SPEED)

        updateTournamentScores()
    end
end

local function stop(ended)
    if M.participants:length() > 0 then
        BJCChat.sendChatEvent(ended and "chat.events.gamemodeEnded" or "chat.events.gamemodeStopped", {
            gamemode = "chat.events.gamemodes.speed",
            reason = not ended and "chat.events.gamemodeStopReasons.manual" or nil,
        })
    end
    BJCAsync.removeTask("BJCSpeedStart")
    BJCAsync.removeTask("BJCSpeedEnd")
    M.startTime = nil
    M.participants = Table()
    M.leaderboard = Table()
    M.speed = 0

    BJCScenario.CurrentScenario = nil
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.SPEED)
end

---@param time integer
local function slowTick(time)
    if M.startTime and M.startTime <= time and
        M.participants:length() > table.length(M.leaderboard) then
        M.stepCounter = M.stepCounter + 1
        if M.stepCounter >= BJCConfig.Data.Speed.StepDelay then
            M.stepCounter = 0
            M.speed = M.speed + M.stepSpeed
            BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.SPEED)
        end
    end
end

---@param playerID integer
---@param vehID integer
---@param vehData ServerVehicleConfig
local function canSpawnOrEditVehicle(playerID, vehID, vehData)
    return not M.participants[playerID]
end

---@param player BJCPlayer
local function onPlayerDisconnect(player)
    if not M.participants[player.playerID] then
        return
    end

    for i = 1, table.length(M.participants) do
        if M.leaderboard[i] and M.leaderboard[i].playerID == player.playerID then
            for j = i, table.length(M.participants) do
                if M.leaderboard[j + 1] then
                    M.leaderboard[j] = M.leaderboard[j + 1]
                else
                    M.leaderboard[j] = nil
                end
            end
            break
        end
    end

    if M.participants[player.playerID] then
        M.participants[player.playerID] = nil
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.SPEED)
        checkEnd()
    end
end

local function onVehicleDeleted(playerID, vehID)
    if not M.startTime or M.startTime > GetCurrentTime() then
        return
    end

    local eliminated = false
    for i = 1, M.participants:length() do
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
M.clientUpdate = onPlayerFail
M.stop = stop
M.forceStop = stop

M.isForcedScenarioInProgress = function()
    return M.startTime and M.isEvent
end

BJCEvents.addListener(BJCEvents.EVENTS.SLOW_TICK, slowTick, "SpeedManager")

M.canSpawnVehicle = canSpawnOrEditVehicle
M.canEditVehicle = canSpawnOrEditVehicle
M.onPlayerDisconnect = onPlayerDisconnect
M.onVehicleDeleted = onVehicleDeleted

return M
