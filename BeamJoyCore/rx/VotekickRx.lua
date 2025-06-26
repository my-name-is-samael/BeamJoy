local ctrl = {}

function ctrl.start(ctxt)
    local targetID = ctxt.data[1]
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.VOTE_KICK) or
        BJCPerm.isStaff(ctxt.senderID) then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    BJCVote.Kick.start(ctxt.senderID, targetID)
end

function ctrl.vote(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.VOTE_KICK) then
        error({ key = "rx.errors.insufficientPermissions" })
    elseif BJCPerm.isStaff(ctxt.senderID) then
        error({ key = "rx.errors.invalidData" })
    end
    BJCVote.Kick.vote(ctxt.senderID)
end

function ctrl.stop(ctxt)
    if not BJCPerm.isStaff(ctxt.senderID) then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    BJCVote.Kick.stop()
end

return ctrl
