---@class BJITX
local TX = {
    _name = "TX",
    PAYLOAD_LIMIT_SIZE = 20000,
}

---@param controller string
---@param endpoint string
---@param data? table|any
function TX._send(controller, endpoint, data)
    local logData = BJI.DEBUG and data ~= nil
    if type(data) ~= "table" then
        data = { data }
    end

    local id = UUID()
    local parts = {}
    local payload = jsonEncode(data)
    while #payload > 0 do
        table.insert(parts, payload:sub(1, TX.PAYLOAD_LIMIT_SIZE))
        payload = payload:sub(TX.PAYLOAD_LIMIT_SIZE + 1)
    end

    TriggerServerEvent(BJI.CONSTANTS.EVENTS.SERVER_EVENT, jsonEncode({
        id = id,
        parts = #parts,
        controller = controller,
        endpoint = endpoint,
    }))
    for i, p in ipairs(parts) do
        TriggerServerEvent(BJI.CONSTANTS.EVENTS.SERVER_EVENT_PARTS, jsonEncode({
            id = id,
            part = i,
            data = p,
        }))
    end

    LogDebug(string.var("Event {1}.{2} sent ({3} parts data)", { controller, endpoint, #parts }), TX._name)
    if logData then
        PrintObj(data)
    end
end

Table(FS:directoryList("/lua/ge/extensions/BJI/tx"))
    :filter(function(path)
        return path:endswith(".lua") and not path:endswith("/Tx.lua")
    end):map(function(el)
    return el:gsub("^/lua/", ""):gsub(".lua$", "")
end):forEach(function(managerPath)
    local ok, m = pcall(require, managerPath)
    if ok then
        local res = m(TX)
        TX[res._name] = res
    else
        LogError(string.var("Error loading Tx {1} : {2}", { managerPath, m }))
    end
end)

return TX
