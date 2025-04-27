local M = {
    _name = "BJIEventManager",

    EVENTS = {
        PLAYER_CONNECT = "playerconnect",
        PLAYER_DISCONNECT = "playerdisconnect",
        PLAYER_CHAT = "playerchat",
        VEHICLE_SPAWNED = "vehiclespawned",
        VEHICLE_SPAWNED_SELF = "vehiclespawnedself",
        VEHICLE_REMOVED = "vehicleremoved",
        VEHICLE_REMOVED_SELF = "vehicleremovedself",
        VEHICLE_SPEC_CHANGED = "vehiclespecchanged",
        VEHILCLE_SPEC_CHANGED_SELF = "vehiclespecchangedself",
        SCENARIO_CHANGED = "scenariochanged",
        SCENARIO_CHANGED_SELF = "scenariochangedself",

        UI_UPDATE_REQUEST = "uiupdaterequest",
    },

    listeners = {},
    queued = {},
}

---@param events string[]|string
---@param callback fun(ctxt: any, data: any)
---@return string|nil
local function addListener(events, callback)
    if type(events) ~= "table" then
        events = { events }
    end

    local invalid = false
    for _, event in ipairs(events) do
        if not M.EVENTS[event] then
            LogError("Invalid event : " .. event, M._name)
            invalid = true
        end
    end
    if invalid then
        return
    end

    local id = UUID()
    for _, event in ipairs(events) do
        if not M.listeners[event] then
            M.listeners[event] = {}
        end
        M.listeners[event][id] = callback
    end
    return id
end

---@param id string
---@return boolean
local function removeListener(id)
    local found = false
    for _, event in pairs(M.listeners) do
        if event[id] then
            event[id] = nil
            found = true
        end
    end
    return found
end

---@param events string[]|string
---@param data any
local function trigger(events, data)
    if type(events) ~= "table" then
        events = { events }
    end

    local invalid = false
    for _, event in ipairs(events) do
        if not M.EVENTS[event] then
            LogError("Invalid event : " .. event, M._name)
            invalid = true
        end
    end
    if invalid then
        return
    end

    for _, event in ipairs(events) do
        table.insert(M.queued, { event = event, data = data })
    end
end

local function renderTick(ctxt)
    if #M.queued > 0 then
        for _, el in ipairs(M.queued) do
            if M.listeners[el.event] then
                for _, callback in pairs(M.listeners[el.event]) do
                    callback(ctxt, el.data)
                end
            end
        end
    end
end

local function onUnload()
    table.clear(M.listeners)
    table.clear(M.queued)
end

M.addListener = addListener
M.removeListener = removeListener
M.trigger = trigger
M.renderTick = renderTick
M.onUnload = onUnload

RegisterBJIManager(M)
return M

-- BJIEvents = require("ge/extensions/BJI/managers/EventManager")