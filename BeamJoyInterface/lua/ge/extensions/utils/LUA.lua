---@return true
function TrueFn()
    return true
end

---@return false
function FalseFn()
    return false
end

---@return integer
function GetCurrentTime()
    return os.time(os.date("!*t")) ---@diagnostic disable-line
end

---@return integer
function GetCurrentTimeMillis()
    local ms = require "socket".gettime() % 1
    local time = GetCurrentTime() + ms
    return math.round(time * 1000)
end

---@param str string
---@return any
function GetSubobject(str)
    local parts = str:split2(".")
    local obj = _G
    for i = 1, #parts do
        obj = obj[parts[i]]
        if obj == nil and i < #parts then
            error(string.var("Subobject has reached nil in {1}", { parts[i] }))
            return nil
        end
    end
    return obj
end

local PRINTOBJ_MAX_TABLE_CHILDREN = 20
local PRINTOBJ_MAX_TABLE_CHILDREN_SHOW = 3
---@param name string
---@param obj any
---@param indent? integer
function _PrintObj(name, obj, indent)
    if indent == nil then
        indent = 0
    end
    local strIndent = ""
    for _ = 1, indent * 4 do
        strIndent = strIndent .. " "
    end

    if type(obj) == "table" then
        if table.length(obj) == 0 then
            print(string.var("{1}{2} ({3}) = empty table", { strIndent, name, type(name) }))
        elseif table.length(obj) > PRINTOBJ_MAX_TABLE_CHILDREN then
            print(string.var("{1}{2} ({3}, {4} children)", { strIndent, name, type(name), table.length(obj) }))
            local i = 1
            for k in pairs(obj) do
                if i <= PRINTOBJ_MAX_TABLE_CHILDREN_SHOW then
                    _PrintObj(k, obj[k], indent + 1)
                    i = i + 1
                end
            end
            print(string.var("{1}    ...", { strIndent }))
        else
            print(string.var("{1}{2} ({3}) =", { strIndent, name, type(name) }))
            for k in pairs(obj) do
                _PrintObj(k, obj[k], indent + 1)
            end
        end
    elseif type(obj) == "function" then
        print(string.var("{1}{2} ({3}) = function", { strIndent, name, type(name) }))
    elseif type(obj) == "string" then
        print(string.var("{1}{2} ({3}) = \"{4}\" ({5})",
            { strIndent, name, type(name), tostring(obj):escape(), type(obj) }))
    else
        print(string.var("{1}{2} ({3}) = {4} ({5})", { strIndent, name, type(name), tostring(obj), type(obj) }))
    end
end

---@param ... any
function PrintObj(...)
    table.forEach({ ... }, function(el)
        _PrintObj("data", el)
    end)
end

dump = dump or PrintObj

---@param obj any
---@param filterStr? string
function PrintObj1Level(obj, filterStr)
    if type(obj) ~= "table" then
        print("Not a table")
        return
    end
    if table.length(obj) == 0 then
        print("empty table")
    else
        local i = 1
        for k, v in pairs(obj) do
            if not filterStr or k:upper():find(filterStr:upper()) then
                if type(v) == "table" then
                    print(string.var("{1}-{2} ({3} children)", { i, k, table.length(v) }))
                else
                    print(string.var("{1}-{2} = {3} ({4})", { i, k, v, type(v) }))
                end
                i = i + 1
            end
        end
    end
end

--[[

-- count recursively every element in table tree
countElems = function(el)
    if type(el) ~= "table" then return 1 end
    return Table(el):reduce(function(acc, v)
        if type(v) == "table" then
            acc = acc + countElems(v)
        else
            acc = acc + 1
        end
        return acc
    end, 1);
end

]]
