---@class tablelib: table

---@type tablelib
table = table

--- allow to chain "stream" function (ig table.filter({}, function()  end):forEach(function() end))
---@param tab table
---@return tablelib
local function metatable(tab)
    return setmetatable(tab, { __index = table })
end

--- Create a table with chained functions
---@param tab? table
---@return tablelib
function Table(tab)
    tab = tab or {}
    return metatable(tab)
end

--- Create a table filled with range
---@param startIndex integer
---@param endIndex integer
---@return tablelib<integer>
function Range(startIndex, endIndex)
    if type(endIndex) ~= "number" or type(startIndex) ~= "number" then return Table() end
    local res = Table()
    for i = startIndex, endIndex, startIndex <= endIndex and 1 or -1 do
        res:insert(i)
    end
    return res
end

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
--table.sort = table.sort -- Rewrite to handle object tables and chain result

-- ADD-ONS

---@param tab table
---@return boolean
table.isArray = table.isArray or function(tab)
    return type(tab) == "table" and #tab == Table(tab):length()
end

---@param tab table
---@return boolean
table.isObject = table.isObject or function(tab)
    return type(tab) == "table" and #tab ~= Table(tab):length()
end

---@param tab table
---@param distinct? boolean
---@return tablelib
table.duplicates = table.duplicates or function(tab, distinct)
    if type(tab) ~= "table" then return Table() end
    if type(distinct) ~= "boolean" then distinct = false end
    return Table(tab):reduce(function(acc, el)
        if acc.saw:includes(el) then
            if not distinct or not acc.dup:includes(el) then
                acc.dup:insert(el)
            end
        else
            acc.saw:insert(el)
        end
        return acc
    end, { saw = Table(), dup = Table() }).dup
end

---@param tab table
---@return any|nil
table.random = table.random or function(tab)
    if type(tab) ~= "table" then return nil end
    if table.length(tab) == 0 then return nil end
    tab = Table(tab)
    local picked = math.random(1, tab:length())
    return tab:reduce(function(acc, el)
        if acc.i == picked then
            acc.found = el
        end
        acc.i = acc.i + 1
        return acc
    end, { found = nil, i = 1 }).found
end

---@param tab table
---@param index any
---@return integer|string|nil
table.nextIndex = table.nextIndex or function(tab, index)
    if type(tab) ~= "table" then return nil end
    if table.isArray(tab) then
        return index + 1 <= #tab and index + 1 or nil
    end
    return Table(tab):reduce(function(acc, _, k)
        if not acc.next then
            if k == index then
                acc.next = true
            end
        elseif not acc.found then
            acc.found = k
        end
        return acc
    end, { next = false, found = nil }).found
end

---@param tab1 table
---@param tab2 table
---@param distinct? boolean
---@return tablelib
table.addAll = table.addAll or function(tab1, tab2, distinct)
    if type(tab1) ~= "table" or type(tab2) ~= "table" then return Table() end
    if Table(tab1):isArray() then
        return Table(tab2):reduce(function(acc, el)
            if not distinct or not acc:includes(el) then
                acc:insert(el)
            end
            return acc
        end, Table(tab1))
    else
        return Table({ tab1, tab2 })
            :map(function(tab) return Table(tab):values() end)
            :reduce(function(acc, tab)
                Table(tab):forEach(function(el, k)
                    if not distinct or not acc:includes(el) then
                        acc:insert(el)
                    end
                end)
                return acc
            end, Table())
    end
end

-- table.concat only works on arrays, table.join is working on objects too
---@param tab table
---@param sep? string
---@param keys? boolean
table.join = table.join or function(tab, sep, keys)
    if type(tab) ~= "table" then return "" end
    if type(sep) ~= "string" then sep = "" end
    return Table(tab):reduce(function(acc, el, k)
        if #acc > 0 then
            acc = acc .. sep
        end
        if keys then
            acc = acc .. tostring(k) .. ":"
        end
        acc = acc .. tostring(el)
        return acc
    end, "")
end

