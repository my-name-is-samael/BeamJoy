local M = {
    lastScore = 0,
    lastCached = 0,

    nextScoreCancel = false,

    _bigFlashThreshold = 1000,
}

local function isDrifting()
    return gameplay_drift_drift and gameplay_drift_drift.getIsDrifting() or false
end

local function onDriftEndedSuccess(ctxt, driftScore)
    if M.nextScoreCancel then
        M.nextScoreCancel = false
        return
    end

    if ctxt.isOwner and
        driftScore >= BJIContext.BJC.Freeroam.DriftGood then
        BJITx.player.drift(driftScore)
    end
    if BJIScenario.isFreeroam() and
        BJIContext.UserSettings.driftFlashes and
        driftScore > BJIContext.BJC.Freeroam.DriftGood then
        local isBig = driftScore >= BJIContext.BJC.Freeroam.DriftBig

        local prefix = BJILang.get(isBig and "drift.bigFlash" or "drift.goodFlash", "")
        BJIMessage.flash("BJIDriftFlash", svar("{1} {2} ", { prefix, driftScore }), 2, false)
    end
end

local function onVehicleSwitched(oldGameVehID, newGameVehID)
    if BJIScenario.isFreeroam() and M.lastCached > 0 then
        -- if switch from vehicle to another, cancel score reward
        M.nextScoreCancel = true
    end
end

local function updateRealtimeDisplay(ctxt)
    if not gameplay_drift_scoring then
        return
    end
    local veh = ctxt.veh
    if not veh or BJIVeh.isUnicycle(veh:getID()) then
        -- no vehicle or walking
        return
    end

    local scores = gameplay_drift_scoring.getScore()
    local score, cached = scores.score, Round(scores.cachedScore)

    if BJIContext.UserSettings.driftFlashes and
        cached > 0 then
        BJIMessage.realtimeDisplay("drift", svar("{1}: {2}", {
            BJILang.get("drift.indicator"),
            cached
        }))
    elseif BJIMessage.realtimeData.context == "drift" then
        BJIMessage.stopRealtimeDisplay()
    end

    if M.lastScore > score and score == 0 then
        -- respawn
    elseif M.lastCached > cached and cached == 0 then
        -- drift ended
        if M.lastScore < score then
            -- drift success
            onDriftEndedSuccess(ctxt, M.lastCached)
        else
            -- drift failed
        end
    end
    M.lastScore = score
    M.lastCached = cached
end

M.isDrifting = isDrifting

M.onVehicleSwitched = onVehicleSwitched
M.updateRealtimeDisplay = updateRealtimeDisplay

RegisterBJIManager(M)
return M
