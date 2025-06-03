---@class BJCPlayerVehicle
---@field vehicleID integer
---@field vid integer
---@field pid integer
---@field name string
---@field freeze boolean
---@field engine boolean

---@class BJCAuthPlayer
---@field playerName string
---@field ip string
---@field beammp? string
---@field guest boolean
---@field ready boolean

---@class BJCPlayer: BJCAuthPlayer
---@field playerID integer
---@field group string
---@field lang string
---@field reputation integer
---@field stats {delivery: integer, race: integer, bus: integer}
---@field muted? boolean
---@field muteReason string
---@field banned? boolean
---@field tempBanUntil integer
---@field banReason string
---@field kickReason string
---@field hideNametag boolean
---@field currentVehicle? integer
---@field freeze boolean
---@field engine boolean
---@field vehicles BJCPlayerVehicle[]
---@field ai integer[]
---@field messages {time: integer, message: string}[]
---@field scenario string
---@field deliveryPackageStreak? integer

local logTag = "PlayerManager"
SetLogType(logTag, CONSOLE_COLORS.FOREGROUNDS.MAGENTA)

local dbPath = BJCPluginPath:gsub("BeamJoyCore", "BeamJoyData/db/players/")

local M = {
    ---@type table<integer, BJCPlayer> index playerIDs
    Players = {},     -- connected players
    ---@type table<string, BJCAuthPlayer> index playerNames
    AuthPlayers = {}, -- players between auth and connection
    MapCachePermissions = {
        [BJCCache.CACHES.USER] = "User",
        [BJCCache.CACHES.PLAYERS] = "Players",
        [BJCCache.CACHES.DATABASE_VEHICLES] = "DatabaseVehicles",
    },
    _lastDatabaseUpdate = GetCurrentTime(),
}

---@param player? BJCPlayer
---@return BJCPlayer
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

---@param player BJCPlayer
local function savePlayer(player)
    if not player.guest then
        BJCDao.players.save(sanitizeDBPlayer(player))
        M._lastDatabaseUpdate = GetCurrentTime()
    end
end

---@param playerName string
---@param guest boolean
---@param ip string
---@param beammp string
local function addAuthPlayer(playerName, guest, ip, beammp)
    M.AuthPlayers[playerName] = {
        playerName = playerName,
        guest = guest,
        ip = ip,
        beammp = beammp, -- nil if guest
        ready = false,
    }
end

---@param playerID integer
---@param playerName string
---@return boolean
local function bindAuthPlayer(playerID, playerName)
    local player = M.AuthPlayers[playerName]
    if not player then
        Log(BJCLang.getConsoleMessage("players.authPlayerNotFound")
            :var({ playerName = playerName }), logTag)
        return false
    else
        M.Players[playerID] = table.assign({}, {
            playerID = playerID,
            playerName = player.playerName,
            guest = player.guest,
            ip = player.ip,
            beammp = player.beammp, -- nil if guest
            ready = player.ready,
        })
        M.AuthPlayers[playerName] = nil
        return true
    end
end

---@param playerID integer
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
---@param playerID integer
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

---@param playerID integer
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

---@param playerID integer
local function onPlayerJoining(playerID)
end

---@param playerID integer
local function onPlayerJoin(playerID)
    if not M.Players[playerID] then
        MP.DropPlayer(playerID, BJCLang.getServerMessage(playerID, "players.joinError"))
        M.Players[playerID] = nil
    end
end

-- Triggered when player is connected and ready to play
---@param playerID integer
local function onPlayerConnect(playerID)
    if M.Players[playerID] then
        M.Players[playerID].ready = true
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.PLAYERS)

        BJCEvents.trigger(BJCEvents.EVENTS.PLAYER_CONNECTED, playerID)
    else
        MP.DropPlayer(playerID, BJCLang.getServerMessage(playerID, "players.joinError"))
        M.Players[playerID] = nil
    end
end

