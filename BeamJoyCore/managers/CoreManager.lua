local resourcesFolderPath = BJCPluginPath:gsub("Server/BeamJoyCore", "")

local M = {
    Data = {},
    _mapFullNamePrefix = "/levels/",
    _mapFullNameSuffix = "/info.json",
}

local function removeSpecialChars(str)
    local s = str:find("%^")
    while s ~= nil do
        str = svar("{1}{2}", { str:sub(1, s - 1), str:sub(s + 2) })
        s = str:find("%^")
    end
    return str
end

local function readServerConfig()
    local result = {}

    local file, error = io.open("ServerConfig.toml", "r")
    if file and not error then
        local text = file:read("*a")
        file:close()
        result = TOML.parse(text)
    end

    if result.General and result.General.Name then
        result.General.Name = removeSpecialChars(result.General.Name)
    end
    if result.General and result.General.Description then
        result.General.Description = removeSpecialChars(result.General.Description)
    end

    return result
end

local function init()
    local core = readServerConfig()
    M.Data = {
        General = {
            Name = core.General.Name,
            Port = tonumber(core.General.Port),
            AuthKey = core.General.AuthKey,
            Tags = core.General.Tags,
            Debug = core.General.Debug == true,
            Private = core.General.Private == true,
            MaxCars = core.General.MaxCars,
            MaxPlayers = core.General.MaxPlayers,
            Map = core.General.Map,
            Description = core.General.Description,
            ResourceFolder = core.General.ResourceFolder,
        },
        Misc = {
            ImScaredOfUpdates = core.Misc.ImScaredOfUpdates == true,
            SendErrorsShowMessage = core.Misc.SendErrorsShowMessage == true,
            SendErrors = core.Misc.SendErrors == true
        }
    }
end

local function writeServerConfig()
    local tmpfile, error = io.open("ServerConfig.temp", "w")
    if tmpfile and not error then
        local data = TOML.encode(M.Data) -- TOML encoding is altering data
        tmpfile:write(data)
        tmpfile:close()

        FS.Remove("ServerConfig.toml")
        FS.Rename("ServerConfig.temp", "ServerConfig.toml")
    end
end

local function getMap()
    return M.Data.General.Map:gsub(M._mapFullNamePrefix, ""):gsub(M._mapFullNameSuffix, "")
end

local function setMap(mapName)
    local currentMap = BJCMaps.Data[getMap()]
    local targetMap = BJCMaps.Data[mapName]

    if not targetMap or (targetMap.custom and not targetMap.archive) then
        error({ key = "rx.errors.invalidData" })
    end

    if currentMap == targetMap then
        return
    end

    if currentMap.custom then
        -- move map mod out of folder
        local targetPath = svar("{1}Client/{2}", { resourcesFolderPath, currentMap.archive })
        if FS.Exists(targetPath) then
            FS.Remove(targetPath)
        end
    end

    if targetMap.custom then
        -- move map mod into folder
        local sourcePath = svar("{1}{2}", { resourcesFolderPath, targetMap.archive })
        if FS.Exists(sourcePath) then
            local targetPath = svar("{1}Client/{2}", { resourcesFolderPath, targetMap.archive })
            FS.Copy(sourcePath, targetPath)
        else
            error({ key = "mapSwitch.missingArchive" })
        end
    end

    -- save map
    local newFullName = svar("{1}{2}{3}", { M._mapFullNamePrefix, mapName, M._mapFullNameSuffix })
    M.Data.General.Map = newFullName
    MP.Set(MP.Settings.Map, newFullName)
    writeServerConfig()

    -- countdown
    local messagesCache = {}
    for i = 5, 1, -1 do
        BJCAsync.delayTask(function()
            for playerID, player in pairs(BJCPlayers.Players) do
                if not messagesCache[player.lang] then
                    messagesCache[player.lang] = BJCLang.getServerMessage(player.lang, "mapSwitch.kickIn")
                end
                BJCChat.onServerChat(playerID,
                    svar(messagesCache[player.lang], { delay = PrettyDelay(i) }))
            end
        end, 6 - i, svar("BJCSwitchMapMessage-{1}", { i }))
    end

    BJCAsync.delayTask(function()
        -- kick all players
        local playerIDs = {}
        for playerID in pairs(BJCPlayers.Players) do
            table.insert(playerIDs, playerID)
        end
        if #playerIDs > 0 then
            BJCPlayers.dropMultiple(playerIDs, "mapSwitch.kick")
        end

        if (currentMap.custom or targetMap.custom) and targetMap.archive ~= currentMap.archive then
            -- if current or target is custom and not from the same mod, a reboot is mandatory
            Exit()
        else
            -- reload scenarii
            BJCScenario.reload()
        end
    end, 6, "BJCSwitchMap")
end

local function set(key, value)
    local keys = { "Name", "Debug", "Private", "MaxCars", "MaxPlayers", "Map", "Description" }
    if type(M.Data.General[key]) == type(value) and tincludes(keys, key) then
        if key == "Map" then
            setMap(value)
        else
            if key == "Description" then
                value = value:gsub("\n", " ")
            end
            M.Data.General[key] = value
            MP.Set(MP.Settings[key], value)
            writeServerConfig()
            BJCTx.cache.invalidateByPermissions(BJCCache.CACHES.CORE, BJCPerm.PERMISSIONS.SET_CORE)
        end
    elseif key == "Tags" then
        value = value:gsub("\n", ",")
        M.Data.General.Tags = value
        writeServerConfig()
        BJCTx.cache.invalidateByPermissions(BJCCache.CACHES.CORE, BJCPerm.PERMISSIONS.SET_CORE)
    end
end

local function stop()
    -- countdown
    local messagesCache = {}
    for i = 10, 1, -1 do
        BJCAsync.delayTask(function()
            for playerID, player in pairs(BJCPlayers.Players) do
                if not messagesCache[player.lang] then
                    messagesCache[player.lang] = BJCLang.getServerMessage(player.lang,
                        "broadcast.serverStopsIn")
                end
                BJCChat.onServerChat(playerID,
                    svar(messagesCache[player.lang], { delay = PrettyDelay(i) }))
            end
        end, 11 - i, svar("BJCStopMessage-{1}", { i }))
    end

    BJCAsync.delayTask(function()
        -- kick all players
        local playerIDs = {}
        for playerID in pairs(BJCPlayers.Players) do
            table.insert(playerIDs, playerID)
        end
        if #playerIDs > 0 then
            BJCPlayers.dropMultiple(playerIDs, "broadcast.serverStopped")
        end

        Exit()
    end, 11, "BJCStopServer")
end

local function getCache()
    local fields = { "Name", "Tags", "Debug", "Private", "MaxCars", "MaxPlayers", "Description" }
    local cache = {}
    local config = tdeepcopy(M.Data.General)
    for _, v in ipairs(fields) do
        cache[v] = config[v]
        if v == "Tags" then
            cache[v] = cache[v]:gsub(",", "\n")
        end
    end
    return cache, M.getCacheHash()
end

local function getCacheHash()
    return Hash(M.Data)
end

M.getMap = getMap
M.setMap = setMap
M.set = set
M.stop = stop

M.getCache = getCache
M.getCacheHash = getCacheHash

init()

return M
