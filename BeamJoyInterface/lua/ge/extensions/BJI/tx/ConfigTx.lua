---@param TX BJITX
return function(TX)
    local event = BJI.CONSTANTS.EVENTS.CONFIG
    local config = {
        _name = "config"
    }

    function config.bjc(key, value)
        TX._send(event.EVENT, event.TX.BJC, { key, value })
    end

    function config.env(key, value)
        TX._send(event.EVENT, event.TX.ENV, { key, value })
    end

    function config.switchMap(mapName)
        TX._send(event.EVENT, event.TX.MAP_SWITCH, mapName)
    end

    function config.core(key, value)
        TX._send(event.EVENT, event.TX.CORE, { key, value })
    end

    function config.permissions(key, value)
        TX._send(event.EVENT, event.TX.PERMISSIONS, { key, value })
    end

    ---@param groupName string
    ---@param key string
    ---@param value? any
    function config.permissionsGroup(groupName, key, value)
        TX._send(event.EVENT, event.TX.PERMISSIONS_GROUP, { groupName, key, value })
    end

    function config.permissionsGroupSpecific(groupName, permissionName, state)
        TX._send(event.EVENT, event.TX.PERMISSIONS_GROUP_SPECIFIC, { groupName, permissionName, state })
    end

    function config.maps(map, label, archiveName)
        TX._send(event.EVENT, event.TX.MAPS, { map, label, archiveName })
    end

    function config.mapState(map, state)
        TX._send(event.EVENT, event.TX.MAPS, { map, state })
    end

    function config.stop()
        TX._send(event.EVENT, event.TX.STOP)
    end

    return config
end
