local W = {
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
            baseTime = BJI.Utils.Common.RaceDelay(0),
            showFinalTime = false,
            finalTime = "",
            showForfeitBtn = false,
            disableButtons = false,
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
                isParticipant = false,
                showRemainingPlaces = false,
                remainingPlacesStr = "",
                showReadyBtn = false,
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

    ---@type BJIScenarioRaceMulti
    scenario = nil,
}

local function updateLabels()
    W.cache.labels.vSeparator = BJI.Managers.Lang.get("common.vSeparator")
    W.cache.labels.unknown = BJI.Managers.Lang.get("common.unknown")

    W.cache.labels.byAuthor = BJI.Managers.Lang.get("races.play.by"):var({ author = W.scenario.raceAuthor })
    W.cache.labels.lap = string.var("({1})", {
        W.scenario.settings.laps == 1 and
        BJI.Managers.Lang.get("races.settings.lap"):var({ lap = W.scenario.settings.laps }) or
        BJI.Managers.Lang.get("races.settings.laps"):var({ laps = W.scenario.settings.laps })
    })
    W.cache.labels.record = BJI.Managers.Lang.get("races.play.record")
    W.cache.labels.pb = string.var("{1} :", { BJI.Managers.Lang.get("races.leaderboard.pb") })
    W.cache.labels.gameStartsIn = BJI.Managers.Lang.get("races.play.gameStartsIn")
    W.cache.labels.flashCountdownZero = BJI.Managers.Lang.get("races.play.flashCountdownZero")
    W.cache.labels.eliminatedIn = BJI.Managers.Lang.get("races.play.eliminatedIn")
    W.cache.labels.eliminated = BJI.Managers.Lang.get("races.play.flashDnfOut")
    W.cache.labels.gameStartsIn = BJI.Managers.Lang.get("races.play.gameStartsIn")
    W.cache.labels.flashCountdownZero = BJI.Managers.Lang.get("races.play.flashCountdownZero")
    W.cache.labels.eliminatedIn = BJI.Managers.Lang.get("races.play.eliminatedIn")
    W.cache.labels.eliminated = BJI.Managers.Lang.get("races.play.flashDnfOut")

    W.cache.labels.wpCounter = BJI.Managers.Lang.get("races.play.WP")
    W.cache.labels.lapCounter = BJI.Managers.Lang.get("races.play.Lap")
    W.cache.labels.wpDifference = BJI.Managers.Lang.get("races.play.wpDifference")

    W.cache.labels.gridTimeout = BJI.Managers.Lang.get("races.play.timeout")
    W.cache.labels.placesRemaining = BJI.Managers.Lang.get("races.play.placesRemaining")
    W.cache.labels.markReadyCooldown = BJI.Managers.Lang.get("races.play.canMarkReadyIn")
    W.cache.labels.chooseYourVehicle = BJI.Managers.Lang.get("races.play.joinFlash")
    W.cache.labels.waitingForPlayers = BJI.Managers.Lang.get("races.play.waitingForOtherPlayers")
    W.cache.labels.players = string.var("{1}:", { BJI.Managers.Lang.get("races.play.players") })
    W.cache.labels.playerReady = BJI.Managers.Lang.get("races.play.playerReady")
    W.cache.labels.playerNotReady = BJI.Managers.Lang.get("races.play.playerNotReady")
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI.Managers.Tick.getContext()

    if not W.scenario.state then
        return -- race ends
    end

    W.cache.data.disableButtons = false

    -- header
    W.cache.data.showRecord = not not W.scenario.record
    W.cache.data.recordStr = W.cache.data.showRecord and W.cache.labels.record:var({
        playerName = W.scenario.record.playerName,
        model = BJI.Managers.Veh.getModelLabel(W.scenario.record.model) or W.scenario.record.model,
        time = BJI.Utils.Common.RaceDelay(W.scenario.record.time)
    }) or ""
    local _, pbTime = BJI.Managers.RaceWaypoint.getPB(W.scenario.raceHash)
    W.cache.data.showPb = pbTime and (not W.scenario.record or W.scenario.record.time ~= pbTime)
    W.cache.data.pbTime = W.cache.data.showPb and BJI.Utils.Common.RaceDelay(pbTime or 0) or ""
    W.cache.data.showForfeitBtn = W.scenario.isRaceStarted() and not W.scenario.isRaceFinished() and
        not W.scenario.isSpec()
    W.cache.data.startTime = W.scenario.race.startTime
    W.cache.data.hasStartTime = not not W.cache.data.startTime
    W.cache.data.DNFEnabled = W.scenario.settings.respawnStrategy ==
        BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.NO_RESPAWN.key
    W.cache.data.DNFData = W.scenario.dnf

    W.cache.data.raceTimer = W.scenario.race.timers.race or { get = function() return 0 end }
    W.cache.data.lapTimer = W.scenario.race.timers.lap or { get = function() return 0 end }
    W.cache.data.raceTimeOffset = W.scenario.race.timers.raceOffset or 0

    local wpPerLap = W.scenario.race.raceData.wpPerLap
    local leaderboard = W.scenario.race.leaderboard

    W.cache.data.showTimer = W.scenario.isRaceOrCountdownStarted() and not W.scenario.isRaceFinished()
    W.cache.data.showWpCounter = W.cache.data.showTimer and not W.scenario.isSpec()
    W.cache.data.wpCounter = W.cache.data.showWpCounter and string.var("{1}/{2}", {
        W.cache.labels.wpCounter:var({
            wp = Table(leaderboard):reduce(function(acc, lb)
                return BJI.Managers.Context.isSelf(lb.playerID) and lb.wp or acc
            end, 0)
        }),
        wpPerLap,
    }) or ""

    W.cache.data.grid.show = W.scenario.state == W.scenario.STATES.GRID
    W.cache.data.race.show = W.scenario.state >= W.scenario.STATES.RACE

    W.cache.data.showChooseYourVehicleLabel = false
    if W.cache.data.grid.show then
        local gridData = W.scenario.grid
        W.cache.data.showChooseYourVehicleLabel = table.includes(gridData.participants,
            BJI.Managers.Context.User.playerID)
        W.cache.data.grid.showJoinLeaveBtn = not table.includes(gridData.ready, BJI.Managers.Context.User.playerID) and
            BJI.Managers.Perm.canSpawnVehicle()
        W.cache.data.grid.isParticipant = table.includes(gridData.participants, BJI.Managers.Context.User.playerID)
        W.cache.data.grid.showRemainingPlaces = W.cache.data.grid.showJoinLeaveBtn and
            not W.cache.data.grid.isParticipant
        W.cache.data.grid.remainingPlacesStr = W.cache.data.grid.showRemainingPlaces and
            W.cache.labels.placesRemaining:var({
                places = math.max(#W.scenario.grid.startPositions - #W.scenario.grid.participants, 0)
            }) or ""
        W.cache.data.grid.showReadyBtn = W.cache.data.grid.showJoinLeaveBtn and
            not W.cache.data.grid.showRemainingPlaces and BJI.Managers.Veh.isCurrentVehicleOwn()
        W.cache.data.grid.readyCooldownTime = gridData.readyTime
        W.cache.data.grid.participantsList = Table(gridData.participants):map(function(pid)
            local readyState = table.includes(gridData.ready, pid)
            return {
                playerName = BJI.Managers.Context.Players[pid].playerName,
                readyState = readyState,
                readyLabel = string.var("({1})",
                    { readyState and W.cache.labels.playerReady or W.cache.labels.playerNotReady }),
            }
        end)
    end

    if W.cache.data.race.show then
        W.cache.data.race.colWidths = Table()
        local isSpec = W.scenario.isSpec()
        if isSpec then
            W.cache.data.race.colWidths:insert(1, GetBtnIconSize())
        end

        local playerNames = Table()
        table.insert(W.cache.data.race.colWidths, Table(leaderboard):reduce(function(acc, lb, i)
            local player = BJI.Managers.Context.Players[lb.playerID]
            playerNames[i] = player and player.playerName or W.cache.labels.unknown
            local w = BJI.Utils.Common.GetColumnTextWidth(playerNames[i])
            return w > acc and w or acc
        end, 0))

        local showLapCol = W.scenario.settings.laps and W.scenario.settings.laps > 1
        if showLapCol then
            table.insert(W.cache.data.race.colWidths, Range(1, W.scenario.settings.laps):reduce(function(acc, i)
                local label = W.cache.labels.lapCounter:var({ lap = i })
                local w = BJI.Utils.Common.GetColumnTextWidth(label)
                return w > acc and w or acc
            end, 0))
        end

        table.insert(W.cache.data.race.colWidths, Range(1, wpPerLap):reduce(function(acc, i)
            local label = W.cache.labels.wpCounter:var({ wp = i })
            local w = BJI.Utils.Common.GetColumnTextWidth(label)
            return w > acc and w or acc
        end, 0))
        table.insert(W.cache.data.race.colWidths, -1)

        local firstPlayerCurrentWp
        W.cache.data.race.cols = Table(leaderboard):map(function(lb, i)
            local playerCurrentWP = lb.wp
            local playerLap = lb.lap
            if playerCurrentWP > 1 then
                playerLap = playerLap - 1
            end
            playerCurrentWP = playerCurrentWP + (playerLap * wpPerLap)
            if i == 1 then
                firstPlayerCurrentWp = playerCurrentWP
            end

            local color = playerNames[i] == BJI.Managers.Context.User.playerName and
                BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT
            local cells = {}
            if isSpec then
                table.insert(cells, function()
                    local ctxt2 = BJI.Managers.Tick.getContext()
                    local target = BJI.Managers.Context.Players[lb.playerID]
                    local disabled = table.includes(W.scenario.race.finished, lb.playerID) or
                        table.includes(W.scenario.race.eliminated, lb.playerID) or
                        not target
                    if not disabled then
                        local finalGameVehID = BJI.Managers.Veh.getVehicleObject(target.currentVehicle)
                        finalGameVehID = finalGameVehID and finalGameVehID:getID() or nil
                        disabled = finalGameVehID and ctxt2.veh and ctxt2.veh:getID() == finalGameVehID or false
                    end
                    LineBuilder()
                        :btnIcon({
                            id = string.var("watchPlayer{1}", { i }),
                            icon = ICONS.visibility,
                            disabled = disabled,
                            onClick = function()
                                BJI.Managers.Veh.focus(lb.playerID)
                                BJI.Managers.Cam.setCamera(BJI.Managers.Cam.CAMERAS.ORBIT)
                            end
                        })
                        :build()
                end)
            end
            table.insert(cells, function() LineLabel(playerNames[i], color) end)
            if showLapCol then
                table.insert(cells, function() LineLabel(W.cache.labels.lapCounter:var({ lap = lb.lap }), color) end)
            end
            table.insert(cells, function() LineLabel(W.cache.labels.wpCounter:var({ wp = lb.wp }), color) end)
            local playerTime = BJI.Utils.Common.RaceDelay(lb.time or 0)
            local diffLabel = i > 1 and W.cache.labels.wpDifference
                :var({ wpDifference = firstPlayerCurrentWp - playerCurrentWP }) or ""
            local diffVal = math.abs(lb.diff or 0)
            local diffTime = string.var("+{1}", { BJI.Utils.Common.RaceDelay(diffVal) })
            local diffColor = diffVal > 0 and BJI.Utils.Style.TEXT_COLORS.ERROR or BJI.Utils.Style.TEXT_COLORS.DEFAULT
            table.insert(cells, function()
                if i == 1 then
                    -- first player
                    LineLabel(playerTime)
                else
                    -- next players
                    local line = LineBuilder()
                    if playerCurrentWP < firstPlayerCurrentWp then
                        line:text(diffLabel, BJI.Utils.Style.TEXT_COLORS.ERROR):text(W.cache.labels.vSeparator)
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
    W.scenario = BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.RACE_MULTI)

    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, function(ctxt)
        updateLabels()
        updateCache(ctxt)
    end))

    updateCache()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.PLAYER_CONNECT,
        BJI.Managers.Events.EVENTS.PLAYER_DISCONNECT,
        BJI.Managers.Events.EVENTS.VEHICLE_SPAWNED,
        BJI.Managers.Events.EVENTS.RACE_NEW_PB,
        BJI.Managers.Events.EVENTS.SCENARIO_UPDATED,
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED,
    }, updateCache))
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.CACHE_LOADED, function(ctxt, data)
        if data.cache == BJI.Managers.Cache.CACHES.RACES then
            updateCache(ctxt)
        end
    end))

    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        function()
            if W.scenario.isRaceOrCountdownStarted() and
                W.scenario.isParticipant() and
                not BJI.Managers.Perm.canSpawnVehicle() then
                -- permission loss
                BJI.Tx.scenario.RaceMultiUpdate(W.scenario.CLIENT_EVENTS.LEAVE)
            end
        end))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

