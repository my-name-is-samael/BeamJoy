---@class BJIDerbyParticipant
---@field playerID integer
---@field ready boolean
---@field gameVehID? integer
---@field lives integer
---@field eliminationTime? integer
---@field startPosition integer

---@class BJCScenarioDerby: BJCScenario
local M = {
    name = "Derby",

    MINIMUM_PARTICIPANTS = function()
        if BJCCore.Data.General.Debug and MP.GetPlayerCount() < 3 then
            return MP.GetPlayerCount()
        end
        return 3
    end,
    -- received events
    CLIENT_EVENTS = {
        JOIN = "Join",           -- preparation
        READY = "Ready",         -- preparation
        LEAVE = "Leave",         -- game
        DESTROYED = "Destroyed", -- game
    },
    STATES = {
        PREPARATION = 1, -- time when all players choose cars and mark ready
        GAME = 2,        -- time during game / spectate
    },

    state = nil,
    ---@type {name: string, startPositions: BJIPositionRotation[]}?
    baseArena = nil,
    settings = {
        lives = 0,
        configs = Table(),
    },

    ---@type tablelib<integer, BJIDerbyParticipant> index 1-N
    participants = Table(),

    preparation = {
        timeout = nil,
    },
    game = {
        startTime = nil,
        ---@type Timer?
        gameTimer = nil,
    },

    countInvalidVehicles = {}, -- count to detect invalid setting config
}

local function getParticipantPosition(playerID)
    local pos
    M.participants:find(function(p) return p.playerID == playerID end, function(_, position)
        pos = position
    end)
    return pos
end

local function cancelPreparationTimeout()
    BJCAsync.removeTask("BJCDerbyPreparationTimeout")
    M.preparation.timeout = nil
end

-- ends the derby
local function stopDerby()
    cancelPreparationTimeout()
    M.state = nil
    M.baseArena = nil
    M.settings = {
        lives = 0,
    }
    M.participants = Table()
    M.preparation = {}
    M.game = {}
    M.countInvalidVehicles = {}

    BJCScenario.CurrentScenario = nil
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DERBY)
end

local function onClientStopDerby()
    if not M.state then
        error({ key = "rx.errors.invalidData" })
    end

    stopDerby()
end

local function startDerby()
    if M.state ~= M.STATES.PREPARATION then
        error({ key = "rx.errors.invalidData" })
    end

    M.game.startTime = GetCurrentTime() + BJCConfig.Data.Derby.StartCountdown
    M.countInvalidVehicles = {}
    M.state = M.STATES.GAME
    BJCAsync.programTask(function()
        M.game.gameTimer = math.timer()
    end, M.game.startTime, "BJCDerbyGameStartTimer")

    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DERBY)
end

local function onPreparationTimeout()
    -- remove no vehicle players from participants
    M.participants:filter(function(p) return not p.ready end)
        :forEach(function(p)
            local player = BJCPlayers.Players[p.playerID]
            if not player or table.length(player.vehicles) == 0 then
                M.participants = M.participants
                    :filter(function(p2) return p2.playerID ~= p.playerID end)
            else
                p.ready = true
                if not p.gameVehID then
                    Table(player.vehicles):find(function() return true end, function(v)
                        p.gameVehID = v.gameVehID
                    end)
                    if not p.gameVehID then
                        M.participants = M.participants
                            :filter(function(p2) return p2.playerID ~= p.playerID end)
                    end
                end
            end
        end)

    if #M.participants < M.MINIMUM_PARTICIPANTS() then
        BJCChat.sendChatEvent("chat.events.gamemodeStopped", {
            gamemode = "chat.events.gamemodes.derby",
            reason = "chat.events.gamemodeStopReasons.notEnoughParticipants",
        })
        stopDerby()
    else
        startDerby()
        local reward = BJCConfig.Data.Reputation.DerbyParticipationReward
        M.participants:forEach(function(p)
            BJCPlayers.reward(p.playerID, reward)
        end)
    end
end

local function startPreparationTimeout()
    M.preparation.timeout = GetCurrentTime() + BJCConfig.Data.Derby.PreparationTimeout
    BJCAsync.programTask(onPreparationTimeout, M.preparation.timeout, "BJCDerbyPreparationTimeout")
end

local function finishDerby()
    local winner = M.participants[1] and BJCPlayers.Players[M.participants[1].playerID] or nil
    local second = M.participants[2]
    if winner and (not second or second.eliminationTime) then
        BJCTx.player.flash(BJCTx.ALL_PLAYERS, "derby.winner", { playerName = winner.playerName }, 5)
        M.participants:forEach(function(p, i)
            local reward = math.round(BJCConfig.Data.Reputation.DerbyWinnerReward / i)
            BJCPlayers.reward(p.playerID, reward)
        end)
    else
        BJCTx.player.flash(BJCTx.ALL_PLAYERS, "derby.draw", {}, 5)
    end

    BJCAsync.delayTask(stopDerby, BJCConfig.Data.Derby.EndTimeout)
