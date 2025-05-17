local W = {
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

            ---@type Timer
            raceTimer = nil,
            ---@type Timer
            lapTimer = nil,
            baseTime = BJI.Utils.Common.RaceDelay(0),
            showFinalTime = false,
            finalTime = "",
            showLoopBtn = false,
            showForfeitBtn = false,
            showRestartBtn = false,
            ---@type boolean
            showAll = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.SCENARIO_RACE_SHOW_ALL_DATA),
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
    ---@type BJIScenarioRaceSolo
    scenario = nil,
}

local function updateLabels()
    W.cache.labels.vSeparator = BJI.Managers.Lang.get("common.vSeparator")

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
    W.cache.labels.showAll = BJI.Managers.Lang.get("races.play.showAllData")

    W.cache.labels.wpCounter = BJI.Managers.Lang.get("races.play.WP")
    W.cache.labels.lapCounter = BJI.Managers.Lang.get("races.play.Lap")
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI.Managers.Tick.getContext()

    -- header
    W.cache.data.showRecord = not not W.scenario.record
    W.cache.data.recordStr = W.cache.data.showRecord and W.cache.labels.record:var({
        playerName = W.scenario.record.playerName,
        model = BJI.Managers.Veh.getModelLabel(W.scenario.record.model) or W.scenario.record.model,
        time = BJI.Utils.Common.RaceDelay(W.scenario.record.time)
    }) or ""
    local _, pbTime
    if not W.scenario.testing then
        _, pbTime = BJI.Managers.RaceWaypoint.getPB(W.scenario.raceHash)
    end
    W.cache.data.showPb = pbTime and (not W.scenario.record or W.scenario.record.time ~= pbTime)
    W.cache.data.pbTime = W.cache.data.showPb and BJI.Utils.Common.RaceDelay(pbTime or 0) or ""
    W.cache.data.showLoopBtn = not W.scenario.testing
    W.cache.data.showForfeitBtn = W.scenario.isRaceStarted()
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
    W.cache.data.finalTime = W.cache.data.showFinalTime and BJI.Utils.Common.RaceDelay(W.scenario.race.timers.finalTime)
    W.cache.data.showRaceTimer = not not W.scenario.race.timers.race and W.scenario.isRaceStarted()

    local leaderboard = W.scenario.race.leaderboard or {}
    local wpPerLap = W.scenario.race.raceData.wpPerLap

    local function printEllipsis()
        LineBuilder():text(W.ELLIPSIS_MARKER):build()
    end

    W.cache.data.showSprint = not W.scenario.settings.laps or W.scenario.settings.laps == 1
    if W.cache.data.showSprint then
        -- sprint
        W.cache.data.showBtnShowAll = wpPerLap > W.SHOW_ALL_THRESHOLD
        W.cache.data.wpCounter = string.var("{1}/{2}", {
            W.cache.labels.wpCounter:var({ wp = leaderboard.wp or 0 }),
            wpPerLap,
        })

        local labelsWidth = 0
        local currentWp = 0
        for i = 1, wpPerLap do
            local w = BJI.Utils.Common.GetColumnTextWidth(W.cache.labels.wpCounter:var({ wp = i }))
            if w > labelsWidth then
                labelsWidth = w
            end
            if leaderboard.waypoints and leaderboard.waypoints[i] then
                currentWp = i
            end
        end

        W.cache.data.columnsWidths = { labelsWidth, -1 }
        W.cache.data.cols = {}
        local wps = Table(leaderboard.waypoints):map(function(time, wp)
                return {
                    wp = wp,
                    time = time and BJI.Utils.Common.RaceDelay(time) or
                        W.cache.data.baseTime
                }
            end)
            :sort(function(a, b) return a.wp < b.wp end) or Table()
        if not W.cache.data.showAll and #wps > W.SHOW_ALL_THRESHOLD then
            while #wps > W.SHOW_ALL_THRESHOLD do
                Table(wps):remove(1)
            end
            table.insert(W.cache.data.cols, {
                cells = { printEllipsis, printEllipsis }
            })
        end
        wps:forEach(function(el)
            local color = el.wp == currentWp and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or
                BJI.Utils.Style.TEXT_COLORS.DEFAULT
            local wpLabel = W.cache.labels.wpCounter:var({ wp = el.wp })
            table.insert(W.cache.data.cols, {
                cells = { function() LineBuilder():text(wpLabel, color):build() end,
                    function() LineBuilder():text(el.time, color):build() end }
            })
        end)
    else
        -- loop
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

        local labelsWidth = 0
        for i = 1, W.scenario.race.lap do
            local w = BJI.Utils.Common.GetColumnTextWidth(W.cache.labels.lapCounter:var({ lap = i }))
            if w > labelsWidth then
                labelsWidth = w
            end
        end

        W.cache.data.columnsWidths = { labelsWidth, -1 }
        W.cache.data.cols = {}
        ---@param data {wp: integer, time?: integer, diff?: integer}
        local laps = Table(leaderboard.laps):map(function(data, i) return { lap = i, data = data } end)
            :sort(function(a, b) return a.lap < b.lap end) or Table()
        if not W.cache.data.showAll and #laps > W.SHOW_ALL_THRESHOLD then
            local hiddenBestLap
            while #laps > W.SHOW_ALL_THRESHOLD do
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
            laps:insert(1, W.ELLIPSIS_MARKER)
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
            if el == W.ELLIPSIS_MARKER then
                table.insert(W.cache.data.cols, { cells = { printEllipsis, printEllipsis } })
            else
                local lapLabel = W.cache.labels.lapCounter:var({ lap = el.lap })
                local timeLabel, diff
                if el.data.wp == wpPerLap then
                    -- one of previous laps
                    timeLabel = BJI.Utils.Common.RaceDelay(el.data.time or 0)
                    diff = el.data.diff
                end
                local diffLabel = (diff and diff > 0) and string.var("+{1}", { BJI.Utils.Common.RaceDelay(diff or 0) }) or
                    ""
                table.insert(W.cache.data.cols, {
                    cells = {
                        function() LineBuilder():text(lapLabel):build() end,
                        function()
                            local finalTimeLabel = timeLabel or BJI.Utils.Common.RaceDelay(W.cache.data.lapTimer:get())
                            LineBuilder():text(finalTimeLabel):text(diffLabel, BJI.Utils.Style.TEXT_COLORS.ERROR):build()
                        end,
                    }
                })
            end
        end)
    end
    W.cache.data.showAllWidth = W.cache.data.showBtnShowAll and
        BJI.Utils.Common.GetColumnTextWidth(W.cache.labels.showAll) + GetBtnIconSize() or 0
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
    end))

    updateCache()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.RACE_NEW_PB,
        BJI.Managers.Events.EVENTS.SCENARIO_UPDATED,
        BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED,
    }, updateCache))
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.CACHE_LOADED, function(ctxt, data)
        if data.cache == BJI.Managers.Cache.CACHES.RACES then
            updateCache(ctxt)
        end
    end))

    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        function()
            if not BJI.Managers.Perm.canSpawnVehicle() then
                -- permission loss
                BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.FREEROAM)
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
local function headerSprint(ctxt)
    local currentTime = W.cache.data.baseTime
    if W.cache.data.showFinalTime then
        currentTime = W.cache.data.finalTime
    elseif W.cache.data.showRaceTimer then
        currentTime = BJI.Utils.Common.RaceDelay(W.cache.data.raceTimer:get())
    end

    LineBuilder()
        :text(W.cache.data.wpCounter)
        :text(W.cache.labels.vSeparator)
        :text(currentTime)
        :build()
