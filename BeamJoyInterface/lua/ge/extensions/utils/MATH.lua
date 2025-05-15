-- MATH UTILS

---@class point
---@field x number
---@field y number

---@class vec3: point
---@field z number
---@field distance fun(self: vec3, target: vec3): number|nil
---@field normalized fun(self: vec3): vec3

---@class vec4 : point
---@field z number
---@field w number

---@class quat: point
---@field z number
---@field w number
---@field inversed fun(self: quat): quat

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
---@return vec3
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

---@param pos1 vec3
---@param pos2 vec3
---@return number|nil
math.horizontalDistance = math.horizontalDistance or function(pos1, pos2)
    local _, _, err = pcall(vec3, pos1)
    local _, _, err2 = pcall(vec3, pos2)
    if err or err2 then
        LogError("invalid position", "GetHorizontalDistance")
        return 0
    end

    local p1 = vec3(pos1.x, pos1.y, 0)
    local p2 = vec3(pos2.x, pos2.y, 0)
    return p1:distance(p2)
end

---@param obj table
---@return BJIPositionRotation
math.tryParsePosRot = math.tryParsePosRot or function(obj)
    if type(obj) ~= "table" then
        return obj
    end

    if table.includes({ "table", "userdata" }, type(obj.pos)) and
        table.every({ "x", "y", "z" }, function(k) return obj.pos[k] ~= nil end) then
        obj.pos = vec3(obj.pos.x, obj.pos.y, obj.pos.z)
    end
    if table.includes({ "table", "userdata" }, type(obj.rot)) and
        table.every({ "x", "y", "z", "w" }, function(k) return obj.rot[k] ~= nil end) then
        obj.rot = quat(obj.rot.x, obj.rot.y, obj.rot.z, obj.rot.w)
    end
    return obj
end

---@param posRot BJIPositionRotation
---@return BJIPositionRotation
math.roundPositionRotation = math.roundPositionRotation or function(posRot)
    if posRot and posRot.pos then
        posRot.pos.x = math.round(posRot.pos.x, 3)
        posRot.pos.y = math.round(posRot.pos.y, 3)
        posRot.pos.z = math.round(posRot.pos.z, 3)
    end
    if posRot and posRot.rot then
        posRot.rot.x = math.round(posRot.rot.x, 4)
        posRot.rot.y = math.round(posRot.rot.y, 4)
        posRot.rot.z = math.round(posRot.rot.z, 4)
        posRot.rot.w = math.round(posRot.rot.w, 4)
    end
    return posRot
end

---@class Timer
---@field get fun(self): number
---@field reset fun(self)
math.timer = math.timer or function()
    return ({
        _timer = hptimer(),
        get = function(self)
            local timeStr = tostring(self._timer):gsub("s", "")
            return math.floor(tonumber(timeStr) or 0)
        end,
        reset = function(self)
            self._timer:stopAndReset()
        end
    })
end