end

local function updateDerbyState()
    if M.state == M.STATES.PREPARATION then
        if #M.participants >= M.MINIMUM_PARTICIPANTS() and
            M.participants:every(function(p) return p.ready end) then
            startDerby()
        elseif not M.participants:any(function(p) return p.ready end) and
            not BJCAsync.exists("BJCDerbyPreparationTimeout") then
            startPreparationTimeout()
        end
    elseif M.state == M.STATES.GAME then
        if not M.participants[math.min(2, M.MINIMUM_PARTICIPANTS())] or
            M.participants[math.min(2, M.MINIMUM_PARTICIPANTS())].eliminationTime then
            if M.participants[1] then
                BJCChat.sendChatEvent("chat.events.gamemodeFinished", {
                    playerName = BJCPlayers.Players[M.participants[1].playerID].playerName,
                    gamemode = "chat.events.gamemodes.derby",
                    gamemodePosition = 1,
                })
            end
            finishDerby()
        end
    end
end

local function start(derbyIndex, lives, configs)
    BJCScenario.stopServerScenarii()
    for _, player in pairs(BJCPlayers.Players) do
        player.scenario = nil
    end

    M.baseArena = table.deepcopy(BJCScenarioData.Derby[derbyIndex])
    M.settings.lives = lives
    M.settings.configs = configs and Table(configs):clone() or Table()
    while #M.settings.configs >= 6 do -- limit to 5 configs max
        M.settings.configs:remove(6)
    end

    M.participants = Table()

    M.state = M.STATES.PREPARATION
    BJCChat.sendChatEvent("chat.events.gamemodeStarted", {
        gamemode = "chat.events.gamemodes.derby",
    })
    startPreparationTimeout()

    BJCScenario.CurrentScenario = M
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DERBY)
end

local function stop()
    if M.state then
        BJCChat.sendChatEvent("chat.events.gamemodeStopped", {
            gamemode = "chat.events.gamemodes.derby",
            reason = "chat.events.gamemodeStopReasons.manual",
        })
        stopDerby()
    end
end

local function sortParticipants()
    if #M.participants < 2 then
        return
    end
    -- sort players by lives remaining DESC, then eliminationTime DESC
    M.participants:sort(function(a, b)
        if a.eliminationTime or b.eliminationTime then
            if a.eliminationTime and b.eliminationTime then
                return a.eliminationTime > b.eliminationTime
            else
                return b.eliminationTime ~= nil
            end
        end
        return a.lives > b.lives
    end)
end

---@param playerID integer
local function onClientDestroyed(playerID)
    local time = M.game.gameTimer:get()
    local pos = getParticipantPosition(playerID)
    if not pos then
        -- not a participant
        error({ key = "rx.errors.insufficientPermissions" })
        return
    end

    local participant = M.participants[pos]
    if participant.lives > 0 then
        participant.lives = participant.lives - 1
    else
        participant.eliminationTime = time
    end

    sortParticipants()
    if participant.eliminationTime then
        M.participants:find(function(p) return p.playerID == playerID end, function(_, finalPos)
            if finalPos > 1 then
                BJCChat.sendChatEvent("chat.events.gamemodeFinished", {
                    playerName = BJCPlayers.Players[playerID].playerName,
                    gamemode = "chat.events.gamemodes.derby",
                    gamemodePosition = finalPos,
                })
            end
        end)
    end
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DERBY)
    updateDerbyState()
end

