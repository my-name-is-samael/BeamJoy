local ctrl = {}

---@param ctxt BJCContext
function ctrl.clear(ctxt)
    if not BJCPerm.isStaff(ctxt.senderID) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCTournament.clear()
end

---@param ctxt BJCContext
function ctrl.toggle(ctxt)
    if not BJCPerm.isStaff(ctxt.senderID) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCTournament.toggle(ctxt.data[1] == true)
end

---@param ctxt BJCContext
function ctrl.endTournament(ctxt)
    if not BJCPerm.isStaff(ctxt.senderID) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCTournament.endTournament()
end

---@param ctxt BJCContext
function ctrl.toggleWhitelist(ctxt)
    if not BJCPerm.isStaff(ctxt.senderID) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCTournament.toggleWhitelist(ctxt.data[1] == true)
end

---@param ctxt BJCContext
function ctrl.toggleWhitelistPlayer(ctxt)
    if not BJCPerm.isStaff(ctxt.senderID) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local playerName, state = ctxt.data[1], ctxt.data[2] == true
    BJCTournament.toggleWhitelistPlayer(playerName, state)
end

---@param ctxt BJCContext
function ctrl.removeActivity(ctxt)
    if not BJCPerm.isStaff(ctxt.senderID) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local activityIndex = ctxt.data[1]
    BJCTournament.removeActivity(activityIndex)
end

---@param ctxt BJCContext
function ctrl.editScore(ctxt)
    if not BJCPerm.isStaff(ctxt.senderID) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local playerName, activityIndex, score = ctxt.data[1], ctxt.data[2], ctxt.data[3]
    BJCTournament.editPlayerScore(playerName, activityIndex, score)
end

---@param ctxt BJCContext
function ctrl.removePlayer(ctxt)
    if not BJCPerm.isStaff(ctxt.senderID) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local playerName = ctxt.data[1]
    BJCTournament.removePlayer(playerName)
end

---@param ctxt BJCContext
function ctrl.addSoloRace(ctxt)
    if not BJCPerm.isStaff(ctxt.senderID) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local raceID, timeoutMin = ctxt.data[1], ctxt.data[2]
    BJCTournament.addSoloRaceActivity(raceID, timeoutMin)
end

---@param ctxt BJCContext
function ctrl.endSoloRace(ctxt)
    if not BJCPerm.isStaff(ctxt.senderID) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCTournament.endSoloRaceActivity()
end

return ctrl
