---@class BJIInfectedParticipant
---@field originalInfected boolean
---@field ready boolean
---@field startPosition integer?
---@field gameVehID integer?
---@field infectionTime integer? time
---@field infectedSurvivors integer[]
---@field score integer

---@class BJCScenarioInfected: BJCScenario
local M = {
    name = "Infected",

    MINIMUM_PARTICIPANTS = function()
        if BJCCore.Data.Debug and
            MP.GetPlayerCount() == 1 then
            return 1
        end
        return 3
    end,
    STATES = {
        PREPARATION = 1,
        GAME = 2,
    },
    CLIENT_EVENTS = {
        JOIN = "join",
        READY = "ready",
        LEAVE = "leave",
        INFECTION = "infection",
    },

    state = nil,

    -- preparation & common

    -- keep track of joined participants to have valid infected everytime
    ---@type tablelib<integer, integer> index 1-N, value playerID
    joinOrder = Table(),
    ---@type tablelib<integer, BJIInfectedParticipant> index playerID
    participants = Table(),
    ---@type integer?
    preparationTimeout = nil,

    -- settings

    endAfterLastSurvivorInfected = false,
    ---@type ClientVehicleConfig?
    config = nil,
    enableColors = false,
    ---@type BJIColor?
    survivorsColor = nil,
    ---@type BJIColor?
    infectedColor = nil,

    -- game

    survivorsStartTime = nil,
    infectedStartTime = nil,
    finished = false,
}

local function getCache()
    return {
        minimumParticipants = M.MINIMUM_PARTICIPANTS(),
        state = M.state,
        participants = M.participants,
        preparationTimeout = M.preparationTimeout,
        config = M.config,
        enableColors = M.enableColors,
        survivorsColor = M.survivorsColor,
        infectedColor = M.infectedColor,
        survivorsStartTime = M.survivorsStartTime,
        infectedStartTime = M.infectedStartTime,
        finished = M.finished,
    }, M.getCacheHash()
end

local function getCacheHash()
    return Hash({
        M.MINIMUM_PARTICIPANTS(),
        M.state,
        M.participants,
        M.preparationTimeout,
        M.endAfterLastSurvivorInfected,
        M.config ~= nil,
        M.enableColors,
        M.survivorsColor,
        M.infectedColor,
        M.survivorsStartTime,
        M.infectedStartTime,
        M.finished,
    })
end

local function cancelGridTimeout()
    BJCAsync.removeTask("BJCInfectedGridTimeout")
    M.preparationTimeout = nil
end

local function stop()
    cancelGridTimeout()
    M.state = nil
    M.joinOrder = Table()
    M.participants = Table()
    M.preparationTimeout = nil
    M.endAfterLastSurvivorInfected = false
    M.config = nil
    M.enableColors = false
    M.survivorsColor = nil
    M.infectedColor = nil
    M.survivorsStartTime = nil
    M.infectedStartTime = nil
    M.finished = false

    BJCScenario.CurrentScenario = nil
end

