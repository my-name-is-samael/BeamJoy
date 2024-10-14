local M = {
    -- received events
    CLIENT_EVENTS = {
        JOIN = "Join",                            -- grid
        READY = "Ready",                          -- grid
        LEAVE = "Leave",                          -- race
        CHECKPOINT_REACHED = "CheckpointReached", -- race
        FINISH_REACHED = "FinishReached",         -- race
    },
    STATES = {
        GRID = 1,     -- time when all players choose cars and mark ready
        RACE = 2,     -- time during race / spectate
        FINISHED = 3, -- spectate while others are finishing
    },
    RESPAWN_STRATEGIES = {
        NO_RESPAWN = "norespawn",
        LAST_CHECKPOINT = "lastcheckpoint",
        STAND = "stand",
    },

    state = nil,
    baseRace = nil,
    settings = {
        laps = nil,
        model = nil,
        config = nil,
        respawnStrategy = nil,
        time = {
            label = nil,
            ToD = nil,
        },
        weather = {
            label = nil,
            keys = nil,
        },
    },

    previous = {   -- data to restore after race
        env = nil, -- list of keys to restore
    },

    grid = {
        participants = {},
        ready = {},
        timeout = nil,
        readyTime = nil,
    },

    race = {
        raceTimer = nil,
        startTime = nil,
        raceData = nil,
        leaderboard = {},
        finished = {},   -- list of finished players
        eliminated = {}, -- list of eliminated players (leaved, disconnected, dnf, etc)
    },
}
local MINIMUM_PARTICIPANTS = 2

local function cancelGridTimeout()
    BJCAsync.removeTask("BJCRaceGridTimeout")
end

-- ends the race
local function stopRace()
    cancelGridTimeout()
    M.state = nil
    M.baseRace = nil
    M.settings = {
        laps = nil,
        model = nil,
        config = nil,
        respawnStrategy = nil,
        time = {
            label = nil,
            ToD = nil,
        },
        weather = {
            label = nil,
            keys = nil,
        },
    }
    M.grid = {
        participants = {},
        ready = {},
        timeoutTime = nil,
        readyTime = nil,
    }
    M.race = {
        raceTimer = nil,
        startTime = nil,
        raceData = nil,
        leaderboard = {},
        finished = {}, -- list of finished players
        eliminated = {},
    }

    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.RACE)

    if M.previous.env then
        for k, v in pairs(M.previous.env) do
            pcall(BJCEnvironment.set, k, v)
        end
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.ENVIRONMENT)
    end
    M.previous = { env = nil }
end

local function onClientStopRace()
    if not M.state then
        error({ key = "rx.errors.invalidData" })
    end

    stopRace()
end

local function prepareLeaderboard()
    M.race.leaderboard = {}
    for _, playerID in ipairs(M.grid.participants) do
        table.insert(M.race.leaderboard, {
            playerID,
            {
                {
                    start = 0,
                    waypoints = {},
                }
            }
        })
    end
end

local function startRace()
    cancelGridTimeout()
    prepareLeaderboard()
    M.race = {
        raceTimer = nil,
        startTime = GetCurrentTime() + (BJCConfig.Data.Race.RaceCountdown),
        raceData = {
            loopable = M.baseRace.loopable,
            wpPerLap = #M.baseRace.steps,
            steps = tdeepcopy(M.baseRace.steps),
        },
        leaderboard = M.race.leaderboard,
        finished = {},
        eliminated = {},
    }
    M.state = M.STATES.RACE

    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.RACE)

    BJCAsync.programTask(function()
        M.race.raceTimer = TimerCreate()
        for _, playerID in ipairs(M.grid.participants) do
            BJCPlayers.Players[playerID].stats.race = BJCPlayers.Players[playerID].stats.race + 1
            BJCPlayers.reward(playerID, BJCConfig.Data.Reputation.RaceParticipationReward)
        end
    end, M.race.startTime)
end

local function checkRaceReady()
    if M.state == M.STATES.GRID and
        M.grid.readyTime <= GetCurrentTime() and
        #M.grid.participants > 0 and
        #M.grid.participants == #M.grid.ready then
        startRace()
    end
