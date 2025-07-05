local W = {
    name = "RaceSolo",

    SHOW_ALL_THRESHOLD = 3,

    cache = {
        data = {
            showRecord = false,
            recordTime = "",
            recordTooltip = "",
            recordColor = nil,
            showPb = false,
            pbTime = "",
            hasStartTime = false,
            startTime = 0,

            ---@type Timer
            raceTimer = nil,
            ---@type Timer
            lapTimer = nil,
            baseTime = BJI.Utils.UI.RaceDelay(0),
            showFinalTime = false,
            finalTime = "",
            showLoopBtn = false,
            showRestartBtn = false,
            showManualResetBtn = false,
            showLaunchedRespawnBtn = false,
            ---@type boolean
            showAll = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.SCENARIO_RACE_SHOW_ALL_DATA),
            showBtnShowAll = false,
            bodyData = Table(),
            showRaceTimer = false,
            wpCounter = "",
            lapCounter = "",
            DNFEnabled = false,
            ---@type {timeout: number, process: boolean, targetTime?: integer}
            DNFData = {},

            showSprint = false,
        },

        labels = {
            vSeparator = "",

            byAuthor = "",
            lap = "",
            record = "",
            pb = "",
            gameStartsIn = "",
            flashCountdownZero = "",
            eliminatedIn = "",
            eliminated = "",
            showAll = "",

            wpCounter = "",
            lapCounter = "",

            loop = "",
            forfeit = "",
            restart = "",
            launchedRespawn = "",
            manualReset = "",
        },
    },
    ---@type BJIScenarioRaceSolo
    scenario = nil,
}
--- gc prevention
local loop, currentTime, remainingStart, remainingDNF

