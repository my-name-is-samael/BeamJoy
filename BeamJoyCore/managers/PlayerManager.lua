local logTag = "PlayerManager"
SetLogType(logTag, CONSOLE_COLORS.FOREGROUNDS.MAGENTA)

local dbPath = BJCPluginPath:gsub("BeamJoyCore", "BeamJoyData/db/players/")

local M = {
    Players = {},     -- connected players
    AuthPlayers = {}, -- players between auth and connection
    MapCachePermissions = {
        [BJCCache.CACHES.USER] = "User",
        [BJCCache.CACHES.PLAYERS] = "Players",
        [BJCCache.CACHES.DATABASE_PLAYERS] = "DatabasePlayers",
        [BJCCache.CACHES.DATABASE_VEHICLES] = "DatabaseVehicles",
    },
    _lastDatabaseUpdate = GetCurrentTime(),
}

local function sanitizeDBPlayer(player)
    player = type(player) == "table" and player or {}
    return {
        ip = player.ip,
        beammp = player.beammp,
        playerName = player.playerName,
        group = BJCGroups.Data[player.group] and player.group or BJCGroups.GROUPS.NONE,
        lang = player.lang or BJCLang.FallbackLang,
        reputation = player.reputation or 0,
        stats = {
            delivery = player.stats and player.stats.delivery or 0,
            race = player.stats and player.stats.race or 0,
            bus = player.stats and player.stats.bus or 0,
        },
        muted = player.muted,
        muteReason = player.muteReason,
        kickReason = player.kickReason,
        banReason = player.banReason,
        tempBanUntil = player.tempBanUntil,
        banned = player.banned,
    }
end

local function savePlayer(player)
    if not player.guest then
        BJCDao.players.save(sanitizeDBPlayer(player))
        M._lastDatabaseUpdate = GetCurrentTime()
    end
end

local function addAuthPlayer(playerName, guest, ip, beammp)
    M.AuthPlayers[playerName] = {
        playerName = playerName,
        guest = guest,
        ip = ip,
        beammp = beammp, -- nil if guest
        ready = false,
    }
end

local function bindAuthPlayer(playerID, playerName)
    local player = M.AuthPlayers[playerName]
    if not player then
        Log(BJCLang.getConsoleMessage("players.authPlayerNotFound")
            :var({ playerName = playerName }), logTag)
        return false
    else
        M.Players[playerID] = {
            playerID = playerID,
            playerName = player.playerName,
            guest = player.guest,
            ip = player.ip,
            beammp = player.beammp, -- nil if guest
            ready = player.ready,
        }
        M.AuthPlayers[playerName] = nil
        return true
    end
end

local function instantiatePlayer(playerID)
    local player = M.Players[playerID]

    local data = BJCDao.players.findByPlayerName(player.playerName)

    -- DB PLAYER DATA
    if not data then
        -- new player
        data = {}
    end
    table.assign(player, sanitizeDBPlayer(data))

    -- GAME PLAYER DATA
    player.playerID = playerID
    player.hideNametag = false
    player.currentVehicle = nil
    player.freeze = false
    player.engine = true
    player.vehicles = {}
    player.ai = {}
    player.messages = {}

    M.savePlayer(player)
end

-- block connection if needed (banned, tempbanned, whitelist, etc.)
local function checkJoin(playerID)
    local player = M.Players[playerID]
    if not player then
        MP.DropPlayer(playerID, BJCLang.getServerMessage(playerID, "players.joinError"))
        return
    end

    if player.tempBanUntil then
        local now = GetCurrentTime()
        if player.tempBanUntil <= now then
            -- temp ban ended
            player.tempBanUntil = nil
            M.savePlayer(player)
        elseif player.tempBanUntil > now then
            -- still tempbanned
            local reason = BJCLang.getServerMessage(playerID, "players.tempBanWillEndIn")
                :var({ time = PrettyDelay(player.tempBanUntil - GetCurrentTime()) })
            if player.banReason then
                reason = BJCLang.getServerMessage(playerID, "players.banReason")
                    :var({ base = reason, reason = player.banReason })
            end
            MP.DropPlayer(playerID, reason)
            M.Players[playerID] = nil
            return
        end
    end

    local group = BJCGroups.Data[player.group]
    if player.banned or group.banned then
        local reason = BJCLang.getServerMessage(playerID, "players.banned")
        if player.banReason then
            reason = BJCLang.getServerMessage(playerID, "players.banReason")
                :var({ base = reason, reason = player.banReason })
        end
        MP.DropPlayer(playerID, reason)
        M.Players[playerID] = nil
        return
    end

    -- whitelist
    if BJCConfig.Data.Whitelist.Enabled and
        not table.includes(BJCConfig.Data.Whitelist.PlayerNames, player.playerName) and
        not group.whitelisted and
        not group.staff then
        MP.DropPlayer(playerID, BJCLang.getServerMessage(playerID, "players.notWhitelisted"))
        M.Players[playerID] = nil
        return
    end
end

---@param name string
---@param role string
---@param isGuest boolean
---@param identifiers {ip: string, beammp: string}
local function onPlayerAuth(name, role, isGuest, identifiers)
    addAuthPlayer(name, isGuest, identifiers.ip, identifiers.beammp)
end

local function onPlayerConnecting(playerID)
    local playerName = MP.GetPlayerName(playerID)
    if bindAuthPlayer(playerID, playerName) then
        instantiatePlayer(playerID)

        checkJoin(playerID)
    else
        MP.DropPlayer(playerID, BJCLang.getServerMessage(playerID, "players.joinError"))
        M.AuthPlayers[playerID] = nil
    end
