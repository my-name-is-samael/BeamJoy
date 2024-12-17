local M = {
    _name = "BJIRaceUI",
    lap = {
        current = nil,
        count = nil,
    },
    waypoint = {
        current = nil,
        count = nil,
    },
    hotlap = {},
}

local function drawLap()
    if M.lap.current then
        guihooks.trigger("RaceLapChange", { current = M.lap.current, count = M.lap.count })
    else
        guihooks.trigger("RaceLapClear")
    end
end

local function drawWaypoint()
    if M.waypoint.current then
        guihooks.trigger("WayPointChange", { current = M.waypoint.current, count = M.waypoint.count })
    else
        guihooks.trigger("WayPointReset")
    end
end

local function setLap(current, count)
    M.lap = {
        current = current,
        count = count
    }
    drawLap()
end

local function clearLap()
    M.lap = {
        current = nil,
        count = nil,
    }
    drawLap()
end

local function setWaypoint(current, count)
    M.waypoint = {
        current = current,
        count = count
    }
    drawWaypoint()
end

local function clearWaypoint()
    M.waypoint = {
        current = nil,
        count = nil,
    }
    drawWaypoint()
end

local function drawHotlap()
    local bestTime
    for _, lap in pairs(M.hotlap) do
        if not bestTime or lap.duration < bestTime then
            bestTime = lap.duration
        end
    end

    local rows = {}
    for _, row in ipairs(M.hotlap) do
        local diffLabel = "-"
        local symbol = "-"
        local diff = row.duration - bestTime
        if diff > 0 then
            symbol = "+"
        end
        if diff ~= 0 then
            diffLabel = svar("{1}{2}", { symbol, RaceDelay(math.abs(diff)) })
        end
        table.insert(rows, {
            lap = row.lap,
            duration = RaceDelay(row.duration),
            diff = diffLabel,
            total = RaceDelay(row.total),
        })
    end

    if #rows > 0 then
        guihooks.trigger("HotlappingTimer", {
            normal = rows,
            detail = rows,
            delta = 0,
            closed = false,
            running = false,
            justStarted = false,
            justLapped = false,
        })
    else
        M.clearHotlap()
    end
end

local function addHotlapRow(lap, time)
    local total = time
    for _, row in pairs(M.hotlap) do
        total = total + row.duration
    end
    table.insert(M.hotlap, {
        lap = lap,
        duration = time,
        total = total
    })
    drawHotlap()
end

local function clearHotlap()
    M.hotlap = {}
    --guihooks.trigger("HotlappingResetApp")

    -- will keep app mode selected
    local emptyRow = { lap = "", duration = "", diff = "", total = "" }
    guihooks.trigger("HotlappingTimer", {
        normal = { emptyRow },
        detail = { emptyRow },
        delta = 0,
        closed = false,
        running = false,
        justStarted = false,
        justLapped = false,
    })
end

local function setRaceTime(diffMs, recordDiffMs, timeoutMS)
    if type(diffMs) ~= "number" then
        diffMs = nil
    end
    if type(recordDiffMs) ~= "number" then
        recordDiffMs = nil
    end

    if diffMs then
        guihooks.trigger("RaceCheckpointComparison", { timeOut = timeoutMS, time = diffMs / 1000 })
    end
    if recordDiffMs then
        guihooks.trigger("RaceTimeComparison", { timeOut = timeoutMS, time = recordDiffMs / 1000 })
    end

    if (diffMs or recordDiffMs) and type(timeoutMS) == "number" and timeoutMS > 0 then
        BJIAsync.delayTask(M.clearRaceTime, timeoutMS,
            svar("BJIRaceUIRaceTimeClear{1}{2}", { GetCurrentTimeMillis(), math.random(100) }))
    end
end

local function clearRaceTime()
    guihooks.trigger("ScenarioNotRunning")
    drawLap()
    drawWaypoint()
end

local function clear()
    M.clearLap()
    M.clearWaypoint()
    M.clearHotlap()
    M.clearRaceTime()
end

M.setLap = setLap
M.clearLap = clearLap

M.setWaypoint = setWaypoint
M.clearWaypoint = clearWaypoint

M.addHotlapRow = addHotlapRow
M.clearHotlap = clearHotlap

M.setRaceTime = setRaceTime
M.clearRaceTime = clearRaceTime

M.clear = clear

-- init hotlapping app
extensions.load({ 'core_hotlapping' })

return M
