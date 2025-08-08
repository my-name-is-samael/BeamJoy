---@class BJTournamentActivity
---@field type string
---@field name string? (race|derby)
---@field raceID integer? (solo_race)
---@field targetTime integer? (solo_race)

---@class BJTournamentPlayer
---@field playerName string
---@field scores tablelib<integer, {score: integer?, tempValue: any?}> index ActivityIndex

local M = {
    ACTIVITIES_TYPES = {
        RACE_SOLO = "raceSolo",
        RACE = "race",
        SPEED = "speed",
        HUNTER = "hunter",
        INFECTED = "infected",
        DERBY = "derby",
        TAG = "tag",
    },

    state = false,
    ---@type tablelib<integer, BJTournamentActivity> index 1-N
    activities = Table(),
    ---@type tablelib<integer, BJTournamentPlayer> index 1-N sorted by overall score
    players = Table(),

    whitelist = false, -- closed tournament
    ---@type tablelib<integer, string> playerNames
    whitelistPlayers = Table(),
}

local function save()
    BJCDao.scenario.Tournament.save(M.activities, M.players, M.whitelist, M.whitelistPlayers)
end

local function init()
    local data = BJCDao.scenario.Tournament.get()
    M.activities = Table(data.activities)
    M.players = Table(data.players):map(function(p)
        return table.assign(p, { scores = Table(p.scores) })
    end)
    M.whitelist = data.whitelist
    M.whitelistPlayers = Table(data.whitelistPlayers)

    if #M.activities > 0 and M.activities[#M.activities] and
        M.activities[#M.activities].targetTime then
        M.endSoloActivity()
    end
end

local function clear()
    BJCAsync.removeTask("BJCTournamentSoloActivityTimeout")

    M.state = false
    M.activities = Table()
    M.players = Table()
    M.whitelist = false
    M.whitelistPlayers = Table()

    save()

    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.TOURNAMENT)
end

