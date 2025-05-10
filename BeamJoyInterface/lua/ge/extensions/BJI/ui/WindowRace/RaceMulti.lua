local M = {
    mgr = BJIScenario.get(BJIScenario.TYPES.RACE_MULTI),

    cache = {
        data = {
            showRecord = false,
            recordStr = "",
            showPb = false,
            pbTime = "",

            ---@type Timer
            raceTimer = nil,
            ---@type Timer
            lapTimer = nil,
            raceTimeOffset = 0,
            baseTime = RaceDelay(0),
            showFinalTime = false,
            finalTime = "",
            showForfeitBtn = false,
            disableForfeitBtn = false,
            showTimer = false,
            showWpCounter = false,
            wpCounter = "",
            hasStartTime = false,
            startTime = 0,
            showChooseYourVehicleLabel = false,
            DNFEnabled = false,
            ---@type {timeout: number, process: boolean, targetTime?: integer}
            DNFData = {},

            showRaceData = false,

            grid = {
                show = false,
                showJoinLeaveBtn = false,
                disableJoinLeaveBtn = false,
                isParticipant = false,
                showRemainingPlaces = false,
                remainingPlacesStr = "",
                showReadyBtn = false,
                disableReadyBtn = false,
                readyCooldownTime = 0,
                ---@type {playerName: string, readyState: boolean, readyLabel: string}[]
                participantsList = Table(),
            },

            race = {
                show = false,
                ---@type integer[]
                colWidths = {},
                ---@type {cells: function[]}[]
                cols = {},
            },
        },

        labels = {
            vSeparator = "",
            unknown = "",

            byAuthor = "",
            lap = "",
            record = "",
            pb = "",
            gameStartsIn = "",
            flashCountdownZero = "",
            eliminatedIn = "",
            eliminated = "",

            wpCounter = "",
            lapCounter = "",
            wpDifference = "",

            gridTimeout = "",
            placesRemaining = "",
            markReadyCooldown = "",
            chooseYourVehicle = "",
            waitingForPlayers = "",
            players = "",
            playerReady = "",
            playerNotReady = "",
        },
    },
}

