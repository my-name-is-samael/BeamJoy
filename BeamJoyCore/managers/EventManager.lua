---@class BJCEvent
---@field key string
---@field base? boolean

local M = {
    EVENTS = {
        CONSOLE_INPUT = { key = "onConsoleInput", base = true },
        PLAYER_AUTH = { key = "onPlayerAuth", base = true },
        PLAYER_CONNECTING = { key = "onPlayerConnecting", base = true },
        PLAYER_JOINING = { key = "onPlayerJoining", base = true },
        PLAYER_JOIN = { key = "onPlayerJoin", base = true },
        PLAYER_DISCONNECT = { key = "onPlayerDisconnect", base = true },
        CHAT_MESSAGE = { key = "onChatMessage", base = true },
        VEHICLE_SPAWN = { key = "onVehicleSpawn", base = true },
        VEHICLE_EDITED = { key = "onVehicleEdited", base = true },
        VEHICLE_DELETED = { key = "onVehicleDeleted", base = true },
        VEHICLE_RESET = { key = "onVehicleReset", base = true },

        PLAYER_CONNECTED = { key = "onPlayerConnected" },
        PLAYER_KICKED = { key = "onPlayerKicked" },
        SLOW_TICK = { key = "onSlowTick" },
        FAST_TICK = { key = "onFastTick" },
    },

    ---@type table<string, table<string, fun(data: any)>>
    listeners = {},
}

-- Write BeamMP event handlers to `_G` and make them fire the associated event
local function initMPHandlers()
    Table(M.EVENTS):filter(function(ev) return ev.base end)
        :forEach(function(ev)
            _G[ev.key] = function(...)
                return M.trigger(ev, ...)
            end
            MP.RegisterEvent(ev.key, ev.key)
        end)
end
initMPHandlers()

---@param events BJCEvent[]|BJCEvent
---@param callback fun(...:any)
---@return string|nil
local function addListener(events, callback)
    if events.key then
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
        if not M.listeners[event.key] then
            M.listeners[event.key] = {}
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
local function trigger(event, ...)
    if not table.includes(M.EVENTS, event) then
        return -1
    end

    local data = { ... }
    local returnCode = 0
    if BJCCore.Data.General.Debug and
        not Table({ M.EVENTS.SLOW_TICK, M.EVENTS.FAST_TICK, M.EVENTS.CONSOLE_INPUT }):includes(event) then
        Log(string.var("Event triggered : {1}", { event.key }), M._name)
    end
    if M.listeners[event.key] then
        table.forEach(M.listeners[event.key], function(callback)
            if returnCode ~= 0 then
                return
            end
            local ok, res = pcall(callback, table.unpack(data))
            if not ok then
                LogError(string.var("Error executing event {1} :", { event.key }), M._name)
                dump(res)
            elseif res ~= nil then
                returnCode = res
            end
        end)
    end
    return returnCode
end

function BJCSlowTick()
    trigger(M.EVENTS.SLOW_TICK, GetCurrentTime())
end

MP.RegisterEvent("slowTick", "BJCSlowTick")
MP.CreateEventTimer("slowTick", 1000)

function BJCFastTick()
    trigger(M.EVENTS.FAST_TICK, GetCurrentTime())
end

MP.RegisterEvent("fastTick", "BJCFastTick")
MP.CreateEventTimer("fastTick", 100)

M.addListener = addListener
M.removeListener = removeListener
M.trigger = trigger

return M