local function updateScores()
    local countSurvivors, maxInfectionTime = 0, 0
    ---@param p BJIInfectedParticipant
    M.participants:map(function(p, pid)
        if not p.originalInfected and not p.infectionTime then
            countSurvivors = countSurvivors + 1
        elseif p.infectionTime and p.infectionTime > maxInfectionTime then
            maxInfectionTime = p.infectionTime
        end
        return {
            playerID = pid,
            originalInfected = p.originalInfected,
            infectionTime = p.infectionTime,
            infectedCount = #p.infectedSurvivors,
        }
    end):sort(function(a, b)
        if a.originalInfected or b.originalInfected then
            return a.originalInfected
        elseif a.infectionTime and b.infectionTime then
            return a.infectionTime < b.infectionTime
        elseif a.infectionTime or b.infectionTime then
            return a.infectionTime ~= nil
        else -- 2 survivors
            return a.playerID < b.playerID
        end
    end):forEach(function(p, i, t)
        local score = 0
        if p.originalInfected then
            -- if contaminate >= 75% of survivors, perfect score
            local contagionScore = p.infectedCount / ((#t - 1) * .75)
            score = math.scale(contagionScore, 0, 1, #t, 1, true)
        elseif not p.infectionTime or (countSurvivors == 0 and
                maxInfectionTime == p.infectionTime) then
            -- survivor or winner
            score = 1
        else -- infected
            local survivalScore = (i - 1) / (#t - 1)
            local contagionScore = p.infectedCount / math.max(#t - i - 1, 2)
            score = math.scale(survivalScore * 3 + contagionScore * 2, 0, 5, #t, 1, true)
        end
        M.participants[p.playerID].score = math.round(score)
    end)
end

local function onGridTimeout()
    M.participants = M.participants:filter(function(p) return p.ready and p.gameVehID end)
    -- check players amount
    if M.participants:length() < M.MINIMUM_PARTICIPANTS() then
        BJCTx.player.toast(BJCTx.ALL_PLAYERS, BJC_TOAST_TYPES.ERROR, "rx.errors.insufficientPlayers")
        BJCChat.sendChatEvent("chat.events.gamemodeStopped", {
            gamemode = "chat.events.gamemodes.infected",
            reason = "chat.events.gamemodeStopReasons.notEnoughParticipants",
        })
        stop()
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.INFECTED)
        return
    end

    if not M.participants:any(function(p) return p.originalInfected end) and
        not BJCCore.Data.Debug then
        LogError("Infected player not found")
        BJCTx.player.toast(BJCTx.ALL_PLAYERS, BJC_TOAST_TYPES.ERROR, "infected.invalidInfected")
        BJCChat.sendChatEvent("chat.events.gamemodeStopped", {
            gamemode = "chat.events.gamemodes.infected",
            reason = "chat.events.gamemodeStopReasons.notEnoughParticipants",
        })
        stop()
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.INFECTED)
        return
    end

    -- start game
    M.state = M.STATES.GAME
    M.survivorsStartTime = GetCurrentTime() + BJCConfig.Data.Infected.SurvivorsStartDelay
    M.infectedStartTime = GetCurrentTime() + BJCConfig.Data.Infected.InfectedStartDelay
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.INFECTED)

    updateScores()
    if BJCTournament.state then
        BJCTournament.addActivity(BJCTournament.ACTIVITIES_TYPES.INFECTED)
        M.participants:forEach(function(p, pid)
            BJCTournament.editPlayerScore(BJCPlayers.Players[pid].playerName, #BJCTournament.activities, p.score)
        end)
    end
    M.participants:forEach(function(_, pid)
        BJCPlayers.reward(pid, BJCConfig.Data.Reputation.InfectedParticipationReward)
    end)
end

local function startGridTimeout()
    M.preparationTimeout = GetCurrentTime() + BJCConfig.Data.Infected.GridTimeout
    BJCAsync.programTask(onGridTimeout, M.preparationTimeout, "BJCInfectedGridTimeout")
end

---@param settings {endAfterLastSurvivorInfected: boolean, config: ClientVehicleConfig, enableColors: boolean, survivorsColor: BJIColor?, infectedColor: BJIColor?}
local function start(settings)
    if not BJCScenarioData.HunterInfected.enabledInfected then
        error({ key = "rx.errors.invalidData" })
    elseif BJCPerm.getCountPlayersCanSpawnVehicle() < M.MINIMUM_PARTICIPANTS() then
        error({ key = "rx.errors.insufficientPlayers" })
    elseif M.state then
        error({ key = "rx.errors.invalidData" })
    end

    BJCScenario.stopServerScenarii()
    M.joinOrder = Table()
    M.participants = Table()
    M.endAfterLastSurvivorInfected = settings.endAfterLastSurvivorInfected
    M.config = settings.config
    M.enableColors = settings.enableColors
    M.survivorsColor = settings.survivorsColor
    M.infectedColor = settings.infectedColor
    M.state = M.STATES.PREPARATION
    startGridTimeout()

    BJCScenario.CurrentScenario = M
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.INFECTED)
    BJCChat.sendChatEvent("chat.events.gamemodeStarted", {
        gamemode = "chat.events.gamemodes.infected",
    })
end

---@param originalInfected boolean
---@return integer
local function findFreeStartPosition(originalInfected)
    if originalInfected then
        return math.random(1, #BJCScenarioData.HunterInfected.minorPositions)
    else
        return Range(1, #BJCScenarioData.HunterInfected.majorPositions)
            :filter(function(i)
                return not M.participants:any(function(p)
                    return not p.originalInfected and p.startPosition == i
                end)
            end):random()
    end
end

local function sanitizePreparationOriginalInfected()
    M.joinOrder = M.joinOrder:filter(function(playerID)
        return M.participants[playerID] ~= nil
    end)
    if #M.joinOrder > 0 and M.participants[M.joinOrder[1]] then
        local wasOriginalInfected = M.participants[M.joinOrder[1]].originalInfected
        M.participants[M.joinOrder[1]].originalInfected = true
        M.participants[M.joinOrder[1]].ready = false
        if not wasOriginalInfected then
            M.participants[M.joinOrder[1]].startPosition = findFreeStartPosition(true)
        end
    end
end

local function onJoin(senderID)
    if M.participants[senderID] then
        -- leave participants
        M.participants[senderID] = nil
        sanitizePreparationOriginalInfected()

        if not M.participants:any(function(p) return p.ready end) and
            not BJCAsync.exists("BJCInfectedGridTimeout") then
            startGridTimeout()
        end
    elseif M.participants:length() == 0 then
        -- first to join is infected (or debug)
        local originalInfected = true
        if BJCCore.Data.Debug and MP.GetPlayerCount() == 1 then
            originalInfected = math.random() > 0.5
        end
        M.participants[senderID] = {
            originalInfected = originalInfected,
            ready = false,
            startPosition = findFreeStartPosition(originalInfected),
            infectedSurvivors = {},
        }
        M.joinOrder:insert(senderID)
    else
        -- others are survivors
        M.participants[senderID] = {
            originalInfected = false,
            ready = false,
            startPosition = findFreeStartPosition(false),
            infectedSurvivors = {},
            score = 0,
        }
        M.joinOrder:insert(senderID)
    end
    if M.participants[senderID] then
        BJCChat.sendChatEvent("chat.events.gamemodeJoin", {
            playerName = BJCPlayers.Players[senderID].playerName,
            gamemode = "chat.events.gamemodes.infected",
        })
    else
        BJCChat.sendChatEvent("chat.events.gamemodeLeave", {
            playerName = BJCPlayers.Players[senderID].playerName,
            gamemode = "chat.events.gamemodes.infected",
        })
    end
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.INFECTED)
end

local function onReady(senderID, gameVehID)
    cancelGridTimeout()
    M.participants[senderID].ready = true
    M.participants[senderID].gameVehID = gameVehID
    if M.participants:length() >= M.MINIMUM_PARTICIPANTS() then
        if M.participants:every(function(p) return p.ready end) then
            onGridTimeout()
        end
    end
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.INFECTED)
end

local function onLeave(senderID)
    M.participants[senderID] = nil
    local needStop = not M.participants:any(function(p)
        return p.originalInfected or p.infectionTime ~= nil
    end)
    if needStop or M.participants:length() < M.MINIMUM_PARTICIPANTS() then
        BJCChat.sendChatEvent("chat.events.gamemodeStopped", {
            gamemode = "chat.events.gamemodes.infected",
            reason = "chat.events.gamemodeStopReasons.notEnoughParticipants",
        })
        stop()
    end
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.INFECTED)
end

local function onGameEnd()
    BJCTx.player.flash(BJCTx.ALL_PLAYERS, "infected.gameOver")
    BJCChat.sendChatEvent("chat.events.gamemodeEnded", {
        gamemode = "chat.events.gamemodes.infected",
    })
    M.finished = true
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.INFECTED)

    BJCAsync.delayTask(stop, BJCConfig.Data.Infected.EndTimeout)

    M.participants:forEach(function(p, pid)
        BJCPlayers.reward(pid, math.ceil(math.scale(p.score, #M.participants + 1, 1,
            0, BJCConfig.Data.Reputation.InfectedWinnerReward, true)))
    end)
end

local function onInfection(infectedID, survivorID)
    local infected = M.participants[infectedID]
    local survivor = M.participants[survivorID]
    if not infected or not survivor then return end
    if survivor.originalInfected or survivor.infectionTime then return end
    table.insert(infected.infectedSurvivors, survivorID)
    survivor.infectionTime = GetCurrentTime()

    updateScores()
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.INFECTED)
    if BJCTournament.state then
        M.participants:forEach(function(p, pid)
            BJCTournament.editPlayerScore(BJCPlayers.Players[pid].playerName, #BJCTournament.activities, p.score)
        end)
    end

    local remainingSurvivors = M.participants:filter(function(p)
        return not p.originalInfected and not p.infectionTime
    end):length()
    if remainingSurvivors <= 1 then
        if M.endAfterLastSurvivorInfected and remainingSurvivors == 0 then
            onGameEnd()
        elseif not M.endAfterLastSurvivorInfected and remainingSurvivors <= 1 then
            onGameEnd()
        end
    end
end

local function clientUpdate(senderID, event, data)
    if M.state == M.STATES.PREPARATION then
        if event == M.CLIENT_EVENTS.JOIN then
            onJoin(senderID)
        elseif event == M.CLIENT_EVENTS.READY then
            if M.participants[senderID] then
                onReady(senderID, data)
            end
        end
    elseif M.state == M.STATES.GAME then
        local participant = M.participants[senderID]
        if participant then
            if event == M.CLIENT_EVENTS.LEAVE then
                onLeave(senderID)
            elseif event == M.CLIENT_EVENTS.INFECTION then
                onInfection(senderID, data)
            end
        end
    end
end

local function forceInfected(playerID)
    if M.state ~= M.STATES.PREPARATION then
        error({ key = "rx.errors.invalidData" })
    end

    local pos = M.joinOrder:indexOf(playerID)
    if not pos or pos == 1 then
        error({ key = "rx.errors.invalidPlayerID", data = { playerID = playerID } })
    end

    M.participants[playerID].originalInfected = true
    M.participants[playerID].ready = false
    M.participants[playerID].startPosition = nil -- clear start position to generate a clean one
    while not M.participants[playerID].startPosition or
        M.participants[playerID].startPosition == M.participants[M.joinOrder[1]].startPosition do
        -- find an infected start position
        M.participants[playerID].startPosition = findFreeStartPosition(true)
    end

    M.participants[M.joinOrder[1]].originalInfected = false
    M.participants[M.joinOrder[1]].ready = false
    M.participants[M.joinOrder[1]].startPosition = nil -- clear start position to generate a clean one
    M.participants[M.joinOrder[1]].startPosition = findFreeStartPosition(false)

    M.joinOrder:remove(pos)
    M.joinOrder:insert(1, playerID)

    if not M.participants:any(function(p) return p.ready end) and
        not BJCAsync.exists("BJCInfectedGridTimeout") then
        startGridTimeout()
    end

    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.INFECTED)
