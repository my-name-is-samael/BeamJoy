local ctrl = {}

function ctrl.connected(ctxt)
    BJCPlayers.onPlayerConnect(ctxt.senderID)
end

function ctrl.switchVehicle(ctxt)
    local gameVehID = tonumber(ctxt.data[1])
    BJCPlayers.onVehicleSwitched(ctxt.senderID, gameVehID)
end

function ctrl.lang(ctxt)
    local lang = ctxt.data[1]
    BJCPlayers.changeLang(ctxt.senderID, lang)
end

function ctrl.drift(ctxt)
    local driftScore = ctxt.data[1]
    BJCVehicles.onDriftEnded(ctxt.senderID, driftScore)
end

function ctrl.KmReward(ctxt)
    BJCPlayers.reward(ctxt.senderID, BJCConfig.Data.Reputation.KmDriveReward)
end

function ctrl.explodeVehicle(ctxt)
    local gameVehID = tonumber(ctxt.data[1])
    BJCPlayers.explodeSelfVehicle(ctxt.senderID, gameVehID)
end

function ctrl.UpdateAI(ctxt)
    if not BJCPerm.canSpawnVehicle(ctxt.senderID) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local listVehIDs = ctxt.data[1]
    BJCPlayers.updateAI(ctxt.senderID, listVehIDs)
end

return ctrl