local function updateLabels()
    W.cache.labels.vSeparator = BJI.Managers.Lang.get("common.vSeparator")

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
    W.cache.labels.eliminated = BJI.Managers.Lang.get("races.play.flashDnfOut")
    W.cache.labels.showAll = BJI.Managers.Lang.get("races.play.showAllData")

    W.cache.labels.wpCounter = BJI.Managers.Lang.get("races.play.WP")
    W.cache.labels.lapCounter = BJI.Managers.Lang.get("races.play.Lap")

    W.cache.labels.loop = BJI.Managers.Lang.get("common.buttons.loop")
    W.cache.labels.forfeit = BJI.Managers.Lang.get("common.buttons.forfeit")
    W.cache.labels.restart = BJI.Managers.Lang.get("common.buttons.restart")
    W.cache.labels.launchedRespawn = BJI.Managers.Lang.get("races.play.launchedRespawn")
    W.cache.labels.manualReset = BJI.Managers.Lang.get("common.buttons.manualReset")
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI.Managers.Tick.getContext()

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
    local _, pbTime
    if not W.scenario.testing then
        _, pbTime = BJI.Managers.RaceWaypoint.getPB(W.scenario.raceHash)
    end
    W.cache.data.showPb = pbTime and (not W.scenario.record or W.scenario.record.time ~= pbTime)
    W.cache.data.pbTime = W.cache.data.showPb and BJI.Utils.UI.RaceDelay(pbTime or 0) or ""
    W.cache.data.showLoopBtn = not W.scenario.testing
    W.cache.data.showRestartBtn = W.scenario.isRaceStarted() and not W.scenario.testing and
        not W.scenario.isRaceFinished()
    W.cache.data.startTime = W.scenario.race.startTime
    W.cache.data.hasStartTime = not not W.cache.data.startTime
    W.cache.data.DNFEnabled = W.scenario.settings.respawnStrategy ==
        BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.NO_RESPAWN.key
    W.cache.data.DNFData = W.scenario.dnf

    -- common
    W.cache.data.raceTimer = W.scenario.race.timers.race or { get = function() return 0 end }
    W.cache.data.lapTimer = W.scenario.race.timers.lap or { get = function() return 0 end }
    W.cache.data.showFinalTime = not not W.scenario.race.timers.finalTime
    W.cache.data.finalTime = W.cache.data.showFinalTime and BJI.Utils.UI.RaceDelay(W.scenario.race.timers.finalTime)
    W.cache.data.showRaceTimer = not not W.scenario.race.timers.race and W.scenario.isRaceStarted()

    local leaderboard = W.scenario.race.leaderboard or {}
    local wpPerLap = W.scenario.race.raceData.wpPerLap

    W.cache.data.showSprint = not W.scenario.settings.laps or W.scenario.settings.laps == 1
    if W.cache.data.showSprint then
        -- sprint
        W.cache.data.showBtnShowAll = wpPerLap > W.SHOW_ALL_THRESHOLD
        W.cache.data.wpCounter = string.var("{1}/{2}", {
            W.cache.labels.wpCounter:var({ wp = leaderboard.wp or 0 }),
            wpPerLap,
        })

        local currentWp = 0
        for i = wpPerLap, 1, -1 do
            if leaderboard.waypoints and leaderboard.waypoints[i] then
                currentWp = i
                break
            end
        end

        W.cache.data.bodyData = Range(1, currentWp):reduce(function(res, i)
            local time = leaderboard.waypoints[i]
            if time then
                res:insert({
                    wp = W.cache.labels.wpCounter:var({ wp = i }),
                    time = time and BJI.Utils.UI.RaceDelay(time) or
                        W.cache.data.baseTime,
                    color = i == currentWp and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or nil
                })
            end
            return res
        end, Table())
        if not W.cache.data.showAll and #W.cache.data.bodyData > W.SHOW_ALL_THRESHOLD then
            while #W.cache.data.bodyData > W.SHOW_ALL_THRESHOLD do
                W.cache.data.bodyData:remove(1)
            end
            W.cache.data.bodyData:insert(1, {
                ellipsis = true,
            })
        end
    else -- loop
        W.cache.data.showBtnShowAll = W.scenario.settings.laps > W.SHOW_ALL_THRESHOLD
        local lap = leaderboard.laps and #leaderboard.laps or 0
        W.cache.data.lapCounter = string.var("{1}/{2}", {
            W.cache.labels.lapCounter:var({ lap = lap }),
            W.scenario.settings.laps,
        })
        local wp = (lap > 0 and leaderboard.laps[lap]) and leaderboard.laps[lap].wp or 0
        W.cache.data.wpCounter = string.var("{1}/{2}", {
            W.cache.labels.wpCounter:var({ wp = wp }),
            wpPerLap,
        })

        W.cache.data.bodyData = Range(1, W.scenario.settings.laps):reduce(function(res, i)
            if leaderboard.laps[i] then
                res:insert({
                    lap = i,
                    lapLabel = W.cache.labels.lapCounter:var({ lap = i }),
                    timeLabel = leaderboard.laps[i].wp == wpPerLap and
                        BJI.Utils.UI.RaceDelay(leaderboard.laps[i].time) or nil,
                    diffLabel = (leaderboard.laps[i].wp == wpPerLap and
                            leaderboard.laps[i].diff and leaderboard.laps[i].diff > 0) and
                        "+" .. BJI.Utils.UI.RaceDelay(leaderboard.laps[i].diff) or nil
                })
            end
            return res
        end, Table())
        if not W.cache.data.showAll and #W.cache.data.bodyData > W.SHOW_ALL_THRESHOLD then
            local hiddenBestLap
            while #W.cache.data.bodyData > W.SHOW_ALL_THRESHOLD do
                local removed = W.cache.data.bodyData:remove(1)
                if removed and removed.timeLabel and not removed.diffLabel then
                    hiddenBestLap = removed
                end
            end
            --[[
                case with best time within 3 last laps:
                ...   ...
                Lap 3 %time% + %diff%
                Lap 4 %best_time%
                Lap 5 %current_time%
            ]]
            W.cache.data.bodyData:insert(1, { ellipsis = true })
            if hiddenBestLap then
                --[[
                    case with best time 3+ laps before:
                    Lap 2 %best_time%
                    ...   ...
                    Lap 3 %time% + %diff%
                    Lap 4 %time% + %diff%
                    Lap 5 %current_time%
                ]]
                W.cache.data.bodyData:insert(1, hiddenBestLap)
            end
        end
    end

    W.cache.data.showManualResetBtn = not table.includes({
        BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.NO_RESPAWN.key,
        BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.ALL_RESPAWNS.key,
    }, W.scenario.settings.respawnStrategy)
    W.cache.data.showLaunchedRespawnBtn = false --[[W.cache.data.showManualResetBtn and
        W.scenario.settings.respawnStrategy == BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.LAST_CHECKPOINT.key]]
end