end

---@param player BJCPlayer
local function onPlayerDisconnect(player)
    if M.state and M.participants[player.playerID] then
        M.participants[player.playerID] = nil
        if M.state == M.STATES.PREPARATION then
            M.joinOrder:remove(M.joinOrder:indexOf(player.playerID))
            sanitizePreparationOriginalInfected()
            if not M.participants:any(function(p) return p.ready end) and
                not BJCAsync.exists("BJCInfectedGridTimeout") then
                startGridTimeout()
            end
        elseif M.state == M.STATES.GAME then
            if not M.participants:any(function(p)
                    return p.originalInfected or p.infectionTime
                end) or M.participants:length() < M.MINIMUM_PARTICIPANTS() then
                BJCChat.sendChatEvent("chat.events.gamemodeStopped", {
                    gamemode = "chat.events.gamemodes.infected",
                    reason = "chat.events.gamemodeStopReasons.notEnoughParticipants",
                })
                stop()
            end
        end
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.INFECTED)
    end
end

local function onVehicleDeleted(playerID, vehID)
    if M.state == M.STATES.GAME and M.participants[playerID] then
        M.participants[playerID] = nil
        if not M.participants:any(function(p)
                return p.originalInfected or p.infectionTime
            end) or table.length(M.participants) < M.MINIMUM_PARTICIPANTS() then
            BJCChat.sendChatEvent("chat.events.gamemodeStopped", {
                gamemode = "chat.events.gamemodes.infected",
                reason = "chat.events.gamemodeStopReasons.notEnoughParticipants",
            })
            stop()
        end
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.INFECTED)
    end