---@return boolean
local function isSoloActivityInProgress()
    return M.activities[#M.activities] and
        M.activities[#M.activities].targetTime
end

---@param state boolean?
local function toggle(state)
    if state == nil then
        state = not M.state
    end
    if state and BJCScenario.isServerScenarioInProgress() then
        error({ key = "rx.errors.serverError" })
    end
    M.state = state

    if not M.state and isSoloActivityInProgress() then
        M.endSoloActivity()
    end

    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.TOURNAMENT)
end

---@param playerName string
---@return integer?
local function getCurrentSoloRaceScore(playerName)
    if isSoloActivityInProgress() and M.activities[#M.activities].raceID then
        ---@param p BJTournamentPlayer
        local sorted = M.players:filter(function(p)
            return p.scores[#M.activities] and p.scores[#M.activities].tempValue
        end):map(function(p)
            return {
                playerName = p.playerName,
                time = p.scores[#M.activities].tempValue,
            }
        end):sort(function(a, b)
            if a.time and b.time then
                return a.time < b.time
            else
                return a.time
            end
        end):map(function(el)
            return el.playerName
        end)
        return table.indexOf(sorted, playerName)
    end
end

local function sortPlayers()
    local emptyScore = M.players:length()
    local currentSoloActivity = isSoloActivityInProgress()

    ---@param a BJTournamentPlayer
    ---@param b BJTournamentPlayer
    M.players:sort(function(a, b)
        local res = Range(1, #M.activities):reduce(function(res, i)
            if i == #M.activities and currentSoloActivity then
                if M.activities[#M.activities].raceID then
                    -- solo race
                    res[1] = res[1] + (getCurrentSoloRaceScore(a.playerName) or emptyScore)
                    res[2] = res[2] + (getCurrentSoloRaceScore(b.playerName) or emptyScore)
                else
                    -- other (no increment for now)
                end
            else
                res[1] = res[1] + (a.scores[i] and a.scores[i].score or emptyScore)
                res[2] = res[2] + (b.scores[i] and b.scores[i].score or emptyScore)
            end
            return res
        end, { 0, 0 })
        return res[1] < res[2]
    end)

    save()
end

---@param type string
---@param name? string race name|derby arena name
local function addActivity(type, name)
    M.activities:insert({
        type = type,
        name = name,
    })

    save()

    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.TOURNAMENT)
end

---@param activityIndex integer
local function removeActivity(activityIndex)
    if not M.activities[activityIndex] then
        error({ key = "rx.errors.invalidKey", data = { key = activityIndex } })
    end

    local shift = activityIndex < #M.activities
    M.players:forEach(function(p)
        if shift then
            p.scores = p.scores:reduce(function(newScores, score, i)
                if i < activityIndex then
                    newScores[i] = score
                elseif i > activityIndex then
                    newScores[i - 1] = score
                end
                return newScores
            end, Table())
        elseif p.scores[activityIndex] then
            p.scores[activityIndex] = nil
        end
    end)
    M.activities:remove(activityIndex)
    sortPlayers()

    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.TOURNAMENT)
end

---@param playerName string
---@param activityIndex integer
---@param score? integer
---@param tempValue? any
local function editPlayerScore(playerName, activityIndex, score, tempValue)
    if not M.activities[activityIndex] then
        error({ key = "rx.errors.invalidKey", data = { key = activityIndex } })
    elseif not score and not tempValue then
        error({ key = "rx.errors.invalidData" })
    elseif M.whitelist and not M.whitelistPlayers:includes(playerName) then
        error({ key = "rx.errors.invalidPlayer", { playerName = playerName } })
    end

    if not M.players:find(function(p) return p.playerName == playerName end, function(p)
            -- existing player data
            local finalScore = score or (p.scores[activityIndex] and p.scores[activityIndex].score or nil)
            if finalScore == 0 then
                finalScore = nil
            end
            p.scores[activityIndex] = {
                score = finalScore,
                tempValue = tempValue or (p.scores[activityIndex] and p.scores[activityIndex].tempValue or nil),
            }
        end) then
        -- new player data
        M.players:insert({
            playerName = playerName,
            scores = Table({
                [activityIndex] = {
                    score = score,
                    tempValue = tempValue,
                }
            }),
        })
    end
    sortPlayers()

    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.TOURNAMENT)
end

local function endTournament()
    M.endSoloActivity()
    if #M.activities > 0 and #M.players > 0 then
        -- broadcast results
        for pos = #M.players, 1, -1 do
            BJCChat.sendChatEvent("chat.events.tournamentResult", {
                playerName = M.players[pos].playerName,
                position = pos,
                score = Range(1, #M.activities):map(function(iActivity)
                    return M.players[pos].scores[iActivity] and
                        M.players[pos].scores[iActivity].score or #M.players
                end):reduce(function(res, score)
                    return res + score
                end, 0),
            })
            if pos > 1 then
                MP.Sleep(200)
            end
        end
    end
    M.state = false

    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.TOURNAMENT)
end

---@param playerName string
local function removePlayer(playerName)
    M.players = M.players:filter(function(p) return p.playerName ~= playerName end)
    M.whitelistPlayers:find(function(name) return name == playerName end, function(_, i)
        M.whitelistPlayers:remove(i)
    end)

    save()

    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.TOURNAMENT)
end

---@param state boolean
local function toggleWhitelist(state)
    if state and not M.whitelist then
        M.whitelistPlayers:addAll(M.players:map(function(p) return p.playerName end))
        M.whitelist = true

        save()

        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.TOURNAMENT)
    elseif not state and M.whitelist then
        M.whitelistPlayers = Table()
        M.whitelist = false

        save()

        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.TOURNAMENT)
    end
end

---@param playerName string
---@param state boolean
local function togglePlayer(playerName, state)
    local exists = M.whitelistPlayers:includes(playerName)
    if not state and exists then
        M.players:find(function(p) return p.playerName == playerName end, function(p, i)
            M.players:remove(i)
        end)
        M.whitelistPlayers:remove(M.whitelistPlayers:indexOf(playerName))

        save()

        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.TOURNAMENT)
    elseif state and not exists then
        M.whitelistPlayers:insert(playerName)
        M.players:insert({
            playerName = playerName,
            scores = Table(),
        })

        save()

        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.TOURNAMENT)
    end
end

