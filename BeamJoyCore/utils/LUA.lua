function GetCurrentTime()
    --[[
    local timezone = tostring(os.date('%z')) -- "+0200"
    local signum, hours, minutes = timezone:match('([+-])(%d%d)(%d%d)')

    local offset = (tonumber(signum .. hours) * 3600 + tonumber(signum .. minutes) * 60)
    ]]
    return os.time(os.date("!*t")) -- - offset
end

function GetSubobject(str)
    local parts = ssplit(str, ".")
    local obj = _G
    for i = 1, #parts do
        obj = obj[parts[i]]
        if obj == nil and i < #parts then
            error(svar("Subobject has reached nil in {1}", { parts[i] }))
            return nil
        end
    end
    return obj
end

function Hash(obj)
    local str = JSON.stringifyRaw(obj)
    return tostring(SHA.sha256(str))
end

local PRINTOBJ_MAX_TABLE_CHILDREN = 20
local PRINTOBJ_MAX_TABLE_CHILDREN_SHOW = 3
function _PrintObj(name, obj, indent)
    if indent == nil then
        indent = 0
    end
    local strIndent = ""
    for _ = 1, indent * 4 do
        strIndent = strIndent .. " "
    end

    if type(obj) == "table" then
        if tlength(obj) == 0 then
            print(svar("{1}{2} ({3}) = empty table", { strIndent, name, type(name) }))
        elseif tlength(obj) > PRINTOBJ_MAX_TABLE_CHILDREN then
            print(svar("{1}{2} ({3}, {4} children)", { strIndent, name, type(name), tlength(obj) }))
            local i = 1
            for k in pairs(obj) do
                if i <= PRINTOBJ_MAX_TABLE_CHILDREN_SHOW then
                    _PrintObj(k, obj[k], indent + 1)
                    i = i + 1
                end
            end
            print(svar("{1}    ...", { strIndent }))
        else
            print(svar("{1}{2} ({3}) =", { strIndent, name, type(name) }))
            for k in pairs(obj) do
                _PrintObj(k, obj[k], indent + 1)
            end
        end
    elseif type(obj) == "function" then
        print(svar("{1}{2} ({3}) = function", { strIndent, name, type(name) }))
    elseif type(obj) == "string" then
        print(svar("{1}{2} ({3}) = \"{4}\" ({5})", { strIndent, name, type(name), sescape(obj), type(obj) }))
    else
        print(svar("{1}{2} ({3}) = {4} ({5})", { strIndent, name, type(name), tostring(obj), type(obj) }))
    end
end

function PrintObj(obj, name)
    if name == nil then
        name = "data"
    end
    _PrintObj(name, obj)
end

function PrintObj1Level(obj, str)
    if type(obj) ~= "table" then
        print("Not a table")
        return
    end
    if tlength(obj) == 0 then
        print("empty table")
    else
        local i = 1
        for k, v in pairs(obj) do
            if not str or k:upper():find(str:upper()) then
                if type(v) == "table" then
                    print(svar("{1}-{2} ({3} children)", { i, k, tlength(v) }))
                else
                    print(svar("{1}-{2} = {3} ({4})", { i, k, v, type(v) }))
                end
                i = i + 1
            end
        end
    end
end
