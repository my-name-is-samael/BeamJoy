local M = {
    STATE = false,

    data = {},
    _threshold = 100,
}

--[[
-- USAGE
local start
if BJI.BENCH.STATE then
    start = GetCurrentTimeMillis()
end
-- BENCHMARKED CODE EXEC HERE
if BJI.BENCH.STATE then
    BenchAdd(manager._name, eventName, GetCurrentTimeMillis() - start)
end
]]

---@param wrapperName string
---@param eventName string
---@param time integer
function M.add(wrapperName, eventName, time)
    if not M.data[wrapperName] then
        M.data[wrapperName] = Table()
    end
    if not M.data[wrapperName][eventName] then
        M.data[wrapperName][eventName] = Table()
    end
    table.insert(M.data[wrapperName][eventName], time)
    if #M.data[wrapperName][eventName] > M._threshold then
        table.remove(M.data[wrapperName][eventName], 1)
    end
end

function M.get()
    local lines = {}
    for wrapperName, events in pairs(M.data) do
        for event, times in pairs(events) do
            if #times > 0 then
                local sum, min, max = 0, times[1], times[1]
                for _, t in ipairs(times) do
                    sum = sum + t
                    if t < min then
                        min = t
                    end
                    if t > max then
                        max = t
                    end
                end
                table.insert(lines, {
                    manager = wrapperName,
                    event = event,
                    min = min,
                    max = max,
                    avg = math.round(sum / #times, 1),
                    amount = #times,
                })
            end
        end
    end
    table.sort(lines, function(a, b) return a.avg > b.avg end)
    local out = "\n"
    for _, l in ipairs(lines) do
        out = string.var("{1}{2}.{3} - min {4}ms ; max {5}ms ; avg {6}ms [{7}]\n",
            { out, l.manager, l.event, l.min, l.max, l.avg, l.amount })
    end
    return out
end

function M.reset()
    M.data = {}
end

function M.startWindow()
    M.STATE = true
    M.reset()
    BJI.DEBUG = function() return M.get() end
end

function M.stop()
    M.STATE = false
    M.reset()
end

return M
