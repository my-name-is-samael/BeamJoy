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

    local ctxt = BJI_Tick.getContext()
    if ctxt.isOwner and data.addedScore >= BJI_Context.BJC.Freeroam.DriftGood then
        BJI_Tx_player.drift(data.addedScore)
    end
end

---@param oldGameVehID integer
---@param newGameVehID integer
local function onVehicleSwitched(oldGameVehID, newGameVehID)
    if BJI_Scenario.isFreeroam() and M.lastCached > 0 then
        -- if switch from vehicle to another, cancel score reward
        M.nextScoreCancel = true
    end
end

---@param ctxt TickContext
local function fastTick(ctxt)
    if not gameplay_drift_scoring then
        return
    end
    if not ctxt.veh or ctxt.veh.jbeam == "unicycle" then
        -- no vehicle or walking
        return
    end

    M.lastCached = math.floor(gameplay_drift_scoring.getScore().cachedScore)
end

M.onLoad = function()
    BJI_Events.addListener(BJI_Events.EVENTS.NG_DRIFT_COMPLETED_SCORED, onDriftCompletedScored, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.NG_VEHICLE_SWITCHED, onVehicleSwitched, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.FAST_TICK, fastTick, M._name)
end

return M