end

local function onPlayerJoining(playerID)
end

local function onPlayerJoin(playerID)
    if not M.Players[playerID] then
        MP.DropPlayer(playerID, BJCLang.getServerMessage(playerID, "players.joinError"))
        M.Players[playerID] = nil
    end
end

-- Triggered when player is connected and ready to play
local function onPlayerConnect(playerID)
    if M.Players[playerID] then
        M.Players[playerID].ready = true
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.PLAYERS)
        BJCTx.cache.invalidateByPermissions(BJCCache.CACHES.DATABASE_PLAYERS, BJCPerm.PERMISSIONS.DATABASE_PLAYERS)

        BJCEvents.trigger(BJCEvents.EVENTS.PLAYER_CONNECTED, playerID)
    else
        MP.DropPlayer(playerID, BJCLang.getServerMessage(playerID, "players.joinError"))
        M.Players[playerID] = nil
    end
end

local function onPlayerDisconnect(playerID)
    if M.Players[playerID] then
        local playerName = M.Players[playerID].playerName
        M.Players[playerID] = nil

        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.PLAYERS)
        BJCTx.cache.invalidateByPermissions(BJCCache.CACHES.DATABASE_PLAYERS, BJCPerm.PERMISSIONS.DATABASE_PLAYERS)

        BJCEvents.trigger(BJCEvents.EVENTS.PLAYER_DISCONNECTED, { playerID = playerID, playerName = playerName })
        -- TriggerBJCManagers("onPlayerDisconnect", playerID, playerName)
    end
end

local function onVehicleSwitched(senderID, gameVehID)
    local player = M.Players[senderID]
    player.currentVehicle = gameVehID
    BJCTx.cache.invalidate(senderID, BJCCache.CACHES.USER)
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.PLAYERS)
end

local function getCount(permission, excludeStaff)
    if not permission then
        permission = BJCGroups.Data[BJCGroups.GROUPS.NONE].level
    end

    local count = 0
    for _, player in pairs(M.Players) do
        if BJCPerm.hasPermission(player.playerID, permission) and
            (not excludeStaff or not BJCGroups.Data[player.group].staff) then
            count = count + 1
        end
    end
    return count
end

-- CACHES

local function getCacheUser(playerID)
    local player = M.Players[playerID]
    if not player then
        LogError(BJCLang.getConsoleMessage("players.invalidPlayer"):var({ playerID = playerID }))
        return {}, M.getCacheUserHash(playerID)
    else
        local data = {
            playerID = player.playerID,
            playerName = player.playerName,
            group = player.group,
            lang = player.lang,
            freeze = player.freeze,
            engine = player.engine,
            vehicles = {},
            currentVehicle = player.currentVehicle,

            reputation = player.reputation,

            stats = table.deepcopy(player.stats),
        }
        for vehID, vehicle in pairs(player.vehicles) do
            data.vehicles[vehID] = {
                vehID = vehID,
                gameVehID = vehicle.vid,
                model = vehicle.name,
                freeze = vehicle.freeze,
                engine = vehicle.engine,
            }
        end
        return data, M.getCacheUserHash(playerID)
    end
end

local function getCacheUserHash(playerID)
    return M.Players[playerID] and Hash(M.Players[playerID]) or tostring(GetCurrentTime())
end

local function getCachePlayers(senderID)
    local players = {}
    for playerID, player in pairs(M.Players) do
        if player.ready then
            -- basic data
            players[playerID] = {
                playerID = playerID,
                playerName = player.playerName,
                guest = player.guest,
                group = player.group,
                reputation = player.reputation,
                staff = BJCPerm.isStaff(playerID),
                currentVehicle = player.currentVehicle,
                vehicles = {},
                ai = table.deepcopy(player.ai),
                isGhost = table.includes({
                    BJCScenario.PLAYER_SCENARII.RACE_SOLO
                }, player.scenario),
            }
            players[playerID].vehicles = {}
            for vehID, vehicle in pairs(player.vehicles) do
                players[playerID].vehicles[vehID] = {
                    vehID = vehID,
                    gameVehID = vehicle.vid,
                    model = vehicle.name,
                }
            end
            -- moderation data
            if BJCPerm.hasMinimumGroup(senderID, BJCGroups.GROUPS.MOD) then
                players[playerID].freeze = player.freeze
                players[playerID].engine = player.engine
                players[playerID].muted = player.muted
                players[playerID].muteReason = player.muteReason
                players[playerID].kickReason = player.kickReason
                players[playerID].banReason = player.banReason

                for vehID, vehicle in pairs(player.vehicles) do
                    players[playerID].vehicles[vehID].freeze = vehicle.freeze
                    players[playerID].vehicles[vehID].engine = vehicle.engine
                end

                players[playerID].messages = {}
                for _, msg in ipairs(player.messages) do
                    table.insert(players[playerID].messages, {
                        time = msg.time,
                        message = msg.message,
                    })
                end
            end
        end
    end
    return players, M.getCachePlayersHash()
end

local function getCachePlayersHash()
    return Hash(M.Players)
end

