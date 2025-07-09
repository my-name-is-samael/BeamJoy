local ctrl = {}

---@param ctxt BJCContext
function ctrl.MapStart(ctxt)
    local mapName = ctxt.data[1]
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.VOTE_MAP) then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    BJCVote.Map.start(ctxt.senderID, mapName)
end

---@param ctxt BJCContext
function ctrl.MapVote(ctxt)
    BJCVote.Map.vote(ctxt.senderID)
end

---@param ctxt BJCContext
function ctrl.MapStop(ctxt)
    if not BJCPerm.isStaff(ctxt.senderID) and
        ctxt.senderID ~= BJCVote.Map.creatorID then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    BJCVote.Map.stop()
end

---@param ctxt BJCContext
function ctrl.KickStart(ctxt)
    local targetID = ctxt.data[1]
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.VOTE_KICK) or
        BJCPerm.isStaff(ctxt.senderID) then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    BJCVote.Kick.start(ctxt.senderID, targetID)
end

---@param ctxt BJCContext
function ctrl.KicVotek(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.VOTE_KICK) then
        error({ key = "rx.errors.insufficientPermissions" })
    elseif BJCPerm.isStaff(ctxt.senderID) then
        error({ key = "rx.errors.invalidData" })
    end
    BJCVote.Kick.vote(ctxt.senderID)
end

---@param ctxt BJCContext
function ctrl.KickStop(ctxt)
    if not BJCPerm.isStaff(ctxt.senderID) and
        ctxt.senderID ~= BJCVote.Kick.creatorID then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    BJCVote.Kick.stop()
end

---@param ctxt BJCContext
function ctrl.ScenarioStart(ctxt)
    local scenario, isVote, data = ctxt.data[1], ctxt.data[2] == true, ctxt.data[3] or {}
    if isVote and not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.VOTE_SERVER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    elseif not isVote and not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_SERVER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    if BJCScenario.isServerScenarioInProgress() then
        error({ key = "rx.errors.invalidData" })
    end

    BJCVote.Scenario.start(scenario, ctxt.senderID, isVote, data)
end

---@param ctxt BJCContext
function ctrl.ScenarioVote(ctxt)
    local data = ctxt.data[1]
    BJCVote.Scenario.vote(ctxt.senderID, data)
end

---@param ctxt BJCContext
function ctrl.ScenarioStop(ctxt)
    if not BJCPerm.isStaff(ctxt.senderID) and
        ctxt.senderID ~= BJCVote.Scenario.creatorID then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    BJCVote.Scenario.stop()
end

return ctrl