end

---@param playerID integer
---@param vehID integer
---@param vehData ServerVehicleConfig
local function canSpawnOrEditVehicle(playerID, vehID, vehData)
    local participant = M.participants[playerID]
    if M.state == M.STATES.PREPARATION and participant and not participant.ready then
        if M.config then
            local model = vehData.jbm or vehData.vcf.model or vehData.vcf.mainPartName
            return model == M.config.model and
                BJCScenario.isVehicleSpawnedMatchesRequired(vehData.vcf.parts, M.config.parts)
        end
        -- no config restriction
        return true
    end
    -- during game
    return false
end

local function onStop()
    if M.state then
        if M.state == M.STATES.GAME then
            BJCTx.player.flash(BJCTx.ALL_PLAYERS, "infected.gameOver")
        end
        BJCChat.sendChatEvent("chat.events.gamemodeStopped", {
            gamemode = "chat.events.gamemodes.infected",
            reason = "chat.events.gamemodeStopReasons.moderation",
        })
        stop()
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.INFECTED)
    end
end

M.getCache = getCache
M.getCacheHash = getCacheHash

M.start = start
M.clientUpdate = clientUpdate
M.forceInfected = forceInfected
M.stop = onStop
M.forceStop = onStop

M.canSpawnVehicle = canSpawnOrEditVehicle
M.canEditVehicle = canSpawnOrEditVehicle
M.onPlayerDisconnect = onPlayerDisconnect
M.onVehicleDeleted = onVehicleDeleted

return M