local function updateLabels()
    M.cache.labels.vSeparator = BJILang.get("common.vSeparator")
    M.cache.labels.unknown = BJILang.get("common.unknown")

    M.cache.labels.byAuthor = BJILang.get("races.play.by"):var({ author = M.mgr.raceAuthor })
    M.cache.labels.lap = string.var("({1})", {
        M.mgr.settings.laps == 1 and
        BJILang.get("races.settings.lap"):var({ lap = M.mgr.settings.laps }) or
        BJILang.get("races.settings.laps"):var({ laps = M.mgr.settings.laps })
    })
    M.cache.labels.record = BJILang.get("races.play.record")
    M.cache.labels.pb = string.var("{1} :", { BJILang.get("races.leaderboard.pb") })
    M.cache.labels.gameStartsIn = BJILang.get("races.play.gameStartsIn")
    M.cache.labels.flashCountdownZero = BJILang.get("races.play.flashCountdownZero")
    M.cache.labels.eliminatedIn = BJILang.get("races.play.eliminatedIn")
    M.cache.labels.eliminated = BJILang.get("races.play.flashDnfOut")
    M.cache.labels.gameStartsIn = BJILang.get("races.play.gameStartsIn")
    M.cache.labels.flashCountdownZero = BJILang.get("races.play.flashCountdownZero")
    M.cache.labels.eliminatedIn = BJILang.get("races.play.eliminatedIn")
    M.cache.labels.eliminated = BJILang.get("races.play.flashDnfOut")

    M.cache.labels.wpCounter = BJILang.get("races.play.WP")
    M.cache.labels.lapCounter = BJILang.get("races.play.Lap")
    M.cache.labels.wpDifference = BJILang.get("races.play.wpDifference")

    M.cache.labels.gridTimeout = BJILang.get("races.play.timeout")
    M.cache.labels.placesRemaining = BJILang.get("races.play.placesRemaining")
    M.cache.labels.markReadyCooldown = BJILang.get("races.play.canMarkReadyIn")
    M.cache.labels.chooseYourVehicle = BJILang.get("races.play.joinFlash")
    M.cache.labels.waitingForPlayers = BJILang.get("races.play.waitingForOtherPlayers")
    M.cache.labels.players = string.var("{1}:", { BJILang.get("races.play.players") })
    M.cache.labels.playerReady = BJILang.get("races.play.playerReady")
    M.cache.labels.playerNotReady = BJILang.get("races.play.playerNotReady")
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJITick.getContext()

    -- header
    M.cache.data.showRecord = not not M.mgr.record
    M.cache.data.recordStr = M.cache.labels.record:var({
        playerName = M.mgr.record.playerName,
        model = BJIVeh.getModelLabel(M.mgr.record.model) or M.mgr.record.model,
        time = RaceDelay(M.mgr.record.time)
    })
    local _, pbTime = BJIRaceWaypoint.getPB(M.mgr.raceHash)
    M.cache.data.showPb = pbTime and (not M.mgr.record or M.mgr.record.time ~= pbTime)
    M.cache.data.pbTime = M.cache.data.showPb and RaceDelay(pbTime) or ""
    M.cache.data.showForfeitBtn = M.mgr.isRaceStarted() and not M.mgr.isRaceFinished() and not M.mgr.isSpec()
    M.cache.data.startTime = M.mgr.race.startTime
    M.cache.data.hasStartTime = not not M.cache.data.startTime
    M.cache.data.DNFEnabled = M.mgr.settings.respawnStrategy == BJI_RACES_RESPAWN_STRATEGIES.NO_RESPAWN.key
    M.cache.data.DNFData = M.mgr.dnf

    M.cache.data.raceTimer = M.mgr.race.timers.race or { get = function() return 0 end }
    M.cache.data.lapTimer = M.mgr.race.timers.lap or { get = function() return 0 end }
    M.cache.data.raceTimeOffset = M.mgr.race.timers.raceOffset or 0

    local wpPerLap = M.mgr.race.raceData.wpPerLap
    local leaderboard = M.mgr.race.leaderboard

    M.cache.data.showTimer = M.mgr.isRaceOrCountdownStarted() and not M.mgr.isRaceFinished()
    M.cache.data.showWpCounter = M.cache.data.showTimer and not M.mgr.isSpec()
    M.cache.data.wpCounter = M.cache.data.showWpCounter and string.var("{1}/{2}", {
        M.cache.labels.wpCounter:var({
            wp = Table(leaderboard):reduce(function(acc, lb)
                return BJIContext.isSelf(lb.playerID) and lb.wp or acc
            end, 0)
        }),
        wpPerLap,
    }) or ""

    M.cache.data.grid.show = M.mgr.state == M.mgr.STATES.GRID
    M.cache.data.race.show = M.mgr.state >= M.mgr.STATES.RACE

    M.cache.data.showChooseYourVehicleLabel = false
    if M.cache.data.grid.show then
        local gridData = M.mgr.grid
        M.cache.data.showChooseYourVehicleLabel = table.includes(gridData.participants, BJIContext.User.playerID)
        M.cache.data.grid.showJoinLeaveBtn = not table.includes(gridData.ready, BJIContext.User.playerID)
        M.cache.data.grid.disableJoinLeaveBtn = false
        M.cache.data.grid.isParticipant = table.includes(gridData.participants, BJIContext.User.playerID)
        M.cache.data.grid.showRemainingPlaces = M.cache.data.grid.showJoinLeaveBtn and
            not M.cache.data.grid.isParticipant
        M.cache.data.grid.remainingPlacesStr = M.cache.data.grid.showRemainingPlaces and
            M.cache.labels.placesRemaining:var({
                places = math.max(#M.mgr.grid.startPositions - #M.mgr.grid.participants, 0)
            }) or ""
        M.cache.data.grid.showReadyBtn = M.cache.data.grid.showJoinLeaveBtn and
            not M.cache.data.grid.showRemainingPlaces and BJIVeh.isCurrentVehicleOwn()
        M.cache.data.grid.readyCooldownTime = gridData.readyTime
        M.cache.data.grid.participantsList = Table(gridData.participants):map(function(pid)
            local readyState = table.includes(gridData.ready, pid)
            return {
                playerName = BJIContext.Players[pid].playerName,
                readyState = readyState,
                readyLabel = string.var("({1})",
                    { readyState and M.cache.labels.playerReady or M.cache.labels.playerNotReady }),
            }
        end)
    end

    if M.cache.data.race.show then
        M.cache.data.race.colWidths = Table()
        local isSpec = M.mgr.isSpec()
        if isSpec then
            M.cache.data.race.colWidths:insert(1, GetBtnIconSize())
        end

        local playerNames = Table()
        table.insert(M.cache.data.race.colWidths, Table(leaderboard):reduce(function(acc, lb, i)
            local player = BJIContext.Players[lb.playerID]
            playerNames[i] = player and player.playerName or M.cache.labels.unknown
            local w = GetColumnTextWidth(playerNames[i])
            return w > acc and w or acc
        end, 0))

        local showLapCol = M.mgr.settings.laps and M.mgr.settings.laps > 1
        if showLapCol then
            table.insert(M.cache.data.race.colWidths, Range(1, M.mgr.settings.laps):reduce(function(acc, i)
                local label = M.cache.labels.lapCounter:var({ lap = i })
                local w = GetColumnTextWidth(label)
                return w > acc and w or acc
            end, 0))
        end

        table.insert(M.cache.data.race.colWidths, Range(1, wpPerLap):reduce(function(acc, i)
            local label = M.cache.labels.wpCounter:var({ wp = i })
            local w = GetColumnTextWidth(label)
            return w > acc and w or acc
        end, 0))
        table.insert(M.cache.data.race.colWidths, -1)

        local firstPlayerCurrentWp
        M.cache.data.race.cols = Table(leaderboard):map(function(lb, i)
            local playerCurrentWP = lb.wp
            local playerLap = lb.lap
            if playerCurrentWP > 1 then
                playerLap = playerLap - 1
            end
            playerCurrentWP = playerCurrentWP + (playerLap * wpPerLap)
            if i == 1 then
                firstPlayerCurrentWp = playerCurrentWP
            end

            local color = playerNames[i] == BJIContext.User.playerName and TEXT_COLORS.HIGHLIGHT or TEXT_COLORS.DEFAULT
            local cells = {}
            if isSpec then
                table.insert(cells, function(ctxt2)
                    local target = BJIContext.Players[lb.playerID]
                    local disabled = table.includes(M.mgr.race.finished, lb.playerID) or
                        table.includes(M.mgr.race.eliminated, lb.playerID) or
                        not target
                    if not disabled then
                        local finalGameVehID = BJIVeh.getVehicleObject(target.currentVehicle)
                        finalGameVehID = finalGameVehID and finalGameVehID:getID() or nil
                        disabled = finalGameVehID and ctxt2.veh and ctxt2.veh:getID() == finalGameVehID or false
                    end
                    LineBuilder()
                        :btnIcon({
                            id = string.var("watchPlayer{1}", { i }),
                            icon = ICONS.visibility,
                            disabled = disabled,
                            onClick = function()
                                BJIVeh.focus(lb.playerID)
                                BJICam.setCamera(BJICam.CAMERAS.ORBIT)
                            end
                        })
                        :build()
                end)
            end
            table.insert(cells, function()
                LineBuilder()
                    :text(playerNames[i], color)
                    :build()
            end)
            if showLapCol then
                table.insert(cells, function()
                    LineBuilder()
                        :text(M.cache.labels.lapCounter:var({ lap = lb.lap }), color)
                        :build()
                end)
            end
            table.insert(cells, function()
                LineBuilder()
                    :text(M.cache.labels.wpCounter:var({ wp = lb.wp }), color)
                    :build()
            end)
            local playerTime = RaceDelay(lb.time or 0)
            local diffLabel = i > 1 and M.cache.labels.wpDifference
                :var({ wpDifference = firstPlayerCurrentWp - playerCurrentWP }) or ""
            local diffVal = math.abs(lb.diff or 0)
            local diffTime = string.var("+{1}", { RaceDelay(diffVal) })
            local diffColor = diffVal > 0 and TEXT_COLORS.ERROR or TEXT_COLORS.DEFAULT
            table.insert(cells, function()
                if i == 1 then
                    -- first player
                    LineBuilder():text(playerTime):build()
                else
                    -- next players
                    local line = LineBuilder()
                    if playerCurrentWP < firstPlayerCurrentWp then
                        line:text(diffLabel, TEXT_COLORS.ERROR):text(M.cache.labels.vSeparator)
                    end
                    line:text(diffTime, diffColor):build()
                end
            end)
            return { cells = cells }
        end)
    end
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJIEvents.addListener({
        BJIEvents.EVENTS.LANG_CHANGED,
        BJIEvents.EVENTS.UI_UPDATE_REQUEST,
    }, function(ctxt)
        updateLabels()
        updateCache(ctxt)
    end))

    updateCache()
    listeners:insert(BJIEvents.addListener({
        BJIEvents.EVENTS.PLAYER_CONNECT,
        BJIEvents.EVENTS.PLAYER_DISCONNECT,
        BJIEvents.EVENTS.VEHICLE_SPAWNED,
        BJIEvents.EVENTS.RACE_NEW_PB,
        BJIEvents.EVENTS.SCENARIO_UPDATED,
        BJIEvents.EVENTS.UI_SCALE_CHANGED,
    }, updateCache))
    listeners:insert(BJIEvents.addListener(BJIEvents.EVENTS.CACHE_LOADED, function(ctxt, data)
        if data.cache == BJICache.CACHES.RACES then
            updateCache(ctxt)
        end
    end))