local function getCacheDatabasePlayers()
    local db = {}
    for _, filename in pairs(FS.ListFiles(dbPath)) do
        local file, error = io.open(string.var("{1}/{2}", { dbPath, filename }), "r")
        if not error and file then
            local player = JSON.parse(file:read("*a"))
            file:close()
            if player ~= nil then
                if player.tempBanUntil and player.tempBanUntil <= GetCurrentTime() then
                    player.tempBanUntil = nil
                    M.savePlayer(player)
                end
                db[player.beammp] = {
                    playerName = player.playerName,
                    group = player.group,
                    tempBanUntil = player.tempBanUntil,
                    banned = player.banned,
                    banReason = player.banReason,
                    muted = player.muted,
                    muteReason = player.muteReason,
                    beammp = player.beammp,
                    lang = player.lang,
                }
            end
        end
    end
    return db, M.getCacheDatabasePlayersHash()
end

local function getCacheDatabasePlayersHash()
    return Hash({ M._lastDatabaseUpdate })
end

-- PLAYER MODERATION

local function drop(playerID, reason)
    local player = M.Players[playerID]
    if type(reason) ~= "string" or #reason == 0 then
        reason = nil
    end
    if reason and not reason:find(" ") then
        -- maybe a key
        local parsed = BJCLang.getServerMessage(player.lang, reason)
        if parsed and parsed ~= reason then
            reason = parsed
        end
    end
    BJCEvents.trigger(BJCEvents.EVENTS.PLAYER_KICKED, playerID)
    MP.DropPlayer(playerID, reason)
    local connected = player.ready
    M.Players[playerID] = nil
    if connected then
        BJCChat.onPlayerDisconnect(playerID, player.playerName)
    end
end

local function dropMultiple(playerIDs, reasonKey)
    for _, playerID in ipairs(playerIDs) do
        local playerName = M.Players[playerID].playerName
        drop(playerID, reasonKey)
        M.Players[playerID] = nil
        BJCChat.onPlayerDisconnect(playerID, playerName)
    end
end

local function setGroup(ctxt, targetName, groupName)
    local target
    local connected = false
    for _, player in pairs(M.Players) do
        if player.playerName == targetName then
            target = player
            connected = true
        end
    end
    if not target then
        target = BJCDao.players.findByPlayerName(targetName)
    end
    if not target then
        error({ key = "rx.errors.invalidPlayer", data = { playerName = targetName } })
    end

    local groupToAssign = BJCGroups.Data[groupName]
    if not groupToAssign then
        error({ key = "rx.errors.invalidGroup", data = { group = groupName } })
    end

    if ctxt.origin == "player" then
        local senderGroup = BJCGroups.Data[ctxt.sender.group]
        local targetGroup = BJCGroups.Data[target.group]
        if groupToAssign.level >= senderGroup.level or targetGroup.level >= senderGroup.level then
            error({ key = "rx.errors.insufficientPermissions" })
        end
    end

    target.group = groupName
    M.savePlayer(target)

    if connected then
        -- invalidate all caches that are constructed by group permission
        BJCTx.cache.invalidate(target.playerID, BJCCache.CACHES.USER)
        BJCTx.cache.invalidate(target.playerID, BJCCache.CACHES.BJC)
        BJCTx.cache.invalidate(target.playerID, BJCCache.CACHES.RACES)
        BJCTx.cache.invalidate(target.playerID, BJCCache.CACHES.DELIVERIES)
        BJCTx.cache.invalidate(target.playerID, BJCCache.CACHES.STATIONS)
        BJCTx.cache.invalidate(target.playerID, BJCCache.CACHES.DATABASE_VEHICLES)
        BJCTx.cache.invalidate(target.playerID, BJCCache.CACHES.CORE)
        BJCTx.cache.invalidate(target.playerID, BJCCache.CACHES.MAPS)

        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.PLAYERS)
    end
end

local function toggleFreeze(targetID, vehID) -- optional vehID
    local target = M.Players[targetID]
    if not target then
        error({ key = "rx.errors.invalidPlayerID", data = { playerID = targetID } })
    end

    local vehicle
    if vehID then
        vehicle = target.vehicles[vehID]
        if not vehicle then
            error({ key = "rx.errors.invalidVehicleID", data = { vehicleID = vehID } })
        end
    end

    if vehicle then
        vehicle.freeze = not vehicle.freeze
    else
        target.freeze = not target.freeze
    end

    BJCTx.cache.invalidate(targetID, BJCCache.CACHES.USER)
    BJCTx.cache.invalidateByPermissions(BJCCache.CACHES.PLAYERS, BJCPerm.PERMISSIONS.FREEZE_PLAYERS)
end

local function toggleEngine(targetID, vehID) -- optional vehID
    local target = M.Players[targetID]
    if not target then
        error({ key = "rx.errors.invalidPlayerID", data = { playerID = targetID } })
    end

    local vehicle
    if vehID then
        vehicle = target.vehicles[vehID]
        if not vehicle then
            error({ key = "rx.errors.invalidVehicleID", data = { vehicleID = vehID } })
        end
    end

    if vehicle then
        vehicle.engine = not vehicle.engine
    else
        target.engine = not target.engine
    end

    BJCTx.cache.invalidate(targetID, BJCCache.CACHES.USER)
    BJCTx.cache.invalidateByPermissions(BJCCache.CACHES.PLAYERS, BJCPerm.PERMISSIONS.ENGINE_PLAYERS)
end

local function teleportFrom(senderID, targetID)
    local target = M.Players[targetID]
    if not target then
        error({ key = "rx.errors.invalidPlayerID", data = { playerID = targetID } })
    end

    BJCTx.player.teleportToPlayer(target.playerID, senderID)