end

local function onGridTimeout()
    -- remove no vehicle players from participants
    for iParticipant, playerID in ipairs(M.grid.participants) do
        if not tincludes(M.grid.ready, playerID, true) then
            local player = BJCPlayers.Players[playerID]
            if tlength(player.vehicles) == 0 then
                table.remove(M.grid.participants, iParticipant)
            else
                table.insert(M.grid.ready, playerID)
            end
        end
    end

    if #M.grid.participants < MINIMUM_PARTICIPANTS then
        stopRace()
    else
        checkRaceReady()
    end
end

local function startGridTimeout(time)
    BJCAsync.programTask(onGridTimeout, time, "BJCRaceGridTimeout")
end

local function start(raceID, settings, time, weather)
    BJCScenario.stopServerScenarii()
    for _, player in pairs(BJCPlayers.Players) do
        player.scenario = nil
    end

    M.baseRace = BJCScenario.getRace(raceID)
    M.settings = settings
    M.time = time
    M.weather = weather

    M.grid.participants = {}
    M.grid.ready = {}
    M.grid.timeout = GetCurrentTime() + BJCConfig.Data.Race.GridTimeout
    M.grid.readyTime = GetCurrentTime() + BJCConfig.Data.Race.GridReadyTimeout

    if M.time.ToD or M.weather.keys then
        M.previous.env = {}
        if M.time.ToD then
            if not BJCEnvironment.Data.controlSun then
                M.previous.env.controlSun = BJCEnvironment.Data.controlSun
                BJCEnvironment.set("controlSun", true)
            end
            if BJCEnvironment.Data.timePlay then
                M.previous.env.timePlay = BJCEnvironment.Data.timePlay
                BJCEnvironment.set("timePlay", false)
            end
            M.previous.env.ToD = BJCEnvironment.Data.ToD
            BJCEnvironment.set("ToD", M.time.ToD)
        end
        if M.weather.keys then
            if not BJCEnvironment.Data.controlWeather then
                M.previous.env.controlWeather = BJCEnvironment.Data.controlWeather
                BJCEnvironment.set("controlWeather", true)
            end
            for k, v in pairs(M.weather.keys) do
                if BJCEnvironment.Data[k] then
                    M.previous.env[k] = BJCEnvironment.Data[k]
                    pcall(BJCEnvironment.set, k, v)
                end
            end
        end
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.ENVIRONMENT)
    end

    M.state = M.STATES.GRID
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.RACE)
    startGridTimeout(M.grid.timeout)
end

local function stop()
    if M.state then
        stopRace()
    end
end

--[[
returns array =
<ul>
    <li>playerID: number</li>
    <li>lap: number (current lap)</li>
    <li>wp: number (last lap waypoint reached)</li>
    <li>time: number (if first, race time)</li>
    <li>lapTime: number (if last wp was lap or finish, lap time)</li>
    <li>diff: number (if not first, last common waypoint difference with first player)</li>
</ul>
]]
local function parseLeaderboard()
    local res = {}
    for pos, lb in ipairs(M.race.leaderboard) do
        local lapTime
        local lap, wp = 1, 0
        local time, diff = 0, 0
        lap = #lb[2]
        while lap > 1 and #lb[2][lap].waypoints == 0 do
            lap = lap - 1
        end
        local wpPerLap = M.race.raceData.wpPerLap
        if #lb[2][lap].waypoints > 0 then
            -- after first waypoint of race
            if pos == 1 then
                -- first player
                for iWp = wpPerLap, 1, -1 do
                    if lb[2][lap].waypoints[iWp] then
                        wp = iWp
                        time = lb[2][lap].waypoints[iWp].race
                        break
                    end
                end
            else
                -- not first player
                local playerWp
                local diffFound = false
                -- might take different branch, so we find the last common wp time to create diff
                for iWp = wpPerLap, 1, -1 do
                    if lb[2][lap].waypoints[iWp] then
                        if not playerWp then
                            playerWp = iWp
                        end
                        local firstPlayerWp = M.race.leaderboard[1][2][lap] and
                            M.race.leaderboard[1][2][lap].waypoints[iWp] or nil
                        if firstPlayerWp then
                            diff = lb[2][lap].waypoints[iWp].race - firstPlayerWp.race
                            diffFound = true
                        end
                        if playerWp and diffFound then
                            break
                        end
                    end
                end
                wp = playerWp or 0
            end
        end

        if M.settings.laps and M.settings.laps > 1 and
            wp == wpPerLap then
            -- lap / finish
            lapTime = lb[2][lap].waypoints[wp].lap
            if lap < M.settings.laps then
                -- not finish (next lap with wp 0)
                lap = lap + 1
                wp = 0
            end
        end

        table.insert(res, {
            playerID = lb[1],
            lap = lap,
            wp = wp,
            time = time,
            lapTime = lapTime,
            diff = diff,
        })
    end
    return res
