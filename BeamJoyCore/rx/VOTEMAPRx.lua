local ctrl = {}

function ctrl.start(ctxt)
    local mapName = ctxt.data[1]
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.VOTE_MAP) then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    BJCVote.Map.start(ctxt.senderID, mapName)
end

function ctrl.vote(ctxt)
    BJCVote.Map.vote(ctxt.senderID)
end

function ctrl.stop(ctxt)
    if not BJCPerm.isStaff(ctxt.senderID) then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    BJCVote.Map.stop()
end

return ctrl