end

local function whitelist(ctxt, playerName)
    for _, player in pairs(BJCPlayers.Players) do
        if player.name == playerName and player.guest then
            error({ key = "rx.errors.guestCannotBeWhitelisted" })
        end
    end

    local whitelistNames = BJCConfig.Data.Whitelist.PlayerNames
    local pos = table.indexOf(whitelistNames, playerName)
    if pos ~= nil then
        table.remove(whitelistNames, pos)
    else
        table.insert(whitelistNames, playerName)
    end

    BJCConfig.set(ctxt, "Whitelist.PlayerNames", whitelistNames)

    BJCTx.cache.invalidateByPermissions(BJCCache.CACHES.BJC, BJCPerm.PERMISSIONS.WHITELIST)
    BJCTx.cache.invalidateByPermissions(BJCCache.CACHES.DATABASE_PLAYERS, BJCPerm.PERMISSIONS.DATABASE_PLAYERS)
end

local function toggleMute(ctxt, targetName, reason)
    local target
    local connected = false
    for _, player in pairs(M.Players) do
        if player.playerName == targetName then
            target = player
            connected = true
            break
        end
    end
    if not target then
        target = BJCDao.players.findByPlayerName(targetName)
    end
    if not target then
        error({ key = "rx.errors.invalidPlayer", data = { playerName = targetName } })
    end

    if ctxt.origin == "player" then
        local senderGroup = BJCGroups.Data[ctxt.sender.group]
        local targetGroup = BJCGroups.Data[target.group]
        if senderGroup.level <= targetGroup.level then
            error({ key = "rx.errors.insufficientPermissions" })
        end
    end

    target.muted = target.muted ~= true
    target.muteReason = reason
    M.savePlayer(target)

    if connected then
        if target.muted then
            local finalReason
            if target.muteReason and #target.muteReason > 0 then
                finalReason = target.muteReason
            end

            local msg
            if finalReason then
                msg = BJCLang.getServerMessage(target.lang, "players.mutedReason")
                    :var({ reason = finalReason })
            else
                msg = BJCLang.getServerMessage(target.lang, "players.muted")
            end
            BJCChat.onServerChat(target.playerID, msg)
        else
            BJCChat.onServerChat(target.playerID, BJCLang.getServerMessage(target.lang, "players.unmuted"))
        end
    end
end

local function deleteVehicle(senderID, targetID, gameVehID)
    local target = M.Players[targetID]
    if not target then
        error({ key = "rx.errors.invalidPlayerID", data = { playerID = targetID } })
    end

    local self = M.Players[senderID]
    local selfGroup = BJCGroups.Data[self.group]
    local targetGroup = BJCGroups.Data[target.group]
    if selfGroup.level <= targetGroup.level and senderID ~= targetID then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    if table.length(target.vehicles) == 0 then
        -- invalid veh, continue without error
        return
    elseif gameVehID ~= -1 or table.length(target.vehicles) == 1 then
        -- remove specific player vehicle
        if gameVehID == -1 then
            for _, veh in pairs(target.vehicles) do
                gameVehID = veh.vid
                break
            end
        end
        local multipleVehicles = table.length(target.vehicles) > 1
        local current = target.currentVehicle == gameVehID
        local vehID
        for id, veh in pairs(target.vehicles) do
            if veh.vid == gameVehID then
                vehID = id
                break
            end
        end
        local vehicle = vehID and target.vehicles[vehID] or nil
        if not gameVehID or not vehicle then
            -- invalid veh, continue without error
            return
        end

        if senderID ~= targetID then
            local prefix = BJCLang.getServerMessage(senderID, "rx.vehicleRemoveMain")
            if multipleVehicles and not current then
                prefix = BJCLang.getServerMessage(senderID, "rx.vehicleRemoveOneOf")
            end
            BJCTx.player.toast(targetID, BJC_TOAST_TYPES.WARNING, "rx.vehicleRemoveSuffix",
                { typeVehicleRemove = prefix }, 7)
        end

        if current then
            target.currentVehicle = nil
        end
        MP.RemoveVehicle(targetID, vehID)
        target.vehicles[gameVehID] = nil
        BJCEvents.trigger(BJCEvents.EVENTS.VEHICLE_DELETED, targetID, vehID)
    else
        --remove all player vehicles
        target.currentVehicle = nil
        for vehID in pairs(target.vehicles) do
            MP.RemoveVehicle(targetID, vehID)
            target.vehicles[vehID] = nil
            BJCEvents.trigger(BJCEvents.EVENTS.VEHICLE_DELETED, targetID, vehID)
        end

        BJCTx.player.toast(targetID, BJC_TOAST_TYPES.WARNING, "rx.vehicleRemoveAll",
            nil, 7)
    end

    BJCTx.cache.invalidate(targetID, BJCCache.CACHES.USER)
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.PLAYERS)
end

local function kick(ctxt, targetID, reason)
    local target = M.Players[targetID]
    if not target then
        error({ key = "rx.errors.invalidPlayerID", data = { playerID = targetID } })
    end

    if ctxt.origin == "player" then -- can kick from console or votekick
        local senderGroup = BJCGroups.Data[ctxt.sender.group]
        local targetGroup = BJCGroups.Data[target.group]
        if senderGroup.level <= targetGroup.level then
            error({ key = "rx.errors.insufficientPermissions" })
        end
    end

    if reason then
        target.kickReason = reason
        M.savePlayer(target)
    else
        target.kickReason = nil
        reason = BJCLang.getServerMessage(target.lang, "players.kicked")
    end

    M.drop(targetID, reason)
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.PLAYERS)
    BJCTx.cache.invalidateByPermissions(BJCCache.CACHES.DATABASE_PLAYERS, BJCPerm.PERMISSIONS.DATABASE_PLAYERS)
