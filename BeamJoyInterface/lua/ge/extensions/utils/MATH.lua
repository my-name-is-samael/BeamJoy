function Round(val, precision)
    if not precision or not tonumber(precision) or precision < 0 then
        precision = 0
    end
    return tonumber(string.format(svar("%.{1}f", { precision }), tonumber(val) or 0))
end

function Clamp(value, min, max)
    if min and value < min then
        return min
    elseif max and value > max then
        return max
    end
    return value
end

function Scale(value, sourceMin, sourceMax, targetMin, targetMax, clamped)
    local scaled = ((value - sourceMin) / (sourceMax - sourceMin)) * (targetMax - targetMin) + targetMin
    if clamped then
        scaled = Clamp(scaled,
            targetMin < targetMax and targetMin or targetMax,
            targetMax > targetMin and targetMax or targetMin)
    end
    return scaled
end

function KelvinToCelsius(kelvin)
    return kelvin - 273.15
end

function CelsiusToKelvin(celsius)
    return celsius + 273.15
end

function KelvinToFahrenheit(kelvin)
    return (kelvin - 273.15) * (9 / 5) + 32
end

-- override because deprecated in lua.math
function Atan2(y, x)
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

function Rotate2DVec(vec, rad)
    local cosrad, sinrad = math.cos(rad), math.sin(rad)
    local res = vec3()
    res.x = cosrad * vec.x - sinrad * vec.y
    res.y = sinrad * vec.x + cosrad * vec.y
    return res
end

function AngleFromQuatRotation(rot)
    local sin_yaw = 2 * (rot.w * rot.z + rot.x * rot.y)
    local cos_yaw = 1 - 2 * (rot.y ^ 2 + rot.z ^ 2)
    local angle = Atan2(sin_yaw, cos_yaw) + math.pi
    return Scale(angle, 0, math.pi * 2, math.pi * 2, 0)
end
