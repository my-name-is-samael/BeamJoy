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
                showSpectateBtn = false,
                bodyData = Table(),
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
--- gc prevention
local showLapCol, firstPlayerCurrentLap, firstPlayerCurrentWp, player, lapDiff, wpDiff, timeDiff,
gridTimeoutRemaining, showReadyCooldown, color, remainingStart, remainingDNF

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
    W.cache.data.showForfeitBtn = W.scenario.isRaceStarted(ctxt) and not W.scenario.isRaceFinished() and
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

    if W.cache.data.race.show then
        W.cache.data.race.showSpectateBtn = W.scenario.isSpec()

        showLapCol = W.scenario.settings.laps and W.scenario.settings.laps > 1

        firstPlayerCurrentLap, firstPlayerCurrentWp = nil, nil
        W.cache.data.bodyData = Table(leaderboard):map(function(lb, i)
            if not ctxt.players[lb.playerID] then return nil end

            player = ctxt.players[lb.playerID]
            if i == 1 then
                firstPlayerCurrentLap = lb.lap
                firstPlayerCurrentWp = lb.wp
            end
            lapDiff = nil
            if i > 1 and lb.lap < firstPlayerCurrentLap then
                lapDiff = string.format("(+%d)", firstPlayerCurrentLap - lb.lap)
            end
            wpDiff = nil
            if i > 1 and not lapDiff and lb.wp < firstPlayerCurrentWp then
                wpDiff = string.format("(+%d)", firstPlayerCurrentWp - lb.wp)
            end
            timeDiff = nil
            if i > 1 then
                timeDiff = string.format("(+%s)", BJI.Utils.UI.RaceDelay(math.abs(lb.diff or 0)))
            end
            return {
                playerID = lb.playerID,
                playerName = player.playerName,
                color = lb.playerID == ctxt.user.playerID and
                    BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or nil,
                done = W.scenario.isSpec(lb.playerID),
                lapLabel = showLapCol and W.cache.labels.lapCounter:var({ lap = lb.lap }) or nil,
                lapDiff = lapDiff,
                wpLabel = W.cache.labels.wpCounter:var({ wp = lb.wp }),
                wpDiff = wpDiff,
                timeLabel = W.scenario.isEliminated(lb.playerID) and
                    W.cache.labels.eliminated or BJI.Utils.UI.RaceDelay(lb.time or 0),
                timeDiff = timeDiff,
                timeColor = W.scenario.isEliminated(lb.playerID) and
                    BJI.Utils.Style.TEXT_COLORS.ERROR or nil
            }
        end)

        W.cache.data.showManualResetBtn = not W.scenario.isSpec() and not table.includes({
            BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.NO_RESPAWN.key,
            BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.ALL_RESPAWNS.key,
        }, W.scenario.settings.respawnStrategy)
        W.cache.data.showLaunchedRespawnBtn = false --[[W.cache.data.showManualResetBtn and
            W.scenario.settings.respawnStrategy == BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.LAST_CHECKPOINT.key]]
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
    Text(W.scenario.raceName)
    SameLine()
    Text(W.cache.labels.byAuthor)
    if W.scenario.settings.laps then
        SameLine()
        Text(W.cache.labels.lap)
    end

    if W.cache.data.showRecord or W.cache.data.showPb then
        if BeginTable("BJIRaceRecordPb", {
                { label = "##race-record-left", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
                { label = "##race-record-right" }
            }) then
            TableNewRow()
            if W.cache.data.showRecord then
                Text(W.cache.labels.record)
                TooltipText(W.cache.data.recordTooltip)
                SameLine()
                Text(W.cache.data.recordTime, { color = W.cache.data.recordColor })
                TooltipText(W.cache.data.recordTooltip)
            end
            TableNextColumn()
            if W.cache.data.showPb then
                Text(W.cache.labels.pb)
                SameLine()
                Text(W.cache.data.pbTime)
            end

            EndTable()
        end
    else
        EmptyLine()
    end

    if W.cache.data.showForfeitBtn or W.cache.data.showManualResetBtn then
        if BeginTable("BJIRaceActions", {
                { label = "##race-actions-left", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
                { label = "##race-actions-right" }
            }) then
            TableNewRow()
            if W.cache.data.showForfeitBtn then
                if IconButton("forfeitRace", BJI.Utils.Icon.ICONS.exit_to_app,
                        { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, big = true,
                            disabled = W.cache.data.disableButtons }) then
                    W.cache.data.disableButtons = true
                    BJI.Tx.scenario.RaceMultiUpdate(W.scenario.CLIENT_EVENTS.LEAVE)
                end
                TooltipText(W.cache.labels.buttons.forfeit)
            end
            TableNextColumn()
            if W.cache.data.showManualResetBtn then
                if W.cache.data.showLaunchedRespawnBtn then
                    if IconButton("manualLaunchedRespawn", BJI.Utils.Icon.ICONS.vertical_align_top,
                            { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, big = true,
                                disabled = W.scenario.resetLock }) then
                        BJI.Managers.Scenario.saveHome(ctxt.veh.gameVehicleID)
                    end
                    TooltipText(string.format("%s (%s)",
                        W.cache.labels.launchedRespawn,
                        extensions.core_input_bindings.getControlForAction("saveHome"):capitalizeWords()
                    ))
                    SameLine()
                end
                if IconButton("manualReset", BJI.Utils.Icon.ICONS.build,
                        { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                            big = true, disabled = W.scenario.resetLock }) then
                    BJI.Managers.Scenario.loadHome(ctxt.veh.gameVehicleID)
                end
                TooltipText(string.format("%s (%s)",
                    W.cache.labels.buttons.manualReset,
                    extensions.core_input_bindings.getControlForAction("loadHome"):capitalizeWords()
                ))
            end

            EndTable()
        end
    end

    if W.cache.data.showTimer then
        Icon(BJI.Utils.Icon.ICONS.flag)
        SameLine()
        Text(BJI.Utils.UI.RaceDelay(W.cache.data.raceTimer:get() + W.cache.data.raceTimeOffset))

        if W.cache.data.showWpCounter then
            Icon(BJI.Utils.Icon.ICONS.timer)
            SameLine()
            Text(W.cache.data.wpCounter)
            SameLine()
            Text(BJI.Utils.UI.RaceDelay(W.cache.data.lapTimer:get() + W.cache.data.raceTimeOffset))
        end

        EmptyLine()
    end

    Icon(BJI.Utils.Icon.ICONS.timer, { big = true })
    if W.cache.data.showChooseYourVehicleLabel and not ctxt.isOwner then
        SameLine()
        Text(W.cache.labels.chooseYourVehicle, { color = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT })
    end

    if W.cache.data.hasStartTime then
        remainingStart = getDiffTime(W.cache.data.startTime, ctxt.now)
        remainingDNF = (remainingStart < -3 and W.cache.data.DNFEnabled and
                W.cache.data.DNFData.process and W.cache.data.DNFData.targetTime) and
            getDiffTime(W.cache.data.DNFData.targetTime, ctxt.now) or nil
        if remainingStart > 0 then
            SameLine()
            Text(W.cache.labels.gameStartsIn:var({ delay = BJI.Utils.UI.PrettyDelay(remainingStart) }))
        elseif remainingStart > -3 then
            SameLine()
            Text(W.cache.labels.flashCountdownZero)
        elseif remainingDNF then
            if remainingDNF < W.cache.data.DNFData.timeout then
                SameLine()
                if remainingDNF > 0 then
                    Text(W.cache.labels.eliminatedIn:var({ delay = BJI.Utils.UI.PrettyDelay(remainingDNF) }))
                else
                    Text(W.cache.labels.eliminated, {
                        color = remainingDNF > 3 and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or
                            BJI.Utils.Style.TEXT_COLORS.ERROR
                    })
                end
            end
        end
    end
end

---@param ctxt TickContext
local function drawGrid(ctxt)
    gridTimeoutRemaining = getDiffTime(W.scenario.grid.timeout, ctxt.now)
    Text(gridTimeoutRemaining < 1 and W.cache.labels.gridAboutToTimeout or
        W.cache.labels.gridTimeout:var({ delay = BJI.Utils.UI.PrettyDelay(gridTimeoutRemaining) }),
        {
            color = gridTimeoutRemaining < 3 and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or
                BJI.Utils.Style.TEXT_COLORS.DEFAULT
        })

    if W.cache.data.grid.showJoinLeaveBtn then
        if IconButton("joinLeaveRace", W.cache.data.grid.isParticipant and
                BJI.Utils.Icon.ICONS.exit_to_app or BJI.Utils.Icon.ICONS.videogame_asset,
                { disabled = W.cache.data.disableButtons, btnStyle = W.cache.data.grid.isParticipant and
                    BJI.Utils.Style.BTN_PRESETS.ERROR or BJI.Utils.Style.BTN_PRESETS.SUCCESS, big = true }) then
            W.cache.data.disableButtons = true
            BJI.Tx.scenario.RaceMultiUpdate(W.scenario.CLIENT_EVENTS.JOIN)
        end
        TooltipText(W.cache.data.grid.isParticipant and W.cache.labels.buttons.spectate or W.cache.labels.buttons.join)
        if W.cache.data.grid.showRemainingPlaces then
            SameLine()
            Text(W.cache.data.grid.remainingPlacesStr)
        elseif W.cache.data.grid.showReadyBtn then
            showReadyCooldown = ctxt.now < W.cache.data.grid.readyCooldownTime
            SameLine()
            if IconButton("raceReady", BJI.Utils.Icon.ICONS.check,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, big = true,
                        disabled = W.cache.data.disableButtons or showReadyCooldown }) then
                W.cache.data.disableButtons = true
                BJI.Tx.scenario.RaceMultiUpdate(W.scenario.CLIENT_EVENTS.READY)
            end
            TooltipText(W.cache.labels.buttons.markReady)
            if showReadyCooldown then
                SameLine()
                Text(W.cache.labels.markReadyCooldown:var({
                    delay = BJI.Utils.UI.PrettyDelay(getDiffTime(W.cache.data.grid.readyCooldownTime, ctxt.now))
                }))
            end
        end
    else
        Text(W.cache.labels.waitingForPlayers)
    end

    if #W.scenario.grid.participants > 0 then
        Text(W.cache.labels.players)
        Indent(); Indent()
        W.cache.data.grid.participantsList:forEach(function(player, i)
            color = player.readyState and BJI.Utils.Style.TEXT_COLORS.SUCCESS or
                BJI.Utils.Style.TEXT_COLORS.DEFAULT
            Text(i)
            SameLine()
            Text(player.playerName, { color = color })
            SameLine()
            Text(player.readyLabel, { color = color })
        end)
        Unindent(); Unindent()
    end
end

---@param ctxt TickContext
local function drawRace(ctxt)
    if BeginTable("BJIRaceMulti", {
            { label = "##race-spec" },
            { label = "##race-name" },
            { label = "##race-lap" },
            { label = "##race-wp" },
            { label = "##race-times", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } }
        }) then
        W.cache.data.bodyData:forEach(function(el)
            TableNewRow()
            if W.cache.data.race.showSpectateBtn and not el.done then
                if IconButton("spectate-" .. el.playerName, BJI.Utils.Icon.ICONS.visibility) then
                    BJI.Managers.Veh.focus(el.playerID)
                    BJI.Managers.Cam.setCamera(BJI.Managers.Cam.CAMERAS.ORBIT)
                end
                TooltipText(W.cache.labels.buttons.show)
            end
            TableNextColumn()
            Text(el.playerName, { color = el.color })
            TableNextColumn()
            if el.lapLabel then
                Text(el.lapLabel, { color = el.color })
                if el.lapDiff then
                    SameLine()
                    Text(el.lapDiff, { color = BJI.Utils.Style.TEXT_COLORS.ERROR })
                end
            end
            TableNextColumn()
            Text(el.wpLabel, { color = el.color })
            if el.wpDiff then
                SameLine()
                Text(el.wpDiff, { color = BJI.Utils.Style.TEXT_COLORS.ERROR })
            end
            TableNextColumn()
            Text(el.timeLabel, { color = el.timeColor or el.color })
            if el.timeDiff then
                SameLine()
                Text(el.timeDiff, { color = BJI.Utils.Style.TEXT_COLORS.ERROR })
            end
        end)
        EndTable()
    end
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
