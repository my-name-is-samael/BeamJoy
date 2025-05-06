local mgr

local function drawHeader(ctxt)
    mgr = BJIScenario.get(BJIScenario.TYPES.RACE_SOLO)
    if not mgr then return end

    local line = LineBuilder()
        :text(mgr.raceName)
        :text(BJILang.get("races.play.by"):var({ author = mgr.raceAuthor }))
    if mgr.settings.laps then
        line:text(string.var("({1})",
            {
                mgr.settings.laps == 1 and
                BJILang.get("races.settings.lap"):var({ lap = mgr.settings.laps }) or
                BJILang.get("races.settings.laps"):var({ laps = mgr.settings.laps })
            }))
    end
    line:build()

    if mgr.record then
        local modelName = BJIVeh.getModelLabel(mgr.record.model)
        if modelName then
            LineBuilder()
                :text(BJILang.get("races.play.record"):var({
                    playerName = mgr.record.playerName,
                    model = modelName,
                    time = RaceDelay(mgr.record.time)
                }))
                :build()
        end
    end

    local _, pbTime = BJIRaceWaypoint.getPB(mgr.raceHash)
    if pbTime and (not mgr.record or mgr.record.time ~= pbTime) then
        LineBuilder()
            :text(string.var("{1} :", { BJILang.get("races.leaderboard.pb") }))
            :text(RaceDelay(pbTime))
            :build()
    else
        EmptyLine()
    end

    if mgr.race.startTime then
        local remaining = math.ceil((mgr.race.startTime - ctxt.now) / 1000)
        if remaining > 0 then
            LineBuilder()
                :text(BJILang.get("races.play.gameStartsIn")
                    :var({ delay = PrettyDelay(remaining) }))
                :build()
        elseif remaining > -3 then
            LineBuilder()
                :text(BJILang.get("races.play.flashCountdownZero"))
                :build()
        else
            EmptyLine()
        end
    else
        EmptyLine()
    end

    line = LineBuilder()
    if not mgr.testing then
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
    if mgr.isRaceStarted() then
        line:btnIcon({
            id = "leaveRace",
            icon = ICONS.exit_to_app,
            style = BTN_PRESETS.ERROR,
            onClick = function()
                BJIScenario.switchScenario(BJIScenario.TYPES.FREEROAM, ctxt)
            end,
            big = true,
        })
        if not mgr.testing and not mgr.isRaceFinished() then
            line:btnIcon({
                id = "restartRace",
                icon = ICONS.restart,
                style = BTN_PRESETS.WARNING,
                onClick = function()
                    local settings, raceData = mgr.baseSettings, mgr.baseRaceData
                    BJIScenario.switchScenario(BJIScenario.TYPES.FREEROAM, ctxt)
                    BJIScenario.get(BJIScenario.TYPES.RACE_SOLO).initRace(ctxt, settings, raceData)
                end,
                big = true,
            })
        end
    end
    line:build()

    if mgr.settings.respawnStrategy == BJI_RACES_RESPAWN_STRATEGIES.NO_RESPAWN.key then
        if mgr.dnf.process and mgr.dnf.targetTime then
            local remaining = math.ceil((mgr.dnf.targetTime - ctxt.now) / 1000)
            if remaining >= 0 and remaining < mgr.dnf.timeout then
                LineBuilder()
                    :text(BJILang.get("races.play.eliminatedIn")
                        :var({ delay = PrettyDelay(math.abs(remaining)) }))
                    :build()
            else
                EmptyLine()
            end
        else
            EmptyLine()
        end
    end
end

