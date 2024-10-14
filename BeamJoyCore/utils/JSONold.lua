--[[ json.lua
A compact pure-Lua JSON library.
The main functions are: json.stringify, json.parse.
## json.stringify:
This expects the following to be true of any tables being encoded:
 * They only have string or number keys. Number keys must be represented as
   strings in json; this is part of the json spec.
 * They are not recursive. Such a structure cannot be specified in json.
A Lua table is considered to be an array if and only if its set of keys is a
consecutive sequence of positive integers starting at 1. Arrays are encoded like
so: `[2, 3, false, "hi"]`. Any other type of Lua table is encoded as a json
object, encoded like so: `{"key1": 2, "key2": false}`.
Because the Lua nil value cannot be a key, and as a table value is considered
equivalent to a missing key, there is no way to express the json "null" value in
a Lua table. The only way this will output "null" is if your entire input obj is
nil itself.
An empty Lua table, {}, could be considered either a json object or array -
it's an ambiguous edge case. We choose to treat this as an object as it is the
more general type.
To be clear, none of the above considerations is a limitation of this code.
Rather, it is what we get when we completely observe the json specification for
as arbitrary a Lua object as json is capable of expressing.
## json.parse:
This function parses json, with the exception that it does not pay attention to
\u-escaped unicode code points in strings.
It is difficult for Lua to return null as a value. In order to prevent the loss
of keys with a null value in a json string, this function uses the one-off
table value json.null (which is just an empty table) to indicate null values.
This way you can check if a value is null with the conditional
`val == json.null`.
If you have control over the data and are using Lua, I would recommend just
avoiding null values in your data to begin with.
--]]

local json = {}

-- Internal functions.

local function kind_of(obj)
    if type(obj) ~= 'table' then return type(obj) end
    local i = 1
    for _ in pairs(obj) do
        if obj[i] ~= nil then i = i + 1 else return 'table' end
    end
    if i == 1 then return 'table' else return 'array' end
end

local function escape_str(s)
    local in_char  = { '\\', '"', '/', '\b', '\f', '\n', '\r', '\t' }
    local out_char = { '\\', '"', '/', 'b', 'f', 'n', 'r', 't' }
    for i, c in ipairs(in_char) do
        s = s:gsub(c, '\\' .. out_char[i])
    end
    return s
end

-- Returns pos, did_find; there are two cases:
-- 1. Delimiter found: pos = pos after leading space + delim; did_find = true.
-- 2. Delimiter not found: pos = pos after leading space;     did_find = false.
-- This throws an error if err_if_missing is true and the delim is not found.
local function skip_delim(str, pos, delim, err_if_missing)
    pos = pos + #str:match('^%s*', pos)
    if str:sub(pos, pos) ~= delim then
        if err_if_missing then
            error('Expected ' .. delim .. ' near position ' .. pos)
        end
        return pos, false
    end
    return pos + 1, true
end

-- Expects the given pos to be the first character after the opening quote.
-- Returns val, pos; the returned pos is after the closing quote character.
local function parse_str_val(str, pos, val)
    val = val or ''
    local early_end_error = 'End of input found while parsing string.'
    if pos > #str then error(early_end_error) end
    local c = str:sub(pos, pos)
    if c == '"' then return val, pos + 1 end
    if c ~= '\\' then return parse_str_val(str, pos + 1, val .. c) end
    -- We must have a \ character.
    local esc_map = { b = '\b', f = '\f', n = '\n', r = '\r', t = '\t' }
    local nextc = str:sub(pos + 1, pos + 1)
    if not nextc then error(early_end_error) end
    return parse_str_val(str, pos + 2, val .. (esc_map[nextc] or nextc))
end

-- Returns val, pos; the returned pos is after the number's final character.
local function parse_num_val(str, pos)
    local num_str = str:match('^-?%d+%.?%d*[eE]?[+-]?%d*', pos)
    local val = tonumber(num_str)
    if not val then error('Error parsing number at position ' .. pos .. '.') end
    return val, pos + #num_str
end


-- Public values and functions.

