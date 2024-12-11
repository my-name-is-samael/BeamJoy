function tlength(table)
    local length = 0
    for _ in pairs(table) do length = length + 1 end
    return length
end

function tincludes(table, value, inValues)
    for k, v in pairs(table) do
        if (not inValues and k == value) or v == value then
            return true
        end
    end
    return false
end

function tpos(table, value)
    for i in ipairs(table) do
        if table[i] == value then
            return i
        end
    end
    for k in pairs(table) do
        if table[k] == value then
            return k
        end
    end
    return nil
end

function tconcat(arr, separator)
    if tlength(arr) < 1 then
        return ""
    end
    local out = arr[1]
    for i = 2, tlength(arr) do
        out = out .. separator .. arr[i]
    end
    return out
end

function tisarray(obj)
    if type(obj) ~= 'table' then return false end
    return #obj == tlength(obj)
end

function tnextindex(table, index)
    local next = index + 1 % tlength(table) + 1
    if next == 0 then
        next = 1
    end
    return next
end

T_SORT_DIRS = { ASC = 1, DESC = 2 }

function tsortarray(arr, dir)
    if type(arr) == "table" and tlength(arr) == 0 then
        return
    elseif not tisarray(arr) then
        error("Tried to sort an array that is not an array")
        return arr
    end
    if dir == nil then
        dir = T_SORT_DIRS.ASC
    end
    if not tincludes(T_SORT_DIRS, dir) then
        error()
    end
    local types = {}
    for _,v in ipairs(arr) do
        if not tincludes(types, type(v)) then
            types[#types + 1] = type(v)
        end
    end
    if #types > 1 then
        error("multi types array")
        return
    end

    table.sort(arr, function(a, b)
        if dir == T_SORT_DIRS.ASC then
            return a:upper() < b:upper()
        else
            return a:upper() > b:upper()
        end
    end)
end

function tsortbykey(arr, key, dir)
    if type(arr) ~= "table" or tisarray(arr) then
        return {}
    end
    if key == nil or type(key) ~= "string" or #key == 0 then
        return {}
    end
    if dir == nil then
        dir = T_SORT_DIRS.ASC
    end
    if not tincludes(T_SORT_DIRS, dir) then
        error()
    end

    local keys = {}
    for _, v in pairs(arr) do
        if v[key] == nil then
            error("Invalid key")
            return {}
        end
        table.insert(keys, type(v[key]) == "number" and v[key] or tostring(v[key]))
    end
    tsortarray(keys, dir)


    local res = {}
    for _, s in ipairs(keys) do
        for k, v in pairs(arr) do
            if v[key] == s then
                table.insert(res, { k, v })
            end
        end
    end
    return res
end

function tfind(arr, findFn)
    if arr == nil or type(arr) ~= "table" or tisarray(arr) then
        return nil
    end

    for k,v in pairs(arr) do
        if findFn(v) then
            return {k,v}
        end
    end
    return nil
end

function tdeepcopy(obj, seen)
    if type(obj) ~= 'table' then
        return obj
    end
    if seen and seen[obj] then
        return seen[obj]
    end
    seen = seen or {}
    local res = {}
    seen[obj] = res
    for k, v in pairs(obj) do
        res[tdeepcopy(k, seen)] = tdeepcopy(v, seen)
    end
    return setmetatable(res, getmetatable(obj))
end

function tdeepassign(target, source)
    if type(target) ~= 'table' or type(source) ~= 'table' then
        return
    end

    for k, v in pairs(source) do
        if type(v) == "table" then
            if type(target[k]) == "table" then
                tdeepassign(target[k], v)
            else
                target[k] = tdeepcopy(v)
            end
        elseif tincludes({"string", "boolean", "number"}, type(v)) then
            target[k] = v
        end
    end

    return target
end

function tkeys(arr)
    local res = {}
    if type(arr) ~= "table" then
        return res
    end
    for k in pairs(arr) do
        table.insert(res, k)
    end
    return res
end

function tisduplicates(arr)
    if not tisarray(arr) then
        return false
    end
    for i = 1, #arr do
        for j = i + 1, #arr do
            if arr[i] == arr[j] then
                return true
            end
        end
    end
    return false
end

function trandom(arr)
    local iTarget = math.random(1, tlength(arr))
    for _, elem in pairs(arr) do
        if iTarget == 1 then
            return elem
        end
        iTarget = iTarget - 1
    end
    return nil
end

table.clear = table.clear or function(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

function tdeepcompare(table1, table2)
    local avoid_loops = {}
    local function recurse(t1, t2)
        if type(t1) ~= type(t2) then return false end
        if type(t1) ~= "table" then return t1 == t2 end
        if avoid_loops[t1] then return avoid_loops[t1] == t2 end
        avoid_loops[t1] = t2
        local t2keys = {}
        local t2tablekeys = {}
        for k, _ in pairs(t2) do
            if type(k) == "table" then table.insert(t2tablekeys, k) end
            t2keys[k] = true
        end
        for k1, v1 in pairs(t1) do
            local v2 = t2[k1]
            if type(k1) == "table" then
                local ok = false
                for i, tk in ipairs(t2tablekeys) do
                    if tdeepcompare(k1, tk) and recurse(v1, t2[tk]) then
                        table.remove(t2tablekeys, i)
                        t2keys[tk] = nil
                        ok = true
                        break
                    end
                end
                if not ok then return false end
            else
                if v2 == nil then return false end
                t2keys[k1] = nil
                if not recurse(v1, v2) then return false end
            end
        end
        if next(t2keys) then return false end
        return true
    end
    return recurse(table1, table2)
end

function tevery(table, fn)
    for _, val in pairs(table) do
        if not fn(val) then
            return false
        end
    end
    return true
end

function tsome(table, fn)
    for _, val in pairs(table) do
        if fn(val) then
            return true
        end
    end
    return false
end