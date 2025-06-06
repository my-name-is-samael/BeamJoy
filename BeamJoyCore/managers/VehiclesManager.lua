local M = {
    Data = BJCDao.vehicles.findAll(),
}

---@param playerID integer
---@param vehID integer
---@param vehDataStr string
local function onVehicleSpawn(playerID, vehID, vehDataStr)
    local s, e = vehDataStr:find('%{')
    vehDataStr = s and vehDataStr:sub(s) or ""
    ---@type ServerVehicleConfig?
    local vehData = JSON.parse(vehDataStr) or nil

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
        -- spawning vehicle
        if group.vehicleCap > -1 and group.vehicleCap <= table.length(player.vehicles) then
            BJCTx.player.toast(playerID, BJC_TOAST_TYPES.ERROR, "players.cannotSpawnVehicle")
            return 1
        end

        local model = vehData.jbm or vehData.vcf.model or vehData.vcf.mainPartName

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
            name = tostring(model),
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
                player.currentVehicle = vehicle.vid

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

    local isCurrent = player.vehicles[vehID] and
        player.vehicles[vehID].vid == player.currentVehicle
    player.vehicles[vehID] = nil
    if isCurrent then
        player.currentVehicle = nil
    end
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

M.setModelBlacklist = setModelBlacklist

M.getCache = getCache
M.getCacheHash = getCacheHash

M.onDriftEnded = onDriftEnded

BJCEvents.addListener(BJCEvents.EVENTS.MP_VEHICLE_SPAWN, onVehicleSpawn, "VehiclesManager")
BJCEvents.addListener(BJCEvents.EVENTS.MP_VEHICLE_EDITED, onVehicleEdited, "VehiclesManager")
BJCEvents.addListener(BJCEvents.EVENTS.MP_VEHICLE_RESET, onVehicleReset, "VehiclesManager")
BJCEvents.addListener(BJCEvents.EVENTS.MP_VEHICLE_DELETED, onVehicleDeleted, "VehiclesManager")

return M