end

local function onUnload()
    listeners:forEach(BJIEvents.removeListener)
    M.cache.data.disableForfeitBtn = false
    M.cache.data.grid.disableReadyBtn = false
end

local function getDiffTime(time, now)
    if not time then
        return 0
    end
    return math.ceil((time - now) / 1000)
end

local function drawHeader(ctxt)
    M.mgr = BJIScenario.get(BJIScenario.TYPES.RACE_MULTI)

    local line = LineBuilder()
        :text(M.mgr.raceName)
        :text(M.cache.labels.byAuthor)
    if M.mgr.settings.laps then
        line:text(M.cache.labels.lap)
    end
    line:build()

    if M.cache.data.showRecord then
        LineBuilder()
            :text(M.cache.data.recordStr)
            :build()
    else
        EmptyLine()
    end

    if M.cache.data.showPb then
        LineBuilder()
            :text(M.cache.labels.pb)
            :text(M.cache.data.pbTime)
            :build()
    else
        EmptyLine()
    end

    if M.cache.data.showForfeitBtn then
        LineBuilder()
            :btnIcon({
                id = "forfeitRace",
                icon = ICONS.exit_to_app,
                style = BTN_PRESETS.ERROR,
                disabled = M.cache.data.disableForfeitBtn,
                onClick = function()
                    M.cache.data.disableForfeitBtn = true -- api request protection
                    BJITx.scenario.RaceMultiUpdate(M.mgr.CLIENT_EVENTS.LEAVE)
                end,
                big = true,
            })
            :build()
    end

    if M.cache.data.showTimer then
        LineBuilder():icon({ icon = ICONS.flag })
            :text(RaceDelay(M.cache.data.raceTimer:get() + M.cache.data.raceTimeOffset))
            :build()

        if M.cache.data.showWpCounter then
            LineBuilder():icon({ icon = ICONS.timer })
                :text(M.cache.data.wpCounter)
                :text(RaceDelay(M.cache.data.lapTimer:get() + M.cache.data.raceTimeOffset))
                :build()
        end

        EmptyLine()
    end

    line = LineBuilder()
        :icon({
            icon = ICONS.timer,
            big = true,
        })

    if M.cache.data.showChooseYourVehicleLabel and not ctxt.isOwner then
        line:text(M.cache.labels.chooseYourVehicle, TEXT_COLORS.HIGHLIGHT)
    end

    if M.cache.data.hasStartTime then
        local remaining = getDiffTime(M.cache.data.startTime, ctxt.now)
        if remaining > 0 then
            line:text(M.cache.labels.gameStartsIn:var({ delay = PrettyDelay(remaining) }))
        elseif remaining > -3 then
            line:text(M.cache.labels.flashCountdownZero)
        elseif M.cache.data.DNFEnabled and M.cache.data.DNFData.process and M.cache.data.DNFData.targetTime then
            remaining = getDiffTime(M.cache.data.DNFData.targetTime, ctxt.now)
            if remaining < M.cache.data.DNFData.timeout then
                local color = remaining > 3 and TEXT_COLORS.HIGHLIGHT or TEXT_COLORS.ERROR
                if remaining > 0 then
                    line:text(M.cache.labels.eliminatedIn:var({ delay = PrettyDelay(math.abs(remaining)) }))
                else
                    line:text(M.cache.labels.eliminated, color)
                end
            end
        end
    end

    line:build()
