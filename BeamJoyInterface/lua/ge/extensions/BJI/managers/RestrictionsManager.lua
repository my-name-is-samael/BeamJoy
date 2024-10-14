local logTag = "BJIRestrictions"

local M = {
    TYPES = {
        Reset = "Reset",
        ResetRace = "ResetRace",
        ResetHunter = "ResetHunter",
        ResetHunted = "ResetHunted",
        ResetSpeed = "ResetSpeed",
        ResetDerby = "ResetDerby",
        ResetBusMission = "ResetBusMission",
        Delivery = "Delivery",
        NodeGrabber = "NodeGrabber",
        Console = "Console",
        Editor = "Editor",
    },
    Tags = {
        Reset = "BJIReset",
        ResetRace = "BJIResetRace",
        ResetHunter = "BJIResetHunter",
        ResetHunted = "BJIResetHunted",
        ResetSpeed = "BJIResetSpeed",
        ResetDerby = "BJIResetDerby",
        ResetBusMission = "BJIResetBusMission",
        Delivery = "BJIDelivery",
        NodeGrabber = "BJINodeGrabber",
        Console = "BJIConsole",
        Editor = "BJIEditor",
    },
    Restrictions = {
        Reset = {
            "reset_physics",
            "reset_all_physics",
            "recover_vehicle",
            "recover_vehicle_alt",
            "recover_to_last_road",
            "reload_vehicle",
            "reload_all_vehicles",
            "loadHome",
            "saveHome",
            "dropPlayerAtCamera",
            "dropPlayerAtCameraNoReset",
            "goto_checkpoint",
        },
        ResetRace = {
            --"recover_vehicle", -- only recover allowed in race
            "reset_physics",
            "reset_all_physics",
            "recover_vehicle_alt",
            "recover_to_last_road",
            "reload_vehicle",
            "reload_all_vehicles",
            "loadHome",
            "saveHome",
            "dropPlayerAtCamera",
            "dropPlayerAtCameraNoReset",
            "goto_checkpoint",
            "nodegrabberRender",
        },
        ResetHunter = {
            --"recover_vehicle", -- only recover allowed for hunters
            "reset_physics",
            "reset_all_physics",
            "recover_vehicle_alt",
            "recover_to_last_road",
            "reload_vehicle",
            "reload_all_vehicles",
            "loadHome",
            "saveHome",
            "dropPlayerAtCamera",
            "dropPlayerAtCameraNoReset",
            "goto_checkpoint",
            "nodegrabberRender",
        },
        ResetHunted = {
            "recover_vehicle",
            "reset_physics",
            "reset_all_physics",
            "recover_vehicle_alt",
            "recover_to_last_road",
            "reload_vehicle",
            "reload_all_vehicles",
            "loadHome",
            "saveHome",
            "dropPlayerAtCamera",
            "dropPlayerAtCameraNoReset",
            "goto_checkpoint",
            "nodegrabberRender",
        },
        ResetSpeed = {
            "recover_vehicle",
            "reset_physics",
            "reset_all_physics",
            "recover_vehicle_alt",
            "recover_to_last_road",
            "reload_vehicle",
            "reload_all_vehicles",
            "loadHome",
            "saveHome",
            "dropPlayerAtCamera",
            "dropPlayerAtCameraNoReset",
            "goto_checkpoint",
            "nodegrabberRender",
        },
        ResetDerby = {
            --"recover_vehicle", -- only recover allowed in derby, with lives >= 1
            "reset_physics",
            "reset_all_physics",
            "recover_vehicle_alt",
            "recover_to_last_road",
            "reload_vehicle",
            "reload_all_vehicles",
            "loadHome",
            "saveHome",
            "dropPlayerAtCamera",
            "dropPlayerAtCameraNoReset",
            "goto_checkpoint",
            "nodegrabberRender",
        },
        ResetBusMission = {
            --"recover_vehicle", -- only recover allowed in bus mission
            "reset_physics",
            "reset_all_physics",
            "recover_vehicle_alt",
            "recover_to_last_road",
            "reload_vehicle",
            "reload_all_vehicles",
            "loadHome",
            "saveHome",
            "dropPlayerAtCamera",
            "dropPlayerAtCameraNoReset",
            "goto_checkpoint",
            "nodegrabberRender",
        },
        Delivery = {
            --"recover_vehicle", -- only recover allowed in delivery
            "reset_physics",
            "reset_all_physics",
            "recover_vehicle_alt",
            "recover_to_last_road",
            "reload_vehicle",
            "reload_all_vehicles",
            "loadHome",
            "saveHome",
            "dropPlayerAtCamera",
            "dropPlayerAtCameraNoReset",
            "goto_checkpoint",
            "nodegrabberRender",
        },
        NodeGrabber = {
            "nodegrabberRender",
        },
        Console = {
            "toggleConsoleNG",
        },
        Editor = {
            "editorToggle",
            "editorSafeModeToggle",
            "objectEditorToggle",
        },
    },
    states = {}
}
for k in pairs(M.TYPES) do
    local tag = M.Tags[k]
    M.states[tag] = false

    local restrictions = M.Restrictions[k]
    extensions.core_input_actionFilter.setGroup(tag, restrictions)
    extensions.core_input_actionFilter.addAction(0, tag, M.states[tag])
end

local function apply(type, state)
    if not M.TYPES[type] then
        LogError(svar("Invalid restriction type {1}", { type }))
        return
    end

    local tag = M.Tags[type]
    M.states[tag] = state
    extensions.core_input_actionFilter.addAction(0, tag, M.states[tag])
end

local function applySpecific(tag, restrictions, state)
    if state then
        -- try enabling restrictions
        if M.states[tag] == nil then
            -- if not exists, creating group
            extensions.core_input_actionFilter.setGroup(tag, restrictions)
        end
        extensions.core_input_actionFilter.addAction(0, tag, state)
    elseif M.states[tag] then
        -- if trying to disable and existing
        extensions.core_input_actionFilter.addAction(0, tag, state)
    else
        LogError(svar("Invalid restriction \"{1}\"", { tag }), logTag)
    end
end

local function getState(type)
    if not M.TYPES[type] then
        LogError(svar("Invalid restriction type {1}", { type }))
        return
    end

    local tag = M.Tags[type]
    return M.states[tag]
end

local function updateCEN()
    -- restricted and not admin+
    local consoleRestriction = not BJIPerm.hasMinimumGroup(BJI_GROUP_NAMES.ADMIN) and
        not BJIContext.BJC.CEN.Console
    M.apply(M.TYPES.Console, consoleRestriction)

    local editorRestriction = not BJIPerm.hasMinimumGroup(BJI_GROUP_NAMES.ADMIN) and
        not BJIContext.BJC.CEN.Editor
    M.apply(M.TYPES.Editor, editorRestriction)

    local nodeGrabberRestriction = not BJIPerm.hasMinimumGroup(BJI_GROUP_NAMES.ADMIN) and
        not BJIContext.BJC.CEN.NodeGrabber
    M.apply(M.TYPES.NodeGrabber, nodeGrabberRestriction)
end

M.apply = apply
M.applySpecific = applySpecific
M.getState = getState
M.updateCEN = updateCEN

RegisterBJIManager(M)
return M
