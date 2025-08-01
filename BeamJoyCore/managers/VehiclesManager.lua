local M = {
    Data = BJCDao.vehicles.findAll(),
}

---@param playerID integer
---@param vehID integer
---@param vehDataStr string
local function onVehicleSpawn(playerID, vehID, vehDataStr)
    local s, e = vehDataStr:find('%{')
    vehDataStr = s and vehDataStr:sub(s) or ""
    local data = JSON.parse(vehDataStr)
    ---@type ServerVehicleConfig?
    local vehData = type(data) == "table" and data or nil

    local player = BJCPlayers.Players[playerID]
    if not player then
        LogError(BJCLang.getConsoleMessage("players.invalidPlayer"):var({ playerID = playerID }))
        return 1
    end

    local group = BJCGroups.Data[player.group]
    if not group then
        LogError(BJCLang.getConsoleMessage("players.invalidGroup"):var({ group = player.group }))
        return 1
    end

    if not vehData then
        LogError(BJCLang.getConsoleMessage("players.invalidVehicleData"):var({ playerID = playerID }))
        return 1
    end

    if not BJCScenario.canSpawnVehicle(playerID, vehID, vehData) then
        BJCTx.player.toast(playerID, BJC_TOAST_TYPES.ERROR, "players.cannotSpawnVehicle")
        return 1
    end

    if vehData.jbm == "unicycle" then
        -- starting to walk
        if group.vehicleCap == 0 then
            BJCTx.player.toast(playerID, BJC_TOAST_TYPES.ERROR, "players.cannotSpawnVehicle")
            return 1
        elseif not BJCConfig.Data.Freeroam.AllowUnicycle or
            not BJCScenario.canWalk(playerID) then
            BJCTx.player.toast(playerID, BJC_TOAST_TYPES.ERROR, "players.walkNotAllowed")
            return 1
        end
    else
        local model = tostring(vehData.jbm or vehData.vcf.model or vehData.vcf.mainPartName)
        local isAi = model:lower():find("traffic") ~= nil
        -- spawning vehicle
        if vehData.vcf.model and isAi then
            -- traffic
            if MP.GetPlayerCount() == 1 then
                -- alone on server with permission to spawn a veh, allow traffic
                if not BJCPerm.canSpawnVehicle(playerID) then
                    BJCTx.player.toast(playerID, BJC_TOAST_TYPES.ERROR, "players.cannotSpawnVehicle")
                    return 1
                end
            elseif group.vehicleCap ~= -1 then
                BJCTx.player.toast(playerID, BJC_TOAST_TYPES.ERROR, "players.cannotSpawnVehicle")
                return 1
            end
        else
            -- non-traffic vehicle
            if group.vehicleCap > -1 and group.vehicleCap <= table.filter(player.vehicles, function(v)
                    return not v.isAi
                end):length() then
                return 1
            end
        end

        if table.includes(BJCVehicles.Data.ModelBlacklist, model) then
            if BJCPerm.isStaff(playerID) then
                BJCTx.player.toast(playerID, BJC_TOAST_TYPES.WARNING, "players.blacklistedVehicle")
            else
                BJCTx.player.toast(playerID, BJC_TOAST_TYPES.ERROR, "players.blacklistedVehicle")
                return 1
            end
        end

        player.vehicles[vehID] = {
            vehicleID = vehID,
            vid = vehData.vid,
            pid = vehData.pid,
            name = model,
            isAi = isAi,
            freeze = false,
            engine = true,
        }
    end

    BJCTx.cache.invalidate(playerID, BJCCache.CACHES.USER)
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.PLAYERS)
end

---@param playerID integer
---@param vehID integer
---@param vehDataStr string
local function onVehicleEdited(playerID, vehID, vehDataStr)
    local s, e = vehDataStr:find('%{')
    vehDataStr = s and vehDataStr:sub(s) or ""
    local vehData = JSON.parse(vehDataStr)

    if not vehData then
        LogError(BJCLang.getConsoleMessage("players.invalidVehicleData"):var({ playerID = playerID }))
        return 1
    end

    if not BJCScenario.canEditVehicle(playerID, vehID, vehData) then
        return 1
    end

    local model = vehData.jbm or vehData.vcf.model

    if table.includes(BJCVehicles.Data.ModelBlacklist, model) then
        if BJCPerm.isStaff(playerID) then
            BJCTx.player.toast(playerID, BJC_TOAST_TYPES.WARNING, "players.blacklistedVehicle")
        else
            BJCTx.player.toast(playerID, BJC_TOAST_TYPES.ERROR, "players.blacklistedVehicle")
            return 1
        end
    end

    local player = BJCPlayers.Players[playerID]
    if vehData and player then
        local vehicle = player.vehicles[vehID]
        if vehicle then
            -- NO vid ON THIS EVENT
            if vehicle.name ~= vehData.jbm then
                vehicle.name = model

                BJCTx.cache.invalidate(playerID, BJCCache.CACHES.USER)
                BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.PLAYERS)
            end
        end
    end