---@param time integer
---@param now integer
---@return integer
local function getDiffTime(time, now)
    if not time then
        return 0
    end
    return math.ceil((time - now) / 1000)
end

---@param ctxt TickContext
local function header(ctxt)
    local line = LineBuilder()
        :text(W.scenario.raceName)
        :text(W.cache.labels.byAuthor)
    if W.scenario.settings.laps then
        line:text(W.cache.labels.lap)
    end
    line:build()

    if W.cache.data.showRecord then
        LineBuilder()
            :text(W.cache.data.recordStr)
            :build()
    else
        EmptyLine()
    end

    if W.cache.data.showPb then
        LineBuilder()
            :text(W.cache.labels.pb)
            :text(W.cache.data.pbTime)
            :build()
    else
        EmptyLine()
    end

    if W.cache.data.showForfeitBtn then
        LineBuilder()
            :btnIcon({
                id = "forfeitRace",
                icon = ICONS.exit_to_app,
                style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                disabled = W.cache.data.disableButtons,
                onClick = function()
                    W.cache.data.disableButtons = true -- api request protection
                    BJI.Tx.scenario.RaceMultiUpdate(W.scenario.CLIENT_EVENTS.LEAVE)
                end,
                big = true,
            })
            :build()
    end

    if W.cache.data.showTimer then
        LineBuilder():icon({ icon = ICONS.flag })
            :text(BJI.Utils.Common.RaceDelay(W.cache.data.raceTimer:get() + W.cache.data.raceTimeOffset))
            :build()

        if W.cache.data.showWpCounter then
            LineBuilder():icon({ icon = ICONS.timer })
                :text(W.cache.data.wpCounter)
                :text(BJI.Utils.Common.RaceDelay(W.cache.data.lapTimer:get() + W.cache.data.raceTimeOffset))
                :build()
        end

        EmptyLine()
    end

    line = LineBuilder()
        :icon({
            icon = ICONS.timer,
            big = true,
        })

    if W.cache.data.showChooseYourVehicleLabel and not ctxt.isOwner then
        line:text(W.cache.labels.chooseYourVehicle, BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT)
    end

    if W.cache.data.hasStartTime then
        local remaining = getDiffTime(W.cache.data.startTime, ctxt.now)
        if remaining > 0 then
            line:text(W.cache.labels.gameStartsIn:var({ delay = BJI.Utils.Common.PrettyDelay(remaining) }))
        elseif remaining > -3 then
            line:text(W.cache.labels.flashCountdownZero)
        elseif W.cache.data.DNFEnabled and W.cache.data.DNFData.process and W.cache.data.DNFData.targetTime then
            remaining = getDiffTime(W.cache.data.DNFData.targetTime, ctxt.now)
            if remaining < W.cache.data.DNFData.timeout then
                local color = remaining > 3 and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or
                    BJI.Utils.Style.TEXT_COLORS.ERROR
                if remaining > 0 then
                    line:text(W.cache.labels.eliminatedIn:var({ delay = BJI.Utils.Common.PrettyDelay(math.abs(remaining)) }))
                else
                    line:text(W.cache.labels.eliminated, color)
                end
            end
        end
    end

    line:build()
