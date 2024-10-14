local event = BJI_EVENTS.CONFIG

BJITx.config = {}

function BJITx.config.bjc(key, value)
    BJITx._send(event.EVENT, event.TX.BJC, { key, value })
end

function BJITx.config.env(key, value)
    BJITx._send(event.EVENT, event.TX.ENV, { key, value })
end

function BJITx.config.switchMap(mapName)
    BJITx._send(event.EVENT, event.TX.MAP_SWITCH, mapName)
end

function BJITx.config.core(key, value)
    BJITx._send(event.EVENT, event.TX.CORE, { key, value })
end

function BJITx.config.permissions(key, value)
    BJITx._send(event.EVENT, event.TX.PERMISSIONS, { key, value })
end

function BJITx.config.permissionsGroup(groupName, key, value)
    BJITx._send(event.EVENT, event.TX.PERMISSIONS_GROUP, { groupName, key, value })
end

function BJITx.config.permissionsGroupSpecific(groupName, permissionName, state)
    BJITx._send(event.EVENT, event.TX.PERMISSIONS_GROUP_SPECIFIC, { groupName, permissionName, state })
end

function BJITx.config.maps(map, label, archiveName)
    BJITx._send(event.EVENT, event.TX.MAPS, { map, label, archiveName })
end

function BJITx.config.stop()
    BJITx._send(event.EVENT, event.TX.STOP)
end
