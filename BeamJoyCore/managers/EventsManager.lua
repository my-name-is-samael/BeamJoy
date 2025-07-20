---@class BJCEvent
---@field key string
---@field base? boolean
---@field cancellable? boolean

local M = {
    EVENTS = {
        MP_ON_INIT = { key = "onInit", base = true },
        --MP_ON_SHUTDOWN = { key = "onShutdown", base = true },
        MP_PLAYER_AUTH = { key = "onPlayerAuth", base = true, cancellable = true }, -- not allowed with 1, bypass with 2, reason with string
        MP_PLAYER_CONNECTING = { key = "onPlayerConnecting", base = true },
        MP_PLAYER_JOINING = { key = "onPlayerJoining", base = true },
        MP_PLAYER_JOIN = { key = "onPlayerJoin", base = true },
        MP_PLAYER_DISCONNECT = { key = "onPlayerDisconnect", base = true },
        MP_CHAT_MESSAGE = { key = "onBJCChatMessage", base = true, cancellable = true },  -- cancel with int ~= 0
        MP_VEHICLE_SPAWN = { key = "onVehicleSpawn", base = true, cancellable = true },   -- cancel with int ~= 0
        MP_VEHICLE_RESET = { key = "onVehicleReset", base = true },
        MP_VEHICLE_EDITED = { key = "onVehicleEdited", base = true, cancellable = true }, -- cancel with int ~= 0
        MP_VEHICLE_PAINT_CHANGED = { key = "onVehiclePaintChanged", base = true },
        MP_VEHICLE_DELETED = { key = "onVehicleDeleted", base = true },
        MP_ON_FILE_CHANGED = { key = "onFileChanged", base = true },
        MP_CONSOLE_INPUT = { key = "onConsoleInput", base = true, cancellable = true }, -- cancel with string (reason)

        PLAYER_CONNECTED = { key = "onPlayerConnected" },
        PLAYER_DISCONNECTED = { key = "onPlayerDisconnected" },
        PLAYER_KICKED = { key = "onPlayerKicked" },
        SLOW_TICK = { key = "onSlowTick" },
        FAST_TICK = { key = "onFastTick" },
    },

    ---@type table<string, tablelib<string, fun(data: any)>>
    listeners = {},
}

-- Write BeamMP event handlers to `_G` and make them fire the associated event
local function initMPHandlers()
    Table(M.EVENTS):filter(function(ev) return ev.base end)
        :forEach(function(ev)
            _G["BJC" .. ev.key] = function(...)
                return M.trigger(ev, ...)
            end
            MP.RegisterEvent(ev.key, "BJC" .. ev.key)
        end)
end
initMPHandlers()

---@param events BJCEvent[]|BJCEvent
---@param callback fun(...:any)
---@return string|nil
local function addListener(events, callback, id)
    id = id or UUID()
    if events.key then
        events = { events }
    end

    if type(callback) ~= "function" then
        LogError(string.var("Invalid callback {1}({2})", { id, Table(events)
            :map(function(e) return e.key end):join("|") }), M._name)
        return
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

    table.forEach(events, function(event)
        if not M.listeners[event.key] then
            M.listeners[event.key] = Table()
        end
        M.listeners[event.key][id] = callback
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

---@param event BJCEvent
---@param ...any
---@return any
local function processMPEvent(event, ...)
    if M.listeners[event.key] and M.listeners[event.key]:length() > 0 then
        local params = { ... }
        if event.cancellable then
            local condReturn = function(v) return false end
            if table.includes({ --[[M.EVENTS.MP_CHAT_MESSAGE,]] M.EVENTS.MP_VEHICLE_SPAWN,
                    M.EVENTS.MP_VEHICLE_EDITED }, event) then
                condReturn = function(v) return type(v) == "number" and v ~= 0 end
            elseif event == M.EVENTS.MP_CONSOLE_INPUT then
                condReturn = function(v) return type(v) == "string" end
            elseif event == M.EVENTS.MP_PLAYER_AUTH then
                condReturn = function(v) return type(v) == "string" or v == 1 or v == 2 end
            end

            for id, callback in pairs(M.listeners[event.key]) do
                local ok, res = pcall(callback, table.unpack(params))
                if not ok then
                    LogError(string.var("Error executing MP event {1}.{2} :", { event.key, id }), M._name)
                    dump(res)
                elseif condReturn(res) then
                    return res
                end
            end
        else
            M.listeners[event.key]:forEach(function(callback, id)
                local ok, res = pcall(callback, table.unpack(params))
                if not ok then
                    LogError(string.var("Error executing MP event {1}.{2} :", { event.key, id }), M._name)
                    dump(res)
                end
            end)
        end
    end
end

---@param event BJCEvent
---@param ...any
---@return any
local function trigger(event, ...)
    if not table.includes(M.EVENTS, event) then
        return
    end

    if event.base then
        return processMPEvent(event, ...)
    end

    local params = { ... }
    if BJCCore.Data.Debug and
        not Table({ M.EVENTS.SLOW_TICK, M.EVENTS.FAST_TICK, M.EVENTS.MP_CONSOLE_INPUT }):includes(event) then
        Log(string.var("Event triggered : {1}", { event.key }), M._name)
    end
    if M.listeners[event.key] and M.listeners[event.key]:length() > 0 then
        M.listeners[event.key]:forEach(function(callback, id)
            local ok, res = pcall(callback, table.unpack(params))
            if not ok then
                LogError(string.var("Error executing event {1}.{2} :", { event.key, id }), M._name)
                dump(res)
            end
        end)
    end
end

function BJCSlowTick()
    if type(M.trigger) == "function" then
        M.trigger(M.EVENTS.SLOW_TICK, GetCurrentTime())
    end
end

MP.RegisterEvent("slowTick", "BJCSlowTick")
MP.CreateEventTimer("slowTick", 1000)

function BJCFastTick()
    if type(M.trigger) == "function" then
        M.trigger(M.EVENTS.FAST_TICK, GetCurrentTime())
    end
end

MP.RegisterEvent("fastTick", "BJCFastTick")
MP.CreateEventTimer("fastTick", 100)

M.addListener = addListener
M.removeListener = removeListener
M.trigger = trigger

M.shutdown = function()
    BJCSlowTick = function() end
    BJCFastTick = function() end
    M.trigger = function() end
    M.listeners = {}
end

return M