---@param tab table
---@return tablelib
table.flat = table.flat or function(tab)
    if type(tab) ~= "table" then return Table() end
    return Table(tab):reduce(function(acc, el)
        if type(el) == "table" then
            acc:addAll(Table(el):flat())
        else
            acc:insert(el)
        end
        return acc
    end, Table())
end

---@param tab table
---@param val any
---@return any result nil if not found
table.indexOf = table.indexOf or function(tab, val)
    return Table(tab):reduce(function(acc, el, k) return el == val and k or acc end)
end

---@param target table
---@param source table
---@param level? integer
---@return table
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
    return Table(target)
end

---@generic K, V, T
---@param tab table<K, V>
---@param mapFn fun(el: V, index: K, tab: table<K, V>): T
---@return tablelib<K, T>
table.map = table.map or function(tab, mapFn)
    if type(tab) ~= "table" then return Table() end
    if type(mapFn) ~= "function" then return Table() end
    local status, mapped
    local res = {}
    for k, v in pairs(tab) do
        status, res[k] = pcall(mapFn, v, k, tab)
        if not status then
            res[k] = nil
        end
    end
    return Table(res)
end

---@generic K, V
---@param tab table<K, V>
---@param filterFn fun(el: V, index: K, tab: table<K, V>): boolean
---@return tablelib<K, V>
table.filter = table.filter or function(tab, filterFn)
    if type(tab) ~= "table" then return Table() end
    if type(filterFn) ~= "function" then return Table() end
    local res = {}
    for k, v in pairs(tab) do
        local status, cond = pcall(filterFn, v, k, tab)
        if status and cond then
            if table.isArray(tab) then
                table.insert(res, v)
            else
                res[k] = v
            end
        end
    end
    return Table(res)
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
---@param initialValue? T
---@return T
table.reduce = table.reduce or function(tab, reduceFn, initialValue)
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

---@param tab table
---@return integer
table.length = table.length or function(tab)
    if type(tab) ~= "table" then return 0 end
    return Table(tab):reduce(function(acc) return acc + 1 end, 0)
end

---@generic K
---@param tab table<K, any>
---@return tablelib<K>
table.keys = table.keys or function(tab)
    if type(tab) ~= "table" then return Table() end
    return Table(tab):reduce(function(acc, _, k)
        acc:insert(k)
        return acc
    end, Table())
end

---@generic V
---@param tab table<any, V>
---@return tablelib<V>
table.values = table.values or function(tab)
    if type(tab) ~= "table" then return Table() end
    return Table(tab):reduce(function(acc, el)
        acc:insert(el)
        return acc
    end, Table())
end

---@param tab table
---@param el any
---@return boolean
table.includes = table.includes or function(tab, el)
    if type(tab) ~= "table" then return false end
    return Table(tab):any(function(v)
        return v == el
    end)
end
table.contains = table.contains or table.includes

---@param tab1 table
---@param tab2 table
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
---@param tab1 table
---@param tab2 table
---@return boolean
table.deepcompare = table.deepcompare or function(tab1, tab2)
    return table.compare(tab1, tab2, true)
end
---@param tab1 table
---@param tab2 table
---@return boolean
table.shallowcompare = table.shallowcompare or function(tab1, tab2)
    return table.compare(tab1, tab2)
end

-- Depends on Lua version
table.unpack = table.unpack or
    unpack ---@diagnostic disable-line

---@generic V
---@param obj V
---@param level? integer
---@return V
table.clone = table.clone or function(obj, level)
    if type(obj) ~= 'table' then
        return obj
    end
    -- table.deepcopy does not handle userdata and cdata types
    return Table(table.deepcopy(obj))
end

local baseSort = table.sort
---@generic T
---@param tab T[]
---@param sortFn? fun(a: T, b: T): boolean
---@return tablelib<T>
table.sort = function(tab, sortFn) ---@diagnostic disable-line
    tab = tab or {}
    if table.isObject(tab) then
        tab = Table(tab):values()
    end
    local ok, err = pcall(baseSort, tab, sortFn)
    if not ok then
        LogError(string.var("Error while sorting table : {1}", { err }))
    end
    return Table(tab)
end
