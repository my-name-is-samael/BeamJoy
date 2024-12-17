local M = {
    _name = "BJIAutomaticLights",
    morningSwitched = {}, -- gameVehID : state
    nightSwitched = {},   -- gameVehID : state
}

local function isNight()
    return BJIEnv.Data.ToD >= .245 and BJIEnv.Data.ToD <= .76
end

local function updatePreviousVeh(gameVehID)
    if BJIContext.UserSettings.automaticLights and
        gameVehID and gameVehID ~= -1 and
        BJIVeh.isVehicleOwn(gameVehID) then
        BJIVeh.lights(false, gameVehID)
        M.nightSwitched[gameVehID] = nil
        M.morningSwitched[gameVehID] = nil
    end
end

local function updateCurrentVeh(gameVehID)
    if BJIContext.UserSettings.automaticLights and
        gameVehID and gameVehID ~= -1 and
        BJIVeh.isVehicleOwn(gameVehID) then
        -- switch lights once if needed
        local night = isNight()
        if night then
            M.morningSwitched = {}
        else
            M.nightSwitched = {}
        end
        if night and not M.nightSwitched[gameVehID] then
            -- switch lights once at night
            BJIVeh.lights(true, gameVehID)
            M.nightSwitched[gameVehID] = true
        elseif not night and not M.morningSwitched[gameVehID] then
            -- switch lights once at morning
            BJIVeh.lights(false, gameVehID)
            M.morningSwitched[gameVehID] = true
        end
    end

    -- purge invalid vehicles
    for vid in pairs(M.morningSwitched) do
        if not BJIVeh.getVehicleObject(vid) then
            M.morningSwitched[vid] = nil
        end
    end
    for vid in pairs(M.nightSwitched) do
        if not BJIVeh.getVehicleObject(vid) then
            M.morningSwitched[vid] = nil
        end
    end
end

local function slowTick(ctxt)
    if ctxt.isOwner then
        updateCurrentVeh(ctxt.veh:getID())
    end
end

local function onVehicleSwitched(oldGameVehID, newGameVehID)
    if oldGameVehID and oldGameVehID ~= -1 and
        BJIVeh.isVehicleOwn(oldGameVehID) then
        updatePreviousVeh(oldGameVehID)
    end

    if newGameVehID and newGameVehID ~= -1 and
        BJIVeh.isVehicleOwn(newGameVehID) then
        updateCurrentVeh(newGameVehID)
    end
end

M.slowTick = slowTick
M.onVehicleSwitched = onVehicleSwitched

RegisterBJIManager(M)
return M
