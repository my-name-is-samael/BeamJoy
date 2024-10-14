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

function CelsiusToFarenheit(celsius)
    return (celsius * 9 / 5) + 32
end