end

local function tempBan(ctxt, targetName, reason, duration)
    local connected = false
    local target
    for _, player in pairs(M.Players) do
        if player.playerName == targetName then
            target = player
            connected = true
            break
        end
    end
    if not target then
        target = BJCDao.players.findByPlayerName(targetName)
    end
    if not target then
        error({ key = "rx.errors.invalidPlayer", data = { playerName = targetName } })
    end

    if ctxt.origin == "player" then -- can tempban from console
        local senderGroup = BJCGroups.Data[ctxt.sender.group]
        local targetGroup = BJCGroups.Data[target.group]
        if senderGroup.level <= targetGroup.level then
            error({ key = "rx.errors.insufficientPermissions" })
        end
    end

    local config = BJCConfig.Data.TempBan
    duration = math.clamp(math.round(duration), config.minTime, config.maxTime)

    target.banReason = reason
    target.tempBanUntil = GetCurrentTime() + duration
    M.savePlayer(target)

    if connected then
        local finalReason = BJCLang.getServerMessage(target.playerID, "players.tempBanned")
            :var({ time = PrettyDelay(duration) })
        if reason then
            finalReason = BJCLang.getServerMessage(target.playerID, "players.banReason")
                :var({ base = finalReason, reason = reason })
        end

        M.drop(target.playerID, finalReason)
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.PLAYERS)
    end
end

local function ban(ctxt, targetName, reason)
    local target
    local connected = false
    for _, player in pairs(M.Players) do
        if player.playerName == targetName then
            target = player
            connected = true
            break
        end
    end
    if not target then
        target = BJCDao.players.findByPlayerName(targetName)
    end
    if not target then
        error({ key = "rx.errors.invalidPlayer", data = { playerName = targetName } })
    end

    if ctxt.origin == "player" then -- can ban from console
        local senderGroup = BJCGroups.Data[ctxt.sender.group]
        local targetGroup = BJCGroups.Data[target.group]
        if senderGroup.level <= targetGroup.level then
            error({ key = "rx.errors.insufficientPermissions" })
        end
    end

    target.banReason = reason
    target.banned = true
    M.savePlayer(target)

    if connected then
        local finalReason = BJCLang.getServerMessage(target.playerID, "players.banned")
        if reason then
            finalReason = BJCLang.getServerMessage(target.playerID, "players.banReason")
                :var({ base = finalReason, reason = reason })
        end

        M.drop(target.playerID, finalReason)
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.PLAYERS)
    end
end

local function unban(targetName)
    local target = BJCDao.players.findByPlayerName(targetName)

    if target == nil then
        error({ key = "rx.errors.invalidPlayer", data = { playerName = targetName } })
    end

    if not target.banned and target.tempBanUntil == nil then
        error({ key = "rx.errors.invalidData" })
    end

    target.banned = nil
    target.tempBanUntil = nil
    M.savePlayer(target)
end

local function changeLang(targetID, lang)
    local target = BJCPlayers.Players[targetID]
    if lang == target.lang then
        return
    end

    if not BJCLang.Langs[lang] then
        error({ key = "rx.errors.invalidLang", data = { lang = lang } })
    end

    target.lang = lang
    M.savePlayer(target)

    BJCTx.cache.invalidate(targetID, BJCCache.CACHES.USER)
    BJCTx.cache.invalidate(targetID, BJCCache.CACHES.LANG)
end

local function updateAI(playerID, listVehIDs)
    local player = M.Players[playerID]
    if not player then
        error({ key = "rx.errors.invalidPlayerID", data = { playerID = playerID } })
    end

    player.ai = listVehIDs or {}
    table.sort(player.ai)
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.PLAYERS)
end

local function setPlayerScenario(playerID, scenario)
    local self = M.Players[playerID]
    self.scenario = scenario
end

local function onRaceSoloEnd(playerID, finished)
    local player = M.Players[playerID]
    if player.scenario ~= BJCScenario.PLAYER_SCENARII.RACE_SOLO then
        error({ key = "rx.errors.invalidData" })
    end

    M.setPlayerScenario(playerID, BJCScenario.PLAYER_SCENARII.FREEROAM)
    player.stats.race = player.stats.race + 1
    if finished then
        M.reward(playerID, BJCConfig.Data.Reputation.RaceSoloReward)
    else
        M.savePlayer(player)
    end
end

local function onDeliveryVehicleSuccess(playerID, pristine)
    local self = M.Players[playerID]
    local reward = BJCConfig.Data.Reputation.DeliveryVehicleReward
    if pristine then
        reward = reward + BJCConfig.Data.Reputation.DeliveryVehiclePristineReward
    end
    M.reward(playerID, reward)
    self.scenario = BJCScenario.PLAYER_SCENARII.FREEROAM
    self.stats.delivery = self.stats.delivery + 1

    BJCAsync.delayTask(function()
        BJCScenario.updateDeliveryLeaderboard()
    end, 0)
end

