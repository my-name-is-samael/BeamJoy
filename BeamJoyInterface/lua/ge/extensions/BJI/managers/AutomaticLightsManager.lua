---@class BJIManagerAutomaticLights : BJIManager
local M = {
    _name = "AutomaticLights",

    morningSwitched = {}, -- gameVehID : state
    nightSwitched = {},   -- gameVehID : state
}

local function isNight()
    return BJI.Managers.Env.Data.ToD >= .245 and BJI.Managers.Env.Data.ToD <= .76
end

local function updatePreviousVeh(gameVehID)
    if BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.AUTOMATIC_LIGHTS) and
        gameVehID and gameVehID ~= -1 and
        BJI.Managers.Veh.isVehicleOwn(gameVehID) then
        BJI.Managers.Veh.lights(false, gameVehID)
        M.nightSwitched[gameVehID] = nil
        M.morningSwitched[gameVehID] = nil
    end
end

local function updateCurrentVeh(gameVehID)
    if BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.AUTOMATIC_LIGHTS) and
        gameVehID and gameVehID ~= -1 and
        BJI.Managers.Veh.isVehicleOwn(gameVehID) then
        -- switch lights once if needed
        local night = isNight()
        if night then
            M.morningSwitched = {}
        else
            M.nightSwitched = {}
        end
        if night and not M.nightSwitched[gameVehID] then
            -- switch lights once at night
            BJI.Managers.Veh.lights(true, gameVehID)
            M.nightSwitched[gameVehID] = true
        elseif not night and not M.morningSwitched[gameVehID] then
            -- switch lights once at morning
            BJI.Managers.Veh.lights(false, gameVehID)
            M.morningSwitched[gameVehID] = true
        end
    end

    -- purge invalid vehicles
    for vid in pairs(M.morningSwitched) do
        if not BJI.Managers.Veh.getVehicleObject(vid) then
            M.morningSwitched[vid] = nil
        end
    end
    for vid in pairs(M.nightSwitched) do
        if not BJI.Managers.Veh.getVehicleObject(vid) then
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
        BJI.Managers.Veh.isVehicleOwn(oldGameVehID) then
        updatePreviousVeh(oldGameVehID)
    end

    if newGameVehID and newGameVehID ~= -1 and
        BJI.Managers.Veh.isVehicleOwn(newGameVehID) then
        updateCurrentVeh(newGameVehID)
    end
end

M.onLoad = function()
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_VEHICLE_SWITCHED, onVehicleSwitched, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.SLOW_TICK, slowTick, M._name)
end

return M
