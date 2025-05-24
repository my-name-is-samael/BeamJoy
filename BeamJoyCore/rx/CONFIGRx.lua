local ctrl = {}

function ctrl.bjc(ctxt)
    local key, value = ctxt.data[1], ctxt.data[2]
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.SET_CONFIG) then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    BJCConfig.set(ctxt, key, value)
end

function ctrl.env(ctxt)
    local key, value = ctxt.data[1], ctxt.data[2]
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.SET_ENVIRONMENT) then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    if key == "reset" then
        BJCEnvironment.resetType(value)
    else
        BJCEnvironment.set(key, value)
    end
end

function ctrl.envPreset(ctxt)
    local preset = ctxt.data[1]
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.SET_ENVIRONMENT_PRESET) then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    BJCEnvironment.applyPreset(preset)
end

function ctrl.permissions(ctxt)
    local key, value = ctxt.data[1], ctxt.data[2]
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.SET_PERMISSIONS) then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    BJCPerm.setPermission(key, value)
end

function ctrl.permissionsGroup(ctxt)
    local groupName, key, value = ctxt.data[1], ctxt.data[2], ctxt.data[3]
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.SET_PERMISSIONS) then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    BJCGroups.setPermission(groupName, key, value)
end

function ctrl.permissionsGroupSpecific(ctxt)
    local groupName, permissionName, state = ctxt.data[1], ctxt.data[2], ctxt.data[3]
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.SET_PERMISSIONS) then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    BJCGroups.toggleGroupPermission(groupName, permissionName, state == true)
end

function ctrl.core(ctxt)
    local key, value = ctxt.data[1], ctxt.data[2]
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.SET_CORE) then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    BJCCore.set(key, value)
end

function ctrl.switchMap(ctxt)
    local mapName = ctxt.data[1]
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.SWITCH_MAP) then
        error({ key = "rx.errors.insufficientPermissions" })
    end
    BJCCore.setMap(mapName)
end

function ctrl.maps(ctxt)
    if type(ctxt.data[2]) == "boolean" then
        -- update map state
        local mapName, state = ctxt.data[1], ctxt.data[2]
        if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.SET_MAPS) then
            error({ key = "rx.errors.insufficientPermissions" })
        end
        BJCMaps.setMapState(mapName, state)
    else
        -- CRUD map
        local mapName, label, archive = ctxt.data[1], ctxt.data[2], ctxt.data[3]
        if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.SET_MAPS) then
            error({ key = "rx.errors.insufficientPermissions" })
        end
        BJCMaps.set(mapName, label, archive)
    end
end

function ctrl.stop(ctxt)
    if not BJCPerm.hasPermission(ctxt.senderID, BJCPerm.PERMISSIONS.SET_CORE) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    BJCCore.stop()
end

return ctrl
