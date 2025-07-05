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
function ctrl.RaceStart(ctxt)
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

---@param ctxt BJCContext
function ctrl.RaceVote(ctxt)
    BJCVote.Race.vote(ctxt.senderID)
end

---@param ctxt BJCContext
function ctrl.RaceStop(ctxt)
    if not BJCPerm.isStaff(ctxt.senderID) and
        ctxt.senderID ~= BJCVote.Race.creatorID then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    BJCVote.Race.stop()
end

---@param ctxt BJCContext
function ctrl.SpeedStart(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.START_SERVER_SCENARIO) and
        not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.VOTE_SERVER_SCENARIO) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    if BJCScenario.isServerScenarioInProgress() then
        error({ key = "rx.errors.invalidData" })
    end

    local isVote = ctxt.data[1] == true
    BJCVote.Speed.start(ctxt.senderID, isVote)
end

---@param ctxt BJCContext
function ctrl.SpeedVote(ctxt)
    if not BJCPerm.canSpawnVehicle(ctxt.senderID) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local gameVehID = ctxt.data[1]
    BJCVote.Speed.join(ctxt.senderID, gameVehID)
end

---@param ctxt BJCContext
function ctrl.SpeedStop(ctxt)
    if not BJCPerm.isStaff(ctxt.senderID) and
        ctxt.senderID ~= BJCVote.Speed.creatorID then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    BJCVote.Speed.stop()
end

return ctrl