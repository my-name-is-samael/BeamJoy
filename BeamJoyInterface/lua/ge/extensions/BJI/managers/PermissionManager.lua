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

local M = {
    _name = "BJIPerm",
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

    Groups = {},
    Permissions = {},
    Inputs = {
        newGroupName = "",
        newGroupLevel = 0,
    },
}

local function onLoad()
    BJICache.addRxHandler(BJICache.CACHES.PERMISSIONS, function(cacheData)
        local previous = table.clone(M.Permissions) or {}
        for k, v in pairs(cacheData) do
            M.Permissions[k] = v
        end

        -- events detection
        if not table.compare(previous, M.Permissions, true) then
            local changed = {}
            for k, v in pairs(M.Permissions) do
                if v ~= previous[k] then
                    table.insert(changed, {
                        permission = k,
                        previousLevel = previous[k] or -1,
                        currentLevel = v,
                    })
                end
            end

            BJIAsync.task(function()
                return M.Groups[BJIContext.User.group]
            end, function()
                local selfLevel = M.Groups[BJIContext.User.group].level
                local selfImpact = false
                for _, change in pairs(changed) do
                    if not selfImpact and (
                            (selfLevel >= change.previousLevel and selfLevel < change.currentLevel) or
                            (selfLevel < change.previousLevel and selfLevel >= change.currentLevel)
                        ) then
                        selfImpact = true
                    end
                end
                BJIEvents.trigger(BJIEvents.EVENTS.PERMISSION_CHANGED, {
                    self = selfImpact,
                    type = "permission_change",
                    changes = changed,
                })
            end, "BJIPermissionsCacheHandler")
        end
    end)

    BJICache.addRxHandler(BJICache.CACHES.GROUPS, function(cacheData)
        local previous = table.clone(M.Groups) or {}
        for groupName, group in pairs(cacheData) do
            M.Groups[groupName] = M.Groups[groupName] or {}
            -- bind values
            for k, v in pairs(group) do
                M.Groups[groupName][k] = v
            end
            -- remove obsolete keys
            for k in pairs(M.Groups[groupName]) do
                if not table.includes({ "_new" }, k) and
                    group[k] == nil then
                    M.Groups[groupName][k] = nil
                end
            end
            -- new permission input
            if not M.Groups[groupName]._new then
                M.Groups[groupName]._new = ""
            end
        end
        -- remove obsolete groups
        for k in pairs(M.Groups) do
            if cacheData[k] == nil then
                M.Groups[k] = nil
            end
        end

        -- events detection
        if not table.compare(previous, M.Groups, true) then
            local changedLevels = {}
            for groupName, group in pairs(M.Groups) do
                if previous[groupName] and group.level ~= previous[groupName].level then
                    changedLevels[groupName] = {
                        previousLevel = previous[groupName].level,
                        currentLevel = group.level,
                    }
                end
            end

            local changedPermissions = {}
            for groupName, group in pairs(M.Groups) do
                if previous[groupName] and not table.compare(group.permissions, previous[groupName].permissions, true) then
                    changedPermissions[groupName] = {}
                    for _, p in ipairs(group.permissions) do
                        if not table.includes(previous[groupName].permissions, p) then
                            table.insert(changedPermissions[groupName], {
                                permission = p,
                                added = true,
                            })
                        end
                    end
                    for _, p in ipairs(previous[groupName].permissions) do
                        if not table.includes(group.permissions, p) then
                            table.insert(changedPermissions[groupName], {
                                permission = p,
                                removed = true,
                            })
                        end
                    end
                end
            end

            local changedAttributes = {}
            for groupName, group in pairs(M.Groups) do
                local previousGroup = previous[groupName] or {}
                for k, v in pairs(group) do
                    if not table.includes({ "level", "permissions" }, k) and v ~= previousGroup[k] then
                        changedAttributes[groupName] = changedAttributes[groupName] or {}
                        changedAttributes[groupName][k] = {
                            previousValue = previousGroup[k],
                            currentValue = v,
                        }
                    end
                end
                for k, v in pairs(previousGroup) do
                    if not table.includes({ "level", "permissions" }, k) and
                        not changedAttributes[groupName][k] then
                        if group[k] == nil then
                            changedAttributes[groupName] = changedAttributes[groupName] or {}
                            changedAttributes[groupName][k] = {
                                previousValue = v,
                                currentValue = nil,
                            }
                        end
                    end
                end
            end

            if table.length(changedLevels) > 0 or
                table.length(changedPermissions) > 0 or
                table.length(changedAttributes) > 0 then
                BJIEvents.trigger(BJIEvents.EVENTS.PERMISSION_CHANGED, {
                    self = changedLevels[BJIContext.User.group] or
                        changedPermissions[BJIContext.User.group] or
                        changedAttributes[BJIContext.User.group],
                    type = "group_change",
                    changedLevels = changedLevels,
                    changedPermissions = changedPermissions,
                    changedAttributes = changedAttributes,
                })
            end

            local previousGroupsCount = table.length(previous)
            local currentGroupsCount = table.length(M.Groups)
            if previousGroupsCount ~= currentGroupsCount then
                if previousGroupsCount > currentGroupsCount then
                    table.find(previous, function(_, groupName)
                        return not M.Groups[groupName]
                    end, function(_, groupName)
                        BJIEvents.trigger(BJIEvents.EVENTS.PERMISSION_CHANGED, {
                            type = "group_remove",
                            group = groupName,
                        })
                    end)
                else
                    BJIEvents.trigger(BJIEvents.EVENTS.PERMISSION_CHANGED, {
                        type = "group_change",
                        added = true,
                    })
                end
            end
        end
    end)
