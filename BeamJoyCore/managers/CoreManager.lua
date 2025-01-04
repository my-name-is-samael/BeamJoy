local resourcesFolderPath = BJCPluginPath:gsub("Server/BeamJoyCore", "")

local M = {
    Data = {},
    _mapFullNamePrefix = "/levels/",
    _mapFullNameSuffix = "/info.json",
}

local function readServerConfig()
    local result = {}

    local file, error = io.open("ServerConfig.toml", "r")
    if file and not error then
        local text = file:read("*a")
        file:close()
        result = TOML.parse(text)
    end

    return result
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

    -- fix invalid MaxCars
    if M.Data.General.MaxCars < 0 then
        M.Data.General.MaxCars = 0
        writeServerConfig()
    end
end

local function consoleSetLang(args)
    local langs = BJCLang.getLangsList()
    table.sort(langs, function(a, b) return a:lower() < b:lower() end)

    if not args[1] then -- displays current
        return svar(BJCLang.getConsoleMessage("command.currentLang"),
            { langName = BJCConfig.Data.Server.Lang })
    end

    if not tincludes(langs, args[1]:lower()) then -- invalid lang
        return svar("{1}\n{2}", {
            svar(BJCLang.getConsoleMessage("command.errors.invalidValue"), { value = args[1] }),
            svar(BJCLang.getConsoleMessage("command.validLangs"), { langNames = tconcat(langs, ", ") })
        })
    end

    local ctxt = {}
    BJCInitContext(ctxt)
    BJCConfig.set(ctxt, "Server.Lang", args[1]:lower())
    return svar(BJCLang.getConsoleMessage("command.langChanged"), { langName = BJCConfig.Data.Server.Lang })
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

    if currentMap and targetMap and currentMap == targetMap then
        return
    end

    if currentMap and currentMap.custom then
        -- move map mod out of folder
        local targetPath = svar("{1}Client/{2}", { resourcesFolderPath, currentMap.archive })
        if FS.Exists(targetPath) then
            FS.Remove(targetPath)
        end
    end

    if targetMap and targetMap.custom then
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

        if currentMap and targetMap and
            (currentMap.custom or targetMap.custom) and
            targetMap.archive ~= currentMap.archive then
            -- if current or target is custom and not from the same mod, a reboot is mandatory
            Exit()
        else
            -- reload scenarii
            BJCScenario.reload()
        end
    end, 6, "BJCSwitchMap")
end

local function consoleSetMap(args)
    local maps = {}
    for mapName, map in pairs(BJCMaps.Data) do
        if map.enabled then
            table.insert(maps, mapName)
        end
    end
    table.sort(maps, function(a, b) return a:lower() < b:lower() end)

    if not args[1] or #args[1] == 0 then -- show current and list maps
        return svar("{1}\n{2}", {
            svar(BJCLang.getConsoleMessage("command.currentMap"), { mapName = getMap() }),
            svar(BJCLang.getConsoleMessage("command.validMaps"),
                { maps = tconcat(maps, ", ") })
        })
    end

    local matches = {}
    for _, name in ipairs(maps) do
        if name == args[1] then -- exact match
            matches = { name }
            break
        elseif name:lower():find(args[1]:lower()) then -- approximate match
            table.insert(matches, name)
        end
    end

    if #matches == 0 then -- no match
        return svar("{1}\n{2}", {
            svar(BJCLang.getConsoleMessage("command.errors.invalidMap"), { mapName = args[1] }),
            svar(BJCLang.getConsoleMessage("command.validMaps"),
                { maps = tconcat(maps, ", ") })
        })
    elseif #matches > 1 then -- multiple matches
        return svar(BJCLang.getConsoleMessage("command.errors.mapAmbiguity"),
            { mapName = args[1], mapList = tconcat(matches, ", ") })
    end

    -- switch map
    M.setMap(matches[1])
    return BJCLang.getConsoleMessage("command.mapSwitched")
end

