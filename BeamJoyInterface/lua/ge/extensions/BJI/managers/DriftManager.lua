local M = {
    lastCached = 0,

    nextScoreCancel = false,
}

local function onDriftCompletedScored(data)
    if M.nextScoreCancel then
        M.nextScoreCancel = false
        return
    end

    local ctxt = BJITick.getContext()
    if ctxt.isOwner and data.addedScore >= BJIContext.BJC.Freeroam.DriftGood then
        BJITx.player.drift(data.addedScore)
    end
end

local function onVehicleSwitched(oldGameVehID, newGameVehID)
    if BJIScenario.isFreeroam() and M.lastCached > 0 then
        -- if switch from vehicle to another, cancel score reward
        M.nextScoreCancel = true
    end
end

local function renderTick(ctxt)
    if not gameplay_drift_scoring then
        return
    end
    local veh = ctxt.veh
    if not veh or BJIVeh.isUnicycle(veh:getID()) then
        -- no vehicle or walking
        return
    end

    M.lastCached = math.floor(gameplay_drift_scoring.getScore().cachedScore)
end

M.onDriftCompletedScored = onDriftCompletedScored
M.onVehicleSwitched = onVehicleSwitched
M.renderTick = renderTick

RegisterBJIManager(M)
return M