end

local function sortLeaderboard()
    if #M.race.leaderboard < 2 then
        return
    end

    local function getPlayerLapAndWpAndTime(lbLine)
        local lap = #lbLine[2]
        if tlength(lbLine[2][lap].waypoints) == 0 then
            lap = lap - 1
        end
        local wp, time = 0, 0
        for i = #M.baseRace.steps, 1, -1 do
            if lbLine[2][lap] and lbLine[2][lap].waypoints[i] then
                if lbLine[2][lap].waypoints[i] then
                    wp = i
                    time = lbLine[2][lap].waypoints[i].race
                    break
                end
            end
        end
        return lap, wp, time
    end

    -- sort players by most laps then most waypoints desc
    table.sort(M.race.leaderboard, function(a, b)
        if tincludes(M.race.eliminated, a[1], true) ~= tincludes(M.race.eliminated, b[1], true) then
            return not tincludes(M.race.eliminated, a[1], true)
        end

        local aLap, aWp, aTime = getPlayerLapAndWpAndTime(tdeepcopy(a))
        local bLap, bWp, bTime = getPlayerLapAndWpAndTime(tdeepcopy(b))

        if aLap ~= bLap then
            return aLap > bLap
        end
        if aWp ~= bWp then
            return aWp > bWp
        end
        return aTime < bTime
    end)
end

local function startFinishRace()
    M.state = M.STATES.FINISHED
    BJCAsync.delayTask(function()
        stopRace()
    end, BJCConfig.Data.Race.RaceEndTimeout)
end

local function onClientReachedWaypoint(playerID, currentWp, time)
    local pos
    for i, lbData in ipairs(M.race.leaderboard) do
        if lbData[1] == playerID then
            pos = i
            break
        end
    end
    if not pos then
        -- not a participant
        error({ key = "rx.errors.insufficientPermissions" })
    end

    -- determining current lap and wp
    local wpPerLap = M.race.raceData.wpPerLap
    local lap, wp = 1, currentWp
    if M.baseRace.loopable and M.settings.laps and M.settings.laps > 1 then
        while wp >= wpPerLap do
            wp = wp - wpPerLap
            lap = lap + 1
        end
        if lap > M.settings.laps then
            -- finished
            lap = M.settings.laps
            wp = wpPerLap
        end
    end

    -- save wp time
    if lap > 1 and wp == 0 then
        -- saving last lap last waypoint
        local lapLb = M.race.leaderboard[pos][2][lap - 1]
        lapLb.waypoints[wpPerLap] = {
            race = time,
            lap = time - lapLb.start,
        }
        -- init next lap data
        if lap then
            M.race.leaderboard[pos][2][lap] = {
                start = time,
                waypoints = {},
            }
        end
    else
        -- saving waypoint
        local lapLb = M.race.leaderboard[pos][2][lap]
        lapLb.waypoints[wp] = {
            race = time,
            lap = time - lapLb.start,
        }
    end

    -- on lap / finish
    if wp == wpPerLap then
        -- prepare player next lap in leaderboard
        if lap < (M.settings.laps or 1) then
            M.race.leaderboard[pos][2][lap + 1] = {
                start = time,
                waypoints = {},
            }
        end

        local lapTime = time - M.race.leaderboard[pos][2][lap].start
        -- check race record
        if not M.baseRace.record or M.baseRace.record.time > lapTime then
            BJCAsync.delayTask(function()
                local target = BJCPlayers.Players[playerID]
                if M.baseRace.record then
                    BJCPlayers.reward(playerID, BJCConfig.Data.Reputation.RaceRecordReward)
                end
                local _, err
                if not target.guest then
                    -- record save if not guest player
                    local vehID
                    for id in pairs(target.vehicles) do
                        vehID = id
                        break
                    end
                    M.baseRace.record = {
                        playerName = target.playerName,
                        model = target.vehicles[vehID].name,
                        time = lapTime,
                    }
                    _, err = pcall(BJCScenario.saveRaceRecord, M.baseRace.id, M.baseRace.record)
                    if not err then
                        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.RACES)
                    end
                end
                if not err then
                    -- broadcast new race record
                    BJCScenario.broadcastRaceRecord(M.baseRace.name, target.playerName, M.baseRace.record.time)
                end
            end, 1)
        end
    end

    sortLeaderboard()
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.RACE)
end