local function onDeliveryPackageSuccess(playerID)
    local self = M.Players[playerID]
    local streak = self.deliveryPackageStreak or 0
    local reward = BJCConfig.Data.Reputation.DeliveryPackageReward +
        streak * BJCConfig.Data.Reputation.DeliveryPackageStreakReward
    M.reward(playerID, reward)
    self.deliveryPackageStreak = streak + 1
    self.stats.delivery = self.stats.delivery + 1
    BJCTx.scenario.DeliveryPackageSuccess(playerID, self.deliveryPackageStreak)

    BJCAsync.delayTask(function()
        BJCScenario.updateDeliveryLeaderboard()
    end, 0)
end

local function onDeliveryPackageFail(playerID)
    local self = M.Players[playerID]
    self.deliveryPackageStreak = nil
    self.scenario = BJCScenario.PLAYER_SCENARII.FREEROAM
end

local function onBusMissionReward(playerID, idBusLine)
    local line = BJCScenario.BusLines[idBusLine]
    local ratio = line and math.round(line.distance / 1000, 1) or 1
    local reward = math.ceil(BJCConfig.Data.Reputation.BusMissionReward * ratio)
    M.Players[playerID].stats.bus = M.Players[playerID].stats.bus + 1
    M.reward(playerID, reward)
end

local function reward(playerID, amount)
    local self = M.Players[playerID]
    self.reputation = self.reputation + amount
    M.savePlayer(self)

    BJCTx.cache.invalidate(playerID, BJCCache.CACHES.USER)
end

local function explodeVehicle(senderID, gameVehID)
    local sender = M.Players[senderID]
    if not sender then
        error({ key = "rx.errors.invalidPlayerID", data = { playerID = senderID } })
    end
    local group = BJCGroups.Data[sender.group]
    if not group then
        error({ key = "rx.errors.invalidGroup", data = { group = sender.group } })
    end

    local veh
    if group.staff then
        for _, p in pairs(M.Players) do
            for _, v in pairs(p.vehicles) do
                if v.vid == gameVehID then
                    veh = v
                    break
                end
            end
        end
    else
        for _, v in pairs(sender.vehicles) do
            if v.vid == gameVehID then
                veh = v
                break
            end
        end
    end
    if not veh then
        error({ key = "rx.errors.invalidVehicle" })
    end
    BJCTx.player.explodeVehicle(gameVehID)
end

-- CONSOLE

local function findConnectedPlayers(playerName)
    local matches = {}
    for _, p in pairs(M.Players) do
        if p.playerName:lower():find(playerName:lower()) then
            table.insert(matches, p)
        end
    end
    return matches
end

local function consoleSetGroup(args)
    local playerName, groupName = args[1], args[2]
    if not playerName then
        return BJCLang.getConsoleMessage("command.errors.usage")
            :var({
                command = string.var(
                    "{1}setgroup {2}",
                    { BJCCommand.commandPrefix, BJCLang.getConsoleMessage("command.help.setgroupArgs") }
                )
            })
    end

    local matches = findConnectedPlayers(playerName)
    if #matches == 0 then
        local list = {}
        for _, p in pairs(M.Players) do
            table.insert(list, p.playerName)
        end
        return BJCLang.getConsoleMessage("command.errors.invalidPlayerWithList")
            :var({
                playerName = playerName,
                playerList = #list > 0 and
                    table.join(list, ", ") or
                    BJCLang.getConsoleMessage("common.empty")
            })
    elseif #matches > 1 then
        return BJCLang.getConsoleMessage("command.errors.playerAmbiguity")
            :var({ playerName = playerName, playerList = table.join(matches, ", ") })
    end
    local target = matches[1]

    if not groupName then
        groupName = BJCGroups.GROUPS.NONE
    elseif not BJCGroups.Data[groupName] then
        local list = {}
        for g in pairs(BJCGroups.Data) do
            table.insert(list, g)
        end
        table.sort(list, function(a, b) return a:lower() < b:lower() end)
        return BJCLang.getConsoleMessage("command.errors.invalidGroupWithList"):var({
            groupName = groupName,
            groupList = table.join(list, ", ")
        })
    end

    local ctxt = {}
    BJCInitContext(ctxt)

    local status, err = pcall(M.setGroup, ctxt, target.playerName, groupName)
    if not status then
        err = type(err) == "table" and err or {}
        return BJCLang.getServerMessage(BJCConfig.Data.Server.Lang, err.key or "rx.errors.serverError")
            :var(err.data or {})
    end

    return BJCLang.getConsoleMessage("command.groupAssigned")
        :var({ playerName = playerName, group = groupName })
end

local function consoleKick(args)
    local playerName = args[1]
    if not playerName then
        return BJCLang.getConsoleMessage("command.errors.usage")
            :var({
                command = string.var(
                    "{1}kick {2}",
                    { BJCCommand.commandPrefix, BJCLang.getConsoleMessage("command.help.kickArgs") }
                )
            })
    end

    ---@type any
    local reason = table.deepcopy(args)
    table.remove(reason, 1)
    reason = table.join(reason, " ")
    reason = #reason > 0 and reason or nil

    local matches = findConnectedPlayers(playerName)
    if #matches == 0 then
        local list = {}
        for _, p in pairs(M.Players) do
            table.insert(list, p.playerName)
        end
        return BJCLang.getConsoleMessage("command.errors.invalidPlayerWithList")
            :var({
                playerName = playerName,
                playerList = #list > 0 and
                    table.join(list, ", ") or
                    BJCLang.getConsoleMessage("common.empty")
            })
    elseif #matches > 1 then
        return BJCLang.getConsoleMessage("command.errors.playerAmbiguity")
            :var({ playerName = playerName, playerList = table.join(matches, ", ") })
    end

    local ctxt = {}
    BJCInitContext(ctxt)
    local status, err = pcall(M.kick, ctxt, matches[1].playerID, reason)
    if not status then
        err = type(err) == "table" and err or {}
        return BJCLang.getServerMessage(BJCConfig.Data.Server.Lang, err.key or "rx.errors.serverError")
            :var(err.data or {})
    end

    return BJCLang.getConsoleMessage("command.playerKicked"):var({ playerName = matches[1].playerName })
