-- ALREADY PRESENT FUNCTIONS

table.clear = table.clear
table.concat = table.concat
table.deepcopy = table.deepcopy
table.foreach = table.foreach
table.foreachi = table.foreachi
table.getn = table.getn
table.insert = table.insert
table.maxn = table.maxn
table.move = table.move
table.new = table.new
table.remove = table.remove
table.shallowcopy = table.shallowcopy
table.sort = table.sort

-- ADD-ONS

---@generic K, V
---@class tablelib<any, any> : table
---@field isArray fun(tab: table<any, any>): boolean
---@field isObject fun(tab: table<any, any>): boolean
---@field nextIndex fun(tab: table<any, any>, index: any): any
---@field flat fun(tab: table<any, any>): tablelib<any, any>
---@field assign fun(tab: table<any, any>, source: table<any, any>, level?: integer): tablelib<any, any>
---@field keys fun(tab: table<any, any>): tablelib<any, any>
---@field values fun(tab: table<any, any>): tablelib<any, any>
---@field clear fun(tab: table<any, any>): tablelib<any, any>
---@field concat fun(tab: table<any, any>, sep: string, keys: boolean): string
---@field join fun(tab: table<any, any>, sep: string, keys: boolean): string
---@field duplicates fun(tab: table<any, any>, distinct: boolean): tablelib<any, any>
---@field includes fun(tab: table<any, any>, el: any): boolean
---@field contains fun(tab: table<any, any>, el: any): boolean
---@field indexOf fun(tab: table<any, any>, el: any): integer
---@field length fun(tab: table<any, any>): integer
---@field random fun(tab: table<any, any>): any
---@field filter fun(tab: table<any, any>, func: fun(el: any, index: any, tab: table<any, any>): boolean): tablelib<any, any>
---@field forEach fun(tab: table<any, any>, func: fun(el: any, index: any, tab: table<any, any>))
---@field map fun(tab: table<any, any>, func: fun(el: any, index: any, tab: table<any, any>): any): tablelib<any, any>
---@field reduce fun(tab: table<any, any>, func: fun(acc: any, el: any, index: any, tab: table<any, any>)): any
---@field every fun(tab: table<any, any>, func: fun(el: any, index: any, tab: table<any, any>): boolean): boolean
---@field all fun(tab: table<any, any>, func: fun(el: any, index: any, tab: table<any, any>)): boolean
---@field some fun(tab: table<any, any>, func: fun(el: any, index: any, tab: table<any, any>): boolean): boolean
---@field any fun(tab: table<any, any>, func: fun(el: any, index: any, tab: table<any, any>): boolean): boolean
---@field find fun(tab: table<any, any>, func: (fun(el: any, index: any, tab: table<any, any>): boolean), callbackFn: fun(el: any, index: any)?): any, integer
---@field compare fun(tab1: table<any, any>, tab2: table<any, any>, deep?: boolean): boolean
---@field shallowcompare fun(tab1: table<any, any>, tab2: table<any, any>): tablelib<any, any>
---@field deepcompare fun(tab1: table<any, any>, tab2: table<any, any>): tablelib<any, any>
---@field clone fun(tab: table<any, any>, level?: integer): tablelib<any, any>
---@field unpack fun(tab: table<any, any>): ...
---@field sort fun(tab: table<any, any>, func: fun(el1: any, el2: any): boolean)


--- allow to chain "stream" function (ig table.filter({}, function()  end):forEach(function() end))
---@param tab table<any, any>
---@return tablelib<any, any>
local function metatable(tab)
    return setmetatable(tab, { __index = table })
end

---@param tab table<any, any>
---@return boolean
table.isArray = table.isArray or function(tab)
    return type(tab) == "table" and #tab == table.length(tab)
end

---@param tab table<any, any>
---@return boolean
table.isObject = table.isObject or function(tab)
    return type(tab) == "table" and #tab ~= table.length(tab)
end

---@param tab table<any, any>
---@param distinct? boolean
---@return tablelib<any, any>
table.duplicates = table.duplicates or function(tab, distinct)
    if type(tab) ~= "table" then return metatable({}) end
    if type(distinct) ~= "boolean" then distinct = false end
    local saw = {}
    local res = {}
    for _, v in pairs(tab) do
        if not saw[v] then
            saw[v] = true
        elseif not table.includes(res, v) or not distinct then
            table.insert(res, v)
        end
    end
    return metatable(res)
end

---@param tab table<any, any>
---@return any|nil
table.random = table.random or function(tab)
    if type(tab) ~= "table" then return nil end
    if table.length(tab) == 0 then return nil end
    local picked = math.random(1, table.length(tab))
    local i = 1
    for _, v in pairs(tab) do
        if i == picked then
            if type(v) == "table" then
                return metatable(v)
            else
                return v
            end
        end
        i = i + 1
    end
