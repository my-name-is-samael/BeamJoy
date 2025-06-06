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
        return BJCLang.getConsoleMessage("command.currentLang"):var({ langName = BJCConfig.Data.Server.Lang })
    end

    if not table.includes(langs, args[1]:lower()) then -- invalid lang
        return string.var("{1}\n{2}", {
            BJCLang.getConsoleMessage("command.errors.invalidValue"):var({ value = args[1] }),
            BJCLang.getConsoleMessage("command.validLangs"):var({ langNames = table.join(langs, ", ") })
        })
    end

    local ctxt = {}
    BJCInitContext(ctxt)
    BJCConfig.set(ctxt, "Server.Lang", args[1]:lower())
    return BJCLang.getConsoleMessage("command.langChanged"):var({ langName = BJCConfig.Data.Server.Lang })
end

local function getMap()
    local mapName = M.Data.General.Map:gsub(M._mapFullNamePrefix, ""):gsub(M._mapFullNameSuffix, "")
    return mapName
end

---@param mapName string
---@return boolean
local function setMap(mapName)
    local currentMap = BJCMaps.Data[getMap()]
    local targetMap = BJCMaps.Data[mapName]

    if not targetMap or (targetMap.custom and not targetMap.archive) then
        error({ key = "rx.errors.invalidData" })
    end

    if currentMap and targetMap and currentMap == targetMap then
        return false
    end

    if currentMap and currentMap.custom then
        -- move map mod out of folder
        local targetPath = string.var("{1}Client/{2}", { resourcesFolderPath, currentMap.archive })
        if FS.Exists(targetPath) then
            FS.Remove(targetPath)
        end
    end

    if targetMap and targetMap.custom then
        -- move map mod into folder
        local sourcePath = string.var("{1}{2}", { resourcesFolderPath, targetMap.archive })
        if FS.Exists(sourcePath) then
            local targetPath = string.var("{1}Client/{2}", { resourcesFolderPath, targetMap.archive })
            FS.Copy(sourcePath, targetPath)
        else
            error({ key = "mapSwitch.missingArchive" })
        end
    end

    -- save map
    local newFullName = string.var("{1}{2}{3}", { M._mapFullNamePrefix, mapName, M._mapFullNameSuffix })

    local messagesCache = {}
    CountdownKickAll(6, function(player, delaySec)
        if not messagesCache[player.lang] then
            messagesCache[player.lang] = BJCLang.getServerMessage(player.lang, "mapSwitch.kickIn")
        end
        return messagesCache[player.lang]:var({ delay = PrettyDelay(delaySec) })
    end, "mapSwitch.kick", function()
        M.Data.General.Map = newFullName
        MP.Set(MP.Settings.Map, newFullName)
        writeServerConfig()

        if currentMap and targetMap and
            (currentMap.custom or targetMap.custom) and
            targetMap.archive ~= currentMap.archive then
            -- if current or target is custom and not from the same mod, a reboot is mandatory
            LogWarn("Map switch requires a reboot, restarting now...")
            Exit()
        else
            BJCScenarioData.reload()
        end
    end)
    return true
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
        return string.var("{1}\n{2}", {
            BJCLang.getConsoleMessage("command.currentMap"):var({ mapName = getMap() }),
            BJCLang.getConsoleMessage("command.validMaps"):var({ maps = table.join(maps, ", ") })
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
        return string.var("{1}\n{2}", {
            BJCLang.getConsoleMessage("command.errors.invalidMap"):var({ mapName = args[1] }),
            BJCLang.getConsoleMessage("command.validMaps"):var({ maps = table.join(maps, ", ") })
        })
    elseif #matches > 1 then -- multiple matches
        return BJCLang.getConsoleMessage("command.errors.mapAmbiguity"):var({
            mapName = args[1],
            mapList = table.join(matches, ", ")
        })
    end

    -- switch map
    M.setMap(matches[1])
    return BJCLang.getConsoleMessage("command.mapSwitched")
end

local function set(key, value)
    local keys = { "Name", "Debug", "Private", "MaxCars", "MaxPlayers" }
    if type(M.Data.General[key]) == type(value) and table.includes(keys, key) then
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
    local keyParts = key:split(".")
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
        if table.includes({ "Port", "MaxPlayers", "MaxCars" }, keyParts[2]) then
            value = tonumber(value)
            if not value then
                error({ key = "rx.errors.invalidValue", data = { value = value } })
            end
        elseif table.includes({ "Debug", "Private" }, keyParts[2]) then
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
    if MP.GetPlayerCount() == 0 then
        Exit()
        return BJCLang.getConsoleMessage("command.stop")
    end
    local messagesCache = {}
    CountdownKickAll(stopDelay, function(player, delaySec)
        if not messagesCache[player.lang] then
            messagesCache[player.lang] = BJCLang.getServerMessage(player.lang,
                "broadcast.serverStopsIn")
        end
        return messagesCache[player.lang]:var({ delay = PrettyDelay(delaySec) })
    end, "broadcast.serverStopped", Exit)

    return BJCLang.getConsoleMessage("command.stopIn"):var({ seconds = stopDelay })
end

local function getCache()
    local fields = { "Name", "Tags", "Debug", "Private", "MaxCars", "MaxPlayers", "Description" }
    local cache = {}
    local config = table.deepcopy(M.Data.General)
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
