local M = {
    _name = "BJIEventManager",

    EVENTS = {
        CACHE_LOADED = "cache_loaded",
        PLAYER_CONNECT = "player_connect",
        PLAYER_DISCONNECT = "player_disconnect",
        VEHICLE_SPAWNED = "vehicle_spawned",
        VEHICLE_UPDATED = "vehicle_updated",
        VEHICLE_REMOVED = "vehicle_removed",
        VEHICLE_SPEC_CHANGED = "vehicle_spec_changed",
        VEHDATA_UPDATED = "vehdata_updated",
        SCENARIO_CHANGED = "scenario_changed",
        SCENARIO_UPDATED = "scenario_updated",
        PERMISSION_CHANGED = "permission_changed",
        LANG_CHANGED = "lang_changed",
        UI_SCALE_CHANGED = "ui_scale_changed",
        WINDOW_VISIBILITY_TOGGLED = "window_toggled",
        GPS_CHANGED = "gps_changed",
        ENV_CHANGED = "env_changed",
        NAMETAGS_VISIBILITY_CHANGED = "nametags_visibility_changed",
        CORE_CHANGED = "core_changed",
        LEVEL_UP = "level_up",
        RACE_NEW_PB = "race_new_pb",

        UI_UPDATE_REQUEST = "ui_update_request",
    },

    ---@type table<string, table<string, fun(ctxt: any, data: any)>>
    listeners = {},
    ---@type {event: string, data: table}[]
    queued = {},
}

---@param events string[]|string
---@param callback fun(ctxt: any, data: table)
---@return string|nil
local function addListener(events, callback)
    if type(events) ~= "table" then
        events = { events }
    end

    if table.any(events, function(event)
            if not table.includes(M.EVENTS, event) then
                LogError("Invalid event : " .. event, M._name)
                return true
            end
            return false
        end) then
        return
    end

    local id = UUID()
    table.forEach(events, function(event)
        if not M.listeners[event] then
            M.listeners[event] = {}
        end
        M.listeners[event][id] = callback
    end)
    return id
end

---@param id string
---@return boolean
local function removeListener(id)
    local found = false
    table.forEach(M.listeners, function(event)
        if event[id] then
            event[id] = nil
            found = true
        end
    end)
    return found
end

---@param events string[]|string
---@param data any
local function trigger(events, data)
    if type(events) ~= "table" then
        events = { events }
    end

    if table.any(events, function(event)
            if not table.includes(M.EVENTS, event) then
                LogError("Invalid event : " .. event, M._name)
                return true
            end
            return false
        end) then
        return
    end

    for _, event in ipairs(events) do
        table.insert(M.queued, { event = event, data = data })
    end
end

local function renderTick(ctxt)
    while #M.queued > 0 do
        ---@type {event: string, data: table|nil}
        local el = table.remove(M.queued, 1)
        if M.listeners[el.event] then
            LogInfo(string.var("Event triggered : {1}{2}", {
                el.event,
                el.event == M.EVENTS.CACHE_LOADED and
                string.var(" ({1})", { el.data.cache }) or ""
            }), M._name)
            table.forEach(M.listeners[el.event], function(callback)
                local data = el.data or {}
                data._event = el.event
                pcall(callback, ctxt, el.data)
            end)
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