local function onClientUpdate(senderID, event, data)
    if M.state == M.STATES.GRID then
        if event == M.CLIENT_EVENTS.JOIN then
            if tincludes(M.grid.participants, senderID, true) then
                local pos = tpos(M.grid.participants, senderID)
                table.remove(M.grid.participants, pos)
            else
                table.insert(M.grid.participants, senderID)
            end

            BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.RACE)
        elseif event == M.CLIENT_EVENTS.READY then
            if not M.grid.readyTime or M.grid.readyTime > GetCurrentTime() then
                -- cannot be ready yet
                return
            end
            if not tincludes(M.grid.ready, senderID, true) then
                table.insert(M.grid.ready, senderID)
            end

            BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.RACE)

            checkRaceReady()
        end
    elseif M.state == M.STATES.RACE then
        if event == M.CLIENT_EVENTS.LEAVE then
            if not tincludes(M.race.eliminated, senderID, true) then
                table.insert(M.race.eliminated, senderID)
            end
            sortLeaderboard()
            BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.RACE)
            if #M.grid.participants - (#M.race.eliminated + #M.race.finished) == 0 then
                startFinishRace()
            end
        elseif event == M.CLIENT_EVENTS.CHECKPOINT_REACHED then
            local time = M.race.raceTimer and M.race.raceTimer:get() or 0
            onClientReachedWaypoint(senderID, data, time)
        elseif event == M.CLIENT_EVENTS.FINISH_REACHED then
            if not tincludes(M.race.finished, senderID, true) then
                table.insert(M.race.finished, senderID)
            end
            sortLeaderboard()
            -- apply winner rewards
            if #M.grid.participants > 1 then
                for _, playerID in ipairs(M.grid.participants) do
                    local pos
                    for i, lb in ipairs(M.race.leaderboard) do
                        if lb[1] == playerID then
                            pos = i
                            break
                        end
                    end
                    pos = pos or #M.race.leaderboard
                    local points = Round(BJCConfig.Data.Reputation.RaceWinnerReward / pos)
                    BJCPlayers.reward(playerID, points)
                end
            end
            -- detect race end
            if #M.race.finished + #M.race.eliminated == #M.race.leaderboard then
                startFinishRace()
            end
            BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.RACE)
        end
    end
end

local function canSpawnOrEditVehicle(playerID, vehID, vehData)
    if not M.state then
        return true
    elseif M.state == M.STATES.GRID and
        tincludes(M.grid.participants, playerID, true) and
        not tincludes(M.grid.ready, playerID, true) then
        local function onWrongVehicleAtGrid()
            table.remove(M.grid.participants, tpos(M.grid.participants, playerID))
            BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.RACE)
        end

        if not vehData then
            onWrongVehicleAtGrid()
            return false
        end

        if M.settings.model then
            if type(M.settings.config) == "table" then
                -- forced config
                M.settings.config = M.settings.config or {}
                local sameConfig = tdeepcompare({ model = vehData.vcf.model, parts = vehData.vcf.parts },
                    { model = M.settings.config.model, parts = M.settings.config.parts })
                if not sameConfig then
                    onWrongVehicleAtGrid()
                end
                return sameConfig
            else
                -- forced model
                local sameModel = M.settings.model == (vehData.jbm or vehData.vcf.model)
                if not sameModel then
                    onWrongVehicleAtGrid()
                end
                return sameModel
            end
        end
        -- no model restriction
        return true
    end
    -- during race or finished
    return false