---@param playerID integer
local function onPlayerDisconnect(playerID)
    if M.Players[playerID] then
        local player = M.Players[playerID]
        M.Players[playerID] = nil

        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.PLAYERS)
        BJCEvents.trigger(BJCEvents.EVENTS.PLAYER_DISCONNECTED, player)
    end
end

---@param playerID integer
---@param gameVehID integer
local function onVehicleSwitched(playerID, gameVehID)
    local player = M.Players[playerID]
    player.currentVehicle = gameVehID
    BJCTx.cache.invalidate(playerID, BJCCache.CACHES.USER)
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.PLAYERS)
end

---@param level integer
---@param excludeStaff? boolean
---@return integer
local function getCount(level, excludeStaff)
    if not level then
        level = BJCGroups.Data[BJCGroups.GROUPS.NONE].level
    end

    local count = 0
    for _, player in pairs(M.Players) do
        if BJCPerm.hasPermission(player.playerID, level) and
            (not excludeStaff or not BJCGroups.Data[player.group].staff) then
            count = count + 1
        end
    end
    return count
end

-- CACHES

---@param playerID integer
---@return table, string
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
            reputation = player.reputation,
            freeze = player.freeze,
            engine = player.engine,
            currentVehicle = player.currentVehicle,
            vehicles = Table(player.vehicles)
                :map(function(vehicle, vehID)
                    return {
                        vehID = vehID,
                        gameVehID = vehicle.vid,
                        model = vehicle.name,
                        freeze = vehicle.freeze,
                        engine = vehicle.engine,
                    }
                end),
            stats = table.deepcopy(player.stats),
        }
        return data, M.getCacheUserHash(playerID)
    end
end

---@param playerID integer
---@return string
local function getCacheUserHash(playerID)
    return M.Players[playerID] and Hash(M.Players[playerID]) or tostring(GetCurrentTime())
end

---@param playerID integer
---@return table, string
local function getCachePlayers(playerID)
    return Table(M.Players)
        :filter(function(p) return p.ready end, true)
        :map(function(p, pid)
            local res = {
                playerID = pid,
                playerName = p.playerName,
                guest = p.guest,
                group = p.group,
                reputation = p.reputation,
                staff = BJCPerm.isStaff(pid),
                currentVehicle = p.currentVehicle,
                ai = table.deepcopy(p.ai),
                isGhost = table.includes({
                    BJCScenario.PLAYER_SCENARII.RACE_SOLO
                }, p.scenario),
                vehicles = Table(p.vehicles):map(function(v, vid)
                    return {
                        vehID = vid,
                        gameVehID = v.vid,
                        model = v.name,
                    }
                end),
            }
            return not BJCPerm.isStaff(playerID) and res or table.assign(res, {
                -- staff additional data
                freeze = p.freeze,
                engine = p.engine,
                muted = p.muted,
                muteReason = p.muteReason,
                kickReason = p.kickReason,
                banReason = p.banReason,
                vehicles = Table(p.vehicles):map(function(v, vid)
                    return {
                        vehID = vid,
                        gameVehID = v.vid,
                        model = v.name,
                        freeze = v.freeze,
                        engine = v.engine,
                    }
                end),
                messages = Table(p.messages):map(function(msg)
                    return {
                        time = msg.time,
                        message = msg.message,
                    }
                end)
            })
        end), M.getCachePlayersHash()
end

---@return string
local function getCachePlayersHash()
    return Hash(M.Players)
end

