---@return integer
function GetCurrentTime()
    return os.time(os.date("!*t")) -- - offset
end

---@param str string
---@return any
function GetSubobject(str)
    if type(str) ~= "string" then return nil end
    local parts = str:split(".")
    local obj = _G
    for i = 1, #parts do
        obj = obj[parts[i]]
        if obj == nil and i < #parts then
            error(("Subobject has reached nil in %s"):format(parts[i]))
            return nil
        end
    end
    return obj
end

---@param obj any
---@return string
function Hash(obj)
    local str = JSON.stringifyRaw(obj)
    return tostring(SHA.sha256(str))
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
            print(("%s%s (%s) = empty table"):format(strIndent, tostring(name), type(name)))
        elseif table.length(obj) > PRINTOBJ_MAX_TABLE_CHILDREN then
            print(("%s%s (%s, %d children)"):format(strIndent, tostring(name), type(name), table.length(obj)))
            local i = 1
            for k in pairs(obj) do
                if i <= PRINTOBJ_MAX_TABLE_CHILDREN_SHOW then
                    _PrintObj(k, obj[k], indent + 1)
                    i = i + 1
                end
            end
            print(("%s    ..."):format(strIndent))
        else
            print(("%s%s (%s}) ="):format(strIndent, tostring(name), type(name)))
            for k in pairs(obj) do
                _PrintObj(k, obj[k], indent + 1)
            end
        end
    elseif type(obj) == "function" then
        print(("%s%s (%s) = function"):format(strIndent, tostring(name), type(name)))
    elseif type(obj) == "string" then
        print(("%s%s (%s) = \"%s\" (%s)"):format(strIndent, tostring(name), type(name), obj:escape(), type(obj)))
    else
        print(("%s%s (%s) = %s (%s)"):format(strIndent, tostring(name), type(name), tostring(obj), type(obj)))
    end
end

---@param obj any
---@param name? string
function PrintObj(obj, name)
    if name == nil then
        name = "data"
    end
    _PrintObj(name, obj)
end
dump = dump or PrintObj

---@param obj any
---@param str? string
function PrintObj1Level(obj, str)
    if type(obj) ~= "table" then
        print("Not a table")
        return
    end
    if table.length(obj) == 0 then
        print("empty table")
    else
        local i = 1
        for k, v in pairs(obj) do
            if not str or k:upper():find(str:upper()) then
                if type(v) == "table" then
                    print(("%d-%s (%d children)"):format(i, tostring(k), table.length(v)))
                else
                    print(("%d-%s = %s (%s)"):format(i, tostring(k), tostring(v), type(v)))
                end
                i = i + 1
            end
        end
    end
end