end

local function onPlayerDisconnect(targetID)
    if M.state then
        local function removeFromGrid()
            local changed = false
            local pos = tpos(M.grid.ready, targetID)
            if pos then
                table.remove(M.grid.ready, pos)
                changed = true
            end

            pos = tpos(M.grid.participants, targetID)
            if pos then
                table.remove(M.grid.participants, pos)
                changed = true
            end
            return changed
        end

        if M.state == M.STATES.GRID then
            if removeFromGrid() then
                BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.RACE)
            end
        elseif M.state == M.STATES.RACE then
            local changed = removeFromGrid()
            local pos
            for i, lb in ipairs(M.race.leaderboard) do
                if lb[1] == targetID then
                    pos = i
                    break
                end
            end
            if pos then
                table.remove(M.race.leaderboard, pos)
                changed = true
            end
            pos = tpos(M.race.finished, targetID)
            if pos then
                table.remove(M.race.finished, pos)
                changed = true
            end
            pos = tpos(M.race.eliminated, targetID)
            if pos then
                table.remove(M.race.eliminated, pos)
                changed = true
            end

            if changed then
                BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.RACE)
                if #M.race.leaderboard == #M.race.finished + #M.race.eliminated then
                    startFinishRace()
                end
                BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.RACE)
            end
        end
    end
end

local function onVehicleDeleted(playerID, vehID)
    if M.state then
        if M.state == M.STATES.GRID and tincludes(M.grid.participants, playerID, true) then
            local pos = tpos(M.grid.participants, playerID)
            table.remove(M.grid.participants, pos)
            pos = tpos(M.grid.ready, playerID)
            if pos then
                table.remove(M.grid.ready, pos)
            end
            BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.RACE)
            checkRaceReady()
        elseif M.state == M.STATES.RACE and
            tincludes(M.grid.participants, playerID, true) and
            not tincludes(M.race.finished, playerID, true) and
            not tincludes(M.race.eliminated, playerID, true) then
            table.insert(M.race.eliminated, playerID)
            sortLeaderboard()
            BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.RACE)
        end
    end
end

local function getCache()
    return {
        -- common
        state = M.state,
        raceName = M.baseRace and M.baseRace.name or nil,
        raceAuthor = M.baseRace and M.baseRace.author or nil,
        record = M.baseRace and M.baseRace.record or nil,
        -- settings
        laps = M.settings.laps,
        model = M.settings.model,
        config = M.settings.config,
        respawnStrategy = M.settings.respawnStrategy,
        -- grid
        previewPosition = M.baseRace and M.baseRace.previewPosition or nil,
        startPositions = M.baseRace and M.baseRace.startPositions or nil,
        participants = M.grid.participants,
        ready = M.grid.ready,
        timeout = M.grid.timeout,
        readyTime = M.grid.readyTime,
        -- race
        steps = M.baseRace and M.baseRace.steps or nil,
        startTime = M.race.startTime,
        leaderboard = parseLeaderboard(),
        finished = M.race.finished,
        eliminated = M.race.eliminated,
    }, M.getCacheHash()
end

local function getCacheHash()
    return Hash({
        M.state,
        M.grid,
        M.race,
        M.baseRace and M.baseRace.record or nil,
    })
end

M.getCache = getCache
M.getCacheHash = getCacheHash

M.onClientStopRace = onClientStopRace

M.start = start
M.stop = stop

M.onClientUpdate = onClientUpdate
M.canSpawnVehicle = canSpawnOrEditVehicle
M.canEditVehicle = canSpawnOrEditVehicle

M.onPlayerDisconnect = onPlayerDisconnect

M.postVehicleDeleted = onVehicleDeleted

RegisterBJCManager(M)
return M
