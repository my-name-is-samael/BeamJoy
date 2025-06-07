local M = {
    Data = {}
}

local function init()
    M.Data = BJCDefaults.maps()
    table.assign(M.Data, BJCDao.maps.findAll())
end

--[[
CREATE %mapName%, %label%, %archive%
UPDATE %mapName%, %newLabel%, %newArchive% NULLABLE
DELETE %mapName%
]]
local function set(mapName, label, archive)
    local map = M.Data[mapName]
    if not map then
        -- creation
        if type(label) ~= "string" or #label == 0 or not type(archive) == "string" or #archive == 0 then
            error({ key = "rx.errors.invalidData" })
        end
        map = {
            label = label,
            archive = archive,
            custom = true,
            enabled = true,
        }

        M.Data[mapName] = map
        BJCDao.maps.saveMap(mapName, map)
    elseif not label then
        -- deletion
        if not map.custom then
            -- reset label on basemaps
            map.label = mapName
            BJCDao.maps.saveMap(mapName, map)
        else
            -- remove custom map
            M.Data[mapName] = nil
            BJCDao.maps.remove(mapName)
        end
    else
        if map.custom then
            if not archive then
                error({ key = "rx.errors.invalidData" })
            end
            map.archive = archive
        end
        map.label = label

        M.Data[mapName] = map
        BJCDao.maps.saveMap(mapName, map)
    end

    if mapName == BJCCore.getMap() then
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.MAP)
    end
    BJCTx.cache.invalidateByPermissions(BJCCache.CACHES.MAPS, BJCPerm.PERMISSIONS.SET_CORE)
end

local function setMapState(mapName, state)
    local map = M.Data[mapName]
    if not map or type(state) ~= "boolean" then
        error({ key = "rx.errors.invalidData" })
    end

    if map.enabled ~= state then
        map.enabled = state
        BJCDao.maps.saveMap(mapName, map)
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.MAPS)
    end
end

local function getCacheMap(senderID)
    local mapName = BJCCore.getMap()
    local map = M.Data[mapName]
    if map then
        return {
            name = mapName,
            label = map.label,
        }, M.getCacheMapHash()
    else
        return {
            label = BJCLang.getServerMessage(senderID, "rx.errors.invalidData")
        }, M.getCacheMapHash()
    end
end

local function getCacheMapHash()
    local mapName = BJCCore.getMap()
    return M.Data[mapName] and Hash(M.Data[mapName]) or tostring(GetCurrentTime())
end

local function getCacheMaps(senderID)
    local canVote = BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.VOTE_MAP)
    local canEdit = BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.SET_MAPS)
    local maps = {}
    for k, v in pairs(M.Data) do
        if canEdit or (canVote and v.enabled) then
            maps[k] = {
                label = v.label,
                custom = v.custom,
                enabled = v.enabled,
            }
            if canEdit then
                maps[k].archive = v.archive
            end
        end
    end
    return maps, M.getCacheMapsHash()
end

local function getCacheMapsHash()
    return Hash(M.Data)
end

M.set = set
M.setMapState = setMapState

M.getCacheMap = getCacheMap
M.getCacheMapHash = getCacheMapHash
M.getCacheMaps = getCacheMaps
M.getCacheMapsHash = getCacheMapsHash

init()
return M
