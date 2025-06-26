local ctrl = {}

function ctrl.playersGet(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.DATABASE_PLAYERS) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCTx.database.playersGet(ctxt.senderID, BJCPlayers.getDatabasePlayers())
end

function ctrl.vehicle(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.DATABASE_VEHICLES) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    local model, state = ctxt.data[1], ctxt.data[2]
    BJCVehicles.setModelBlacklist(model, state)
end

return ctrl