local function findFreeStartPosition()
    if #M.participants == #M.baseArena.startPositions then
        error({ key = "rx.errors.invalidData" })
    end

    return Range(1, #M.baseArena.startPositions)
        :filter(function(i) return not M.participants:any(function(p) return p.startPosition == i end) end)
        :random()
end

local function onClientUpdate(senderID, event, data)
    if M.state == M.STATES.PREPARATION then
        if event == M.CLIENT_EVENTS.JOIN then
            local pos = getParticipantPosition(senderID)
            if pos then
                M.participants:remove(pos)
            else
                if #M.participants == #M.baseArena.startPositions then
                    error({ key = "rx.errors.invalidData" })
                end
                M.participants:insert({
                    playerID = senderID,
                    lives = M.settings.lives,
                    ready = false,
                    eliminationTime = nil,
                    startPosition = findFreeStartPosition(),
                })
            end
            updateDerbyState()

            local chatEvent = pos and "chat.events.gamemodeLeave" or "chat.events.gamemodeJoin"
            BJCChat.sendChatEvent(chatEvent, {
                playerName = BJCPlayers.Players[senderID].playerName,
                gamemode = "chat.events.gamemodes.derby",
            })
            BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DERBY)
        elseif event == M.CLIENT_EVENTS.READY then
            M.participants:find(function(p) return p.playerID == senderID end, function(_, pos)
                M.participants[pos].gameVehID = data
                M.participants[pos].ready = true
                cancelPreparationTimeout()
                updateDerbyState()
                BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DERBY)
            end)
        end
    elseif M.state == M.STATES.GAME then
        if event == M.CLIENT_EVENTS.LEAVE then
            M.participants
                :filter(function(p) return not p.eliminationTime end)
                :find(function(p) return p.playerID == senderID end, function(p)
                    p.eliminationTime = M.game.gameTimer:get()
                    sortParticipants()
                    local finalPos = getParticipantPosition(senderID)
                    BJCChat.sendChatEvent("chat.events.gamemodeFinished", {
                        playerName = BJCPlayers.Players[senderID].playerName,
                        gamemode = "chat.events.gamemodes.derby",
                        gamemodePosition = finalPos,
                    })
                    updateDerbyState()
                    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DERBY)
                end)
        elseif event == M.CLIENT_EVENTS.DESTROYED then
            onClientDestroyed(senderID)
        end
    end
end

local function canSpawnOrEditVehicle(playerID, vehID, vehData)
    if not M.state then
        return true
    elseif M.state == M.STATES.PREPARATION then
        local pos = getParticipantPosition(playerID)
        if not pos or not vehData then
            return false
        end

        if #M.settings.configs > 0 then
            -- forced config
            local found = M.settings.configs:any(function(c)
                return vehData.vcf.model == c.model and
                    BJCScenario.isVehicleSpawnedMatchesRequired(vehData.vcf.parts, c.config.parts)
            end)
            if not found then
                M.countInvalidVehicles[playerID] = true
                if table.length(M.countInvalidVehicles) > 1 then
                    -- 2 players tried to spawn an invalid vehicle => surely the config setting is broken
                    BJCAsync.delayTask(function()
                        BJCChat.sendChatEvent("chat.events.gamemodeStopped", {
                            gamemode = "chat.events.gamemodes.derby",
                            reason = "chat.events.gamemodeStopReasons.invalidVehConfig",
                        })
                        stopDerby()
                    end, 0)
                end
            end
            return found
        end
        -- no model restriction
        return true
    end
    -- during game
    return false
end

---@param player BJCPlayer
local function onPlayerDisconnect(player)
    if M.state then
        local pos = getParticipantPosition(player.playerID)
        if pos then
            M.participants:remove(pos)
            updateDerbyState()
            BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DERBY)
        end

        if MP.GetPlayerCount() == 0 then
            stopDerby()
        end
    end
end

local function onVehicleDeleted(playerID, vehID)
    if M.state then
        local pos = getParticipantPosition(playerID)
        if pos then
            if M.state == M.STATES.PREPARATION then
                M.participants:remove(pos)
                updateDerbyState()
                BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DERBY)
            elseif M.state == M.STATES.GAME then
                M.participants[pos].eliminationTime = (GetCurrentTime() - M.game.startTime) * 1000
                sortParticipants()
                if (not M.participants[2] or M.participants[2].eliminationTime) and
                    M.participants[1] then
                    BJCChat.sendChatEvent("chat.events.gamemodeFinished", {
                        playerName = BJCPlayers.Players[M.participants[1].playerID].playerName,
                        gamemode = "chat.events.gamemodes.derby",
                        position = 1,
                    })
                    finishDerby()
                end
                BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DERBY)
            end
        end
    end
end

local function getCache()
    return {
        -- common
        minimumParticipants = M.MINIMUM_PARTICIPANTS(),
        state = M.state,
        destroyedTimeout = BJCConfig.Data.Derby.DestroyedTimeout,
        -- settings
        configs = M.settings.configs or {},
        -- preparation
        baseArena = M.baseArena,
        participants = M.participants,
        preparationTimeout = M.preparation.timeout,
        -- game
        startTime = M.game.startTime,
    }, M.getCacheHash()
end

local function getCacheHash()
    return Hash({
        M.MINIMUM_PARTICIPANTS(),
        M.state,
        M.baseArena,
        M.preparation,
        M.participants,
        M.game,
        BJCConfig.Data.Derby.DestroyedTimeout,
    })
end

M.getCache = getCache
M.getCacheHash = getCacheHash

M.start = start
M.clientUpdate = onClientUpdate
M.stop = onClientStopDerby
M.forceStop = stop

M.canSpawnVehicle = canSpawnOrEditVehicle
M.canEditVehicle = canSpawnOrEditVehicle
M.onPlayerDisconnect = onPlayerDisconnect
M.onVehicleDeleted = onVehicleDeleted

return M