end

---@param tab table<any, any>
---@param index any
---@return integer|string|nil
table.nextIndex = table.nextIndex or function(tab, index)
    if type(tab) ~= "table" then return nil end
    if table.isArray(tab) then
        return index + 1 <= #tab and index + 1 or nil
    else
        local next = false
        for k in pairs(tab) do
            if not next and k == index then
                next = true
            elseif next then
                return k
            end
        end
    end
    local next = index + 1 % table.length(tab) + 1
    if next == 0 then
        next = 1
    end
    return next
end

-- table.concat only works on arrays, table.join is working on objects too
---@param tab table<any, any>
---@param sep? string
---@param keys? boolean
table.join = table.join or function(tab, sep, keys)
    if type(tab) ~= "table" then return "" end
    if type(sep) ~= "string" then sep = "" end
    if table.isArray(tab) then
        if keys then
            local str = "";
            for i, v in ipairs(tab) do
                str = ("%s%d:%s"):format(str, i, tostring(v))
                if i ~= table.length(tab) then
                    str = str .. sep
                end
                i = i + 1
            end
            return str
        else
            return table.concat(tab, sep)
        end
    else
        local str = "";
        local i = 1
        for k, v in pairs(tab) do
            str = ("%s%s%s"):format(str, keys and (tostring(k) .. ":") or "", tostring(v))
            if i ~= table.length(tab) then
                str = str .. sep
            end
            i = i + 1
        end
        return str
    end
end

---@param tab1 table<any, any>
---@param tab2 table<any, any>
---@return tablelib<any, any>
table.concat = table.concat or function(tab1, tab2)
    if type(tab1) ~= "table" or type(tab2) ~= "table" then return metatable({}) end
    local res = {}
    table.forEach(tab1, function(v) table.insert(res, v) end)
    table.forEach(tab2, function(v) table.insert(res, v) end)
    return metatable(res)
end

---@param tab table<any, any>
---@return tablelib<any, any>
table.flat = table.flat or function(tab)
    if type(tab) ~= "table" then return metatable({}) end
    local res = {}
    table.forEach(tab, function(v)
        if type(v) == "table" then
            table.forEach(table.flat(v), function(v) table.insert(res, v) end)
        else
            table.insert(res, v)
        end
    end)
    return metatable(res)
end

---@param tab table<any, any>
---@param val any
---@return any result nil if not found
table.indexOf = table.indexOf or function(tab, val)
    for k, v in pairs(tab) do
        if v == val then
            return k
        end
    end
end

---@param target table<any, any>
---@param source table<any, any>
---@param level? integer
table.assign = table.assign or function(target, source, level)
    if type(target) ~= "table" or type(source) ~= "table" then return target end
    if type(level) ~= "number" then
        level = 1
    else
        level = math.round(level)
        if level >= 20 then
            return {}
        end
    end
    for k, v in pairs(source) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then
                target[k] = {}
            end
            table.assign(target[k], v, level + 1)
        else
            target[k] = v
        end
    end
end

---@generic K, V, T
---@param tab table<K, V>
---@param mapFn fun(el: V, index: K, tab: table<K, V>): T
---@return tablelib<K, T>
table.map = table.map or function(tab, mapFn)
    if type(tab) ~= "table" then return metatable({}) end
    if type(mapFn) ~= "function" then return metatable({}) end
    local status, mapped
    local res = {}
    for k, v in pairs(tab) do
        status, res[k] = pcall(mapFn, v, k, tab)
        if not status then
            res[k] = nil
        end
    end
    return metatable(res)
end

---@generic K, V
---@param tab table<K, V>
---@param filterFn fun(el: V, index: K, tab: table<K, V>): boolean
---@return tablelib<K, V>
table.filter = table.filter or function(tab, filterFn)
    if type(tab) ~= "table" then return metatable({}) end
    if type(filterFn) ~= "function" then return metatable({}) end
    local res = {}
    for k, v in pairs(tab) do
        local status, cond = pcall(filterFn, v, k, tab)
        if status and cond then
            res[k] = v
        end
    end
    return metatable(res)
end

---@generic K, V
---@param tab table<K, V>
---@param someFn fun(el: V, index: K, tab: table<K, V>): boolean
---@return boolean
table.some = table.some or function(tab, someFn)
    if type(tab) ~= "table" then return false end
    if type(someFn) ~= "function" then return false end
    for k, v in pairs(tab) do
        local status, cond = pcall(someFn, v, k, tab)
        if status and cond then
            return true
        end
    end
    return false