local listeners = Table()
local function onLoad()
    W.scenario = BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.RACE_SOLO)

    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, function(ctxt)
        updateLabels()
        updateCache(ctxt)
    end, W.name))

    updateCache()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.RACE_NEW_PB,
        BJI.Managers.Events.EVENTS.SCENARIO_UPDATED,
        BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED,
    }, updateCache, W.name))
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.CACHE_LOADED, function(ctxt, data)
        if data.cache == BJI.Managers.Cache.CACHES.RACES then
            updateCache(ctxt)
        end
    end, W.name))

    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        function()
            if not BJI.Managers.Perm.canSpawnVehicle() then
                -- permission loss
                BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.FREEROAM)
            end
        end, W.name))

    if not W.cache.data.showAll then
        BJI.Windows.Race.maxSize = ImVec2(350, 320)
    end
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
local function headerSprint(ctxt)
    currentTime = W.cache.data.baseTime
    if W.cache.data.showFinalTime then
        currentTime = W.cache.data.finalTime
    elseif W.cache.data.showRaceTimer then
        currentTime = BJI.Utils.UI.RaceDelay(W.cache.data.raceTimer:get())
    end

    Text(W.cache.data.wpCounter)
    SameLine()
    Text(W.cache.labels.vSeparator)
    SameLine()
    Text(currentTime)
end

---@param ctxt TickContext
local function headerLoop(ctxt)
    currentTime = W.cache.data.baseTime
    if W.cache.data.showFinalTime then
        currentTime = W.cache.data.finalTime
    elseif W.cache.data.showRaceTimer then
        currentTime = BJI.Utils.UI.RaceDelay(W.cache.data.raceTimer:get())
    end

    Text(W.cache.data.lapCounter)
    SameLine()
    Text(W.cache.labels.vSeparator)
    SameLine()
    Text(W.cache.data.wpCounter)
    SameLine()
    Text(W.cache.labels.vSeparator)
    SameLine()
    Text(currentTime)
end

