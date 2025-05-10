---@class LocalStorageElement
---@field key string
---@field default any

local M = {
    _name = "BJILocalStorage",

    -- global values are shared between all beamjoy servers
    GLOBAL_VALUES = {
        UI_SCALE = {
            key = "beamjoy.ui_scale",
            default = 1,
        },

        AUTOMATIC_LIGHTS = {
            key = "beamjoy.vehicle.automatic_lights",
            default = false,
        },

        FREECAM_SMOOTH = {
            key = "beamjoy.freecam.smooth",
            default = false,
        },
        FREECAM_FOV = {
            key = "beamjoy.freecam.fov",
            default = 65,
        },

        NAMETAGS_COLOR_PLAYER_TEXT = {
            key = "beamjoy.nametags.colors.player.text",
            default = ShapeDrawer.Color(1, 1, 1),
        },
        NAMETAGS_COLOR_PLAYER_BG = {
            key = "beamjoy.nametags.colors.player.bg",
            default = ShapeDrawer.Color(0, 0, 0),
        },
        NAMETAGS_COLOR_IDLE_TEXT = {
            key = "beamjoy.nametags.colors.idle.text",
            default = ShapeDrawer.Color(1, .6, 0),
        },
        NAMETAGS_COLOR_IDLE_BG = {
            key = "beamjoy.nametags.colors.idle.bg",
            default = ShapeDrawer.Color(0, 0, 0),
        },
        NAMETAGS_COLOR_SPEC_TEXT = {
            key = "beamjoy.nametags.colors.spec.text",
            default = ShapeDrawer.Color(.6, .6, 1),
        },
        NAMETAGS_COLOR_SPEC_BG = {
            key = "beamjoy.nametags.colors.spec.bg",
            default = ShapeDrawer.Color(0, 0, 0),
        },

        SCENARIO_SOLO_RACE_LOOP = {
            key = "beamjoy.scenario.solo_race.loop",
            default = false,
        },
        SCENARIO_VEHICLE_DELIVERY_LOOP = {
            key = "beamjoy.scenario.vehicle_delivery.loop",
            default = false,
        },
        SCENARIO_BUS_MISSION_LOOP = {
            key = "beamjoy.scenario.bus_mission.loop",
            default = false,
        },
        SCENARIO_RACE_SHOW_ALL_DATA = {
            key = "beamjoy.scenario.race.show_all_data",
            default = true,
        },
    },

    -- values are specific to a server
    VALUES = {
        RACES_PB = {
            key = "races_hashes_pb",
            ---@type table<string, table<string, MapRacePBWP[]>> table<mapName, table<raceHash, MapRacePBWP[]>>
            default = {
                --[[
                italy = {
                    ["e8f2f5b2-b2c0-4c2f-8a2f-5b2b2c0e8f2f"] = {
                        { time = 4251, speed = 73.77 },
                        { time = 12897, speed = 122.01 },
                        nil, -- each wp is linked to race, and then can be optional
                        { time = 45887, speed = 89.45 },
                        ...
                    },
                }
                ]]
            },
        },
    },

    data = {
        global = {},
        values = {},
    },
}
local VALUES_KEY = "beamjoy.values"

local function getServerIP()
    local srvData = MPCoreNetwork.getCurrentServer()
    return srvData and string.var("{1}:{2}", { srvData.ip, srvData.port }) or nil
end

-- remove all non existing/updated races from PBs
local function sanitizeMapRacesPBs()
    local mapName = GetMapName()
    if not mapName then
        BJIAsync.delayTask(sanitizeMapRacesPBs, 500)
        LogDebug("LocalStorage Races PBs sanitizer waiting for map : looping...")
        return
    elseif mapName ~= BJIContext.Scenario.Data.Races.mapName then
        LogError("LocalStorage Races PBs sanitizer : current map not matching races map, skipping...")
        return
    end
    local pbRaces = M.data.values[M.VALUES.RACES_PB.key][mapName]
    local srvRaces = BJIContext.Scenario.Data.Races
    local changes = false
    if #srvRaces > 0 then
        if not pbRaces then
            M.data.values[M.VALUES.RACES_PB.key][mapName] = {}
            changes = true
        else
            table.forEach(pbRaces, function(_, pbHash)
                if not table.any(srvRaces, function(srvRace)
                        return srvRace.hash == pbHash
                    end) then
                    LogInfo(string.var("Removing PB from obsolete race \"{1}\"", { pbHash }))
                    pbRaces[pbHash] = nil
                    changes = true
                end
            end)
        end
    elseif pbRaces > 0 then
        M.data.values[M.VALUES.RACES_PB.key][mapName] = {}
        changes = true
    end
    if changes then
        M.set(M.VALUES.RACES_PB, M.data.values[M.VALUES.RACES_PB.key])
    end