end
table.any = table.any or table.some

---@generic K, V
---@param tab table<K, V>
---@param everyFn fun(el: V, index: K, tab: table<K, V>): boolean
---@return boolean
table.every = table.every or function(tab, everyFn)
    if type(tab) ~= "table" then return false end
    if type(everyFn) ~= "function" then return false end
    for k, v in pairs(tab) do
        local status, cond = pcall(everyFn, v, k, tab)
        if not status or not cond then
            return false
        end
    end
    return true
end
table.all = table.all or table.every

---@generic K, V, T
---@param tab table<K, V>
---@param reduceFn fun(value: T, el: V, index: K, tab: table<K, V>): T
---@param initialValue T
---@return T
table.reduce = table.reduce or function(tab, reduceFn, initialValue)
    if initialValue == nil then return initialValue end
    if type(tab) ~= "table" then return initialValue end
    if type(reduceFn) ~= "function" then return initialValue end
    local res = initialValue
    for k, v in pairs(tab) do
        local status, value = pcall(reduceFn, res, v, k, tab)
        if status then
            res = value
        end
    end
    return res
end

---@generic K, V
---@param tab table<K, V>
---@param foreachFn fun(el: V, index: K, tab: table<K, V>)
table.forEach = table.forEach or function(tab, foreachFn)
    if type(tab) ~= "table" then return end
    if type(foreachFn) ~= "function" then return end
    for k, v in pairs(tab) do
        foreachFn(v, k, tab)
    end
end

---@generic K, V
---@param tab table<K, V>
---@param findFn fun(el: V, index: K, tab: table<K, V>): boolean
---@param callbackFn? fun(el: V, index: K)
---@return V, K | nil
table.find = table.find or function(tab, findFn, callbackFn)
    if type(tab) ~= "table" then return nil end
    if type(findFn) ~= "function" then return nil end
    for k, v in pairs(tab) do
        local status, cond = pcall(findFn, v, k, tab)
        if status and cond then
            if callbackFn then
                callbackFn(v, k)
            end
            return v, k
        end
    end
    return nil
end

---@param tab table<any, any>
---@return integer
table.length = table.length or function(tab)
    if type(tab) ~= "table" then return 0 end
    local sum = 0
    table.forEach(tab, function() sum = sum + 1 end)
    return sum
end

---@generic K
---@param tab table<K, any>
---@return K[]
table.keys = table.keys or function(tab)
    if type(tab) ~= "table" then return metatable({}) end
    local res = {}
    for k in pairs(tab) do
        table.insert(res, k)
    end
    table.sort(res)
    return metatable(res)
end

---@generic V
---@param tab table<any, V>
---@return V[]
table.values = table.values or function(tab)
    if type(tab) ~= "table" then return metatable({}) end
    local res = {}
    for _, v in pairs(tab) do
        table.insert(res, v)
    end
    return metatable(res)
end

---@param tab table<any, any>
---@param el any
---@return boolean
table.includes = table.includes or function(tab, el)
    if type(tab) ~= "table" then return false end
    for _, v in pairs(tab) do
        if v == el then
            return true
        end
    end
    return false
end
table.contains = table.contains or table.includes

---@param tab1 table<any, any>
---@param tab2 table<any, any>
---@param deep? boolean DEFAULT to false
---@return boolean
table.compare = table.compare or function(tab1, tab2, deep)
    if type(tab1) ~= "table" or type(tab2) ~= "table" then return tab1 == tab2 end
    if #tab1 ~= #tab2 then return false end
    local saw = {}
    for k, v in pairs(tab1) do
        if type(v) == "table" and type(tab2[k]) == "table" then
            if deep and not table.compare(v, tab2[k], deep) then
                return false
            end
        elseif v ~= tab2[k] then
            return false
        end
        saw[k] = true
    end
    for k in pairs(tab2) do
        if not saw[k] then
            return false
        end
    end
    return true
end
---@param tab1 table<any, any>
---@param tab2 table<any, any>
---@return boolean
table.deepcompare = table.deepcompare or function(tab1, tab2)
    return table.compare(tab1, tab2, true)
end
---@param tab1 table<any, any>
---@param tab2 table<any, any>
---@return boolean
table.shallowcompare = table.shallowcompare or function(tab1, tab2)
    return table.compare(tab1, tab2)
end

-- Depends on Lua version
table.unpack = table.unpack or unpack

---@generic V
---@param obj V
---@param level? integer
---@return V
table.clone = table.clone or function(obj, level)
    if type(obj) ~= 'table' then
        return obj
    end
    -- table.deepcopy does not handle userdata and cdata types
    return metatable(table.deepcopy(obj))
end
