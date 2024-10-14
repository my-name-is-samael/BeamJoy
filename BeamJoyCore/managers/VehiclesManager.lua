local M = {
    Data = {},
}

local function init()
    M.Data = BJCDao.vehicles.findAll()
end

function _BJCOnVehicleSpawn(playerID, vehID, vehData)
    local s, e = vehData:find('%{')
    vehData = vehData:sub(s)
    vehData = JSON.parse(vehData)

    local player = BJCPlayers.Players[playerID]
    if not player then
        LogError(svar(BJCLang.getConsoleMessage("players.invalidPlayer"), { playerID = playerID }))
        return 1
    end

    local group = BJCGroups.Data[player.group]
    if not group then
        LogError(svar(BJCLang.getConsoleMessage("players.invalidGroup"), { group = player.group }))
        return 1
    end

    if not vehData then
        LogError(svar(BJCLang.getConsoleMessage("players.invalidVehicleData"), { playerID = playerID }))
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
        if group.vehicleCap > -1 and group.vehicleCap <= tlength(player.vehicles) then
            BJCTx.player.toast(playerID, BJC_TOAST_TYPES.ERROR, "players.cannotSpawnVehicle")
            return 1
        end

        local model = vehData.jbm or vehData.vcf.model

        if tincludes(BJCVehicles.Data.ModelBlacklist, model, true) then
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
            freeze = false,
            engine = true,
        }
    end


    BJCTx.cache.invalidate(playerID, BJCCache.CACHES.USER)
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.PLAYERS)
end

function _BJCOnVehicleEdited(playerID, vehID, vehData)
    local s, e = vehData:find('%{')
    vehData = vehData:sub(s)
    vehData = JSON.parse(vehData)

    if not vehData then
        LogError(svar(BJCLang.getConsoleMessage("players.invalidVehicleData"), { playerID = playerID }))
    end

    if not BJCScenario.canEditVehicle(playerID, vehID, vehData) then
        return 1
    end

    local model = vehData.jbm or vehData.vcf.model

    if tincludes(BJCVehicles.Data.ModelBlacklist, model, true) then
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

function _BJCOnVehicleReset(playerID, vehID, posRot)
    -- NO USE FOR NOW
    posRot = JSON.parse(posRot)
end

function _BJCOnVehicleDeleted(playerID, vehID)
    local player = BJCPlayers.Players[playerID]
    if not player then
        LogError(svar(BJCLang.getConsoleMessage("players.invalidPlayer"), { playerID = playerID }))
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

    BJCScenario.onVehicleDeleted(playerID, vehID)
end

local function initHooks()
    MP.RegisterEvent("onVehicleSpawn", "_BJCOnVehicleSpawn")
    MP.RegisterEvent("onVehicleEdited", "_BJCOnVehicleEdited")
    MP.RegisterEvent("onVehicleDeleted", "_BJCOnVehicleDeleted")
    MP.RegisterEvent("onVehicleReset", "_BJCOnVehicleReset")
end

local function setModelBlacklist(model, state)
    if state and not tincludes(M.Data.ModelBlacklist, model, true) then
        table.insert(M.Data.ModelBlacklist, model)
    elseif not state then
        local pos = tpos(M.Data.ModelBlacklist, model)
        if pos then
            table.remove(M.Data.ModelBlacklist, pos)
        end
    end
    BJCDao.vehicles.save(M.Data)
end

local function getCache()
    return tdeepcopy(M.Data), M.getCacheHash()
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
                BJCChat.onServerChat(targetID, svar(BJCLang.getServerMessage(target.lang, "broadcast.bigDrift"),
                    { playerName = player.playerName, score = driftScore }))
            end
        end
    end
end

M.setModelBlacklist = setModelBlacklist

M.getCache = getCache
M.getCacheHash = getCacheHash

M.onDriftEnded = onDriftEnded

init()
initHooks()

return M