end

local function consoleBan(args)
    local playerName = args[1]
    if not playerName then
        return BJCLang.getConsoleMessage("command.errors.usage")
            :var({
                command = string.var(
                    "{1}kick {2}",
                    { BJCCommand.commandPrefix, BJCLang.getConsoleMessage("command.help.banArgs") }
                )
            })
    end

    ---@type any
    local reason = table.deepcopy(args)
    table.remove(reason, 1)
    reason = table.join(reason, " ")
    reason = #reason > 0 and reason or nil

    local matches = findConnectedPlayers(playerName)
    if #matches == 0 then
        local list = {}
        for _, p in pairs(M.Players) do
            table.insert(list, p.playerName)
        end
        return BJCLang.getConsoleMessage("command.errors.invalidPlayerWithList")
            :var({
                playerName = playerName,
                playerList = #list > 0 and
                    table.join(list, ", ") or
                    BJCLang.getConsoleMessage("common.empty")
            })
    elseif #matches > 1 then
        return BJCLang.getConsoleMessage("command.errors.playerAmbiguity")
            :var({ playerName = playerName, playerList = table.join(matches, ", ") })
    end

    local ctxt = {}
    BJCInitContext(ctxt)
    local status, err = pcall(M.ban, ctxt, matches[1].playerName, reason)
    if not status then
        err = type(err) == "table" and err or {}
        return BJCLang.getServerMessage(BJCConfig.Data.Server.Lang, err.key or "rx.errors.serverError")
            :var(err.data or {})
    end

    return BJCLang.getConsoleMessage("command.playerBanned"):var({ playerName = matches[1].playerName })
end

local function consoleTempBan(args)
    local playerName, duration = args[1], tonumber(args[2])
    if not playerName or not duration then
        return BJCLang.getConsoleMessage("command.errors.usage")
            :var({
                command = string.var(
                    "{1}kick {2}",
                    { BJCCommand.commandPrefix, BJCLang.getConsoleMessage("command.help.tempbanArgs") }
                )
            })
    end

    duration = math.round(duration)
    local config = BJCConfig.Data.TempBan
    duration = math.clamp(duration, config.minTime, config.maxTime)

    local reasonArr = {}
    for i = 3, #args do
        table.insert(reasonArr, args[i])
    end
    local reason
    reason = table.join(reasonArr, " ")
    reason = #reason > 0 and reason or nil

    local matches = findConnectedPlayers(playerName)
    if #matches == 0 then
        local list = {}
        for _, p in pairs(M.Players) do
            table.insert(list, p.playerName)
        end
        return BJCLang.getConsoleMessage("command.errors.invalidPlayerWithList")
            :var({
                playerName = playerName,
                playerList = #list > 0 and
                    table.join(list, ", ") or
                    BJCLang.getConsoleMessage("common.empty")
            })
    elseif #matches > 1 then
        return BJCLang.getConsoleMessage("command.errors.playerAmbiguity")
            :var({ playerName = playerName, playerList = table.join(matches, ", ") })
    end

    local ctxt = {}
    BJCInitContext(ctxt)

    PrintObj({ matches[1].playerName, reason, duration })
    local status, err = pcall(M.tempBan, ctxt, matches[1].playerName, reason, duration)
    if not status then
        err = type(err) == "table" and err or {}
        return BJCLang.getServerMessage(BJCConfig.Data.Server.Lang, err.key or "rx.errors.serverError")
            :var(err.data or {})
    end

    return BJCLang.getConsoleMessage("command.playerBanned"):var({ playerName = matches[1].playerName })
end

local function consoleUnban(args)
    local playerName = args[1]
    if not playerName then
        return BJCLang.getConsoleMessage("command.errors.usage")
            :var({
                command = string.var(
                    "{1}kick {2}",
                    { BJCCommand.commandPrefix, BJCLang.getConsoleMessage("command.help.unbanArgs") }
                )
            })
    end

    local target = BJCDao.players.findByPlayerName(playerName)
    if not target then
        return BJCLang.getConsoleMessage("command.errors.invalidPlayer"):var({ playerName = playerName })
    elseif not target.banned and not target.tempBanUntil then
        return BJCLang.getConsoleMessage("command.playerNotBanned"):var({ playerName = playerName })
    end

    local status, err = pcall(M.unban, playerName)
    if not status then
        err = type(err) == "table" and err or {}
        return BJCLang.getServerMessage(BJCConfig.Data.Server.Lang, err.key or "rx.errors.serverError")
            :var(err.data or {})
    end

    return BJCLang.getConsoleMessage("command.playerUnbanned"):var({ playerName = playerName })
end

