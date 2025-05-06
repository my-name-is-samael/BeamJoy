---@class tablelib<any, any> : table

---@type tablelib
table = table

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

---@param tab table<any, any>
---@return table<any, any>
table.clear = table.clear or function(tab)
    if type(tab) ~= "table" then return {} end
    for k in pairs(tab) do
        tab[k] = nil
    end
    return tab
end

---@generic V
---@param obj V
---@param level? integer
---@return V
table.clone = table.clone or function(obj, level)
    if type(obj) ~= "table" then return {} end
    if not level then
        level = 1
    elseif level >= 20 then
        return {}
    end
    local res = {}
    for k, v in pairs(obj) do
        if type(v) == "table" then
            res[k] = table.clone(v, level + 1)
        elseif type(v) ~= "function" then
            res[k] = v
        end
    end
    return res
end
---@generic V
---@param obj V
---@return V
table.deepcopy = function(obj) return table.clone(obj) end
---@generic V
---@param obj V
---@return V
table.shallowcopy = function(obj) return table.clone(obj, 19) end

---@generic K, V
---@param tab table<K, V>
---@param foreachFn fun(index: K, el: V)
table.foreach = table.foreach or function(tab, foreachFn)
    if type(tab) ~= "table" then return end
    for k, v in pairs(tab) do
        foreachFn(k, v)
    end
end

---@generic V
---@param tab table<any, V>
---@param foreachiFn fun(index: integer, el: V)
table.foreachi = table.foreachi or function(tab, foreachiFn)
    if type(tab) ~= "table" then return end
    for i, v in ipairs(tab) do
        foreachiFn(i, v)
    end
end

---@param tab table<any, any>
---@return integer
table.getn = table.getn or function(tab)
    return type(tab) == "table" and #tab or 0
end

---@param tab table<any, any>
---@return integer|nil
table.maxn = table.maxn or function(tab)
    local highest = 0
    for i in pairs(tab) do
        if type(i) == "number" and i > highest then
            highest = i
        end
    end
    return highest
end

---@param narr integer
---@param nrec? integer
---@return nil[]
table.new = table.new or function(narr, nrec)
    if type(narr) ~= "number" then return {} end
    if type(nrec) ~= "number" then nrec = 0 end
    return setmetatable({}, { __index = function() return table.new(narr, nrec + 1) end })
end

-- ADD-ONS

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
---@return table<any, any>
table.duplicates = table.duplicates or function(tab, distinct)
    if type(tab) ~= "table" then return {} end
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
    return res
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
            return v
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


---@param tab1 table<any, any>
---@param tab2 table<any, any>
---@return table<any, any>
table.addAll = table.addAll or function(tab1, tab2)
    if type(tab1) ~= "table" or type(tab2) ~= "table" then return {} end
    local res = {}
    table.forEach(tab1, function(v) table.insert(res, v) end)
    table.forEach(tab2, function(v) table.insert(res, v) end)
    return res
end

--- table.concat only works on arrays, table.join is working on objects too
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

---@param tab table<any, any>
---@return table<any, any>
table.flat = table.flat or function(tab)
    if type(tab) ~= "table" then return {} end
    local res = {}
    table.forEach(tab, function(v)
        if type(v) == "table" then
            table.forEach(table.flat(v), function(v) table.insert(res, v) end)
        else
            table.insert(res, v)
        end
    end)
    return res
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
---@return table<K, T>
table.map = table.map or function(tab, mapFn)
    if type(tab) ~= "table" then return {} end
    if type(mapFn) ~= "function" then return {} end
    local status
    local res = {}
    for k, v in pairs(tab) do
        status, res[k] = pcall(mapFn, v, k, tab)
        if not status then
            res[k] = nil
        end
    end
    return res
end

---@generic K, V
---@param tab table<K, V>
---@param filterFn fun(el: V, index: K, tab: table<K, V>): boolean
---@return table<K, V>
table.filter = table.filter or function(tab, filterFn)
    if type(tab) ~= "table" then return {} end
    if type(filterFn) ~= "function" then return {} end
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
    return res
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

---@param tab table<any, any>
---@return integer
table.length = table.length or function(tab)
    if type(tab) ~= "table" then return 0 end
    local sum = 0
    for _ in pairs(tab) do sum = sum + 1 end
    return sum
end

---@generic K
---@param tab table<K, any>
---@return K[]
table.keys = table.keys or function(tab)
    if type(tab) ~= "table" then return {} end
    local res = {}
    for k in pairs(tab) do
        table.insert(res, k)
    end
    table.sort(res)
    return res
end

---@generic V
---@param tab table<any, V>
---@return V[]
table.values = table.values or function(tab)
    if type(tab) ~= "table" then return {} end
    local res = {}
    for _, v in pairs(tab) do
        table.insert(res, v)
    end
    return res
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

local baseSort = table.sort
---@generic T
---@param tab T[]
---@param sortFn? fun(a: T, b: T): boolean
table.sort = function(tab, sortFn) ---@diagnostic disable-line
    if table.isObject(tab) then
        tab = table.values(tab)
    end
    baseSort(tab, sortFn)
    return tab
end