---@return table
local function getDatabasePlayers()
    return Table(FS.ListFiles(dbPath))
        :map(function(filename)
            local file, error = io.open(string.var("{1}/{2}", { dbPath, filename }), "r")
            return not error and file or nil
        end)
        :map(function(file)
            local player = JSON.parse(file:read("*a"))
            file:close()
            return player
        end)
        :map(function(player)
            if player.tempBanUntil and player.tempBanUntil <= GetCurrentTime() then
                player.tempBanUntil = nil
                M.savePlayer(player)
            end
            return {
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
        end):values()
        :sort(function(a, b)
            return a.playerName < b.playerName
        end) or Table()
end

-- PLAYER MODERATION

---@param playerID integer
---@param reason? string
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

---@param playerIDs integer[]
---@param reasonKey? string
local function dropMultiple(playerIDs, reasonKey)
    for _, playerID in ipairs(playerIDs) do
        local playerName = M.Players[playerID].playerName
        drop(playerID, reasonKey)
        M.Players[playerID] = nil
        BJCChat.onPlayerDisconnect(playerID, playerName)
    end
end

---@param ctxt BJCContext
---@param targetName string
---@param groupName string
local function setGroup(ctxt, targetName, groupName)
    local target, connected = nil, false
    if not Table(M.Players):find(function(player)
            return player.playerName == targetName
        end, function(player)
            target = player
            connected = true
        end) then
        target = BJCDao.players.findByPlayerName(targetName)
    end
    if not target then
        error({ key = "rx.errors.invalidPlayer", data = { playerName = targetName } })
    end

    local previousGroup = BJCGroups.Data[target.group]
    local groupToAssign = BJCGroups.Data[groupName]
    if not groupToAssign then
        error({ key = "rx.errors.invalidGroup", data = { group = groupName } })
    end

    if ctxt.origin == "player" then
        local senderGroup = BJCGroups.Data[ctxt.sender.group]
        if groupToAssign.level >= senderGroup.level or previousGroup.level >= senderGroup.level then
            error({ key = "rx.errors.insufficientPermissions" })
        end
    end

    if connected then
        if previousGroup.vehicleCap == -1 and groupToAssign.vehicleCap ~= -1 then
            -- remove AI vehicles
            Table(target.ai):forEach(function(vid)
                Log("remove ai veh " .. tostring(vid))
                M.deleteVehicle(ctxt, target.playerID, vid)
                Table(target.vehicles):find(function(v)
                    return v.gameVehID == vid
                end, function(_, k)
                    target.vehicles[k] = nil
                end)
            end)
            target.ai = {}
        end
        if previousGroup.vehicleCap ~= 0 and groupToAssign.vehicleCap == 0 then
            -- remove actual vehicles
            Table(target.vehicles):forEach(function(v)
                M.deleteVehicle(ctxt, target.playerID, v.vid)
            end)
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
    BJCTx.database.playersUpdated()
end

---@param playerID integer
---@param vehID? integer
local function toggleFreeze(playerID, vehID)
    local target = M.Players[playerID]
    if not target then
        error({ key = "rx.errors.invalidPlayerID", data = { playerID = playerID } })
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

    BJCTx.cache.invalidate(playerID, BJCCache.CACHES.USER)
    BJCTx.cache.invalidateByPermissions(BJCCache.CACHES.PLAYERS, BJCPerm.PERMISSIONS.FREEZE_PLAYERS)
end

---@param playerID integer
---@param vehID? integer
local function toggleEngine(playerID, vehID)
    local target = M.Players[playerID]
    if not target then
        error({ key = "rx.errors.invalidPlayerID", data = { playerID = playerID } })
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

    BJCTx.cache.invalidate(playerID, BJCCache.CACHES.USER)
    BJCTx.cache.invalidateByPermissions(BJCCache.CACHES.PLAYERS, BJCPerm.PERMISSIONS.ENGINE_PLAYERS)
end

---@param playerID integer
---@param targetID integer
local function teleportFrom(playerID, targetID)
    local target = M.Players[targetID]
    if not target then
        error({ key = "rx.errors.invalidPlayerID", data = { playerID = targetID } })
    end

    BJCTx.player.teleportToPlayer(target.playerID, playerID)
end

---@param ctxt BJCContext
---@param playerName string
local function whitelist(ctxt, playerName)
    for _, player in pairs(BJCPlayers.Players) do
        if player.playerName == playerName and player.guest then
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
    BJCTx.database.playersUpdated()
end

---@param ctxt BJCContext
---@param targetName string
---@param reason? string
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
    if target.muted then
        target.muteReason = reason
    end
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
    BJCTx.database.playersUpdated()
end

---@param ctxt BJCContext
---@param playerID integer
---@param gameVehID integer
local function deleteVehicle(ctxt, playerID, gameVehID)
    local target = M.Players[playerID]
    if not target then
        error({ key = "rx.errors.invalidPlayerID", data = { playerID = playerID } })
    end

    if ctxt.origin == "player" then
        local self = M.Players[ctxt.senderID]
        local selfGroup = BJCGroups.Data[self.group]
        local targetGroup = BJCGroups.Data[target.group]
        if selfGroup.level <= targetGroup.level and ctxt.senderID ~= playerID then
            error({ key = "rx.errors.insufficientPermissions" })
        end
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
        Table(target.vehicles):find(function(v) return v.vid == gameVehID end, function(_, id)
            vehID = id
        end)
        local vehicle = vehID and target.vehicles[vehID] or nil
        if not gameVehID or not vehicle then
            -- invalid veh, continue without error
            return
        end

        if ctxt.origin ~= "player" or ctxt.senderID ~= playerID then
            local prefix = BJCLang.getServerMessage(playerID, "rx.vehicleRemoveMain")
            if multipleVehicles and not current then
                prefix = BJCLang.getServerMessage(playerID, "rx.vehicleRemoveOneOf")
            end
            BJCTx.player.toast(playerID, BJC_TOAST_TYPES.WARNING, "rx.vehicleRemoveSuffix",
                { typeVehicleRemove = prefix }, 7)
        end

        if current then
            target.currentVehicle = nil
        end
        MP.RemoveVehicle(playerID, vehID)
        target.vehicles[vehID] = nil
        BJCEvents.trigger(BJCEvents.EVENTS.MP_VEHICLE_DELETED, playerID, vehID)
    else
        --remove all player vehicles
        target.currentVehicle = nil
        for vehID in pairs(target.vehicles) do
            MP.RemoveVehicle(playerID, vehID)
            target.vehicles[vehID] = nil
            BJCEvents.trigger(BJCEvents.EVENTS.MP_VEHICLE_DELETED, playerID, vehID)
        end

        if ctxt.origin ~= "player" or ctxt.senderID ~= playerID then
            BJCTx.player.toast(playerID, BJC_TOAST_TYPES.WARNING, "rx.vehicleRemoveAll",
                nil, 7)
        end
    end

    BJCTx.cache.invalidate(playerID, BJCCache.CACHES.USER)
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.PLAYERS)
end

