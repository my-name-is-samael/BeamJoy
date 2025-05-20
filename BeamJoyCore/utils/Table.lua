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
---@return tablelib<integer, integer>
function Range(startIndex, endIndex)
    if type(endIndex) ~= "number" or type(startIndex) ~= "number" then return Table() end
    local res = Table()
    for i = startIndex, endIndex, startIndex <= endIndex and 1 or -1 do
        res:insert(i)
    end
    return res
end

-- ALREADY PRESENT FUNCTIONS

table.concat = table.concat
table.insert = table.insert
table.move = table.move
table.pack = table.pack
-- Depends on Lua version
table.unpack = table.unpack or
    unpack ---@diagnostic disable-line
table.remove = table.remove
-- table.sort = table.sort -- Rewrite to handle object tables and chain result

-- RECOVER FROM CLIENT FUNCTIONS

---@param tab tablelib|table|any[]
---@return tablelib
table.clear = table.clear or function(tab)
    if type(tab) ~= "table" then return Table() end
    tab = Table(tab)
    tab:forEach(function(_, k, t) t[k] = nil end)
    return tab
end

---@generic O
---@param obj O
---@param level? integer
---@return O
table.clone = table.clone or function(obj, level)
    if type(obj) ~= "table" then return Table() end
    if not level then
        level = 1
    elseif level >= 20 then
        return Table()
    end
    local res = Table()
    for k, v in pairs(obj) do
        if type(v) == "table" then
            res[k] = Table(v):clone(level + 1)
        elseif type(v) ~= "function" then
            res[k] = v
        end
    end
    return type(res) == "table" and Table(res) or res
end
---@generic O
---@param obj O
---@return O
table.deepcopy = function(obj) return table.clone(obj) end
---@generic O
---@param obj O
---@return O
table.shallowcopy = function(obj) return table.clone(obj, 19) end

---@generic K, V
---@param tab tablelib<K,V>|table<K,V>|V[]
---@param foreachFn fun(index: K, el: V|integer)
table.foreach = table.foreach or function(tab, foreachFn)
    if type(tab) ~= "table" then return end
    for k, v in pairs(tab) do
        foreachFn(k, v)
    end
end

---@generic V
---@param tab tablelib<integer,V>|table<integer,V>|V[]
---@param foreachiFn fun(index: integer, el: V)
table.foreachi = table.foreachi or function(tab, foreachiFn)
    if type(tab) ~= "table" then return end
    for i, v in ipairs(tab) do
        foreachiFn(i, v)
    end
end

---@param tab tablelib|table|any[]
---@return integer
table.getn = table.getn or function(tab)
    return type(tab) == "table" and #tab or 0
end

---@param tab tablelib|table|any[]
---@return integer|nil
table.maxn = table.maxn or function(tab)
    return Table(tab)
        :filter(function(_, k) return type(k) == "number" end)
        :reduce(function(acc, _, i) return (not acc or i > acc) and i or acc end)
end

---@param narr integer
---@param nrec? integer
---@return tablelib
table.new = table.new or function(narr, nrec)
    return Table()
end

-- ADD-ONS

---@param tab tablelib|table|any[]
---@return boolean
table.isArray = table.isArray or function(tab)
    return type(tab) == "table" and #tab == Table(tab):length()
end

---@param tab tablelib|table|any[]
---@return boolean
table.isObject = table.isObject or function(tab)
    return type(tab) == "table" and #tab ~= Table(tab):length()
end


---@generic K, V
---@param tab table<K,V>
---@param distinct? boolean
---@return tablelib<integer, V>
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

---@generic K, V
---@param tab tablelib<K,V>|table<K,V>|V[]
---@return V
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

---@generic K, V
---@param tab tablelib<K,V>|table<K,V>|V[]
---@param index any
---@return K|integer
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

---@generic K, L, V, W
---@param tab1 tablelib<K,V>|table<K,V>|V[]
---@param tab2 tablelib<L,W>|table<L,W>|W[]
---@param distinct? boolean
---@return tablelib<K|L, V|W>
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
---@generic K, V
---@param tab tablelib<K,V>|table<K,V>|V[]
---@param sep? string
---@param keys? boolean
---@return string
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

---@param tab tablelib|table
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

---@generic K, V
---@param tab tablelib<K,V>|table<K,V>|V[]
---@param val V
---@return K|nil
table.indexOf = table.indexOf or function(tab, val)
    return Table(tab):reduce(function(acc, el, k) return el == val and k or acc end)
end

---@generic K, L, V, W
---@param target tablelib<K,V>|table<K,V>|V[]
---@param source tablelib<L,W>|table<L,W>|W[]
---@param level? integer
---@return table<K|L,V|W>
table.assign = table.assign or function(target, source, level)
    if type(target) ~= "table" or type(source) ~= "table" then return target end
    if type(level) ~= "number" then
        level = 1
    else
        level = math.round(level)
        if level >= 20 then
            return Table()
        end
    end
    for k, v in pairs(source) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then
                target[k] = Table()
            end
            table.assign(target[k], v, level + 1)
        else
            target[k] = v
        end
    end
    return Table(target)
