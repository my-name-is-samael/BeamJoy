---@class BJIManagerEvents: BJIManager
local M = {
    _name = "Events",

    EVENTS = {
        -- functional and communication events (async)

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
        TOURNAMENT_UPDATED = "tournament_updated",
        PURSUIT_UPDATE = "pursuit_update",
        RESTRICTIONS_UPDATE = "restrictions_update",
        PLAYER_SCENARIO_CHANGED = "player_scenario_changed",

        -- functional and communication events (sync)

        VEHICLE_INITIALIZED = "vehicle_initialized",

        -- base game events (sync)

        NG_DROP_PLAYER_AT_CAMERA = "ngDropPlayerAtCamera",
        NG_DROP_PLAYER_AT_CAMERA_NO_RESET = "ngDropPlayerAtCameraNoReset",
        NG_VEHICLE_SWITCHED = "ngVehicleSwitched",
        NG_VEHICLE_SPAWNED = "ngVehicleSpawned",
        NG_VEHICLE_RESETTED = "ngVehicleResetted",
        NG_VEHICLE_REPLACED = "ngVehicleReplaced",
        NG_VEHICLE_DESTROYED = "ngVehicleDestroyed",
        NG_DRIFT_COMPLETED_SCORED = "ngDriftCompletedScored",
        NG_AI_MODE_CHANGE = "ngAiModeChange",
        NG_TRAFFIC_STARTED = "ngTrafficStarted",
        NG_TRAFFIC_STOPPED = "ngTrafficStopped",
        NG_TRAFFIC_VEHICLE_ADDED = "ngTrafficVehicleAdded",
        NG_VEHICLE_GROUP_SPAWNED = "ngVehicleGroupSpawned",
        NG_PURSUIT_ACTION = "ngPursuitAction",
        NG_PURSUIT_MODE_UPDATE = "ngPursuitModeUpdate",
        NG_UI_LAYOUT_LOADED = "ngUILayoutLoaded",

        -- tech events (async)

        ON_POST_LOAD = "on_post_load",
        ON_UNLOAD = "on_unload",
        SLOW_TICK = "slow_tick",
        FAST_TICK = "fast_tick",
        CACHE_LOADED = "cache_loaded",
        UI_UPDATE_REQUEST = "ui_update_request",
    },

    ---@type table<string, tablelib<string, fun(...: any)|fun(ctxt: any, data: any)>>
    listeners = {},
    ---@type tablelib<integer, {event: string, target: string, callback: fun(...), data: table?}>
    queued = Table(),
    ---@type tablelib<integer, {target: string, callback: fun(ctxt: TickContext)}>
    fastTickQueued = Table(),
}
M.SYNC_EVENTS = Table({
    M.EVENTS.NG_DROP_PLAYER_AT_CAMERA,
    M.EVENTS.NG_DROP_PLAYER_AT_CAMERA_NO_RESET,
    M.EVENTS.NG_VEHICLE_SWITCHED,
    M.EVENTS.NG_VEHICLE_SPAWNED,
    M.EVENTS.NG_VEHICLE_RESETTED,
    M.EVENTS.NG_VEHICLE_REPLACED,
    M.EVENTS.NG_VEHICLE_DESTROYED,
    M.EVENTS.NG_DRIFT_COMPLETED_SCORED,
    M.EVENTS.NG_AI_MODE_CHANGE,
    M.EVENTS.NG_TRAFFIC_STARTED,
    M.EVENTS.NG_TRAFFIC_STOPPED,
    M.EVENTS.NG_TRAFFIC_VEHICLE_ADDED,
    M.EVENTS.NG_VEHICLE_GROUP_SPAWNED,
    M.EVENTS.NG_PURSUIT_ACTION,
    M.EVENTS.NG_PURSUIT_MODE_UPDATE,
    M.EVENTS.NG_UI_LAYOUT_LOADED,

    M.EVENTS.VEHICLE_INITIALIZED,
})
M.LOG_BLACKLIST_EVENTS = Table({
    M.EVENTS.SLOW_TICK,
    M.EVENTS.FAST_TICK,
})