---@param playerID integer
---@param listVehIDs integer[]
local function markInvalidVehs(playerID, listVehIDs)
    local player = M.Players[playerID]
    if not player then
        error({ key = "rx.errors.invalidPlayerID", data = { playerID = playerID } })
    elseif not BJCPerm.canSpawnVehicle(playerID) then
        error({ key = "rx.errors.insufficientPermissions" })
    end

    Table(listVehIDs):forEach(function(vid)
        Table(player.vehicles):find(function(v)
            return v.vid == vid
        end, function(_, vehID)
            player.vehicles[vehID] = nil
        end)
        local pos = table.indexOf(player.ai, vid)
        if pos then
            table.remove(player.ai, pos)
        end
    end)

    BJCTx.cache.invalidate(playerID, BJCCache.CACHES.USER)
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.PLAYERS)
end

---@param ctxt BJCContext
---@param playerID integer
---@param reason? string
local function kick(ctxt, playerID, reason)
    local target = M.Players[playerID]
    if not target then
        error({ key = "rx.errors.invalidPlayerID", data = { playerID = playerID } })
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

    M.drop(playerID, reason)
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.PLAYERS)
end

---@param ctxt BJCContext
---@param targetName string
---@param reason? string
---@param duration integer
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
    BJCTx.database.playersUpdated()
end

---@param ctxt BJCContext
---@param targetName string
---@param reason? string
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
    BJCTx.database.playersUpdated()
end

---@param targetName string
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
    BJCTx.database.playersUpdated()
end

