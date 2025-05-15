---@class BJIWindowDebug : BJIWindow
local W = {
    name = "Debug",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE,
    },
}

local function body(ctxt)
    local totalLines = 0
    local function display(obj, key)
        local line = LineBuilder()
            :text(key and string.var("{1} ({2}) =", { key, type(key) }) or "")
        if type(obj) == "table" then
            line:text(string.var("({1}, {2} child.ren)", {
                type(obj),
                table.length(obj)
            }))
            Indent(1)
            local objs = {}
            for k, v in pairs(obj) do
                table.insert(objs, { k = k, v = v })
            end
            table.sort(objs, function(a, b)
                return tostring(a.k) < tostring(b.k)
            end)
            for _, el in ipairs(objs) do
                display(el.v, el.k)
                if totalLines > 200 then
                    return
                end
            end
            Indent(-1)
        else
            local val = type(obj) == "string" and
                string.var("\"{1}\"", { obj }) or
                tostring(obj)
            line:text(string.var("{1} ({2})", { val, type(obj) }))
        end
        line:build()
        totalLines = totalLines + 1
    end

    local data = BJI.DEBUG
    if type(data) == "function" then
        local _
        _, data = pcall(data, ctxt)
    end
    display(data)
    if totalLines > 200 then
        LineBuilder():text("..."):build()
    end
end

W.body = body
W.onClose = function() BJI.DEBUG = nil end
W.getState = function()
    return BJI.DEBUG ~= nil
end

return W
