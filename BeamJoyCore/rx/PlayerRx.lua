local ctrl = {}

---@param ctxt BJCContext
function ctrl.connected(ctxt)
    BJCPlayers.onPlayerConnect(ctxt.senderID)
end

---@param ctxt BJCContext
function ctrl.switchVehicle(ctxt)
    local gameVehID = tonumber(ctxt.data[1]) -- optional
    BJCPlayers.onVehicleSwitched(ctxt.senderID, gameVehID)
end

---@param ctxt BJCContext
function ctrl.lang(ctxt)
    local lang = ctxt.data[1]
    BJCPlayers.changeLang(ctxt.senderID, lang)
end

---@param ctxt BJCContext
function ctrl.drift(ctxt)
    local driftScore = ctxt.data[1]
    BJCVehicles.onDriftEnded(ctxt.senderID, driftScore)
end

---@param ctxt BJCContext
function ctrl.KmReward(ctxt)
    BJCPlayers.reward(ctxt.senderID, BJCConfig.Data.Reputation.KmDriveReward)
end

---@param ctxt BJCContext
function ctrl.explodeVehicle(ctxt)
    local gameVehID = tonumber(ctxt.data[1]) or
        error({ key = "rx.errors.invalidVehicleID", data = { vehicleID = ctxt.data[1] } })
    BJCPlayers.explodeSelfVehicle(ctxt.senderID, gameVehID)
end

---@param ctxt BJCContext
function ctrl.markInvalidVehs(ctxt)
    local listVehIDs = ctxt.data[1]
    BJCPlayers.markInvalidVehs(ctxt.senderID, listVehIDs)
end

---@param ctxt BJCContext
function ctrl.syncPaint(ctxt)
    local vid, paintIndex, paintData = tonumber(ctxt.data[1]), tonumber(ctxt.data[2]), ctxt.data[3]
    if not vid or not paintIndex or type(paintData) ~= "table" then
        error({ key = "rx.errors.invalidData" })
    end

    BJCVehicles.syncPaint(ctxt.senderID, vid, paintIndex, paintData)
end

---@param ctxt BJCContext
function ctrl.requestPaint(ctxt)
    local ownerID, vid = tonumber(ctxt.data[1]), tonumber(ctxt.data[2])
    if not vid then
        error({ key = "rx.errors.invalidData" })
    end

    BJCVehicles.requestPaint(ctxt.senderID, ownerID, vid)
end

return ctrl