end

local function drawGrid(ctxt)
    local gridTimeoutRemaining = getDiffTime(M.mgr.grid.timeout, ctxt.now)
    LineBuilder()
        :text(M.cache.labels.gridTimeout
            :var({ delay = PrettyDelay(gridTimeoutRemaining) }),
            gridTimeoutRemaining < 3 and TEXT_COLORS.HIGHLIGHT or TEXT_COLORS.DEFAULT)
        :build()

    if M.cache.data.grid.showJoinLeaveBtn then
        local line = LineBuilder()
            :btnIconToggle({
                id = "joinRace",
                icon = M.cache.data.grid.isParticipant and ICONS.exit_to_app or ICONS.videogame_asset,
                state = not M.cache.data.grid.isParticipant,
                disabled = M.cache.data.grid.disableJoinLeaveBtn,
                onClick = function()
                    M.cache.data.grid.disableJoinLeaveBtn = true -- api request protection
                    if M.cache.data.grid.isParticipant then
                        M.cache.data.grid.disableReadyBtn = true -- api request protection
                    end
                    BJITx.scenario.RaceMultiUpdate(M.mgr.CLIENT_EVENTS.JOIN)
                    if M.cache.data.grid.isParticipant and BJIVeh.isCurrentVehicleOwn() then
                        BJIVeh.deleteAllOwnVehicles()
                    end
                end,
                big = true,
            })
        if M.cache.data.grid.showRemainingPlaces then
            line:text(M.cache.data.grid.remainingPlacesStr)
        elseif M.cache.data.grid.showReadyBtn then
            local showReadyCooldown = ctxt.now < M.cache.data.grid.readyCooldownTime
            line:btnIcon({
                id = "raceReady",
                icon = ICONS.done,
                style = BTN_PRESETS.SUCCESS,
                disabled = M.cache.data.grid.disableReadyBtn or showReadyCooldown,
                onClick = function()
                    M.cache.data.grid.disableReadyBtn = true -- api request protection
                    M.cache.data.grid.disableJoinLeaveBtn = true -- api request protection
                    BJITx.scenario.RaceMultiUpdate(M.mgr.CLIENT_EVENTS.READY)
                end,
                big = true,
            })
            if showReadyCooldown then
                line:text(M.cache.labels.markReadyCooldown:var({
                    delay = PrettyDelay(getDiffTime(M.cache.data.grid.readyCooldownTime, ctxt.now))
                }))
            end
        end
        line:build()
    else
        LineBuilder():text(M.cache.labels.waitingForPlayers):build()
    end

    if #M.mgr.grid.participants > 0 then
        LineBuilder():text(M.cache.labels.players):build()
        Indent(2)
        M.cache.data.grid.participantsList:forEach(function(player, i)
            local color = player.readyState and TEXT_COLORS.SUCCESS or TEXT_COLORS.DEFAULT
            LineBuilder():text(i):text(player.playerName, color)
                :text(player.readyLabel, color):build()
        end)
        Indent(-2)
    end
end

local function drawRace(ctxt)
    local cols = ColumnsBuilder("BJIRaceMultiLeaderboard", M.cache.data.race.colWidths, true)
    M.cache.data.race.cols:forEach(function(colData)
        cols:addRow(colData)
    end)
    cols:build()
end

local function drawBody(ctxt)
    if M.cache.data.grid.show then
        drawGrid(ctxt)
    elseif M.cache.data.race.show then
        drawRace(ctxt)
    end
end

M.onLoad = onLoad
M.onUnload = onUnload

M.header = drawHeader
M.body = drawBody

return M
