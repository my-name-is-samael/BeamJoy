-- MATH UTILS

---@class vec3
---@field x number
---@field y number
---@field z number
---@field distance fun(self: vec3, target: vec3): number|nil

---@class vec4
---@field x number
---@field y number
---@field z number
---@field w number

---@class quat
---@field x number
---@field y number
---@field z number
---@field w number

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

---@param kelvin number
---@return number
math.kelvinToCelsius = math.kelvinToCelsius or function(kelvin)
    return kelvin - 273.15
end

---@param celsius number
---@return number
math.celsiusToKelvin = math.celsiusToKelvin or function(celsius)
    return celsius + 273.15
end

---@param kelvin number
---@return number
math.kelvinToFahrenheit = math.kelvinToFahrenheit or function(kelvin)
    return (kelvin - 273.15) * (9 / 5) + 32
end

-- deprecated in lua.math
---@param y number
---@param x number
---@return number
math.atan2 = math.atan2 or function(y, x)
    if x > 0 then
        return math.atan(y / x)
    elseif x < 0 and y >= 0 then
        return math.atan(y / x) + math.pi
    elseif x < 0 and y < 0 then
        return math.atan(y / x) - math.pi
    elseif x == 0 and y > 0 then
        return math.pi / 2
    elseif x == 0 and y < 0 then
        return -math.pi / 2
    else
        return 0
    end;
end

---@param vec vec3
---@param rad number
math.rotate2DVec = math.rotate2DVec or function(vec, rad)
    local cosrad, sinrad = math.cos(rad), math.sin(rad)
    local res = vec3()
    res.x = cosrad * vec.x - sinrad * vec.y
    res.y = sinrad * vec.x + cosrad * vec.y
    return res
end

---@param rot quat
---@return number
math.angleFromQuatRotation = math.angleFromQuatRotation or function(rot)
    local sin_yaw = 2 * (rot.w * rot.z + rot.x * rot.y)
    local cos_yaw = 1 - 2 * (rot.y ^ 2 + rot.z ^ 2)
    local angle = math.atan2(sin_yaw, cos_yaw) + math.pi
    return math.scale(angle, 0, math.pi * 2, math.pi * 2, 0)
end
