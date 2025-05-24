local RX = {
    _name = "RX",
    ctrls = {},
    _logEndpointsBlacklist = {
        { BJI.CONSTANTS.EVENTS.PLAYER.EVENT, BJI.CONSTANTS.EVENTS.PLAYER.RX.SERVER_TICK }
    }
}
-- route events categories to controller files
for k, v in pairs(BJI.CONSTANTS.EVENTS) do
    if type(v) == "table" and type(v.RX) == "table" and table.length(v.RX) > 0 then
        RX.ctrls[k] = require("ge/extensions/BJI/rx/" .. k:capitalizeWords():gsub(" ", "") .. "Rx")
    end
end
for _, ctrl in pairs(RX.ctrls) do
    function ctrl.dispatchEvent(self, endpoint, data)
        local fn = self[endpoint]
        if fn and type(fn) == "function" then
            fn(data)
        else
            LogWarn(string.var("Event received but not handled : {1}", { endpoint }), self.tag)
        end
    end
end

-- the JSON parser change number keys to strings, so update recursively
local function parsePayload(obj)
    if type(obj) == "table" then
        local cpy = {}
        for k, v in pairs(obj) do
            local finalKey = tonumber(k) or k
            cpy[finalKey] = parsePayload(v)
        end
        return cpy
    end
    return obj
end

local function dispatchEvent(eventName, endpoint, data)
    if not data or type(data) ~= "table" then
        LogError(string.var("Invalid endpoint {1}.{2}", { eventName, endpoint }), RX._name)
        return
    end
    for event, ctrl in pairs(RX.ctrls) do
        if type(BJI.CONSTANTS.EVENTS[event]) == "table" and BJI.CONSTANTS.EVENTS[event].EVENT == eventName then
            -- LOG
            local inBlacklist = false
            for _, el in pairs(RX._logEndpointsBlacklist) do
                if el[1] == eventName and el[2] == endpoint then
                    inBlacklist = true
                    break
                end
            end
            if not inBlacklist then
                LogDebug(string.var("Event received : {1}.{2}", { eventName, endpoint }), RX._name)
                if BJI.DEBUG and table.length(data) > 0 then
                    PrintObj(data)
                end
            end

            ctrl:dispatchEvent(endpoint, data)
            break
        end
    end
end

local retrievingEvents = {}
local function tryFinalizingEvent(id)
    local event = retrievingEvents[id]
    if event then
        if not event.controller or event.parts > #event.data then
            -- not ready yet
            return
        end

        local dataStr = table.join(event.data)
        local data = #dataStr > 0 and jsonDecode(dataStr) or {}
        data = parsePayload(data)
        dispatchEvent(event.controller, event.endpoint, data)
    end

    retrievingEvents[id] = nil
    BJI.Managers.Async.removeTask(string.var("BJIRxEventTimeout-{1}", { id }))
end

local function retrieveEvent(rawData)
    local data = jsonDecode(rawData)
    if not data or type(data) ~= "table" or
        not data.id or not data.parts or
        not data.controller or not data.endpoint then
        PrintObj("Invalid event", data)
        return
    end

    local event = retrievingEvents[data.id]
    if event then
        event.parts = data.parts
        event.controller = data.controller
        event.endpoint = data.endpoint
        if not event.data then
            event.data = {}
        end
    else
        retrievingEvents[data.id] = {
            parts = data.parts,
            controller = data.controller,
            endpoint = data.endpoint,
            data = {},
        }
    end
    if data.parts == 0 then
        tryFinalizingEvent(data.id)
    end
    if retrievingEvents[data.id] then
        BJI.Managers.Async.delayTask(function()
            retrievingEvents[data.id] = nil
        end, 30000, string.var("BJIRxEventTimeout-{1}", { data.id }))
    end
end

local function retrieveEventPart(rawData)
    local data = jsonDecode(rawData)
    if not data or type(data) ~= "table" or
        not data.id or not data.part or
        not data.data then
        PrintObj("Invalid event part", data)
        return
    end

    local event = retrievingEvents[data.id]
    if event then
        if event.data then
            event.data[data.part] = data.data
        else
            event.data = { [data.part] = data.data }
        end
    else
        retrievingEvents[data.id] = {
            data = { [data.part] = data.data }
        }
    end
    tryFinalizingEvent(data.id)
    if retrievingEvents[data.id] then
        BJI.Managers.Async.delayTask(function()
            retrievingEvents[data.id] = nil
        end, 30000, string.var("BJIRxEventTimeout-{1}", { data.id }))
    end
end

AddEventHandler(BJI.CONSTANTS.EVENTS.SERVER_EVENT, retrieveEvent)
AddEventHandler(BJI.CONSTANTS.EVENTS.SERVER_EVENT_PARTS, retrieveEventPart)

RX.dispatchEvent = dispatchEvent

return RX
