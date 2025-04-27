local M = {
    Data = {},
    GROUPS = {
        NONE = "none",
        PLAYER = "player",
        MOD = "mod",
        ADMIN = "admin",
        OWNER = "owner",
    }
}

local function init()
    M.Data = BJCDao.groups.findAll()
end

local function _isLevelAssignedToAnotherGroup(groupName, level)
    level = tonumber(level)
    for k, v in pairs(M.Data) do
        if k ~= groupName and v.level == level then
            return true
        end
    end
    return false
end

local function _reassignMembersAfterGroupDeletion(groupName, oldLevel)
    local newGroupName
    local noneLevel = M.Data[M.GROUPS.NONE].level
    local i = oldLevel - 1
    while not newGroupName and i >= noneLevel do
        for gName, g in pairs(M.Data) do
            if g.level == i then
                newGroupName = gName
            end
        end
        i = i - 1
    end
    if not newGroupName then
        newGroupName = M.GROUPS.NONE
    end
    local players = BJCDao.players.findAll()
    if table.length(players) > 0 then
        for _, player in ipairs(players) do
            if player.group == groupName then
                local connectedID
                for pID, p in pairs(BJCPlayers.Players) do
                    if p.playerName == player.playerName then
                        connectedID = pID
                        break
                    end
                end
                if connectedID then
                    BJCPlayers.setGroup({}, connectedID, newGroupName)
                else
                    player.group = newGroupName
                    BJCDao.players.save(player)
                end
            end
        end
    end
end

local function _reassignLevelAfterGroupChange(oldlevel, newLevel)
    if newLevel == nil then
        -- try find nearest up group
        local maxLevel = M.Data[M.GROUPS.OWNER].level
        for _, g in pairs(M.Data) do
            if g.level > maxLevel then
                maxLevel = g.level
            end
        end
        for i = oldlevel + 1, maxLevel do
            if not newLevel then
                for _, g in pairs(M.Data) do
                    if g.level == i then
                        newLevel = i
                        break
                    end
                end
            end
        end
    end
    if newLevel == nil then
        -- or try find nearest down group
        for i = oldlevel - 1, 0, -1 do
            if not newLevel then
                for _, g in pairs(M.Data) do
                    if g.level == i then
                        newLevel = i
                        break
                    end
                end
            end
        end
    end
    if newLevel == nil then
        LogError("Failed to reassign permissions after group deletion")
        return
    end

    -- assign permissions to new level
    local permChange = false
    for k, v in pairs(BJCPerm.Data) do
        if k == "custom" then
            for k2, v2 in pairs(BJCPerm.Data.custom) do
                if v2 == oldlevel then
                    BJCPerm.Data.custom[k2] = newLevel
                    permChange = true
                end
            end
        else
            if v == oldlevel then
                BJCPerm.Data[k] = newLevel
                permChange = true
            end
        end
    end
    if permChange then
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.PERMISSIONS)
    end
end

--[[
CREATE group = %newGroupName%, "level", %level% -- level must not be already assigned<br>
DELETE group = %groupName%, "level", nil -- nust not be a base group<br>
UPDATE group = %groupName%, "level", %newLevel% -- level must not be already assigned<br>
UPDATE group = %groupName%, "vehicleCap", %newCap% -- newCap must be >= 0<br>
UPDATE group = %groupName%, %key%, %value% -- key can be "banned", "muted", "whitelisted", "staff"
]]
local function setPermission(groupName, key, value)
    -- valid key
    if not table.includes({ "level", "vehicleCap", "banned", "muted", "whitelisted", "staff" }, key) then
        error({ key = "rx.errors.invalidData" })
    end

    -- check group existing
    local group
    for k, v in pairs(M.Data) do
        if k == groupName then
            group = v
            break
        end
    end
    if not group then
        -- group creation
        if key ~= "level" or tonumber(value) == nil or #groupName == 0 then
            -- try creating without level or invalid level or empty groupName
            error({ key = "rx.errors.invalidData" })
        end
        if value < 0 or _isLevelAssignedToAnotherGroup(groupName, value) then
            error({ key = "rx.errors.invalidValue", data = { value = value } })
        end
        M.Data[groupName] = {
            level = tonumber(value),
            vehicleCap = 0,
            banned = false,
            whitelisted = false,
            muted = false,
            staff = false,
            permissions = {},
        }
    else
        if key == "level" and tonumber(value) == nil then
            -- group deletion
            if table.includes(M.GROUPS, groupName) then
                -- trying to delete base group
                error({ key = "rx.errors.invalidValue", data = { value = value } })
            end
            local oldLevel = M.Data[groupName].level
            _reassignMembersAfterGroupDeletion(groupName, oldLevel)
            _reassignLevelAfterGroupChange(oldLevel)

            M.Data[groupName] = nil
        else
            -- group modification
            if key == "level" then
                value = tonumber(value)
                if value < 0 or _isLevelAssignedToAnotherGroup(groupName, value) then
                    error({ key = "rx.errors.invalidValue", data = { value = value } })
                end
                local oldLevel = M.Data[groupName].level
                M.Data[groupName].level = value
                _reassignLevelAfterGroupChange(oldLevel, value)
            elseif key == "vehicleCap" then
                -- setting vehicle cap
                if tonumber(value) == nil or tonumber(value) < -1 then
                    -- invalid vehicleCap
                    error({ key = "rx.errors.invalidValue", data = { value = value } })
                end
                M.Data[groupName].vehicleCap = tonumber(value)
            else
                -- setting key
                M.Data[groupName][key] = value
            end
        end
    end

    BJCDao.groups.save(M.Data)
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.GROUPS)
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.PLAYERS)
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.USER)
end

local function toggleGroupPermission(groupName, permissionName, state)
    -- check group existing
    local group
    for k, v in pairs(M.Data) do
        if k == groupName then
            group = v
            break
        end
    end
    if not group then
        error({ key = "rx.errors.invalidGroup", data = { group = groupName } })
    end

    -- check permission existing
    if not table.includes(BJCPerm.PERMISSIONS, permissionName) then
        error({ key = "rx.errors.invalidData" })
    end

    local function postUpdate()
        BJCDao.groups.save(M.Data)
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.GROUPS)
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.PLAYERS)
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.USER)
    end

    if state then
        if not table.includes(group.permissions, permissionName) then
            table.insert(group.permissions, permissionName)
            postUpdate()
        end
    else
        local pos = table.indexOf(group.permissions, permissionName)
        if pos then
            table.remove(group.permissions, pos)
            postUpdate()
        end
    end
end

local function getCache(senderID)
    local cache = {}
    local groups = table.deepcopy(M.Data)
    for name, g in pairs(groups) do
        cache[name] = {
            canSpawn = g.vehicleCap ~= 0,
            canSpawnAI = g.vehicleCap == -1,
        }
        table.assign(cache[name], g)
    end
    return cache, M.getCacheHash()
end

local function getCacheHash()
    return Hash(M.Data)
end

M.setPermission = setPermission
M.toggleGroupPermission = toggleGroupPermission

M.getCache = getCache
M.getCacheHash = getCacheHash

init()

RegisterBJCManager(M)
return M
