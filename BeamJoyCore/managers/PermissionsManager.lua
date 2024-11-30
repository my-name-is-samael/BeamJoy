local M = {
    PERMISSIONS = {
        SEND_PRIVATE_MESSAGE = "SendPrivateMessage",

        VOTE_KICK = "VoteKick",
        VOTE_MAP = "VoteMap",
        TELEPORT_TO = "TeleportTo",
        START_PLAYER_SCENARIO = "StartPlayerScenario",
        VOTE_SERVER_SCENARIO = "VoteServerScenario",
        SPAWN_TRAILERS = "SpawnTrailers",

        BYPASS_MODEL_BLACKLIST = "BypassModelBlacklist",
        SPAWN_PROPS = "SpawnProps",
        TELEPORT_FROM = "TeleportFrom",
        DELETE_VEHICLE = "DeleteVehicle",
        KICK = "Kick",
        MUTE = "Mute",
        WHITELIST = "Whitelist",
        SET_GROUP = "SetGroup",
        TEMP_BAN = "TempBan",
        FREEZE_PLAYERS = "FreezePlayers",
        ENGINE_PLAYERS = "EnginePlayers",
        SET_CONFIG = "SetConfig",
        SET_ENVIRONMENT_PRESET = "SetEnvironmentPreset",
        START_SERVER_SCENARIO = "StartServerScenario",

        BAN = "Ban",
        DATABASE_PLAYERS = "DatabasePlayers",
        DATABASE_VEHICLES = "DatabaseVehicles",
        SET_ENVIRONMENT = "SetEnvironment",
        SET_REPUTATION = "SetReputation",
        SCENARIO = "Scenario",
        SWITCH_MAP = "SwitchMap",

        SET_PERMISSIONS = "SetPermissions",
        SET_CORE = "SetCore",
        SET_MAPS = "SetMaps",
        SET_CEN = "SetCEN",
    },

    Data = {},
}

local function init()
    M.Data = BJCDefaults.permissions()
    tdeepassign(M.Data, BJCDao.permissions.findAll())
end

local function hasPermission(playerID, permissionName)
    if type(permissionName) ~= "string" or #permissionName == 0 or
        not tincludes(M.PERMISSIONS, permissionName, true) then
        LogError(svar(BJCLang.getConsoleMessage("players.invalidPermission"), { playerID = playerID }))
        return false
    end

    local player = BJCPlayers.Players[playerID]
    if not player then
        LogError(svar(BJCLang.getConsoleMessage("players.invalidPlayer"), { playerID = playerID }))
        return false
    end

    local group = BJCGroups.Data[player.group]
    if not group then
        LogError(svar(BJCLang.getConsoleMessage("players.invalidGroup"), { group = player.group }))
        return false
    end

    if tincludes(group.permissions, permissionName, true) then
        -- group has specific permission
        return true
    end

    -- check group permission
    return group.level >= M.Data[permissionName]
end

local function hasMinimumGroup(playerID, minimumGroupName)
    local player = BJCPlayers.Players[playerID]
    if not player then
        LogError(svar(BJCLang.getConsoleMessage("players.invalidPlayer"), { playerID = playerID }))
        return false
    end

    local playerGroup = BJCGroups.Data[player.group]
    if not playerGroup then
        LogError(svar(BJCLang.getConsoleMessage("players.invalidGroup"), { group = player.group }))
        return false
    end

    local group = BJCGroups.Data[minimumGroupName]
    if not group then
        LogError(svar(BJCLang.getConsoleMessage("players.invalidGroup"), { group = minimumGroupName }))
        return false
    end

    return playerGroup.level >= group.level
end

local function hasMinimumGroupOrPermission(playerID, minimumGroupName, permissionName)
    return M.hasMinimumGroup(playerID, minimumGroupName) or M.hasPermission(playerID, permissionName)
end

local function canSpawnVehicle(playerID)
    local player = BJCPlayers.Players[playerID]
    if not player then
        LogError(svar(BJCLang.getConsoleMessage("players.invalidPlayer"), { playerID = playerID }))
        return false
    end
    local group = BJCGroups.Data[player.group]
    if not group then
        LogError(svar(BJCLang.getConsoleMessage("players.invalidGroup"), { group = player.group }))
        return false
    end
    return group.vehicleCap ~= 0
end

local function getPlayersByPermission(permission)
    local players = {}
    for playerID, player in pairs(BJCPlayers.Players) do
        if M.hasPermission(playerID, permission) then
            players[playerID] = player
        end
    end
    return players
end

local function isStaff(playerID)
    local player = BJCPlayers.Players[playerID]
    if not player then
        LogError(svar(BJCLang.getConsoleMessage("players.invalidPlayer"), { playerID = playerID }))
        return false
    end

    local group = BJCGroups.Data[player.group]
    if not group then
        LogError(svar(BJCLang.getConsoleMessage("players.invalidGroup"), { group = player.group }))
        return false
    end

    return group.staff == true
end

local function setPermission(permName, level)
    if type(permName) ~= "string" or #permName == 0 or
        not tincludes(M.PERMISSIONS, permName, true) then
        error({ key = "rx.errors.invalidData" })
    elseif BJCPerm.Data[permName] and (not tonumber(level) or tonumber(level) < 0) then
        error({ key = "rx.errors.invalidValue", data = { value = level } })
    end

    level = tonumber(level)

    if level ~= nil then
        local groupFound = false
        for _, group in pairs(BJCGroups.Data) do
            if group.level == level then
                groupFound = true
            end
        end
        if not groupFound then
            error({ key = "rx.errors.invalidValue", data = { value = level } })
        end
    end

    BJCPerm.Data[permName] = level
    BJCDao.permissions.save(M.Data)
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.PERMISSIONS)
end

local function getCache()
    return tdeepcopy(M.Data), M.getCacheHash()
end

local function getCacheHash()
    return Hash(M.Data)
end

M.hasPermission               = hasPermission
M.hasMinimumGroup             = hasMinimumGroup
M.hasMinimumGroupOrPermission = hasMinimumGroupOrPermission
M.canSpawnVehicle             = canSpawnVehicle
M.getPlayersByPermission      = getPlayersByPermission
M.isStaff                     = isStaff

M.setPermission               = setPermission

M.getCache                    = getCache
M.getCacheHash                = getCacheHash

init()

RegisterBJCManager(M)
return M
