---@class BJIManagerEvents: BJIManager
local M = {
    _name = "Events",

    EVENTS = {
        -- functional and communication events

        PLAYER_CONNECT = "player_connect",
        PLAYER_DISCONNECT = "player_disconnect",
        VEHICLE_SPAWNED = "vehicle_spawned",
        VEHICLE_REMOVED = "vehicle_removed",
        VEHICLE_SPEC_CHANGED = "vehicle_spec_changed",
        VEHDATA_UPDATED = "vehdata_updated",
        VEHICLES_UPDATED = "vehicles_updated",
        SCENARIO_CHANGED = "scenario_changed",
        SCENARIO_UPDATED = "scenario_updated",
        VOTE_UPDATED = "vote_updated",
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
        DATABASE_PLAYERS_UPDATED = "database_players_updated",
        SCENARIO_EDITOR_UPDATED = "scenario_editor_updated",
        CONFIG_SAVED = "config_saved",
        CONFIG_REMOVED = "config_removed",
        CONFIG_PROTECTION_UPDATED = "config_protection_updated",
        STATION_PROXIMITY_CHANGED = "station_proximity_changed",

        -- base game events

        NG_DROP_PLAYER_AT_CAMERA = "ngDropPlayerAtCamera",
        NG_DROP_PLAYER_AT_CAMERA_NO_RESET = "ngDropPlayerAtCameraNoReset",
        NG_VEHICLE_SWITCHED = "ngVehicleSwitched",
        NG_VEHICLE_SPAWNED = "ngVehicleSpawned",
        NG_VEHICLE_RESETTED = "ngVehicleResetted",
        NG_VEHICLE_REPLACED = "ngVehicleReplaced",
        NG_VEHICLE_DESTROYED = "ngVehicleDestroyed",
        NG_DRIFT_COMPLETED_SCORED = "ngDriftCompletedScored",
        NG_AI_MODE_CHANGE = "ngAiModeChange",

        -- tech events

        ON_UNLOAD = "on_unload",
        SLOW_TICK = "slow_tick",
        FAST_TICK = "fast_tick",
        CACHE_LOADED = "cache_loaded",
        UI_UPDATE_REQUEST = "ui_update_request",
    },

    ---@type table<string, table<string, fun(ctxt: any, data: any)>>
    listeners = {},
    ---@type {event: string, data: table}[]
    queued = {},
}
M.LOG_BLACKLIST_EVENTS = Table({
    M.EVENTS.SLOW_TICK,
    M.EVENTS.FAST_TICK,
})

---@param events string[]|string
---@param callback fun(ctxt: TickContext, data: table)
---@param id? string
---@return string|nil
local function addListener(events, callback, id)
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

    id = id and tostring(id) or UUID()
    table.forEach(events, function(event)
        if not M.listeners[event] then
            M.listeners[event] = Table()
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

local function processSlowTick()
    local callbacks = Table(M.listeners[M.EVENTS.SLOW_TICK])
        :map(function(e) return e end)
    local i = 1
    callbacks:forEach(function(fn, k)
        local asyncEventName = string.var("SlowTick-{1}", { k })
        BJI.Managers.Async.removeTask(asyncEventName)
        BJI.Managers.Async.delayTask(function()
            local ctxt = BJI.Managers.Tick.getContext(true)
            fn(ctxt)
            if BJI.Bench.STATE then
                BJI.Bench.add(tostring(k), "slow_tick", GetCurrentTimeMillis() - ctxt.now)
            end
        end, i / callbacks:length() * 1000, asyncEventName)
        i = i + 1
    end)
end

---@param events string[]|string
---@param ... any
local function trigger(events, ...)
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
        if event == M.EVENTS.SLOW_TICK then
            processSlowTick()
        elseif M.listeners[event] then
            local data = { ... }
            M.listeners[event]:forEach(function(callback, k)
                table.insert(M.queued, { event = event, target = k, fn = callback, data = data })
            end)
        end
    end
end

local renderTimeout = 2
local function renderTick(ctxt)
    while #M.queued > 0 do
        ---@type {event: string, target: string, fn: fun(...), data: table|nil}
        local el = table.remove(M.queued, 1)
        if not M.LOG_BLACKLIST_EVENTS:includes(el.event) then
            LogDebug(string.var("Event triggered : {1}{2}", {
                el.event,
                el.event == M.EVENTS.CACHE_LOADED and
                string.var(" ({1})", { el.data[1].cache }) or ""
            }), M._name)
        end
        local isNg = el.event:startswith("ng")
        local data = table.clone(el.data) or {}
        local ok, err
        if isNg then
            ok, err = pcall(el.fn, table.unpack(data))
        else
            data[1] = data[1] or {}
            data[1]._event = el.event
            ok, err = pcall(el.fn, ctxt, data[1])
        end
        if BJI.Bench.STATE then
            BJI.Bench.add(tostring(el.target), el.event, GetCurrentTimeMillis() - ctxt.now)
        end
        if not ok then
            LogError(string.var("Error firing event {1} :", { el.event }))
            dump(err)
        end
        if GetCurrentTimeMillis() - ctxt.now > renderTimeout then
            LogDebug(string.var("Skipping event {1} (timeout)", { el.target }), M._name)
            return
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

M.onLoad = function()
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.ON_UNLOAD, onUnload, M._name)
end
M.renderTick = renderTick

return M
