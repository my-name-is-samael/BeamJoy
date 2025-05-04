---@class LocalStorageElement
---@field key string
---@field default any

local M = {
    _name = "BJILocalStorage",
    VALUES = {
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
        }
    },

    data = {},
}

local function onLoad()
    table.forEach(M.VALUES, function(el, k)
        local value = settings.getValue(el.key)
        if value == nil then
            M.data[el.key] = el.default
            local payload = type(el.default) == "table" and
                jsonEncode(el.default) or
                tostring(el.default)
            LogDebug(string.var("Assigning default setting value \"{1}\" to \"{2}\"", { el.key, payload }))
            settings.setValue(el.key, payload)
        else
            if type(el.default) == "table" then
                M.data[el.key] = jsonDecode(value)
            elseif type(el.default) == "number" then
                M.data[el.key] = tonumber(value)
            elseif type(el.default) == "boolean" then
                M.data[el.key] = value == "true" and true or false
            else
                M.data[el.key] = value
            end
        end
    end)
    dump(M.data)
end

---@param key LocalStorageElement
---@return any
local function get(key)
    if type(key) ~= "table" or not key.key then
        LogError(string.var("Invalid key \"{1}\"", { key }), M._name)
        return nil
    end

    local value = M.data[key.key]
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

    if table.includes({ "function", "userdata", "cdata" }, type(value)) then
        LogError(string.var("Invalid value type for key {1} : {2}", { key.key, type(value) }), M._name)
        return
    end

    M.data[key.key] = value
    local parsed
    if type(value) == "table" then
        parsed = jsonEncode(value)
    elseif value ~= nil then
        parsed = tostring(value)
    end
    settings.setValue(key.key, parsed)
end

M.onLoad = onLoad

M.get = get
M.set = set

RegisterBJIManager(M)
return M
