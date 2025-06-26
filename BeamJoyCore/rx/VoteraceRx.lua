local ctrl = {}

function ctrl.start(ctxt)
    local raceID, isVote, settings = ctxt.data[1], ctxt.data[2], ctxt.data[3]
    if isVote and not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.VOTE_SERVER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    elseif not isVote and not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_SERVER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    if BJCScenario.isServerScenarioInProgress() then
        error({ key = "rx.errors.invalidData" })
    end

    BJCVote.Race.start(ctxt.senderID, isVote, raceID, settings)
end

function ctrl.vote(ctxt)
    BJCVote.Race.vote(ctxt.senderID)
end

function ctrl.stop(ctxt)
    if not BJCPerm.isStaff(ctxt.senderID) then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    BJCVote.Race.stop()
end

return ctrl
