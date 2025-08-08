---@class BJIWindowDebug : BJIWindow
local W = {
    name = "Debug",

    filter = "",
    renderString = true,
    maxLines = 200,
}
local totalLines, nextValue, ok, value, filtered

local function prepareValue(val)
    ok, value = pcall(function() return type(val) ~= "string" and tostring(val) or '"' .. val .. '"' end)
    return ok and value or "nil"
end

local function filterMatch(el, key)
    if key and tostring(key):lower():find(W.filter:lower()) ~= nil then
        return true
    end
    if type(el) == "table" then
        return Table(el):any(function(v, k) return filterMatch(v, k) end)
    end
    return tostring(el):lower():find(W.filter:lower()) ~= nil
end

local function applyFilter(obj)
    if type(obj) == "table" then
        return Table(obj):reduce(function(res, v, k)
            if type(v) == "table" then
                res[k] = filterMatch(v, k) and applyFilter(v) or nil
            else
                res[k] = filterMatch(v, k) and v or nil
            end
            return res
        end, {})
    else
        return filterMatch(obj) and obj or nil
    end
end

local function updateCacheAndFilter(ctxt)
    if BJI.DEBUG == BJI then
        LogError("Cannot debug main object (recursive obj)")
        BJI.DEBUG = nil
        value = nil
    end
    value = table.clone(BJI.DEBUG)
    if value and type(value) ~= "function" then
        filtered = #W.filter == 0 and value or applyFilter(value)
    end
end

function W.header(ctxt)
    if #W.filter == 0 then
        Icon(BJI.Utils.Icon.ICONS.ab_filter_default)
    else
        if IconButton("debug-filter-clear", BJI.Utils.Icon.ICONS.ab_filter_default,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, bgLess = true }) then
            W.filter = ""
            updateCacheAndFilter(ctxt)
        end
    end
    SameLine()
    nextValue = InputText("debug-filter", W.filter)
    if nextValue then
        W.filter = nextValue
        updateCacheAndFilter(ctxt)
    end

    Text("Render type")
    SameLine()
    if Button("debug-render-type", W.renderString and "String" or "Tree") then
        W.renderString = not W.renderString
    end

    Text("Max lines")
    SameLine()
    nextValue = SliderIntPrecision("debug-max-lines", W.maxLines, 50, 500, {
        step = 5, stepFast = 10, formatRender = "%d lines", disabled = not W.renderString,
    })
    if nextValue then W.maxLines = nextValue end

    Separator()
end

local function drawContentString(obj, key)
    if key then Text(prepareValue(key) .. " =") end
    if type(obj) == "table" then
        SameLine()
        Text(string.var("(table, {1} child.ren)", { table.length(obj) }))
        Indent()
        table.map(obj, function(v, k)
            return { k = k, v = v }
        end):sort(function(a, b)
            return tostring(a.k):lower() < tostring(b.k):lower()
        end):forEach(function(el)
            if totalLines >= W.maxLines then return end
            drawContentString(el.v, el.k)
        end)
        Unindent()
    else
        SameLine()
        Text(string.var("{1} ({2})", { prepareValue(obj), type(obj) }))
    end
    totalLines = totalLines + 1
end

local function drawContentTree(obj, key)
    if type(obj) == "table" then
        local opened = not key and true or BeginTree(tostring(key) .. "")
        if opened then
            table.map(obj, function(v, k)
                return { k = k, v = v }
            end):sort(function(a, b)
                return tostring(a.k):lower() < tostring(b.k):lower()
            end):forEach(function(el)
                drawContentTree(el.v, el.k)
            end)
        end
        if key and opened then
            EndTree()
        end
    else
        if key then
            Text(prepareValue(key) .. " =")
            SameLine()
        end
        Text(string.var("{1} ({2})", { prepareValue(obj), type(obj) }))
    end
end

function W.body(ctxt)
    if type(BJI.DEBUG) == "table" and not table.compare(BJI.DEBUG, value) or
        BJI.DEBUG ~= value then
        updateCacheAndFilter(ctxt)
    end
    if not value then return end
    if type(value) == "function" then
        ok, filtered = pcall(value, ctxt)
        if not ok then
            Text(tostring(filtered), { wrap = true, color = BJI.Utils.Style.TEXT_COLORS.ERROR })
            return
        end
        if #W.filter > 0 then
            filtered = applyFilter(filtered)
        end
    end

    if W.renderString then
        totalLines = 0
        drawContentString(filtered)
        if totalLines >= W.maxLines then
            Text("...")
        end
    else
        drawContentTree(filtered)
    end
end

W.onClose = function() BJI.DEBUG = nil end
W.getState = function()
    return BJI.DEBUG ~= nil
end

return W
