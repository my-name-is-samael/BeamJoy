---@class BJIManagerMinimap : BJIManager
local M = {
    _name = "Minimap",
}

---@param data {veh: NGVehicle?, gameVehID: integer?, state: boolean?}
local function toggleVehicle(data)
    if not data.veh and not data.gameVehID then
        error("Invalid vehicle")
        return
    end

    local veh = BJI_Veh.getVehicleObject(data.veh and data.veh:getID() or data.gameVehID)
    if not veh or BJI_AI.isAIVehicle(veh:getID()) then
        error("Invalid vehicle")
        return
    end

    if data.state == nil then
        data.state = veh.uiState ~= 1
    end
    veh.uiState = data.state and 1 or 0
end

M.toggleVehicle = toggleVehicle

return M
