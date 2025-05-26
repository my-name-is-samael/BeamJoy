---@class BJIManagerGameState : BJIManager
local M = {
    _name = "GameState",

    state = {
        ---@type string?
        appLayout = nil,
        ---@type string?
        menuItems = nil,
        ---@type string?
        state = nil,
    },

    _defaultAppLayout = "",
    _defaultMenuItems = "",
    _defaultState = "",
}

local function firstInit()
    M.state = extensions.core_gamestate.state
    M._defaultAppLayout = M.state.appLayout
    M._defaultMenuItems = M.state.menuItems
    M._defaultState = M.state.state
end

local function _apply(state, appLayout, menuItems)
    if not M.state.state then firstInit() end

    local needUpdate = state ~= M.state.state or appLayout ~= M.state.appLayout or menuItems ~= M.state.menuItems
    state = state or M.state.state
    appLayout = appLayout or M.state.appLayout
    menuItems = menuItems or M.state.menuItems
    if needUpdate then
        extensions.core_gamestate.setGameState(state, appLayout, menuItems)
        M.state = extensions.core_gamestate.state
    end
end

---@param showVehicleSelector? boolean
---@param showVehicleEditor? boolean
---@param showMap? boolean
local function updateMenuItems(showVehicleSelector, showVehicleEditor, showMap)
    local newState
    if not showVehicleSelector and not showVehicleEditor and not showMap then
        newState = "scenario" -- hides map, vehselector, vehedit, env
    else
        newState = M._defaultMenuItems
    end
    _apply(nil, nil, newState)
end

M.updateMenuItems = updateMenuItems

return M