---@param playerID integer
---@param lang string
local function changeLang(playerID, lang)
    local target = BJCPlayers.Players[playerID]
    if lang == target.lang then
        return
    end

    if not BJCLang.Langs[lang] then
        error({ key = "rx.errors.invalidLang", data = { lang = lang } })
    end

    target.lang = lang
    M.savePlayer(target)

    BJCTx.cache.invalidate(playerID, BJCCache.CACHES.USER)
    BJCTx.cache.invalidate(playerID, BJCCache.CACHES.LANG)
    BJCTx.database.playersUpdated()
end

---@param playerID integer
---@param listVehIDs? integer[]
local function updateAI(playerID, listVehIDs)
    local player = M.Players[playerID]
    if not player then
        error({ key = "rx.errors.invalidPlayerID", data = { playerID = playerID } })
    end

    local previous = table.clone(player.ai)
    player.ai = listVehIDs or {}
    table.sort(player.ai)
    if not table.compare(previous, player.ai) then
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.PLAYERS)
    end
end

---@param playerID integer
---@param scenario string
local function setPlayerScenario(playerID, scenario)
    local self = M.Players[playerID]
    self.scenario = scenario
end

---@param playerID integer
---@param finished boolean
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

---@param playerID integer
---@param pristine boolean
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
        BJCScenarioData.updateDeliveryLeaderboard()
    end, 0)
end

---@param playerID integer
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
        BJCScenarioData.updateDeliveryLeaderboard()
    end, 0)
end

---@param playerID integer
local function onDeliveryPackageFail(playerID)
    local self = M.Players[playerID]
    self.deliveryPackageStreak = nil
    self.scenario = BJCScenario.PLAYER_SCENARII.FREEROAM
end

---@param playerID integer
---@param idBusLine integer
local function onBusMissionReward(playerID, idBusLine)
    local line = BJCScenarioData.BusLines[idBusLine]
    local ratio = line and math.round(line.distance / 1000, 1) or 1
    local reward = math.ceil(BJCConfig.Data.Reputation.BusMissionReward * ratio)
    M.Players[playerID].stats.bus = M.Players[playerID].stats.bus + 1
    M.reward(playerID, reward)
end

---@param playerID integer
---@param amount integer
local function reward(playerID, amount)
    local self = M.Players[playerID]
    self.reputation = self.reputation + amount
    M.savePlayer(self)

    BJCTx.cache.invalidate(playerID, BJCCache.CACHES.USER)
end

---@param playerID integer
---@param gameVehID integer
local function explodeVehicle(playerID, gameVehID)
    local sender = M.Players[playerID]
    if not sender then
        error({ key = "rx.errors.invalidPlayerID", data = { playerID = playerID } })
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

---@param playerName string
---@return tablelib<integer, BJCPlayer>
local function findConnectedPlayers(playerName)
    local matches = Table()
    for _, p in pairs(M.Players) do
        if p.playerName == playerName then
            return Table({ p }) -- exact match
        end
        if p.playerName:lower():find(playerName:lower()) then
            matches:insert(p)
        end
    end
    return matches
end

---@param args string[]
---@return string
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
            :var({
                playerName = playerName,
                playerList = matches:map(function(p) return p.playerName end):join(", ")
            })
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

---@param args string[]
---@return string
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

---@param args string[]
---@return string
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

---@param args string[]
---@return string
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

---@param args string[]
---@return string
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

---@param args string[]
---@return string
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

---@param args string[]
---@return string
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
M.getDatabasePlayers = getDatabasePlayers

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
M.markInvalidVehs = markInvalidVehs

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

BJCEvents.addListener(BJCEvents.EVENTS.MP_PLAYER_AUTH, onPlayerAuth)
BJCEvents.addListener(BJCEvents.EVENTS.MP_PLAYER_CONNECTING, onPlayerConnecting)
BJCEvents.addListener(BJCEvents.EVENTS.MP_PLAYER_JOINING, onPlayerJoining)
BJCEvents.addListener(BJCEvents.EVENTS.MP_PLAYER_JOIN, onPlayerJoin)
M.onPlayerConnect = onPlayerConnect
BJCEvents.addListener(BJCEvents.EVENTS.MP_PLAYER_DISCONNECT, onPlayerDisconnect)

return M