end

local listeners = Table()
local function onLoad()
    ---@param parent table
    ---@param storageKey string
    ---@param cacheKey string
    ---@param defaultValue any
    local function initStorageKey(parent, storageKey, cacheKey, defaultValue)
        local value = settings.getValue(storageKey)
        if value == nil then
            parent[cacheKey] = defaultValue
            local payload = type(defaultValue) == "table" and
                jsonEncode(defaultValue) or
                tostring(defaultValue)
            LogDebug(string.var("Assigning default setting value \"{1}\" to \"{2}\"", { cacheKey, payload }))
            settings.setValue(storageKey, payload)
        else
            if type(defaultValue) == "table" then
                parent[cacheKey] = jsonDecode(value)
            elseif type(defaultValue) == "number" then
                parent[cacheKey] = tonumber(value)
            elseif type(defaultValue) == "boolean" then
                parent[cacheKey] = value == "true" and true or false
            else
                parent[cacheKey] = value
            end
        end
    end
    ---@param el LocalStorageElement
    table.forEach(M.GLOBAL_VALUES, function(el)
        initStorageKey(M.data.global, el.key, el.key, el.default)
    end)

    local srvIP = getServerIP()
    if srvIP then
        ---@param el LocalStorageElement
        table.forEach(M.VALUES, function(el)
            local key = string.var("{1}-{2}-{3}", { VALUES_KEY, srvIP, el.key })
            initStorageKey(M.data.values, key, el.key, el.default)
        end)
    end

    BJIAsync.task(function()
        return not not BJIContext.Scenario.Data.Races
    end, sanitizeMapRacesPBs)
    listeners:insert(BJIEvents.addListener(BJIEvents.EVENTS.CACHE_LOADED, function(ctxt, data)
        if table.includes({ BJICache.CACHES.RACES }, data.cache) then
            sanitizeMapRacesPBs()
        end
    end))
end

local function onUnload()
    listeners:forEach(BJIEvents.removeListener)
end

---@param key LocalStorageElement
---@return any
local function get(key)
    if type(key) ~= "table" or not key.key then
        LogError(string.var("Invalid key \"{1}\"", { key }), M._name)
        return nil
    end
    local parent = table.find(M.GLOBAL_VALUES, function(el) return el == key end) and M.data.global or
        table.find(M.VALUES, function(el) return el == key end) and M.data.values or nil
    if not parent then
        LogError(string.var("Invalid key \"{1}\"", { key.key }), M._name)
        return nil
    end

    local value = parent[key.key]
    if type(value) == "table" then
        return table.clone(value)
    end
    return value
end

---@param key LocalStorageElement
---@param value? any
local function set(key, value)
    if type(key) ~= "table" or not key.key then
        LogError(string.var("Invalid key \"{1}\"", { key }), M._name)
        return nil
    end
    local parent = table.find(M.GLOBAL_VALUES, function(el) return el == key end) and M.data.global or
        table.find(M.VALUES, function(el) return el == key end) and M.data.values or nil
    if not parent then
        LogError(string.var("Invalid key \"{1}\"", { key.key }), M._name)
        return nil
    end

    if table.includes({ "function", "userdata", "cdata" }, type(value)) then
        LogError(string.var("Invalid value type for key {1} : {2}", { key.key, type(value) }), M._name)
        return
    end

    parent[key.key] = value
    local parsed
    if type(value) == "table" then
        parsed = jsonEncode(value)
    elseif value ~= nil then
        parsed = tostring(value)
    end
    local storageKey = parent == M.data.global and key.key or
        string.var("{1}-{2}-{3}", { VALUES_KEY, getServerIP(), key.key })
    settings.setValue(storageKey, parsed)
end

M.onLoad = onLoad
M.onUnload = onUnload

M.get = get
M.set = set

RegisterBJIManager(M)
return M