end

---@param ctxt TickContext
local function drawGrid(ctxt)
    local gridTimeoutRemaining = getDiffTime(W.scenario.grid.timeout, ctxt.now)
    LineBuilder()
        :text(W.cache.labels.gridTimeout
            :var({ delay = BJI.Utils.Common.PrettyDelay(gridTimeoutRemaining) }),
            gridTimeoutRemaining < 3 and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT)
        :build()

    if W.cache.data.grid.showJoinLeaveBtn then
        local line = LineBuilder()
            :btnIconToggle({
                id = "joinRace",
                icon = W.cache.data.grid.isParticipant and ICONS.exit_to_app or ICONS.videogame_asset,
                state = not W.cache.data.grid.isParticipant,
                disabled = W.cache.data.disableButtons,
                onClick = function()
                    W.cache.data.disableButtons = true -- api request protection
                    BJI.Tx.scenario.RaceMultiUpdate(W.scenario.CLIENT_EVENTS.JOIN)
                end,
                big = true,
            })
        if W.cache.data.grid.showRemainingPlaces then
            line:text(W.cache.data.grid.remainingPlacesStr)
        elseif W.cache.data.grid.showReadyBtn then
            local showReadyCooldown = ctxt.now < W.cache.data.grid.readyCooldownTime
            line:btnIcon({
                id = "raceReady",
                icon = ICONS.check,
                style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                disabled = W.cache.data.disableButtons or showReadyCooldown,
                onClick = function()
                    W.cache.data.disableButtons = true -- api request protection
                    BJI.Tx.scenario.RaceMultiUpdate(W.scenario.CLIENT_EVENTS.READY)
                end,
                big = true,
            })
            if showReadyCooldown then
                line:text(W.cache.labels.markReadyCooldown:var({
                    delay = BJI.Utils.Common.PrettyDelay(getDiffTime(W.cache.data.grid.readyCooldownTime, ctxt.now))
                }))
            end
        end
        line:build()
    else
        LineBuilder():text(W.cache.labels.waitingForPlayers):build()
    end

    if #W.scenario.grid.participants > 0 then
        LineBuilder():text(W.cache.labels.players):build()
        Indent(2)
        W.cache.data.grid.participantsList:forEach(function(player, i)
            local color = player.readyState and BJI.Utils.Style.TEXT_COLORS.SUCCESS or
                BJI.Utils.Style.TEXT_COLORS.DEFAULT
            LineBuilder():text(i):text(player.playerName, color)
                :text(player.readyLabel, color):build()
        end)
        Indent(-2)
    end
end

---@param ctxt TickContext
local function drawRace(ctxt)
    local cols = ColumnsBuilder("BJIRaceMultiLeaderboard", W.cache.data.race.colWidths, true)
    W.cache.data.race.cols:forEach(function(colData)
        cols:addRow(colData)
    end)
    cols:build()
end

---@param ctxt TickContext
local function body(ctxt)
    if W.cache.data.grid.show then
        drawGrid(ctxt)
    elseif W.cache.data.race.show then
        drawRace(ctxt)
    end
end

W.onLoad = onLoad
W.onUnload = onUnload

W.header = header
W.body = body

return W