end

---@generic K, V, W
---@param tab tablelib<K,V>|table<K,V>|V[]
---@param mapFn fun(el: V, index: K|integer, tab: tablelib<K,V>|table<K,V>|V[]): W
---@return tablelib<K,W>
table.map = table.map or function(tab, mapFn)
    if type(tab) ~= "table" then return Table() end
    if type(mapFn) ~= "function" then return Table() end
    local status
    local res = Table()
    for k, v in pairs(tab) do
        status, res[k] = pcall(mapFn, v, k, tab)
        if not status then
            res[k] = nil
        end
    end
    return Table(res)
end

---@generic K, V
---@param tab tablelib<K,V>|table<K,V>|V[]
---@param filterFn fun(el: V, index: K|integer, tab: tablelib<K,V>|table<K,V>|V[]): boolean
---@param keepIndices? boolean
---@return tablelib<K,V>
table.filter = table.filter or function(tab, filterFn, keepIndices)
    if type(tab) ~= "table" then return Table() end
    if type(filterFn) ~= "function" then return Table() end
    local res = Table()
    local isArray = table.isArray(tab) and not keepIndices
    for k, v in pairs(tab) do
        local status, cond = pcall(filterFn, v, k, tab)
        if status and cond then
            if isArray then
                table.insert(res, v)
            else
                res[k] = v
            end
        end
    end
    return Table(res)
end

---@generic K, V
---@param tab tablelib<K,V>|table<K,V>|V[]
---@param someFn fun(el: V, index: K|integer, tab: tablelib<K,V>|table<K,V>|V[]): boolean
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
---@param tab tablelib<K,V>|table<K,V>|V[]
---@param everyFn fun(el: V, index: K|integer, tab: tablelib<K,V>|table<K,V>|V[]): boolean
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
---@param tab tablelib<K,V>|table<K,V>|V[]
---@param reduceFn fun(value: T, el: V, index: K|integer, tab: tablelib<K,V>|table<K,V>|V[]): T
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
---@param tab tablelib<K,V>|table<K,V>|V[]
---@param foreachFn fun(el: V, index: K|integer, tab: tablelib<K,V>|table<K,V>|V[])
table.forEach = table.forEach or function(tab, foreachFn)
    if type(tab) ~= "table" then return end
    if type(foreachFn) ~= "function" then return end
    for k, v in pairs(tab) do
        foreachFn(v, k, tab)
    end
end

---@generic K, V
---@param tab tablelib<K,V>|table<K,V>|V[]
---@param findFn fun(el: V, index: K|integer, tab: tablelib<K,V>|table<K,V>|V[]): boolean
---@param callbackFn? fun(el: V, index: K|integer)
---@return V|nil, K|nil
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

---@param tab tablelib|table|any[]
---@return integer
table.length = table.length or function(tab)
    if type(tab) ~= "table" then return 0 end
    return Table(tab):reduce(function(acc) return acc + 1 end, 0)
end

---@generic K
---@param tab tablelib<K,any>|table<K,any>|any[]
---@return tablelib<K>|integer[]
table.keys = table.keys or function(tab)
    if type(tab) ~= "table" then return Table() end
    return Table(tab):reduce(function(acc, _, k)
        acc:insert(k)
        return acc
    end, Table())
end

---@generic V
---@param tab tablelib<any,V>|table<any,V>|V[]
---@return tablelib<V>
table.values = table.values or function(tab)
    if type(tab) ~= "table" then return Table() end
    return Table(tab):reduce(function(acc, el)
        acc:insert(el)
        return acc
    end, Table())
end

---@param tab tablelib|table|any[]
---@param el any
---@return boolean
table.includes = table.includes or function(tab, el)
    if type(tab) ~= "table" then return false end
    return Table(tab):any(function(v)
        return v == el
    end)
end
table.contains = table.contains or table.includes

---@param tab1 tablelib|table|any[]
---@param tab2 tablelib|table|any[]
---@param deep? boolean DEFAULT to false
---@return boolean
table.compare = table.compare or function(tab1, tab2, deep)
    if type(tab1) ~= "table" or type(tab2) ~= "table" then return tab1 == tab2 end
    if #tab1 ~= #tab2 then return false end
    local saw = Table()
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
---@param tab1 tablelib|table|any[]
---@param tab2 tablelib|table|any[]
---@return boolean
table.deepcompare = table.deepcompare or function(tab1, tab2)
    return table.compare(tab1, tab2, true)
end
---@param tab1 tablelib|table|any[]
---@param tab2 tablelib|table|any[]
---@return boolean
table.shallowcompare = table.shallowcompare or function(tab1, tab2)
    return table.compare(tab1, tab2)
end

local baseSort = table.sort
---@generic T
---@param tab tablelib<integer,T>|table<integer,T>|T[]
---@param sortFn? fun(a: T, b: T): boolean
---@return tablelib<T>
table.sort = function(tab, sortFn) ---@diagnostic disable-line
    if table.isObject(tab) then
        tab = Table(tab):values()
    end
    baseSort(tab, sortFn)
    return Table(tab)
end
