BJI.BENCH = {
    STATE = false,
}
local bench = {}

function BJI.BENCH.BenchAdd(manager, event, time)
    if not bench[manager] then
        bench[manager] = {}
    end
    if not bench[manager][event] then
        bench[manager][event] = {}
    end
    table.insert(bench[manager][event], time)
    if #bench[manager][event] > 1000 then
        table.remove(bench[manager][event], 1)
    end
end

function BJI.BENCH.BenchGet()
    local lines = {}
    for manager, events in pairs(bench) do
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
                    manager = manager,
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

function BJI.BENCH.BenchReset()
    bench = {}
end

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
