---@class BJIGroup
---@field level integer
---@field permissions string[]
---@field staff boolean
---@field vehicleCap integer
---@field whitelisted boolean
---@field muted boolean
---@field banned boolean
---@field canSpawn boolean
---@field canSpawnAI boolean

---@class BJIManagerPerm : BJIManager
local M = {
    _name = "Perm",

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

    ---@type table<string, BJIGroup>
    Groups = {},
    Permissions = {},
}

local function onLoad()
    BJI.Managers.Cache.addRxHandler(BJI.Managers.Cache.CACHES.PERMISSIONS, function(cacheData)
        for k, v in pairs(cacheData) do
            M.Permissions[k] = v
        end

        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PERMISSION_CHANGED)
    end)

    BJI.Managers.Cache.addRxHandler(BJI.Managers.Cache.CACHES.GROUPS, function(cacheData)
        for groupName, group in pairs(cacheData) do
            M.Groups[groupName] = M.Groups[groupName] or {}
            -- bind values
            for k, v in pairs(group) do
                M.Groups[groupName][k] = v
            end
            -- remove obsolete keys
            for k in pairs(M.Groups[groupName]) do
                if not group[k] then
                    M.Groups[groupName][k] = nil
                end
            end
        end
        -- remove obsolete groups
        for k in pairs(M.Groups) do
            if cacheData[k] == nil then
                M.Groups[k] = nil
            end
        end

        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PERMISSION_CHANGED)
    end)
end

local function hasMinimumGroup(targetGroupName, playerID)
    if not BJI.Managers.Cache.areBaseCachesFirstLoaded() or
        (playerID and not BJI.Managers.Context.Players[playerID]) then
        return false
    end

    local targetGroup = M.Groups[targetGroupName]
    if not targetGroup then
        return false
    end

    local level
    if not playerID then
        -- self
        local selfGroup = M.Groups[BJI.Managers.Context.User.group]
        if not selfGroup then
            return false
        end

        level = selfGroup.level
    else
        -- playerlist
        local player = BJI.Managers.Context.Players[playerID]
        if not player then
            return false
        end

        local playerGroup = M.Groups[player.group]
        if not playerGroup then
            return false
        end

        level = playerGroup.level
    end

    return level >= targetGroup.level
end

local function hasPermission(permissionName, playerID)
    if not BJI.Managers.Cache.areBaseCachesFirstLoaded() or
        (playerID and not BJI.Managers.Context.Players[playerID]) then
        return false
    end
    local permissionLevel = M.Permissions[permissionName]
    if not permissionLevel then
        return false
    end

    local group
    if playerID then
        local player = BJI.Managers.Context.Players[playerID]
        if not player then
            return false
        end

        group = M.Groups[player.group]
    else
        group = M.Groups[BJI.Managers.Context.User.group]
    end
    if not group then
        return false
    end

    if table.includes(group.permissions, permissionName) then
        -- has specific permission
        return true
    end

    -- hash group level permission
    return group.level >= permissionLevel
end

local function hasMinimumGroupOrPermission(targetGroupName, permissionName, playerID)
    if not BJI.Managers.Cache.areBaseCachesFirstLoaded() or
        (playerID and not BJI.Managers.Context.Players[playerID]) then
        return false
    end

    -- has minimum group
    if M.hasMinimumGroup(targetGroupName, playerID or BJI.Managers.Context.User.playerID) then
        return true
    end

    return M.hasPermission(permissionName, playerID)
end

local function canSpawnVehicle(playerID)
    if not BJI.Managers.Cache.areBaseCachesFirstLoaded() or
        (playerID and not BJI.Managers.Context.Players[playerID]) then
        return false
    end

    local groupName = playerID and BJI.Managers.Context.Players[playerID].group or BJI.Managers.Context.User.group

    local group = M.Groups[groupName]
    if not group then
        return false
    end

    return group.canSpawn == true
end

local function canSpawnAI(playerID)
    if not BJI.Managers.Cache.areBaseCachesFirstLoaded() or
        (playerID and not BJI.Managers.Context.Players[playerID]) then
        return false
    end

    if BJI.Managers.Context.Players:length() == 1 then
        return M.canSpawnVehicle(playerID)
    end

    local groupName = playerID and BJI.Managers.Context.Players[playerID].group or BJI.Managers.Context.User.group

    local group = M.Groups[groupName]
    if not group then
        return false
    end

    return group.canSpawnAI == true
end

local function isStaff(playerID)
    if not BJI.Managers.Cache.areBaseCachesFirstLoaded() or
        (playerID and not BJI.Managers.Context.Players[playerID]) then
        return false
    end

    local groupName = playerID and BJI.Managers.Context.Players[playerID].group or BJI.Managers.Context.User.group

    local group = M.Groups[groupName]
    if not group then
        return false
    end

    return group.staff == true
end

---@param groupName string
---@return string?
local function getNextGroup(groupName)
    local baseG = M.Groups[groupName]
    if not baseG then
        return nil
    end

    local next = Table(M.Groups)
        ---@param k string
        :reduce(function(acc, g, k)
            return (g.level > baseG.level and
                    (not acc or acc.level > g.level)) and
                { name = k, level = g.level } or acc
        end)
    return next and next.name or nil
end

---@param groupName string
---@return string?
local function getPreviousGroup(groupName)
    local baseG = M.Groups[groupName]
    if not baseG then
        return nil
    end

    local previous = Table(M.Groups)
        ---@param k string
        :reduce(function(acc, g, k)
            return (g.level < baseG.level and
                    (not acc or acc.level < g.level)) and
                { name = k, level = g.level } or acc
        end)
    return previous and previous.name or nil
end

local function getCountPlayersCanSpawnVehicle()
    return BJI.Managers.Context.Players
        :filter(function(p) return M.canSpawnVehicle(p.playerID) end)
        :length()
end

M.hasMinimumGroup = hasMinimumGroup
M.hasPermission = hasPermission
M.hasMinimumGroupOrPermission = hasMinimumGroupOrPermission
M.canSpawnVehicle = canSpawnVehicle
M.canSpawnAI = canSpawnAI
M.isStaff = isStaff
M.getNextGroup = getNextGroup
M.getPreviousGroup = getPreviousGroup
M.getCountPlayersCanSpawnVehicle = getCountPlayersCanSpawnVehicle

M.onLoad = onLoad

return M