local function set(key, value)
    local keys = { "Name", "Debug", "Private", "MaxCars", "MaxPlayers" }
    if type(M.Data.General[key]) == type(value) and tincludes(keys, key) then
        M.Data.General[key] = value
        MP.Set(MP.Settings[key], value)
        writeServerConfig()
        BJCTx.cache.invalidateByPermissions(BJCCache.CACHES.CORE, BJCPerm.PERMISSIONS.SET_CORE)
    elseif key == "Map" then
        setMap(value)
    elseif key == "Tags" then
        value = value:gsub("\n", ",")
        M.Data.General.Tags = value
        writeServerConfig()
        BJCTx.cache.invalidateByPermissions(BJCCache.CACHES.CORE, BJCPerm.PERMISSIONS.SET_CORE)
    elseif key == "Description" then
        value = value:gsub("\n", "^p")
        M.Data.General.Description = value
        writeServerConfig()
        BJCTx.cache.invalidateByPermissions(BJCCache.CACHES.CORE, BJCPerm.PERMISSIONS.SET_CORE)
    end
end

local function consoleSet(key, value)
    local keyParts = ssplit(key, ".")
    if #keyParts ~= 2 then
        error({ key = "rx.errors.invalidKey", data = { key = key } })
    end
    if not keyParts[1] or not keyParts[2] or not M.Data[keyParts[1]] or M.Data[keyParts[1]][keyParts[2]] == nil then
        error({ key = "rx.errors.invalidKey", data = { key = key } })
    end

    if keyParts[1] == "General" then
        -- AuthKey is not editable
        if keyParts[2] == "AuthKey" then
            error({ key = "rx.errors.forbidden" })
        end

        -- value types validation
        if tincludes({ "Port", "MaxPlayers", "MaxCars" }, keyParts[2], true) then
            value = tonumber(value)
            if not value then
                error({ key = "rx.errors.invalidValue", data = { value = value } })
            end
        elseif tincludes({ "Debug", "Private" }, keyParts[2], true) then
            if value == "true" then
                value = true
            elseif value == "false" then
                value = false
            else
                error({ key = "rx.errors.invalidValue", data = { value = value } })
            end
        end

        -- apply
        if keyParts[2] == "Map" then
            -- not an actual error but will be printed next instead of default message
            error({ key = M.consoleSetMap({ value }) })
        else
            M.set(keyParts[2], value)
        end
    elseif keyParts[2] then -- other than "General"
        M.data[keyParts[1]][keyParts[2]] = value
        writeServerConfig()
    end
end

local stopDelay = 10
local function stop()
    if tlength(BJCPlayers.Players) > 0 then
        -- countdown
        local messagesCache = {}
        for i = stopDelay, 1, -1 do
            BJCAsync.delayTask(function()
                if tlength(BJCPlayers.Players) == 0 then
                    for j = 1, stopDelay do BJCAsync.removeTask(svar("BJCStopMessage-{1}", { j })) end
                    Exit()
                else
                    for playerID, player in pairs(BJCPlayers.Players) do
                        if not messagesCache[player.lang] then
                            messagesCache[player.lang] = BJCLang.getServerMessage(player.lang,
                                "broadcast.serverStopsIn")
                        end
                        BJCChat.onServerChat(playerID,
                            svar(messagesCache[player.lang], { delay = PrettyDelay(i) }))
                    end
                end
                if i == 1 then
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
                    end, 1, "BJCStopServer")
                end
            end, stopDelay + 1 - i, svar("BJCStopMessage-{1}", { i }))
        end

        return svar(BJCLang.getConsoleMessage("command.stopIn"), { seconds = stopDelay })
    else
        Exit()
        return BJCLang.getConsoleMessage("command.stop")
    end
end

local function getCache()
    local fields = { "Name", "Tags", "Debug", "Private", "MaxCars", "MaxPlayers", "Description" }
    local cache = {}
    local config = tdeepcopy(M.Data.General)
    for _, v in ipairs(fields) do
        cache[v] = config[v]
        if v == "Tags" then
            cache[v] = cache[v]:gsub(",", "\n")
        elseif v == "Description" then
            cache[v] = cache[v]:gsub("%^p", "\n")
        end
    end
    return cache, M.getCacheHash()
end

local function getCacheHash()
    return Hash(M.Data)
end

M.consoleSetLang = consoleSetLang
M.getMap = getMap
M.setMap = setMap
M.consoleSetMap = consoleSetMap
M.set = set
M.consoleSet = consoleSet
M.stop = stop

M.getCache = getCache
M.getCacheHash = getCacheHash

init()

return M