local function consoleMute(args)
    local playerName = args[1]
    if not playerName then
        return BJCLang.getConsoleMessage("command.errors.usage")
            :var({
                command = string.var(
                    "{1}kick {2}",
                    { BJCCommand.commandPrefix, BJCLang.getConsoleMessage("command.help.muteArgs") }
                )
            })
    end

    ---@type any
    local reason = table.deepcopy(args)
    table.remove(reason, 1)
    reason = table.join(reason, " ")
    reason = #reason > 0 and reason or nil

    local matches = findConnectedPlayers(playerName)
    if #matches == 0 then
        local list = {}
        for _, p in pairs(M.Players) do
            table.insert(list, p.playerName)
        end
        return BJCLang.getConsoleMessage("command.errors.invalidPlayerWithList")
            :var({
                playerName = playerName,
                playerList = #list > 0 and
                    table.join(list, ", ") or
                    BJCLang.getConsoleMessage("common.empty")
            })
    elseif #matches > 1 then
        return BJCLang.getConsoleMessage("command.errors.playerAmbiguity")
            :var({ playerName = playerName, playerList = table.join(matches, ", ") })
    elseif matches[1].muted then
        return BJCLang.getConsoleMessage("command.playerAlreadyMuted")
            :var({ playerName = matches[1].playerName })
    end

    local ctxt = {}
    BJCInitContext(ctxt)
    local status, err = pcall(M.toggleMute, ctxt, matches[1].playerName, reason)
    if not status then
        err = type(err) == "table" and err or {}
        return BJCLang.getServerMessage(BJCConfig.Data.Server.Lang, err.key or "rx.errors.serverError")
            :var(err.data or {})
    end

    return BJCLang.getConsoleMessage("command.playerMuted"):var({ playerName = matches[1].playerName })
end

local function consoleUnmute(args)
    local playerName = args[1]
    if not playerName then
        return BJCLang.getConsoleMessage("command.errors.usage")
            :var({
                command = string.var(
                    "{1}kick {2}",
                    { BJCCommand.commandPrefix, BJCLang.getConsoleMessage("command.help.unmuteArgs") }
                )
            })
    end

    local matches = findConnectedPlayers(playerName)
    if #matches == 0 then
        local list = {}
        for _, p in pairs(M.Players) do
            table.insert(list, p.playerName)
        end
        return BJCLang.getConsoleMessage("command.errors.invalidPlayerWithList")
            :var({
                playerName = playerName,
                playerList = #list > 0 and
                    table.join(list, ", ") or
                    BJCLang.getConsoleMessage("common.empty")
            })
    elseif #matches > 1 then
        return BJCLang.getConsoleMessage("command.errors.playerAmbiguity")
            :var({ playerName = playerName, playerList = table.join(matches, ", ") })
    elseif not matches[1].muted then
        return BJCLang.getConsoleMessage("command.playerNotMuted")
            :var({ playerName = matches[1].playerName })
    end

    local ctxt = {}
    BJCInitContext(ctxt)
    local status, err = pcall(M.toggleMute, ctxt, matches[1].playerName)
    if not status then
        err = type(err) == "table" and err or {}
        return BJCLang.getServerMessage(BJCConfig.Data.Server.Lang, err.key or "rx.errors.serverError")
            :var(err.data or {})
    end

    return BJCLang.getConsoleMessage("command.playerUnmuted")
        :var({ playerName = matches[1].playerName })
end

M.savePlayer = savePlayer

M.onVehicleSwitched = onVehicleSwitched
M.getCount = getCount

M.getCacheUser = getCacheUser
M.getCacheUserHash = getCacheUserHash
M.getCachePlayers = getCachePlayers
M.getCachePlayersHash = getCachePlayersHash
M.getCacheDatabasePlayers = getCacheDatabasePlayers
M.getCacheDatabasePlayersHash = getCacheDatabasePlayersHash

M.setGroup = setGroup

M.drop = drop
M.dropMultiple = dropMultiple
M.kick = kick
M.tempBan = tempBan
M.ban = ban
M.unban = unban
M.whitelist = whitelist
M.toggleMute = toggleMute

M.toggleFreeze = toggleFreeze
M.toggleEngine = toggleEngine
M.teleportFrom = teleportFrom
M.deleteVehicle = deleteVehicle

M.changeLang = changeLang
M.updateAI = updateAI

M.setPlayerScenario = setPlayerScenario
M.onRaceSoloEnd = onRaceSoloEnd
M.onDeliveryVehicleSuccess = onDeliveryVehicleSuccess
M.onDeliveryPackageSuccess = onDeliveryPackageSuccess
M.onDeliveryPackageFail = onDeliveryPackageFail
M.onBusMissionReward = onBusMissionReward
M.reward = reward

M.explodeSelfVehicle = explodeVehicle

M.consoleSetGroup = consoleSetGroup
M.consoleKick = consoleKick
M.consoleBan = consoleBan
M.consoleTempBan = consoleTempBan
M.consoleUnban = consoleUnban
M.consoleMute = consoleMute
M.consoleUnmute = consoleUnmute

BJCEvents.addListener(BJCEvents.EVENTS.PLAYER_AUTH, onPlayerAuth)
BJCEvents.addListener(BJCEvents.EVENTS.PLAYER_CONNECTING, onPlayerConnecting)
BJCEvents.addListener(BJCEvents.EVENTS.PLAYER_JOINING, onPlayerJoining)
BJCEvents.addListener(BJCEvents.EVENTS.PLAYER_JOIN, onPlayerJoin)
M.onPlayerConnect = onPlayerConnect
BJCEvents.addListener(BJCEvents.EVENTS.PLAYER_DISCONNECT, onPlayerDisconnect)

return M
