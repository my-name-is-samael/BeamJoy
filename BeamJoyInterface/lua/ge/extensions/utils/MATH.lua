-- MATH UTILS

---@class point
---@field x number
---@field y number

---@class vec3: point
---@field z number
---@field distance fun(self: vec3, target: vec3): number|nil
---@field normalized fun(self: vec3): vec3 -- non-mutable
---@field normalize fun(self: vec3) -- self-mutable
---@field cross fun(self: vec3, target: vec3): vec3
---@field dot fun(self: vec3, target: vec3): number

---@class vec4 : point
---@field z number
---@field w number

---@class quat: point
---@field z number
---@field w number
---@field inversed fun(self: quat): quat
---@field setFromEuler fun(self: quat, x: number, y: number, z: number)
---@field setMul2 fun(self: quat, target: quat, target2: quat)
---@field normalized fun(self: quat): quat -- non-mutable
---@field normalize fun(self: quat) -- self-mutable

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

math.quatToForwardVector = math.quatToForwardVector or function(rot)
    return (rot * vec3(0, -1, 0)):normalized()
end

---@param pos1 vec3
---@param pos2 vec3
---@return number|nil
math.horizontalDistance = math.horizontalDistance or function(pos1, pos2)
    local _, _, err = pcall(vec3, pos1)
    local _, _, err2 = pcall(vec3, pos2)
    if err or err2 or not pos1 or not pos2 then
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

---@param a vec4?
---@param b vec4?
math.compareVec4 = math.compareVec4 or function(a, b)
    if not a or not b then return a == b end
    return a.x == b.x and a.y == b.y and a.z == b.z and a.w == b.w
end

---@param color vec4
---@return {[0]: number, [1]: number, [2]: number, [3]: number}
math.vec4ColorToStorage = math.vec4ColorToStorage or function(color)
    return {
        math.round(color.x, BJI.Utils.Style.RGBA_PRECISION),
        math.round(color.y, BJI.Utils.Style.RGBA_PRECISION),
        math.round(color.z, BJI.Utils.Style.RGBA_PRECISION),
        math.round(color.w, BJI.Utils.Style.RGBA_PRECISION)
    }
end

---@param rot quat
---@return vec3 dirFront, vec3 dirUp
math.rotationQuatToDirFrontAndUp = math.rotationQuatToDirFrontAndUp or function(rot)
    return rot * vec3(0, -1, 0), rot * vec3(0, 0, 1)
end