-- gc prevention
local ctxtTmp, ok, err, found, asyncEventName, el, data, start, bench

---@param events string[]|string
---@param callback fun(...: any)|fun(ctxt: TickContext, data: table)
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
    found = false
    table.forEach(M.listeners, function(event)
        if event[id] then
            event[id] = nil
            found = true
        end
    end)
    return found
end

local function processSlowTick()
    Table(M.listeners[M.EVENTS.SLOW_TICK]):map(function(fn, k)
        return {
            callback = fn,
            id = k
        }
    end):values():forEach(function(el2, i, tab)
        asyncEventName = string.var("SlowTick-{1}", { el2.id })
        BJI.Managers.Async.removeTask(asyncEventName)
        BJI.Managers.Async.delayTask(function()
            ctxtTmp = BJI.Managers.Tick.getContext(true)
            el2.callback(ctxtTmp)
            if BJI.Bench.STATE == 1 then
                BJI.Bench.add(tostring(el2.id), "slow_tick", GetCurrentTimeMillis() - ctxtTmp.now)
            end
        end, i / tab:length() * 1000, asyncEventName)
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
        elseif event == M.EVENTS.FAST_TICK then
            M.listeners[event]:forEach(function(callback, k)
                M.fastTickQueued:insert({ target = k, callback = callback })
            end)
        elseif M.listeners[event] then
            local data = { ... }
            if M.SYNC_EVENTS:includes(event) then -- sync events
                M.listeners[event]:forEach(function(callback, k)
                    ok, err = pcall(callback, table.unpack(data))
                    if not ok then
                        LogError(string.var("Error firing event {1}.{2} :", { event, k }))
                        dump(err)
                    end
                end)
            else -- async events call
                M.listeners[event]:forEach(function(callback, k)
                    M.queued:insert({ event = event, target = k, callback = callback, data = data })
                end)
            end
        end
    end
end

local renderTimeout = 2
local function renderTick(ctxt)
    if #M.fastTickQueued > 0 then
        el = M.fastTickQueued:remove(1)
        start = GetCurrentTimeMillis()
        ok, err = pcall(el.callback, ctxt, { _event = M.EVENTS.FAST_TICK })
        bench = GetCurrentTimeMillis() - start
        if BJI.Bench.STATE == 1 then
            BJI.Bench.add(tostring(el.target), el.event, bench)
        end
        if not ok then
            LogError(string.var("Error firing event {1}.{2} :", { M.EVENTS.FAST_TICK, el.target }))
            dump(err)
        end
        if bench > renderTimeout then
            LogWarn(string.var("Event {1}.{2} took {3}ms", { M.EVENTS.FAST_TICK, el.target, bench }))
        end
    end

    if #M.queued > 0 then
        ---@type {event: string, target: string, callback: fun(...), data: table?}
        el = M.queued:remove(1)
        if not M.LOG_BLACKLIST_EVENTS:includes(el.event) then
            LogDebug(string.var("Event triggered : {1}{2}", {
                el.event,
                el.event == M.EVENTS.CACHE_LOADED and
                string.var(" ({1})", { el.data[1].cache }) or ""
            }), M._name)
        end
        data = table.clone(el.data) or {}
        data[1] = data[1] or {}
        data[1]._event = el.event
        start = GetCurrentTimeMillis()
        ok, err = pcall(el.callback, ctxt, data[1])
        bench = GetCurrentTimeMillis() - start
        if BJI.Bench.STATE == 1 then
            BJI.Bench.add(tostring(el.target), el.event, bench)
        end
        if not ok then
            LogError(string.var("Error firing event {1}.{2} :", { el.event, el.target }))
            dump(err)
        end
        if bench > renderTimeout then
            LogWarn(string.var("Event {1}.{2} took {3}ms", { el.event, el.target, bench }))
        end
    end
end

local function onUnload()
    table.clear(M.listeners)
    M.queued:clear()
end

M.addListener = addListener
M.removeListener = removeListener
M.trigger = trigger

M.onLoad = function()
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.ON_UNLOAD, onUnload, M._name)
end
M.renderTick = renderTick

return M