end

---@param ctxt TickContext
local function headerLoop(ctxt)
    local currentTime = W.cache.data.baseTime
    if W.cache.data.showFinalTime then
        currentTime = W.cache.data.finalTime
    elseif W.cache.data.showRaceTimer then
        currentTime = BJI.Utils.Common.RaceDelay(W.cache.data.raceTimer:get())
    end

    LineBuilder()
        :text(W.cache.data.lapCounter)
        :text(W.cache.labels.vSeparator)
        :text(W.cache.data.wpCounter)
        :text(W.cache.labels.vSeparator)
        :text(currentTime)
end

---@param ctxt TickContext
local function header(ctxt)
    if not W.scenario then return end

    local line = LineBuilder()
        :text(W.scenario.raceName)
        :text(W.cache.labels.byAuthor)
    if W.scenario.settings.laps then
        line:text(W.cache.labels.lap)
    end
    line:build()

    if W.cache.data.showRecord then
        LineBuilder():text(W.cache.data.recordStr):build()
    end

    if W.cache.data.showPb then
        LineBuilder()
            :text(W.cache.labels.pb)
            :text(W.cache.data.pbTime)
            :build()
    else
        EmptyLine()
    end

    ColumnsBuilder("BJIRaceSoloActions", { -1, W.cache.data.showAllWidth })
        :addRow({
            cells = {
                function()
                    line = LineBuilder()
                    if W.cache.data.showLoopBtn then
                        local loop = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES
                            .SCENARIO_SOLO_RACE_LOOP)
                        line:btnIconToggle({
                            id = "toggleRaceLoop",
                            icon = ICONS.all_inclusive,
                            state = loop,
                            onClick = function()
                                BJI.Managers.LocalStorage.set(
                                    BJI.Managers.LocalStorage.GLOBAL_VALUES.SCENARIO_SOLO_RACE_LOOP, not loop)
                            end,
                            big = true,
                        })
                    end
                    if W.cache.data.showForfeitBtn then
                        line:btnIcon({
                            id = "leaveRace",
                            icon = ICONS.exit_to_app,
                            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                            onClick = function()
                                BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.FREEROAM, ctxt)
                            end,
                            big = true,
                        })
                    end
                    if W.cache.data.showRestartBtn then
                        line:btnIcon({
                            id = "restartRace",
                            icon = ICONS.restart,
                            style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                            onClick = function()
                                local settings, raceData = W.scenario.baseSettings, W.scenario.baseRaceData
                                BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.FREEROAM, ctxt)
                                W.scenario.initRace(ctxt, settings, raceData)
                            end,
                            big = true,
                        })
                    end
                    line:build()
                end,
                W.cache.data.showBtnShowAll and function()
                    LineBuilder()
                        :text(W.cache.labels.showAll)
                        :btnIconToggle({
                            id = "toggleShowAll",
                            state = W.cache.data.showAll,
                            coloredIcon = true,
                            onClick = function()
                                W.cache.data.showAll = not W.cache.data.showAll
                                BJI.Managers.LocalStorage.set(
                                    BJI.Managers.LocalStorage.GLOBAL_VALUES.SCENARIO_RACE_SHOW_ALL_DATA,
                                    W.cache.data.showAll)
                                updateCache(ctxt)
                            end,
                        })
                        :build()
                end or nil,
            },
        }):build()


    Separator()

    if W.cache.data.showSprint then
        headerSprint(ctxt)
    else
        headerLoop(ctxt)
    end

    line = LineBuilder()
        :icon({
            icon = ICONS.timer,
            big = true,
        })

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
local function drawData(ctxt)
    local cols = ColumnsBuilder("BJIRaceSoloLeaderboard", W.cache.data.columnsWidths)
    Table(W.cache.data.cols):forEach(function(col)
        cols:addRow(col)
    end)
    cols:build()
end

---@param ctxt TickContext
local function drawBody(ctxt)
    drawData(ctxt)
end

W.onLoad = onLoad
W.onUnload = onUnload

W.header = header
W.body = drawBody

return W
