---@class BJIManagerDrift : BJIManager
local M = {
    _name = "Drift",

    lastCached = 0,

    nextScoreCancel = false,
}

---@param data { addedScore: number, combo: number, tier: { minScore: integer, continuousScore: integer, id: string, order: integer }, careerRewards?: { beamXP?: integer } }
local function onDriftCompletedScored(data)
    if M.nextScoreCancel then
        M.nextScoreCancel = false
        return
    end

    local ctxt = BJI.Managers.Tick.getContext()
    if ctxt.isOwner and data.addedScore >= BJI.Managers.Context.BJC.Freeroam.DriftGood then
        BJI.Tx.player.drift(data.addedScore)
    end
end

---@param oldGameVehID integer
---@param newGameVehID integer
local function onVehicleSwitched(oldGameVehID, newGameVehID)
    if BJI.Managers.Scenario.isFreeroam() and M.lastCached > 0 then
        -- if switch from vehicle to another, cancel score reward
        M.nextScoreCancel = true
    end
end

local function renderTick(ctxt)
    if not gameplay_drift_scoring then
        return
    end
    local veh = ctxt.veh
    if not veh or BJI.Managers.Veh.isUnicycle(veh:getID()) then
        -- no vehicle or walking
        return
    end

    M.lastCached = math.floor(gameplay_drift_scoring.getScore().cachedScore)
end

M.onLoad = function()
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_DRIFT_COMPLETED_SCORED, onDriftCompletedScored)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_VEHICLE_SWITCHED, onVehicleSwitched)
end
M.renderTick = renderTick

return M
