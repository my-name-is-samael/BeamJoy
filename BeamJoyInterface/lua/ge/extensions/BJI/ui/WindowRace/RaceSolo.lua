local M = {
    ---@type table<string, any>
    mgr = BJIScenario.get(BJIScenario.TYPES.RACE_SOLO),
    SHOW_ALL_THRESHOLD = 3,
    ELLIPSIS_MARKER = "...",

    cache = {
        data = {
            showRecord = false,
            recordStr = "",
            showPb = false,
            pbTime = "",
            hasStartTime = false,
            startTime = 0,

            ---@type Timer?
            raceTimer = nil,
            ---@type Timer?
            lapTimer = nil,
            baseTime = RaceDelay(0),
            showFinalTime = false,
            finalTime = "",
            ---@type boolean
            showAll = BJILocalStorage.get(BJILocalStorage.GLOBAL_VALUES.SCENARIO_RACE_SHOW_ALL_DATA),
            showBtnShowAll = false,
            showAllWidth = 0,
            ---@type number[]
            columnsWidths = {},
            ---@type {cells: function[]}[]
            cols = {},
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
        },
    },
}

local function updateLabels()
    M.cache.labels.vSeparator = BJILang.get("common.vSeparator")

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
    M.cache.labels.showAll = BJILang.get("races.play.showAllData")

    M.cache.labels.wpCounter = BJILang.get("races.play.WP")
    M.cache.labels.lapCounter = BJILang.get("races.play.Lap")
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
    M.cache.data.hasStartTime = not not M.mgr.hasStartTime
    M.cache.data.startTime = M.cache.data.hasStartTime and tonumber(M.mgr.race.startTime) or 0
    M.cache.data.showAllWidth = GetColumnTextWidth(M.cache.labels.showAll) + GetBtnIconSize()

    -- common
    M.cache.data.raceTimer = M.mgr.race.timers.race
    M.cache.data.lapTimer = M.mgr.race.timers.lap
    M.cache.data.showFinalTime = not not M.mgr.race.timers.finalTime
    M.cache.data.finalTime = M.cache.data.showFinalTime and RaceDelay(M.mgr.race.timers.finalTime)
    M.cache.data.showRaceTimer = not not M.mgr.race.timers.race and M.mgr.isRaceStarted()
    M.cache.data.DNFEnabled = M.mgr.settings.respawnStrategy == BJI_RACES_RESPAWN_STRATEGIES.NO_RESPAWN.key
    M.cache.data.DNFData = M.mgr.dnf

    local leaderboard = M.mgr.race.leaderboard or {}
    local wpPerLap = M.mgr.race.raceData.wpPerLap

    local function printEllipsis()
        LineBuilder():text(M.ELLIPSIS_MARKER):build()
    end

    M.cache.data.showSprint = not M.mgr.settings.laps or M.mgr.settings.laps == 1
    if M.cache.data.showSprint then
        -- sprint
        M.cache.data.showBtnShowAll = wpPerLap > M.SHOW_ALL_THRESHOLD
        M.cache.data.wpCounter = string.var("{1}/{2}", {
            M.cache.labels.wpCounter:var({ wp = leaderboard.wp or 0 }),
            wpPerLap,
        })

        local labelsWidth = 0
        local currentWp = 0
        for i = 1, wpPerLap do
            local w = GetColumnTextWidth(M.cache.labels.wpCounter:var({ wp = i }))
            if w > labelsWidth then
                labelsWidth = w
            end
            if leaderboard.waypoints and leaderboard.waypoints[i] then
                currentWp = i
            end
        end

        M.cache.data.columnsWidths = { labelsWidth, -1 }
        M.cache.data.cols = {}
        local wps = Table(leaderboard.waypoints):map(function(time, wp)
                return {
                    wp = wp,
                    time = time and RaceDelay(time) or
                        M.cache.data.baseTime
                }
            end)
            :sort(function(a, b) return a.wp < b.wp end) or Table()
        if not M.cache.data.showAll and #wps > M.SHOW_ALL_THRESHOLD then
            while #wps > M.SHOW_ALL_THRESHOLD do
                Table(wps):remove(1)
            end
            table.insert(M.cache.data.cols, {
                cells = { printEllipsis, printEllipsis }
            })
        end
        wps:forEach(function(el)
            local color = el.wp == currentWp and TEXT_COLORS.HIGHLIGHT or TEXT_COLORS.DEFAULT
            local wpLabel = M.cache.labels.wpCounter:var({ wp = el.wp })
            table.insert(M.cache.data.cols, {
                cells = { function() LineBuilder():text(wpLabel, color):build() end,
                    function() LineBuilder():text(el.time, color):build() end }
            })
        end)
    else
        -- loop
        M.cache.data.showBtnShowAll = M.mgr.settings.laps > M.SHOW_ALL_THRESHOLD
        local lap = leaderboard.laps and #leaderboard.laps or 0
        M.cache.data.lapCounter = string.var("{1}/{2}", {
            M.cache.labels.lapCounter:var({ lap = lap }),
            M.mgr.settings.laps,
        })
        local wp = (lap > 0 and leaderboard.laps[lap]) and leaderboard.laps[lap].wp or 0
        M.cache.data.wpCounter = string.var("{1}/{2}", {
            M.cache.labels.wpCounter:var({ wp = wp }),
            wpPerLap,
        })

        local labelsWidth = 0
        for i = 1, M.mgr.race.lap do
            local w = GetColumnTextWidth(M.cache.labels.lapCounter:var({ lap = i }))
            if w > labelsWidth then
                labelsWidth = w
            end
        end

        M.cache.data.columnsWidths = { labelsWidth, -1 }
        M.cache.data.cols = {}
        ---@param data {wp: integer, time?: integer, diff?: integer}
        local laps = Table(leaderboard.laps):map(function(data, i) return { lap = i, data = data } end)
            :sort(function(a, b) return a.lap < b.lap end) or Table()
        if not M.cache.data.showAll and #laps > M.SHOW_ALL_THRESHOLD then
            local hiddenBestLap
            while #laps > M.SHOW_ALL_THRESHOLD do
                local removed = laps:remove(1)
                if removed.data and removed.data.wp == wpPerLap and not removed.data.diff then
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
            laps:insert(1, M.ELLIPSIS_MARKER)
            if hiddenBestLap then
                --[[
                    case with best time 3+ laps before:
                    Lap 2 %best_time%
                    ...   ...
                    Lap 3 %time% + %diff%
                    Lap 4 %time% + %diff%
                    Lap 5 %current_time%
                ]]
                laps:insert(1, hiddenBestLap)
            end
        end
        laps:forEach(function(el)
            if el == M.ELLIPSIS_MARKER then
                table.insert(M.cache.data.cols, { cells = { printEllipsis, printEllipsis } })
            else
                local lapLabel = M.cache.labels.lapCounter:var({ lap = el.lap })
                local timeLabel, diff
                if el.data.wp == wpPerLap then
                    -- one of previous laps
                    timeLabel = RaceDelay(el.data.time or 0)
                    diff = el.data.diff
                end
                local diffLabel = (diff and diff > 0) and string.var("+{1}", { RaceDelay(diff or 0) }) or ""
                table.insert(M.cache.data.cols, {
                    cells = {
                        function() LineBuilder():text(lapLabel):build() end,
                        function()
                            local finalTimeLabel = timeLabel or RaceDelay(M.cache.data.lapTimer and
                                M.cache.data.lapTimer:get() or 0)
                            LineBuilder():text(finalTimeLabel):text(diffLabel, TEXT_COLORS.ERROR):build()
                        end,
                    }
                })
            end
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
end

local function getDiffTime(time, now)
    if not time then
        return 0
    end
    return math.ceil((time - now) / 1000)
end

local function headerSprint(ctxt)
    local currentTime = M.cache.data.baseTime
    if M.cache.data.showFinalTime then
        currentTime = M.cache.data.finalTime
    elseif M.cache.data.showRaceTimer then
        currentTime = RaceDelay(M.cache.data.raceTimer:get())
    end

    LineBuilder()
        :text(M.cache.data.wpCounter)
        :text(M.cache.labels.vSeparator)
        :text(currentTime)
        :build()
end

local function headerLoop(ctxt)
    local currentTime = M.cache.data.baseTime
    if M.cache.data.showFinalTime then
        currentTime = M.cache.data.finalTime
    elseif M.cache.data.showRaceTimer then
        currentTime = RaceDelay(M.cache.data.raceTimer:get())
    end

    LineBuilder()
        :text(M.cache.data.lapCounter)
        :text(M.cache.labels.vSeparator)
        :text(M.cache.data.wpCounter)
        :text(M.cache.labels.vSeparator)
        :text(currentTime)
end

local function header(ctxt)
    if not M.mgr then return end

    local line = LineBuilder()
        :text(M.mgr.raceName)
        :text(M.cache.labels.byAuthor)
    if M.mgr.settings.laps then
        line:text(M.cache.labels.lap)
    end
    line:build()

    if M.cache.data.showRecord then
        LineBuilder():text(M.cache.data.recordStr):build()
    end

    if M.cache.data.showPb then
        LineBuilder()
            :text(M.cache.labels.pb)
            :text(M.cache.data.pbTime)
            :build()
    else
        EmptyLine()
    end

    ColumnsBuilder("BJIRaceSoloActions", { -1, M.cache.data.showAllWidth })
        :addRow({
            cells = {
                function()
                    line = LineBuilder()
                    if not M.mgr.testing then
                        local loop = BJILocalStorage.get(BJILocalStorage.GLOBAL_VALUES.SCENARIO_SOLO_RACE_LOOP)
                        line:btnIconToggle({
                            id = "toggleRaceLoop",
                            icon = ICONS.all_inclusive,
                            state = loop,
                            onClick = function()
                                BJILocalStorage.set(BJILocalStorage.GLOBAL_VALUES.SCENARIO_SOLO_RACE_LOOP, not loop)
                            end,
                            big = true,
                        })
                    end
                    if M.mgr.isRaceStarted() then
                        line:btnIcon({
                            id = "leaveRace",
                            icon = ICONS.exit_to_app,
                            style = BTN_PRESETS.ERROR,
                            onClick = function()
                                BJIScenario.switchScenario(BJIScenario.TYPES.FREEROAM, ctxt)
                            end,
                            big = true,
                        })
                        if not M.mgr.testing and not M.mgr.isRaceFinished() then
                            line:btnIcon({
                                id = "restartRace",
                                icon = ICONS.restart,
                                style = BTN_PRESETS.WARNING,
                                onClick = function()
                                    local settings, raceData = M.mgr.baseSettings, M.mgr.baseRaceData
                                    BJIScenario.switchScenario(BJIScenario.TYPES.FREEROAM, ctxt)
                                    BJIScenario.get(BJIScenario.TYPES.RACE_SOLO).initRace(ctxt, settings, raceData)
                                end,
                                big = true,
                            })
                        end
                    end
                    line:build()
                end,
                M.cache.data.showBtnShowAll and function()
                    LineBuilder()
                        :text(M.cache.labels.showAll)
                        :btnIconToggle({
                            id = "toggleShowAll",
                            state = M.cache.data.showAll,
                            coloredIcon = true,
                            onClick = function()
                                M.cache.data.showAll = not M.cache.data.showAll
                                BJILocalStorage.set(BJILocalStorage.GLOBAL_VALUES.SCENARIO_RACE_SHOW_ALL_DATA,
                                    M.cache.data.showAll)
                                updateCache(ctxt)
                            end,
                        })
                        :build()
                end,
            },
        }):build()


    Separator()

    if M.cache.data.showSprint then
        headerSprint(ctxt)
    else
        headerLoop(ctxt)
    end

    line = LineBuilder()
        :icon({
            icon = ICONS.timer,
            big = true,
        })

    if M.cache.data.hasStartTime then
        local remaining = getDiffTime(M.cache.data.hasStartTime, ctxt.now)
        if remaining > 0 then
            line:text(M.cache.labels.gameStartsIn:var({ delay = PrettyDelay(remaining) }))
        elseif remaining > -3 then
            line:text(M.cache.labels.flashCountdownZero)
        end
    end

    if M.cache.data.DNFEnabled and M.cache.data.DNFData.process and M.cache.data.DNFData.targetTime then
        local remaining = getDiffTime(M.cache.data.DNFData.targetTime, ctxt.now)
        if remaining < M.cache.data.DNFData.timeout then
            local color = remaining > 3 and TEXT_COLORS.HIGHLIGHT or TEXT_COLORS.ERROR
            if remaining > 0 then
                line:text(M.cache.labels.eliminatedIn:var({ delay = PrettyDelay(math.abs(remaining)) }))
            else
                line:text(M.cache.labels.eliminated, color)
            end
        end
    end

    line:build()
end

local function drawData(ctxt)
    local cols = ColumnsBuilder("BJIRaceSoloLeaderboard", M.cache.data.columnsWidths)
    Table(M.cache.data.cols):forEach(function(col)
        cols:addRow(col)
    end)
    cols:build()
end

local function drawBody(ctxt)
    drawData(ctxt)
end

M.onLoad = onLoad
M.onUnload = onUnload

M.header = header
M.body = drawBody

return M
