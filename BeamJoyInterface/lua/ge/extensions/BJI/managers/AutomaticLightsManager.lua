---@class BJIManagerAutomaticLights : BJIManager
local M = {
    _name = "AutomaticLights",

    morningSwitched = {}, -- gameVehID : state
    nightSwitched = {},   -- gameVehID : state
}

local function isNight()
    return BJI_Env.Data.ToD >= .245 and BJI_Env.Data.ToD <= .76
end

local function updatePreviousVeh(gameVehID)
    if BJI_LocalStorage.get(BJI_LocalStorage.GLOBAL_VALUES.AUTOMATIC_LIGHTS) and
        gameVehID and gameVehID ~= -1 and
        BJI_Veh.isVehicleOwn(gameVehID) then
        BJI_Veh.lights(false, gameVehID)
        M.nightSwitched[gameVehID] = nil
        M.morningSwitched[gameVehID] = nil
    end
end

local function updateCurrentVeh(gameVehID)
    if BJI_LocalStorage.get(BJI_LocalStorage.GLOBAL_VALUES.AUTOMATIC_LIGHTS) and
        gameVehID and gameVehID ~= -1 and
        BJI_Veh.isVehicleOwn(gameVehID) then
        -- switch lights once if needed
        local night = isNight()
        if night then
            M.morningSwitched = {}
        else
            M.nightSwitched = {}
        end
        if night and not M.nightSwitched[gameVehID] then
            -- switch lights once at night
            BJI_Veh.lights(true, gameVehID)
            M.nightSwitched[gameVehID] = true
        elseif not night and not M.morningSwitched[gameVehID] then
            -- switch lights once at morning
            BJI_Veh.lights(false, gameVehID)
            M.morningSwitched[gameVehID] = true
        end
    end

    -- purge invalid vehicles
    for vid in pairs(M.morningSwitched) do
        if not BJI_Veh.getVehicleObject(vid) then
            M.morningSwitched[vid] = nil
        end
    end
    for vid in pairs(M.nightSwitched) do
        if not BJI_Veh.getVehicleObject(vid) then
            M.morningSwitched[vid] = nil
        end
    end
end

---@param ctxt TickContext
local function slowTick(ctxt)
    if ctxt.isOwner then
        updateCurrentVeh(ctxt.veh.gameVehicleID)
    end
end

---@param oldGameVehID integer
---@param newGameVehID integer
local function onVehicleSwitched(oldGameVehID, newGameVehID)
    if oldGameVehID and oldGameVehID ~= -1 and
        BJI_Veh.isVehicleOwn(oldGameVehID) then
        updatePreviousVeh(oldGameVehID)
    end

    if newGameVehID and newGameVehID ~= -1 and
        BJI_Veh.isVehicleOwn(newGameVehID) then
        updateCurrentVeh(newGameVehID)
    end
end

M.onLoad = function()
    BJI_Events.addListener(BJI_Events.EVENTS.NG_VEHICLE_SWITCHED, onVehicleSwitched, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.SLOW_TICK, slowTick, M._name)
end

return M
