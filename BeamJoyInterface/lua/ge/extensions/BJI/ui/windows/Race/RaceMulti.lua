local W = {
    name = "RaceMulti",

    cache = {
        data = {
            showRecord = false,
            recordTime = "",
            recordTooltip = "",
            recordColor = nil,
            showPb = false,
            pbTime = "",
            pbWidth = 0,

            ---@type Timer
            raceTimer = nil,
            ---@type Timer
            lapTimer = nil,
            raceTimeOffset = 0,
            baseTime = BJI.Utils.UI.RaceDelay(0),
            showFinalTime = false,
            finalTime = "",
            showForfeitBtn = false,
            showManualResetBtn = false,
            showLaunchedRespawnBtn = false,
            manualResetWidth = 0,
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
            gridAboutToTimeout = "",
            placesRemaining = "",
            markReadyCooldown = "",
            chooseYourVehicle = "",
            waitingForPlayers = "",
            players = "",
            playerReady = "",
            playerNotReady = "",

            buttons = {
                join = "",
                spectate = "",
                markReady = "",
                forfeit = "",
                show = "",
                launchedRespawn = "",
                manualReset = "",
            },
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
    W.cache.labels.record = BJI.Managers.Lang.get("races.play.record") .. " :"
    W.cache.labels.pb = BJI.Managers.Lang.get("races.leaderboard.pb") .. " :"
    W.cache.labels.gameStartsIn = BJI.Managers.Lang.get("races.play.gameStartsIn")
    W.cache.labels.flashCountdownZero = BJI.Managers.Lang.get("races.play.flashCountdownZero")
    W.cache.labels.eliminatedIn = BJI.Managers.Lang.get("races.play.eliminatedIn")
    W.cache.labels.eliminated = BJI.Managers.Lang.get("races.play.eliminatedTime")

    W.cache.labels.wpCounter = BJI.Managers.Lang.get("races.play.WP")
    W.cache.labels.lapCounter = BJI.Managers.Lang.get("races.play.Lap")
    W.cache.labels.wpDifference = BJI.Managers.Lang.get("races.play.wpDifference")

    W.cache.labels.gridTimeout = BJI.Managers.Lang.get("races.play.timeout")
    W.cache.labels.gridAboutToTimeout = BJI.Managers.Lang.get("races.play.aboutToTimeout")
    W.cache.labels.placesRemaining = BJI.Managers.Lang.get("races.play.placesRemaining")
    W.cache.labels.markReadyCooldown = BJI.Managers.Lang.get("races.play.canMarkReadyIn")
    W.cache.labels.chooseYourVehicle = BJI.Managers.Lang.get("races.play.joinFlash")
    W.cache.labels.waitingForPlayers = BJI.Managers.Lang.get("races.play.waitingForOtherPlayers")
    W.cache.labels.players = string.var("{1}:", { BJI.Managers.Lang.get("races.play.players") })
    W.cache.labels.playerReady = BJI.Managers.Lang.get("races.play.playerReady")
    W.cache.labels.playerNotReady = BJI.Managers.Lang.get("races.play.playerNotReady")

    W.cache.labels.buttons.join = BJI.Managers.Lang.get("common.buttons.join")
    W.cache.labels.buttons.spectate = BJI.Managers.Lang.get("common.buttons.spectate")
    W.cache.labels.buttons.markReady = BJI.Managers.Lang.get("common.buttons.markReady")
    W.cache.labels.buttons.forfeit = BJI.Managers.Lang.get("common.buttons.forfeit")
    W.cache.labels.buttons.show = BJI.Managers.Lang.get("common.buttons.show")
    W.cache.labels.launchedRespawn = BJI.Managers.Lang.get("races.play.launchedRespawn")
    W.cache.labels.buttons.manualReset = BJI.Managers.Lang.get("common.buttons.manualReset")
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
    W.cache.data.recordTime = W.cache.data.showRecord and
        BJI.Utils.UI.RaceDelay(W.scenario.record.time) or ""
    W.cache.data.recordTooltip = W.cache.data.showRecord and string.var("{1} - {2}", {
        W.scenario.record.playerName,
        BJI.Managers.Veh.getModelLabel(W.scenario.record.model) or W.scenario.record.model
    }) or ""
    W.cache.data.recordColor = (W.cache.data.showRecord and
            W.scenario.record.playerName == ctxt.user.playerName) and
        BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or nil
    local _, pbTime = BJI.Managers.RaceWaypoint.getPB(W.scenario.raceHash)
    W.cache.data.showPb = pbTime and (not W.scenario.record or W.scenario.record.time ~= pbTime)
    W.cache.data.pbTime = W.cache.data.showPb and BJI.Utils.UI.RaceDelay(pbTime or 0) or ""
    W.cache.data.pbWidth = W.cache.data.showPb and BJI.Utils.UI.GetColumnTextWidth(string.var("{1} {2}",
        { W.cache.labels.pb, W.cache.data.pbTime })) or 0
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
            BJI.Managers.Perm.canSpawnVehicle() and BJI.Managers.Tournament.canJoinActivity()
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
                playerName = ctxt.players[pid].playerName,
                readyState = readyState,
                readyLabel = string.var("({1})",
                    { readyState and W.cache.labels.playerReady or W.cache.labels.playerNotReady }),
            }
        end)
    end

    W.cache.data.manualResetWidth = 0
    if W.cache.data.race.show then
        W.cache.data.race.colWidths = Table()
        local isSpec = W.scenario.isSpec()
        if isSpec then
            W.cache.data.race.colWidths:insert(1, BJI.Utils.UI.GetBtnIconSize())
        end

        local playerNames = Table()
        table.insert(W.cache.data.race.colWidths, Table(leaderboard):reduce(function(acc, lb, i)
            local player = ctxt.players[lb.playerID]
            playerNames[i] = player and player.playerName or W.cache.labels.unknown
            local w = BJI.Utils.UI.GetColumnTextWidth(playerNames[i])
            return w > acc and w or acc
        end, 0))

        local showLapCol = W.scenario.settings.laps and W.scenario.settings.laps > 1
        if showLapCol then
            table.insert(W.cache.data.race.colWidths, Range(1, W.scenario.settings.laps):reduce(function(acc, i)
                local label = W.cache.labels.lapCounter:var({ lap = i })
                local w = BJI.Utils.UI.GetColumnTextWidth(label)
                return w > acc and w or acc
            end, 0))
        end

        table.insert(W.cache.data.race.colWidths, Range(1, wpPerLap):reduce(function(acc, i)
            local label = W.cache.labels.wpCounter:var({ wp = i })
            local w = BJI.Utils.UI.GetColumnTextWidth(label)
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
                    local target = ctxt.players[lb.playerID]
                    local disabled = not target or
                        table.includes(W.scenario.race.finished, lb.playerID) or
                        table.includes(W.scenario.race.eliminated, lb.playerID)
                    if not disabled then
                        local finalGameVehID = BJI.Managers.Veh.getVehicleObject(target.currentVehicle)
                        finalGameVehID = finalGameVehID and finalGameVehID:getID() or nil
                        disabled = finalGameVehID and ctxt2.veh and ctxt2.veh:getID() == finalGameVehID or false
                    end
                    LineBuilder():btnIcon({
                        id = string.var("watchPlayer{1}", { i }),
                        icon = BJI.Utils.Icon.ICONS.visibility,
                        disabled = disabled,
                        tooltip = W.cache.labels.buttons.show,
                        onClick = function()
                            BJI.Managers.Veh.focus(lb.playerID)
                            BJI.Managers.Cam.setCamera(BJI.Managers.Cam.CAMERAS.ORBIT)
                        end
                    }):build()
                end)
            end
            table.insert(cells, function() LineLabel(playerNames[i], color) end)
            if showLapCol then
                table.insert(cells, function() LineLabel(W.cache.labels.lapCounter:var({ lap = lb.lap }), color) end)
            end
            table.insert(cells, function() LineLabel(W.cache.labels.wpCounter:var({ wp = lb.wp }), color) end)
            local playerTime = BJI.Utils.UI.RaceDelay(lb.time or 0)
            local diffLabel = i > 1 and W.cache.labels.wpDifference
                :var({ wpDifference = firstPlayerCurrentWp - playerCurrentWP }) or ""
            local diffVal = math.abs(lb.diff or 0)
            local diffTime = string.var("+{1}", { BJI.Utils.UI.RaceDelay(diffVal) })
            local diffColor = diffVal > 0 and BJI.Utils.Style.TEXT_COLORS.ERROR or BJI.Utils.Style.TEXT_COLORS.DEFAULT
            local eliminated = W.scenario.isEliminated(lb.playerID)
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
                    if eliminated then
                        line:text(W.cache.labels.eliminated, BJI.Utils.Style.TEXT_COLORS.ERROR)
                    else
                        line:text(diffTime, diffColor):build()
                    end
                    line:build()
                end
            end)
            return { cells = cells }
        end)

        W.cache.data.showManualResetBtn = not isSpec and not table.includes({
            BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.NO_RESPAWN.key,
            BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.ALL_RESPAWNS.key,
        }, W.scenario.settings.respawnStrategy)
        W.cache.data.manualResetWidth = 0
        W.cache.data.showLaunchedRespawnBtn = false --[[W.cache.data.showManualResetBtn and
            W.scenario.settings.respawnStrategy == BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.LAST_CHECKPOINT.key]]
        if W.cache.data.showManualResetBtn then
            W.cache.data.manualResetWidth = BJI.Utils.UI.GetBtnIconSize(true) +
                BJI.Utils.UI.GetTextWidth("  ") -- load home reset
            if W.cache.data.showLaunchedRespawnBtn then
                W.cache.data.manualResetWidth = W.cache.data.manualResetWidth +
                    BJI.Utils.UI.GetBtnIconSize(true) -- launched reset
            end
        end
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
    end, W.name .. "Labels"))

    updateCache()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.PLAYER_CONNECT,
        BJI.Managers.Events.EVENTS.PLAYER_DISCONNECT,
        BJI.Managers.Events.EVENTS.VEHICLE_SPAWNED,
        BJI.Managers.Events.EVENTS.RACE_NEW_PB,
        BJI.Managers.Events.EVENTS.SCENARIO_UPDATED,
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        BJI.Managers.Events.EVENTS.TOURNAMENT_UPDATED,
        BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED,
    }, updateCache, W.name))
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.CACHE_LOADED, function(ctxt, data)
        if data.cache == BJI.Managers.Cache.CACHES.RACES then
            updateCache(ctxt)
        end
    end, W.name .. "Cache"))

    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        function()
            if W.scenario.isRaceOrCountdownStarted() and
                W.scenario.isParticipant() and
                not BJI.Managers.Perm.canSpawnVehicle() then
                -- permission loss
                BJI.Tx.scenario.RaceMultiUpdate(W.scenario.CLIENT_EVENTS.LEAVE)
            end
        end, W.name .. "AutoLeave"))

    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.TOURNAMENT_UPDATED,
        function(ctxt)
            if W.scenario.isParticipant() and BJI.Managers.Tournament.whitelist and
                not BJI.Managers.Tournament.whitelistPlayers:includes(ctxt.user.playerName) then
                -- got out of whitelist
                BJI.Tx.scenario.RaceMultiUpdate(W.scenario.state == W.scenario.STATES.GRID and
                    W.scenario.CLIENT_EVENTS.JOIN or W.scenario.CLIENT_EVENTS.LEAVE)
            end
        end, W.name .. "AutoLeaveTournament"))
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
    local line = LineBuilder():text(W.scenario.raceName):text(W.cache.labels.byAuthor)
    if W.scenario.settings.laps then
        line:text(W.cache.labels.lap)
    end
    line:build()

    if W.cache.data.showRecord or W.cache.data.showPb then
        ColumnsBuilder("RaceSoloRecordPb", { -1, W.cache.data.pbWidth }):addRow({
            cells = { W.cache.data.showRecord and function()
                LineBuilder()
                    :text(W.cache.labels.record, nil, W.cache.data.recordTooltip)
                    :text(W.cache.data.recordTime, W.cache.data.recordColor, W.cache.data.recordTooltip)
                    :build()
            end or nil,
                W.cache.data.showPb and function()
                    LineBuilder():text(W.cache.labels.pb):text(W.cache.data.pbTime):build()
                end or nil }
        }):build()
    else
        EmptyLine()
    end

    if W.cache.data.showForfeitBtn or W.cache.data.showManualResetBtn then
        ColumnsBuilder("BJIRaceMultiBtns", { -1, W.cache.data.manualResetWidth }):addRow({
            cells = {
                W.cache.data.showForfeitBtn and function()
                    LineBuilder():btnIcon({
                        id = "forfeitRace",
                        icon = BJI.Utils.Icon.ICONS.exit_to_app,
                        style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                        disabled = W.cache.data.disableButtons,
                        tooltip = W.cache.labels.buttons.forfeit,
                        onClick = function()
                            W.cache.data.disableButtons = true -- api request protection
                            BJI.Tx.scenario.RaceMultiUpdate(W.scenario.CLIENT_EVENTS.LEAVE)
                        end,
                        big = true,
                    }):build()
                end or nil,
                W.cache.data.showManualResetBtn and function()
                    line = LineBuilder()
                    if W.cache.data.showLaunchedRespawnBtn then
                        line:btnIcon({
                            id = "manualLaunchedRespawn",
                            icon = BJI.Utils.Icon.ICONS.vertical_align_top,
                            style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                            big = true,
                            disabled = W.scenario.resetLock,
                            tooltip = string.var("{1} ({2})", {
                                W.cache.labels.launchedRespawn,
                                extensions.core_input_bindings.getControlForAction("saveHome"):capitalizeWords()
                            }),
                            onClick = function()
                                BJI.Managers.Scenario.saveHome(ctxt.veh:getID())
                            end,
                        })
                    end
                    line:btnIcon({
                        id = "manualReset",
                        icon = BJI.Utils.Icon.ICONS.build,
                        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        big = true,
                        disabled = W.scenario.resetLock,
                        tooltip = string.var("{1} ({2})", {
                            W.cache.labels.buttons.manualReset,
                            extensions.core_input_bindings.getControlForAction("loadHome"):capitalizeWords()
                        }),
                        onClick = function()
                            BJI.Managers.Veh.loadHome()
                        end,
                    }):build()
                end or nil,
            }
        }):build()
    end

    if W.cache.data.showTimer then
        LineBuilder():icon({ icon = BJI.Utils.Icon.ICONS.flag })
            :text(BJI.Utils.UI.RaceDelay(W.cache.data.raceTimer:get() + W.cache.data.raceTimeOffset))
            :build()

        if W.cache.data.showWpCounter then
            LineBuilder():icon({ icon = BJI.Utils.Icon.ICONS.timer }):text(W.cache.data.wpCounter)
                :text(BJI.Utils.UI.RaceDelay(W.cache.data.lapTimer:get() + W.cache.data.raceTimeOffset))
                :build()
        end

        EmptyLine()
    end

    line = LineBuilder():icon({
        icon = BJI.Utils.Icon.ICONS.timer,
        big = true,
    })

    if W.cache.data.showChooseYourVehicleLabel and not ctxt.isOwner then
        line:text(W.cache.labels.chooseYourVehicle, BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT)
    end

    if W.cache.data.hasStartTime then
        local remainingStart = getDiffTime(W.cache.data.startTime, ctxt.now)
        local remainingDNF = (remainingStart < -3 and W.cache.data.DNFEnabled and
                W.cache.data.DNFData.process and W.cache.data.DNFData.targetTime) and
            getDiffTime(W.cache.data.DNFData.targetTime, ctxt.now) or nil
        if remainingStart > 0 then
            line:text(W.cache.labels.gameStartsIn:var({ delay = BJI.Utils.UI.PrettyDelay(remainingStart) }))
        elseif remainingStart > -3 then
            line:text(W.cache.labels.flashCountdownZero)
        elseif remainingDNF then
            if remainingDNF < W.cache.data.DNFData.timeout then
                local color = remainingDNF > 3 and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or
                    BJI.Utils.Style.TEXT_COLORS.ERROR
                if remainingDNF > 0 then
                    line:text(W.cache.labels.eliminatedIn:var({ delay = BJI.Utils.UI.PrettyDelay(remainingDNF) }))
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
    LineBuilder():text(gridTimeoutRemaining < 1 and W.cache.labels.gridAboutToTimeout or
        W.cache.labels.gridTimeout:var({ delay = BJI.Utils.UI.PrettyDelay(gridTimeoutRemaining) }),
        gridTimeoutRemaining < 3 and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT)
        :build()

    if W.cache.data.grid.showJoinLeaveBtn then
        local line = LineBuilder():btnIconToggle({
            id = "joinRace",
            icon = W.cache.data.grid.isParticipant and BJI.Utils.Icon.ICONS.exit_to_app or
                BJI.Utils.Icon.ICONS.videogame_asset,
            state = not W.cache.data.grid.isParticipant,
            disabled = W.cache.data.disableButtons,
            tooltip = W.cache.data.grid.isParticipant and W.cache.labels.buttons.spectate or W.cache.labels.buttons.join,
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
                icon = BJI.Utils.Icon.ICONS.check,
                style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                disabled = W.cache.data.disableButtons or showReadyCooldown,
                tooltip = W.cache.labels.buttons.markReady,
                onClick = function()
                    W.cache.data.disableButtons = true -- api request protection
                    BJI.Tx.scenario.RaceMultiUpdate(W.scenario.CLIENT_EVENTS.READY)
                end,
                big = true,
            })
            if showReadyCooldown then
                line:text(W.cache.labels.markReadyCooldown:var({
                    delay = BJI.Utils.UI.PrettyDelay(getDiffTime(W.cache.data.grid.readyCooldownTime, ctxt.now))
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
            LineBuilder():text(i):text(player.playerName, color):text(player.readyLabel, color):build()
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
