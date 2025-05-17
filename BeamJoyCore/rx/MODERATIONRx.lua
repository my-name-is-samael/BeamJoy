local ctrl = {}

function ctrl.mute(ctxt)
    local targetName, reason = ctxt.data[1], ctxt.data[2]
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.MUTE) then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    BJCPlayers.toggleMute(ctxt, targetName, reason)
end

--[[
<ul>
    <li> targets = array</li>
    <ul>
        <li>[1] = state NULLABLE</li>
        <li>[2] = playerID</li>
        <li>[3] = vehicleID NULLABLE</li>
    </ul>
</ul>
]]
function ctrl.freeze(ctxt)
    local targetID, vehID = ctxt.data[1], ctxt.data[2]
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.FREEZE_PLAYERS) then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    local errKey, errData
    local _, err = pcall(BJCPlayers.toggleFreeze, targetID, vehID)
    if err then
        err = type(err) == "table" and err or {}
        errKey, errData = err.key, err.data
    end
    if errKey then
        error({ key = errKey, data = errData })
    end
end

function ctrl.engine(ctxt)
    local targetID, vehID = tonumber(ctxt.data[1]), tonumber(ctxt.data[2])
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.ENGINE_PLAYERS) then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    BJCPlayers.toggleEngine(targetID, vehID)
end

function ctrl.kick(ctxt)
    local targetID, reason = tonumber(ctxt.data[1]), ctxt.data[2]
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.KICK) then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    BJCPlayers.kick(ctxt, targetID, reason)
end

function ctrl.tempban(ctxt)
    local targetName, duration, reason = ctxt.data[1], tonumber(ctxt.data[2]), ctxt.data[3]
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.TEMP_BAN) then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    BJCPlayers.tempBan(ctxt, targetName, reason, duration)
end

function ctrl.ban(ctxt)
    local targetName, reason = ctxt.data[1], ctxt.data[2]
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.BAN) then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    BJCPlayers.ban(ctxt, targetName, reason)
end

function ctrl.unban(ctxt)
    local targetName = ctxt.data[1]
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.BAN) then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    BJCPlayers.unban(targetName)
end

function ctrl.teleportFrom(ctxt)
    local targetID = tonumber(ctxt.data[1])
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.TELEPORT_FROM) then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    BJCPlayers.teleportFrom(ctxt.senderID, targetID)
end

function ctrl.setGroup(ctxt)
    local targetName, groupName = ctxt.data[1], ctxt.data[2]
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.SET_GROUP) then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    BJCPlayers.setGroup(ctxt, targetName, groupName)
end

function ctrl.deleteVehicle(ctxt)
    local targetID, gameVehID = tonumber(ctxt.data[1]), tonumber(ctxt.data[2])

    if targetID ~= ctxt.senderID and
        not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.DELETE_VEHICLE) then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    BJCPlayers.deleteVehicle(ctxt.senderID, targetID, gameVehID)
end

function ctrl.whitelist(ctxt)
    local playerName = ctxt.data[1]
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.WHITELIST) then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    BJCPlayers.whitelist(ctxt, playerName)
end

return ctrl
