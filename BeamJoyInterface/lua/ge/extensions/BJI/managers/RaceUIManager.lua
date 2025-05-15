---@class BJIManagerRaceUI : BJIManager
local M = {
    _name = "RaceUI",

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

---@param current integer
---@param count integer
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

---@param current integer
---@param count integer
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

local function drawHotlap()
    local bestTime
    for _, lap in pairs(M.hotlap) do
        if not bestTime or lap.duration < bestTime then
            bestTime = lap.duration
        end
    end

    local rows = {}
    for i, row in ipairs(M.hotlap) do
        local diffLabel = "-"
        local symbol = "-"
        local diff = row.duration - bestTime
        if diff > 0 then
            symbol = "+"
        end
        if diff ~= 0 then
            diffLabel = string.var("{1}{2}", { symbol, BJI.Utils.Common.RaceDelay(math.abs(diff)) })
        end
        table.insert(rows, {
            lap = i,
            duration = BJI.Utils.Common.RaceDelay(row.duration),
            diff = diffLabel,
            total = BJI.Utils.Common.RaceDelay(row.total),
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
        clearHotlap()
    end
end

local lastRaceHotlap
---@param raceName string
---@param time integer
local function addHotlapRow(raceName, time)
    if type(raceName) ~= "string" or type(time) ~= "number" then
        LogError("Invalid hotlap data")
        return
    end
    if lastRaceHotlap ~= raceName then
        clearHotlap()
        lastRaceHotlap = raceName
    end

    local total = time
    for _, row in pairs(M.hotlap) do
        total = total + row.duration
    end
    table.insert(M.hotlap, {
        duration = time,
        total = total
    })
    drawHotlap()
end

---@param diffCheckpoint? integer
---@param diffRace? integer
---@param timeoutMS integer
local function setRaceTime(diffCheckpoint, diffRace, timeoutMS)
    if type(timeoutMS) ~= "number" then
        LogError("setRaceTime invalid timeoutMS")
        return
    end
    if type(diffCheckpoint) ~= "number" then
        diffCheckpoint = nil
    end
    if type(diffRace) ~= "number" then
        diffRace = nil
    end

    BJI.Managers.Async.removeTask("BJIRaceUIRaceTimeClear")

    if diffCheckpoint then
        guihooks.trigger("RaceCheckpointComparison", { timeOut = timeoutMS, time = diffCheckpoint / 1000 })
    end
    if diffRace then
        guihooks.trigger("RaceTimeComparison", { timeOut = timeoutMS, time = diffRace / 1000 })
    end

    if (diffCheckpoint or diffRace) and type(timeoutMS) == "number" and timeoutMS > 0 then
        BJI.Managers.Async.delayTask(M.clearRaceTime, timeoutMS, "BJIRaceUIRaceTimeClear")
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
end

M.setLap = setLap
M.clearLap = clearLap

M.setWaypoint = setWaypoint
M.clearWaypoint = clearWaypoint

M.addHotlapRow = addHotlapRow

M.setRaceTime = setRaceTime
M.clearRaceTime = clearRaceTime

M.clear = clear

-- init hotlapping app
extensions.load({ 'core_hotlapping' })

return M
