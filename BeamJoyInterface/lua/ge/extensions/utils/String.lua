function sescape(str)
    local toEscape = { "\\", '"', "\b", "\f", "\n", "\r", "\t" }
    local escaped = { "\\\\", '\\"', "\\b", "\\f", "\\n", "\\r", "\\t" }
    for i, toEsc in ipairs(toEscape) do
        str = str:gsub(toEsc, escaped[i])
    end
    return str
end

function ssplit(str, separator)
    if not str or not separator then
        LogError("Invalid Split data")
        return {str or ""}
    end
    local t = {}
    for s in str:gmatch("([^" .. separator .. "]+)") do
        t[#t + 1] = s
    end
    return t
end

function strim(str)
    local result = string.gsub(str, "^%s*(.-)%s*$", "%1")
    return result
end

function svar(str, vars)
    if type(vars) ~= "table" then
        return str
    end
    if tisarray(vars) then
        for i, v in ipairs(vars) do
            while (str:find("{" .. tostring(i) .. "}")) do
                str = str:gsub("{" .. tostring(i) .. "}", tostring(v))
            end
        end
    else
        for k, v in pairs(vars) do
            while (str:find("{" .. tostring(k) .. "}")) do
                str = str:gsub("{" .. tostring(k) .. "}", tostring(v))
            end
        end
    end
    return tostring(str)
end

function snormalize(str, length)
    str = tostring(str)
    while #str < length do
        str = str .. " "
    end
    return str
end

function snormalizeint(int, length)
    local str = tostring(int)
    while #str < length do
        str = "0" .. str
    end
    return str
end

function sendswith(str, suffix)
    return str:sub(-#suffix) == suffix
end

function scapitalizewords(str)
    local words = ssplit(str, " ")
    for i in ipairs(words) do
        words[i] = words[i]:lower():gsub("^%l", string.upper)
    end
    return table.concat(words, " ")
end

function sfindinwords(target, search)
    local pTarget = ssplit(target, " ")
    local pSearch = ssplit(search, " ")
    for _, s in ipairs(pSearch) do
        for _, t in ipairs(pTarget) do
            if t:lower():find(s:lower()) then
                return true
            end
        end
    end
    return false
end

function UUID()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end