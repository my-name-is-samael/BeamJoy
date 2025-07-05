local M = {
    STATE = 0,

    data = Table(),
    gcdata = Table(),
    _threshold = 100,
}

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

local sum, min, max
---@param amount? integer
---@param recurrent? boolean
---@return string
function M.get(amount, recurrent)
    return M.data:reduce(function(res, events, wrapperName)
            events:forEach(function(times, event)
                if #times > 0 then
                    sum, min, max = 0, times[1], times[1]
                    for _, t in ipairs(times) do
                        sum = sum + t
                        if t < min then
                            min = t
                        end
                        if t > max then
                            max = t
                        end
                    end
                    res:insert({
                        manager = wrapperName,
                        event = event,
                        min = min,
                        max = max,
                        avg = math.round(sum / #times, 1),
                        amount = #times,
                    })
                end
            end)
            return res
        end, Table())
        :filter(function(line)
            return not recurrent or line.amount == M._threshold
        end)
        :sort(function(a, b)
            return a.avg > b.avg
        end)
        :filter(function(_, i)
            return not amount or i <= amount
        end)
        :reduce(function(out, line)
            return string.var("{1}{2}.{3} - min {4}ms ; max {5}ms ; avg {6}ms [{7}]\n",
                { out, line.manager, line.event, line.min, line.max, line.avg, line.amount })
        end, "")
end

---@param amount? integer
---@param recurrent? boolean
function M.startWindow(amount, recurrent)
    M.STATE = 1
    M.reset()
    BJI.DEBUG = function() return M.get(amount or 10, recurrent ~= false) end
end

local init = false
function M.startGC()
    gcprobe(false, true)
    timeprobe(true)
    init = true
end

---@param name string
function M.saveGC(name)
    if init then
        M.gcdata[name] = { t = tonumber(timeprobe(true)), gc = tonumber(gcprobe(false, true)) }
    end
    init = false
end

local data
function M.showGC(sorted)
    M.STATE = 2
    M.reset()
    BJI.DEBUG = function()
        data = M.gcdata:map(function(v, k)
            return {
                name = k,
                t = v.t,
                gc = v.gc,
            }
        end)
        if sorted ~= false then
            data:sort(function(a, b)
                if a.gc ~= b.gc then
                    return a.gc > b.gc
                end
                return a.t > b.t
            end)
        end
        return data:reduce(function(res, v)
            res = res .. v.name .. " = " .. tostring(v.gc) .. " - " .. tostring(math.round(v.t, 6)) .. "\n"
            return res
        end, "\n")
    end
end

function M.reset()
    if M.data then M.data:clear() end
    if M.gcdata then M.gcdata:clear() end
end

function M.stop()
    M.STATE = 0
    M.reset()
    BJI.DEBUG = nil
end

return M