end

local function hasMinimumGroup(targetGroupName, playerID)
    if not BJICache.areBaseCachesFirstLoaded() then
        return false
    end

    local targetGroup = M.Groups[targetGroupName]
    if not targetGroup then
        return false
    end

    local level
    if not playerID then
        -- self
        local selfGroup = M.Groups[BJIContext.User.group]
        if not selfGroup then
            return false
        end

        level = selfGroup.level
    else
        -- playerlist
        local player = BJIContext.Players[playerID]
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
    if not BJICache.areBaseCachesFirstLoaded() then
        return false
    end
    local permissionLevel = M.Permissions[permissionName]
    if not permissionLevel then
        return false
    end

    local group
    if playerID then
        local player = BJIContext.Players[playerID]
        if not player then
            return false
        end

        group = M.Groups[player.group]
    else
        group = M.Groups[BJIContext.User.group]
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
    if not BJICache.areBaseCachesFirstLoaded() then
        return false
    end

    -- has minimum group
    if M.hasMinimumGroup(targetGroupName, playerID or BJIContext.User.playerID) then
        return true
    end

    return M.hasPermission(permissionName, playerID)
end

local function canSpawnVehicle(playerID)
    if not BJICache.areBaseCachesFirstLoaded() then
        return false
    end

    local groupName = playerID and BJIContext.Players[playerID].group or BJIContext.User.group

    local group = M.Groups[groupName]
    if not group then
        return false
    end

    return group.canSpawn == true
end

local function isStaff(playerID)
    if not BJICache.areBaseCachesFirstLoaded() then
        return false
    end

    local groupName = playerID and BJIContext.Players[playerID].group or BJIContext.User.group

    local group = M.Groups[groupName]
    if not group then
        return false
    end

    return group.staff == true
end

local function getNextGroup(groupName)
    local currentGroup = M.Groups[groupName]
    if not currentGroup then
        return nil
    end

    local list = {}
    for name, group in pairs(M.Groups) do
        if type(group) == "table" and group.level > currentGroup.level then
            table.insert(list, {
                name = name,
                level = group.level
            })
        end
    end
    table.sort(list, function(a, b)
        return a.level < b.level
    end)
    if list[1] then
        return list[1].name
    end
    return nil
end

local function getPreviousGroup(groupName)
    local currentGroup = M.Groups[groupName]
    if not currentGroup then
        return nil
    end

    local list = {}
    for name, group in pairs(M.Groups) do
        if type(group) == "table" and group.level < currentGroup.level then
            table.insert(list, {
                name = name,
                level = group.level
            })
        end
    end
    table.sort(list, function(a, b)
        return b.level > a.level
    end)

    if list[1] then
        return list[1].name
    end
    return nil
end

local function getCountPlayersCanSpawnVehicle()
    local count = 0
    for _, player in pairs(BJIContext.Players) do
        if M.canSpawnVehicle(player.playerID) then
            count = count + 1
        end
    end
    return count
end

M.onLoad = onLoad

M.hasMinimumGroup = hasMinimumGroup
M.hasPermission = hasPermission
M.hasMinimumGroupOrPermission = hasMinimumGroupOrPermission
M.canSpawnVehicle = canSpawnVehicle
M.isStaff = isStaff
M.getNextGroup = getNextGroup
M.getPreviousGroup = getPreviousGroup
M.getCountPlayersCanSpawnVehicle = getCountPlayersCanSpawnVehicle

RegisterBJIManager(M)
return M