end

local function onVehicleReset(playerID, vehID, posRot)
    -- NO USE FOR NOW
    posRot = JSON.parse(posRot)
end

local function onVehicleDeleted(playerID, vehID)
    local player = BJCPlayers.Players[playerID]
    if not player then
        LogError(BJCLang.getConsoleMessage("players.invalidPlayer"):var({ playerID = playerID }))
        return
    end

    player.vehicles[vehID] = nil
    BJCTx.cache.invalidate(playerID, BJCCache.CACHES.USER)
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.PLAYERS)
end

local function setModelBlacklist(model, state)
    if state and not table.includes(M.Data.ModelBlacklist, model) then
        table.insert(M.Data.ModelBlacklist, model)
    elseif not state then
        local pos = table.indexOf(M.Data.ModelBlacklist, model)
        if pos then
            table.remove(M.Data.ModelBlacklist, pos)
        end
    end
    BJCDao.vehicles.save(M.Data)
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DATABASE_VEHICLES)
end

local function getCache()
    return table.deepcopy(M.Data), M.getCacheHash()
end

local function getCacheHash()
    return Hash(M.Data)
end

local function onDriftEnded(playerID, driftScore)
    if driftScore >= BJCConfig.Data.Freeroam.DriftGood then
        local isBig = driftScore >= BJCConfig.Data.Freeroam.DriftBig
        BJCPlayers.reward(playerID, isBig and
            BJCConfig.Data.Reputation.DriftBigReward or
            BJCConfig.Data.Reputation.DriftGoodReward)

        if BJCConfig.Data.Server.DriftBigBroadcast and isBig then
            local player = BJCPlayers.Players[playerID]
            for targetID, target in pairs(BJCPlayers.Players) do
                BJCChat.onServerChat(targetID, BJCLang.getServerMessage(target.lang, "broadcast.bigDrift")
                    :var({ playerName = player.playerName, score = driftScore }))
            end
        end
    end
end

---@param senderID integer
---@param gameVehicleID integer
---@param paintIndex integer 1-3
---@param paintData table
local function syncPaint(senderID, gameVehicleID, paintIndex, paintData)
    local owner = BJCPlayers.Players[senderID]
    if not owner then
        error({ key = "rx.errors.invalidPlayerID", data = { playerID = senderID } })
    end

    local veh = table.find(owner.vehicles, function(v) return v.vid == gameVehicleID end)
    if not veh then
        error({ key = "rx.errors.invalidVehicleID", data = { vehicleID = gameVehicleID } })
    end

    paintIndex = math.clamp(paintIndex, 1, 3) ~= paintIndex and 1 or paintIndex

    if not veh.paints then
        veh.paints = Table()
    end
    veh.paints[paintIndex] = paintData

    Table(BJCPlayers.Players):keys():filter(function(pid) return pid ~= senderID end)
        :forEach(function(pid) BJCTx.player.syncPaint(pid, gameVehicleID, paintIndex, paintData) end)
end

---@param senderID integer
---@param gameVehicleID integer
local function requestPaint(senderID, ownerID, gameVehicleID)
    local sender = BJCPlayers.Players[senderID]
    if not sender then
        error({ key = "rx.errors.invalidPlayerID", data = { playerID = senderID } })
    end
    local owner = BJCPlayers.Players[ownerID]
    if not owner then
        error({ key = "rx.errors.invalidPlayerID", data = { playerID = ownerID } })
    end
    local veh = table.find(owner.vehicles, function(v) return v.vid == gameVehicleID end)
    if not veh then
        error({ key = "rx.errors.invalidVehicleID", data = { vehicleID = gameVehicleID } })
    end
    if veh.paints then
        Range(1, 3):forEach(function(i)
            if veh.paints[i] then
                BJCTx.player.syncPaint(senderID, gameVehicleID, i, veh.paints[i])
            end
        end)
    end
end

M.setModelBlacklist = setModelBlacklist

M.getCache = getCache
M.getCacheHash = getCacheHash

M.onDriftEnded = onDriftEnded

M.syncPaint = syncPaint
M.requestPaint = requestPaint

BJCEvents.addListener(BJCEvents.EVENTS.MP_VEHICLE_SPAWN, onVehicleSpawn, "VehiclesManager")
BJCEvents.addListener(BJCEvents.EVENTS.MP_VEHICLE_EDITED, onVehicleEdited, "VehiclesManager")
BJCEvents.addListener(BJCEvents.EVENTS.MP_VEHICLE_RESET, onVehicleReset, "VehiclesManager")
BJCEvents.addListener(BJCEvents.EVENTS.MP_VEHICLE_DELETED, onVehicleDeleted, "VehiclesManager")

return M