---@param raceID integer
---@param timeoutMin integer
local function addSoloRaceActivity(raceID, timeoutMin)
    if not isSoloActivityInProgress() then
        local race = BJCScenarioData.getRace(raceID)
        if race then
            addActivity(M.ACTIVITIES_TYPES.RACE_SOLO, race.name)
            M.activities[#M.activities].raceID = raceID
            M.activities[#M.activities].targetTime = GetCurrentTime() + timeoutMin * 60

            save()

            BJCAsync.programTask(M.endSoloActivity, M.activities[#M.activities].targetTime,
                "BJCTournamentSoloActivityTimeout")
        end
    end
end

---@param playerName string
---@param time integer
local function saveSoloRaceTime(playerName, time)
    if isSoloActivityInProgress() and M.activities[#M.activities].raceID and
        (not M.whitelist or M.whitelistPlayers:includes(playerName)) then
        local changed = false
        local activityIndex = #M.activities
        if not M.players:find(function(p) return p.playerName == playerName end, function(p)
                -- existing player data
                if not p.scores[activityIndex] or
                    not p.scores[activityIndex].tempValue or
                    p.scores[activityIndex].tempValue > time then
                    p.scores[activityIndex] = {
                        tempValue = time
                    }
                    changed = true
                end
            end) then
            -- new player data
            M.players:insert({
                playerName = playerName,
                scores = Table({
                    [activityIndex] = {
                        tempValue = time,
                    }
                }),
            })
            changed = true
        end

        if changed then
            sortPlayers()
            BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.TOURNAMENT)
        end
    end
end

local function endSoloActivity()
    if isSoloActivityInProgress() then
        BJCAsync.removeTask("BJCTournamentSoloActivityTimeout")
        -- apply scores to participants
        if M.activities[#M.activities].raceID then
            -- solo race score calculation
            M.players:filter(function(p)
                return p.scores[#M.activities] and p.scores[#M.activities].tempValue
            end):map(function(p)
                return {
                    playerName = p.playerName,
                    time = p.scores[#M.activities].tempValue,
                }
            end):sort(function(a, b)
                if a.time and b.time then
                    return a.time < b.time
                else
                    return a.time
                end
            end):map(function(el)
                return el.playerName
            end):forEach(function(playerName, pos)
                M.players:find(function(p) return p.playerName == playerName end, function(p)
                    p.scores[#M.activities].score = pos
                end)
            end)
        end
        -- remove temp values
        M.players:forEach(function(p)
            if p.scores[#M.activities] then
                p.scores[#M.activities].tempValue = nil
            end
        end)
        M.activities[#M.activities].targetTime = nil

        save()

        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.TOURNAMENT)
    end
end

---@param player BJCPlayer
local function onPlayerDisconnected(player)
    if M.state and not Table(BJCPlayers.Players):any(function(_, pid)
            return BJCPerm.hasPermission(pid, BJCPerm.PERMISSIONS.START_SERVER_SCENARIO)
        end) then
        -- auto stop tournament when no habilited member connected
        M.toggle(false)
    end
end

local function getCache(playerID)
    local hasPerm = BJCPerm.hasPermission(playerID, BJCPerm.PERMISSIONS.START_SERVER_SCENARIO)
    return {
        state = M.state,
        activities = (M.state or hasPerm) and M.activities or {},
        players = (M.state or hasPerm) and M.players or {},
        whitelist = (M.state or hasPerm) and M.whitelist or false,
        whitelistPlayers = (M.state or hasPerm) and M.whitelistPlayers or {},
    }, M.getCacheHash()
end

local function getCacheHash()
    return Hash({ M.state, M.activities, M.players, M.whitelist, M.whitelistPlayers })
end

M.clear = clear
M.toggle = toggle
M.addActivity = addActivity
M.removeActivity = removeActivity
M.endTournament = endTournament
M.editPlayerScore = editPlayerScore
M.removePlayer = removePlayer
M.toggleWhitelist = toggleWhitelist
M.togglePlayer = togglePlayer
M.addSoloRaceActivity = addSoloRaceActivity
M.saveSoloRaceTime = saveSoloRaceTime
M.endSoloActivity = endSoloActivity

-- on player disconnect, if enabled and no staff online, disable tournament
BJCEvents.addListener(BJCEvents.EVENTS.PLAYER_DISCONNECTED, onPlayerDisconnected, "TournamentManager")

M.getCache = getCache
M.getCacheHash = getCacheHash

init()

return M