---@param ctxt TickContext
local function header(ctxt)
    if not W.scenario then return end

    Text(W.scenario.raceName)
    SameLine()
    Text(W.cache.labels.byAuthor)
    if W.scenario.settings.laps then
        SameLine()
        Text(W.cache.labels.lap)
    end

    if W.cache.data.showRecord or W.cache.data.showPb then
        if BeginTable("RaceSoloRecord", {
                { label = "##race-record-left", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
                { label = "##race-record-right" },
            }) then
            TableNewRow()
            if W.cache.data.showRecord then
                Text(W.cache.labels.record, nil)
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

    if BeginTable("RaceSoloActions", {
            { label = "##race-actions-left", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
            { label = "##race-actions-right" },
        }) then
        TableNewRow()
        if W.cache.data.showLoopBtn then
            loop = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES
                .SCENARIO_SOLO_RACE_LOOP)
            if IconButton("toggleRaceLoop", BJI.Utils.Icon.ICONS.all_inclusive,
                    { btnStyle = loop and BJI.Utils.Style.BTN_PRESETS.SUCCESS or
                        BJI.Utils.Style.BTN_PRESETS.ERROR, big = true }) then
                BJI.Managers.LocalStorage.set(BJI.Managers.LocalStorage.GLOBAL_VALUES.SCENARIO_SOLO_RACE_LOOP, not loop)
            end
            TooltipText(W.cache.labels.loop)
            SameLine()
        end
        if IconButton("leaveRace", BJI.Utils.Icon.ICONS.exit_to_app,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, big = true }) then
            BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.FREEROAM, ctxt)
        end
        TooltipText(W.cache.labels.forfeit)
        if W.cache.data.showRestartBtn then
            SameLine()
            if IconButton("restartRace", BJI.Utils.Icon.ICONS.restart,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, big = true }) then
                W.scenario.restartRace(W.scenario.baseSettings, W.scenario.baseRaceData)
            end
            TooltipText(W.cache.labels.restart)
        end
        TableNextColumn()
        if W.cache.data.showManualResetBtn then
            if W.cache.data.showLaunchedRespawnBtn then
                if IconButton("manualLaunchedRespawn", BJI.Utils.Icon.ICONS.vertical_align_top,
                        { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, big = true,
                            disabled = W.scenario.resetLock }) then
                    BJI.Managers.Scenario.saveHome(ctxt.veh.gameVehicleID)
                end
                TooltipText(string.format("%s (%s)", W.cache.labels.launchedRespawn,
                    extensions.core_input_bindings.getControlForAction("saveHome"):capitalizeWords()))
                SameLine()
            end
            if IconButton("manualReset", BJI.Utils.Icon.ICONS.build,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        big = true, disabled = W.scenario.resetLock }) then
                BJI.Managers.Scenario.loadHome(ctxt.veh.gameVehicleID)
            end
            TooltipText(string.format("%s (%s)", W.cache.labels.manualReset,
                extensions.core_input_bindings.getControlForAction("loadHome"):capitalizeWords()
            ))
        end
        EndTable()
    end

    Separator()

    if BeginTable("RaceSoloHeader", {
            { label = "##race-header-left", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
            { label = "##race-header-right" },
        }) then
        TableNewRow()
        if W.cache.data.showSprint then
            headerSprint(ctxt)
        else
            headerLoop(ctxt)
        end
        TableNextColumn()
        if W.cache.data.showBtnShowAll then
            Text(W.cache.labels.showAll)
            SameLine()
            if IconButton("toggleShowAll", W.cache.data.showAll and
                    BJI.Utils.Icon.ICONS.check_circle or BJI.Utils.Icon.ICONS.cancel,
                    { bgLess = true, btnStyle = W.cache.data.showAll and
                        BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR }) then
                W.cache.data.showAll = not W.cache.data.showAll
                BJI.Managers.LocalStorage.set(
                    BJI.Managers.LocalStorage.GLOBAL_VALUES.SCENARIO_RACE_SHOW_ALL_DATA,
                    W.cache.data.showAll)
                BJI.Windows.Race.maxSize = W.cache.data.showAll and ImVec2(350, 800) or ImVec2(350, 320)
                updateCache(ctxt)
            end
        end
        EndTable()
    end

    Icon(BJI.Utils.Icon.ICONS.timer, { big = true })
    if W.cache.data.hasStartTime then
        remainingStart = getDiffTime(W.cache.data.startTime, ctxt.now)
        remainingDNF = (remainingStart < -3 and W.cache.data.DNFEnabled and
                W.cache.data.DNFData.process and W.cache.data.DNFData.targetTime)
            and getDiffTime(W.cache.data.DNFData.targetTime, ctxt.now) or nil
        if remainingStart > 0 then
            SameLine()
            Text(W.cache.labels.gameStartsIn:var({ delay = BJI.Utils.UI.PrettyDelay(remainingStart) }))
        elseif remainingStart > -3 then
            SameLine()
            Text(W.cache.labels.flashCountdownZero)
        elseif remainingDNF then
            remainingStart = getDiffTime(W.cache.data.DNFData.targetTime, ctxt.now)
            if remainingDNF < W.cache.data.DNFData.timeout then
                SameLine()
                if remainingDNF > 0 then
                    Text(W.cache.labels.eliminatedIn:var({ delay = BJI.Utils.UI.PrettyDelay(remainingDNF) }))
                else
                    Text(W.cache.labels.eliminated, {
                        color = remainingDNF > 3 and
                            BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.ERROR
                    })
                end
            end
        end
    end
end

---@param ctxt TickContext
local function body(ctxt)
    if W.cache.data.showSprint then
        if BeginTable("BJIRaceSoloSprint", {
                { label = "##race-wps" },
                { label = "##race-times", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } }
            }) then
            W.cache.data.bodyData:forEach(function(el)
                TableNewRow()
                if el.ellipsis then
                    TableNextColumn()
                    Text("...")
                else
                    Text(el.wp, { color = el.color })
                    TableNextColumn()
                    Text(el.time, { color = el.color })
                end
            end)
            EndTable()
        end
    else -- loop race
        if BeginTable("BJIRaceSoloLoop", {
                { label = "##race-wps" },
                { label = "##race-times", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } }
            }) then
            W.cache.data.bodyData:forEach(function(el)
                TableNewRow()
                if el.ellipsis then
                    TableNextColumn()
                    Text("...")
                else
                    Text(el.lapLabel)
                    TableNextColumn()
                    Text(el.timeLabel or BJI.Utils.UI.RaceDelay(W.cache.data.lapTimer:get()),
                        { color = (el.timeLabel and not el.diffLabel) and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or nil })
                    if el.timeLabel and el.diffLabel then
                        SameLine()
                        Text(el.diffLabel, { color = BJI.Utils.Style.TEXT_COLORS.ERROR })
                    end
                end
            end)
            EndTable()
        end
    end
end

W.onLoad = onLoad
W.onUnload = onUnload

W.header = header
W.body = body

return W
