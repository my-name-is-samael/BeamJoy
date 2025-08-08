-- MATH UTILS

---@param value number
---@param fromMin number
---@param fromMax number
---@param toMin number
---@param toMax number
---@param clamped? boolean
---@return number
math.map = math.map or function(value, fromMin, fromMax, toMin, toMax, clamped)
    if not table.every({ value, fromMin, fromMax, toMin, toMax }, function(V) return type(V) == "number" end) then
        return value
    end
    local res = (value - fromMin) / (fromMax - fromMin) * (toMax - toMin) + toMin
    if clamped then
        res = math.clamp(res, math.min(toMin, toMax), math.max(toMin, toMax))
    end
    return res
end
math.scale = math.map

---@param value number
---@param min? number
---@param max? number
---@return number
math.clamp = math.clamp or function(value, min, max)
    if not table.every({ value, min, max }, function(V) return type(V) == "number" end) then
        return value
    end
    if min ~= nil and value < min then
        value = min
    elseif max ~= nil and value > max then
        value = max
    end
    return value
end

---@param val number
---@param prec? integer
---@return number
math.round = math.round or function(val, prec)
    if type(val) ~= "number" then return 0 end
    prec = prec or 0
    if prec < 0 then
        return val
    end
    return tonumber(string.format("%." .. tostring(prec) .. "f", val)) or 0
end

---@param pos1 vec3
---@param pos2 vec3
---@return number
math.horizontalDistance = math.horizontalDistance or function(pos1, pos2)
    if not pos1 or not pos2 or
        not pos1.x or not pos1.y or
        not pos2.x or not pos2.y then
        LogError("invalid position")
        return 0
    end

    return math.sqrt((pos1.x - pos2.x) ^ 2 + (pos1.y - pos2.y) ^ 2)
end

---@return Timer
math.timer = math.timer or function()
    return {
        _timer = MP.CreateTimer(),
        get = function(self)
            local secTime = self._timer:GetCurrent()
            return math.round(secTime * 1000)
        end,
        reset = function(self)
            self._timer:Start()
        end
    }
end
