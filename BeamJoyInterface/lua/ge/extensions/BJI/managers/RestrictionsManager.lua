---@class Restriction
---@field key string
---@field type string
---@field subtype? string

local M = {
    _name = "BJIRestrictions",

    --@type table<string, Restriction>
    TYPES = {
        -- RESET

        RESET_ALL = { -- CUSTOM FLAG
            key = "beamjoy_custom_reset_all",
            type = "Reset",
        },
        RESET_NONE = { -- CUSTOM FLAG
            key = "beamjoy_custom_reset_none",
            type = "Reset",
        },

        RECOVER_VEHICLE = { -- R
            key = "recover_vehicle",
            type = "Reset",
        },
        RESET_PHYSICS = { -- Ctrl + R
            key = "reset_physics",
            type = "Reset",
        },
        RESET_ALL_PHYSICS = { -- Shift + R
            key = "reset_all_physics",
            type = "Reset",
        },
        RECOVER_VEHICLE_ALT = { -- Ctrl + Insert
            key = "recover_vehicle_alt",
            type = "Reset",
        },
        RECOVER_TO_LAST_ROAD = { -- Unassigned
            key = "recover_to_last_road",
            type = "Reset",
        },
        RELOAD_VEHICLE = { -- Ctrl + Alt + R
            key = "reload_vehicle",
            type = "Reset",
        },
        RELOAD_ALL_VEHICLES = { -- Ctrl + Shift + R
            key = "reload_all_vehicles",
            type = "Reset",
        },
        LOAD_HOME = { -- Home
            key = "loadHome",
            type = "Reset",
        },
        SAVE_HOME = { -- Ctrl + Home
            key = "saveHome",
            type = "Reset",
        },
        DROP_PLAYER_AT_CAMERA = { -- F7
            key = "dropPlayerAtCamera",
            type = "Reset",
        },
        DROP_PLAYER_AT_CAMERA_NO_RESET = { -- Shift + F7
            key = "dropPlayerAtCameraNoReset",
            type = "Reset",
        },
        GOTO_CHECKPOINT = {
            key = "goto_checkpoint",
            type = "Reset",
        },

        -- CEN

        CONSOLE = {
            key = "toggleConsoleNG",
            type = "CEN",
            subtype = "Console",
        },
        EDITOR = {
            key = "editorToggle",
            type = "CEN",
            subtype = "Editor",
        },
        EDITOR_SAFE_MODE = {
            key = "editorSafeModeToggle",
            type = "CEN",
            subtype = "Editor",
        },
        EDITOR_OBJECT = {
            key = "objectEditorToggle",
            type = "CEN",
            subtype = "Editor",
        },
        NODEGRABBER = {
            key = "nodegrabberRender",
            type = "CEN",
            subtype = "NodeGrabber",
        },
    },
    ---@type Restriction[]
    currentResets = {},
    ---@type Restriction[]
    currentCEN = {},
    tag = "BeamjoyRestrictions",
}

local function onLoad()
    extensions.core_input_actionFilter.setGroup(M.tag, {})
    extensions.core_input_actionFilter.addAction(0, M.tag, false)
end

local function updateRestrictions()
    extensions.core_input_actionFilter.addAction(0, M.tag, false)

    local res = {}
    table.forEach(M.currentResets, function(r)
        table.insert(res, r)
    end)
    table.forEach(M.currentCEN, function(r)
        table.insert(res, r)
    end)

    extensions.core_input_actionFilter.setGroup(M.tag, res)
    extensions.core_input_actionFilter.addAction(0, M.tag, true)
end

---@param allowedTypes Restriction|Restriction[] allowed reset type(s) or custom flag
local function updateReset(allowedTypes)
    if type(allowedTypes) ~= "table" then
        LogError(string.var("Invalid restriction type {1}", { allowedTypes }))
        return
    end
    if allowedTypes == M.TYPES.RESET_ALL then
        -- allow all resets
        M.currentResets = {}
        updateRestrictions()
        return
    elseif allowedTypes == M.TYPES.RESET_NONE then
        -- restrict all resets
        M.currentResets = {}
        table.filter(M.TYPES, function(t)
            return t.type == "Reset" and not string.startswith(t.key, "beamjoy_custom_")
        end):forEach(function(t)
            table.insert(M.currentResets, t.key)
        end)
        updateRestrictions()
        return
    end

    M.currentResets = {}
    if allowedTypes.key then
        allowedTypes = { allowedTypes }
    end
    ---@param t Restriction
    table.filter(table.clone(M.TYPES), function(t)
        return t.key and t.type == "Reset" and not string.startswith(t.key, "beamjoy_custom_") and
            ---@param t2 Restriction
            not table.find(allowedTypes, function(t2) return t2.key == t.key end)
    end):forEach(function(t)
        table.insert(M.currentResets, t.key)
    end)
    updateRestrictions()
end

---@param restrictedTypes Restriction[]
local function updateCEN(restrictedTypes)
    if type(restrictedTypes) ~= "table" then
        LogError(string.var("Invalid CEN restriction type {1}", { restrictedTypes }))
        return
    end
    M.currentCEN = {}
    ---@param t Restriction
    table.filter(table.clone(M.TYPES), function(t)
        return t.type == "CEN" and not string.startswith(t.key, "beamjoy_custom_") and
            ---@param t2 Restriction
            table.find(restrictedTypes, function(t2) return t2.key == t.key end)
    end):forEach(function(t)
        table.insert(M.currentCEN, t.key)
    end)
    updateRestrictions()
end

---@param rest Restriction
---@return boolean
local function isRestricted(rest)
    if type(rest) ~= "table" or not rest.key or
        string.startswith(rest.key, "beamjoy_custom_") then
        LogError(string.var("Invalid restriction type {1}", { rest }))
        return false
    end

    return table.includes(M.currentResets, rest.key) or
        table.includes(M.currentCEN, rest.key)
end

M.onLoad = onLoad
M.updateReset = updateReset
M.updateCEN = updateCEN
M.isRestricted = isRestricted

RegisterBJIManager(M)
return M