local function drawSprint(ctxt)
    local lb = mgr.race.leaderboard
    local wpPerLap = mgr.race.raceData.wpPerLap

    local currentTime = RaceDelay(0)
    if mgr.race.timers.finalTime then
        currentTime = RaceDelay(mgr.race.timers.finalTime)
    elseif mgr.isRaceStarted() then
        local time = mgr.race.timers.race and mgr.race.timers.race:get() or 0
        currentTime = RaceDelay(time)
    end
    LineBuilder()
        :text(string.var("{1}/{2}", {
            BJILang.get("races.play.WP"):var({ wp = lb.wp }),
            wpPerLap,
        }))
        :text(BJILang.get("common.vSeparator"))
        :text(currentTime)
    EmptyLine()

    local labelWidth = 0
    local currentWp = 1
    for iWp = 1, wpPerLap do
        local label = BJILang.get("races.play.WP"):var({ wp = iWp })
        local w = GetColumnTextWidth(label)
        if w > labelWidth then
            labelWidth = w
        end
        if lb.waypoints[iWp] then
            currentWp = iWp
        end
    end

    LineBuilder()
        :icon({
            icon = ICONS.timer,
            big = true,
        })
        :build()
    local cols = ColumnsBuilder("BJIRaceSoloSprintLeaderboard", { labelWidth, -1 })
    for iWp = 1, wpPerLap do
        if lb.waypoints[iWp] then
            local color = iWp == currentWp and TEXT_COLORS.HIGHLIGHT or TEXT_COLORS.DEFAULT
            cols:addRow({
                cells = {
                    function()
                        LineBuilder()
                            :text(BJILang.get("races.play.WP"):var({ wp = iWp }), color)
                            :build()
                    end,
                    function()
                        LineBuilder()
                            :text(RaceDelay(lb.waypoints[iWp]), color)
                            :build()
                    end,
                }
            })
        end
    end
    cols:build()
end

local function drawLoopable(ctxt)
    local lb = mgr.race.leaderboard
    local wpPerLap = mgr.race.raceData.wpPerLap

    local currentTime = RaceDelay(0)
    if mgr.race.timers.finalTime then
        currentTime = RaceDelay(mgr.race.timers.finalTime)
    elseif mgr.isRaceStarted() then
        local time = mgr.race.timers.race and mgr.race.timers.race:get() or 0
        currentTime = RaceDelay(time)
    end
    local lap = lb.laps and #lb.laps or 0
    local wp = (lap > 0 and lb.laps[lap]) and lb.laps[lap].wp or 0
    LineBuilder()
        :text(BJILang.get("races.play.Lap"):var({ lap = lap }))
        :text(BJILang.get("common.vSeparator"))
        :text(string.var("{1}/{2}", {
            BJILang.get("races.play.WP"):var({ wp = wp }),
            wpPerLap,
        }))
        :text(BJILang.get("common.vSeparator"))
        :text(currentTime)
    EmptyLine()

    local lapTime = mgr.race.timers.lap and mgr.race.timers.lap:get() or 0

    local labelWidth = 0
    for iLap = 1, mgr.race.lap do
        local label = BJILang.get("races.play.Lap"):var({ lap = iLap })
        local w = GetColumnTextWidth(label)
        if w > labelWidth then
            labelWidth = w
        end
    end

    LineBuilder()
        :icon({
            icon = ICONS.timer,
            big = true,
        })
        :build()
    local cols = ColumnsBuilder("BJIRaceSoloLoopableLeaderboard", { labelWidth, -1 })
    for iLap = 1, mgr.race.lap do
        local time, diff
        local lbLap = lb.laps[iLap]
        if lbLap then
            if lbLap.wp == wpPerLap then
                -- lap finished
                time = lbLap.time
                diff = lbLap.diff
            else
                -- current lap
                time = lapTime
            end
        elseif iLap <= mgr.settings.laps then
            -- last lap finished and no waypoint reached in this one
            time = lapTime
        end

        if time then
            local diffSymbol = ""
            if diff and diff > 0 then
                diffSymbol = "+"
            end
            cols:addRow({
                cells = {
                    function()
                        LineBuilder()
                            :text(BJILang.get("races.play.Lap"):var({ lap = iLap }))
                            :build()
                    end,
                    function()
                        LineBuilder()
                            :text(RaceDelay(time))
                            :text(diff and string.var("{1}{2}", { diffSymbol, RaceDelay(diff) }) or "", TEXT_COLORS
                            .ERROR)
                            :build()
                    end,
                }
            })
        end
    end
    cols:build()
end

local function drawBody(ctxt)
    if not mgr then return end
    if not mgr.settings.laps or mgr.settings.laps == 1 then
        drawSprint(ctxt)
    else
        drawLoopable(ctxt)
    end
end

return {
    header = drawHeader,
    body = drawBody,
}
