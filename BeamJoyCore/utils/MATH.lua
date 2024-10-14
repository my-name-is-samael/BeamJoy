function Round(val, precision)
    if not precision or not tonumber(precision) or precision < 0 then
        precision = 0
    end
    return tonumber(string.format(svar("%.{1}f", { precision }), val))
end

function Clamp(value, min, max)
    if value < min then
        return min
    elseif value > max then
        return max
    end
    return value
end