function json.stringify(obj, level, key)
    if not level then
        level = 0
    end

    local s = {}

    local indent = ""
    for _ = 1, level do
        indent = indent .. "    "
    end

    s[#s + 1] = indent
    if key then
        s[#s + 1] = "\"" .. key .. "\": "
    end
    if tincludes({ "boolean", "number" }, type(obj)) then
        s[#s + 1] = tostring(obj)
    elseif type(obj) == "string" then
        s[#s + 1] = "\"" .. sescape(obj) .. "\""
    elseif type(obj) == "nil" then
        s[#s + 1] = "null"
    elseif type(obj) == "table" then
        if tisarray(obj) then
            s[#s + 1] = "[\n"
            for i, v in ipairs(obj) do
                if i > 1 then
                    s[#s + 1] = ",\n"
                end
                s[#s + 1] = json.stringify(v, level + 1)
            end
            s[#s + 1] = "\n"
            s[#s + 1] = indent
            s[#s + 1] = "]"
        else
            s[#s + 1] = "{\n"
            local i = 1
            for k, v in pairs(obj) do
                if i > 1 then
                    s[#s + 1] = ",\n"
                end
                s[#s + 1] = json.stringify(v, level + 1, k)
                i = i + 1
            end
            s[#s + 1] = "\n"
            s[#s + 1] = indent
            s[#s + 1] = "}"
        end
    end

    return table.concat(s)
end

function json.stringifyRaw(obj, key)
    local s = {}

    if key then
        s[#s + 1] = "\"" .. key .. "\":"
    end
    if tincludes({ "boolean", "number" }, type(obj)) then
        s[#s + 1] = tostring(obj)
    elseif type(obj) == "string" then
        s[#s + 1] = "\"" .. sescape(obj) .. "\""
    elseif type(obj) == "nil" then
        s[#s + 1] = "null"
    elseif type(obj) == "table" then
        --[[if tisarray(obj) then
            s[#s + 1] = "["
            for i, v in ipairs(obj) do
                if i > 1 then
                    s[#s + 1] = ","
                end
                s[#s + 1] = json.stringifyRaw(v)
            end
            s[#s + 1] = "]"
        else]]
        s[#s + 1] = "{"
        local i = 1
        for k, v in pairs(obj) do
            if i > 1 then
                s[#s + 1] = ","
            end
            s[#s + 1] = json.stringifyRaw(v, k)
            i = i + 1
        end
        s[#s + 1] = "}"
        --end
    end

    return table.concat(s)
end

json.null = {} -- This is a one-off table to represent the null value.

function json.parse(str, pos, end_delim)
    pos = pos or 1
    if pos > #str then error('Reached unexpected end of input.') end
    local pos = pos + #str:match('^%s*', pos) -- Skip whitespace.
    local first = str:sub(pos, pos)
    if first == '{' then                      -- Parse an object.
        local obj, key, delim_found = {}, true, true
        pos = pos + 1
        while true do
            key, pos = json.parse(str, pos, '}')
            if key == nil then return obj, pos end
            if not delim_found then error('Comma missing between object items.') end
            pos = skip_delim(str, pos, ':', true) -- true -> error if missing.
            obj[key], pos = json.parse(str, pos)
            pos, delim_found = skip_delim(str, pos, ',')
        end
    elseif first == '[' then -- Parse an array.
        local arr, val, delim_found = {}, true, true
        pos = pos + 1
        while true do
            val, pos = json.parse(str, pos, ']')
            if val == nil then return arr, pos end
            if not delim_found then error('Comma missing between array items.') end
            arr[#arr + 1] = val
            pos, delim_found = skip_delim(str, pos, ',')
        end
    elseif first == '"' then                      -- Parse a string.
        return parse_str_val(str, pos + 1)
    elseif first == '-' or first:match('%d') then -- Parse a number.
        return parse_num_val(str, pos)
    elseif first == end_delim then                -- End of an object or array.
        return nil, pos + 1
    else                                          -- Parse true, false, or null.
        local literals = { ['true'] = true, ['false'] = false, ['null'] = json.null }
        for lit_str, lit_val in pairs(literals) do
            local lit_end = pos + #lit_str - 1
            if str:sub(pos, lit_end) == lit_str then return lit_val, lit_end + 1 end
        end
        local pos_info_str = 'position ' .. pos .. ': ' .. str:sub(pos, pos + 10)
        error('Invalid json syntax starting at ' .. pos_info_str)
    end
end

return json
