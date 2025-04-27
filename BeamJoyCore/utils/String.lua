-- ALREADY PRESENT FUNCTIONS

string.byte = string.byte
string.char = string.char
string.dump = string.dump
string.find = string.find
string.format = string.format
string.gmatch = string.gmatch
string.gsub = string.gsub
string.len = string.len
string.lower = string.lower
string.match = string.match
string.pack = string.pack
string.packsize = string.packsize
string.rep = string.rep
string.reverse = string.reverse
string.sub = string.sub
string.unpack = string.unpack
string.upper = string.upper

-- RECOVER FROM CLIENT FUNCTIONS

string.c_str = string.c_str or function()
    LogWarn("string.c_str is not implemented")
end

---@param str string
---@param seq string
---@return boolean
string.endswith = string.endswith or function(str, seq)
    if type(str) ~= "string" then return false end
    return str:sub(- #seq) == seq
end

---@param str string
---@param chars string
---@return string, number
string.rstripchars = string.rstripchars or function(str, chars)
    if type(str) ~= "string" then return "", 0 end
    if type(chars) ~= "string" then return str, 0 end
    local count = 0
    while chars:find(str:sub(-1, -1)) do
        str = str:sub(1, -2)
        count = count + 1
    end
    return str, count
end

---@param str string
---@return string
string.sentenceCase = string.sentenceCase or function(str)
    if type(str) ~= "string" then return "" end
    local res = str:lower():gsub("^%l", string.upper)
    return res
end

---@param str string
---@param sep string
---@return table
string.split = string.split or function(str, sep)
    if type(str) ~= "string" then return {} end
    if type(sep) ~= "string" then return {} end
    local res = {}
    for s in string.gmatch(str, "([^" .. sep .. "]+)") do
        table.insert(res, s)
    end
    return res
end

---@param str string
---@param seq string
---@return boolean
string.startswith = string.startswith or function(str, seq)
    if type(str) ~= "string" then return false end
    if type(seq) ~= "string" then return false end
    return str:sub(1, #seq) == seq
end

---@param str string
---@param chars string
---@return string, number
string.stripchars = string.stripchars or function(str, chars)
    if type(str) ~= "string" then return "", 0 end
    if type(chars) ~= "string" then return str, 0 end
    local count = 0
    while chars:find(str:sub(1, 1)) do
        str = str:sub(2, #str)
        count = count + 1
    end
    while chars:find(str:sub(-1, -1)) do
        str = str:sub(1, -2)
        count = count + 1
    end
    return str, count
end

---@param str string
---@param chars string
---@return string
string.stripcharsFrontBack = string.stripcharsFrontBack or function(str, chars)
    if type(chars) ~= "string" then return "" end
    str = str:stripchars(chars)
    return str
end

-- ADD-ONS

---@param str string
---@return string
string.capitalize = string.capitalize or function(str)
    if type(str) ~= "string" then return "" end
    return str:sentenceCase()
end

---@param str string
---@return string
string.capitalizeWords = string.capitalizeWords or function(str)
    if type(str) ~= "string" then return "" end
    local delims = { " ", "-", ".", ",", ":", ";", "'", '"', "(", ")" }
    table.forEach(delims, function(d)
        ---@type string[]
        local words = str:split(d)
        for i in ipairs(words) do
            words[i] = words[i]:capitalize()
        end
        str = table.concat(words, d)
    end)
    return str
end

---@param str string
---@return string
string.trim = string.trim or function(str)
    if type(str) ~= "string" then return "" end
    return string.stripcharsFrontBack(str, " ")
end

---@param str string
---@return string
string.escape = string.escape or function(str)
    if type(str) ~= "string" then return "" end
    local toEscape = { "\\", '"', "\b", "\f", "\n", "\r", "\t" }
    local escaped = { "\\\\", '\\"', "\\b", "\\f", "\\n", "\\r", "\\t" }
    for i, toEsc in ipairs(toEscape) do
        str = str:gsub(toEsc, escaped[i])
    end
    return str
end

--- string.format only accepts "%" based values, string.var uses "{1}" and "{varName}" values
--- @param str string
---@param vars table<any, any>
---@return string
string.var = string.var or function(str, vars)
    if type(str) ~= "string" then return "" end
    if type(vars) ~= "table" then return str end
    if table.isArray(vars) then
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
    return str
end

---@param seq string
---@param count number
---@return string
string.build = string.build or function(seq, count)
    if type(seq) ~= "string" then seq = " " end
    if #seq < 1 then
        seq = " "
    end
    local res = ""
    for _ = 1, count do
        res = res .. seq
    end
    return res
end

---@param str string
---@param length integer
---@return string
string.normalize = string.normalize or function(str, length)
    if type(str) ~= "string" then return "" end
    if type(length) ~= "number" then return tostring(str) end
    while #str < length do
        str = str .. " "
    end
    while #str > length do
        str = str:sub(1, #str - 1)
    end
    return str
end

---@param int integer|string
---@param length integer
---@return string
string.normalizeInt = string.normalizeInt or function(int, length)
    if type(int) ~= "number" and type(int) ~= "string" then return "" end
    local str = tostring(int)
    if type(length) ~= "number" then return str end
    while #str < length do
        str = "0" .. str
    end
    return str
end

---@return string
UUID = UUID or function()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    local res = string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
    return res
end
