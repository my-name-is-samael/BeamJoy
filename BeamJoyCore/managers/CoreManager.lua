---@class BJCoreConfig
---@field Debug boolean
---@field Private boolean
---@field MaxCars integer
---@field MaxPlayers integer
---@field Map string
---@field Name string
---@field Description string
---@field Tags string
---@field LogChat boolean
---@field InformationPacket boolean?

local resourcesFolderPath = BJCPluginPath:gsub("Server/BeamJoyCore", "")

local M = {
    ---@type BJCoreConfig?
    Data = nil,

    _mapFullNamePrefix = "/levels/",
    _mapFullNameSuffix = "/info.json",
}

---@param key string
---@param value any
local function _set(key, value)
    if not BJC_CORE_CONFIG[key] then
        error({ key = "rx.errors.invalidKey", data = { key = key } })
    elseif type(value) ~= BJC_CORE_CONFIG[key].type then
        error({ key = "rx.errors.invalidValue", data = { value = value } })
    elseif BJC_CORE_CONFIG[key].type == "string" and #value > BJC_CORE_CONFIG[key].maxLength then
        error({ key = "rx.errors.invalidValue", data = { value = value } })
    end

    if BJC_CORE_CONFIG[key].type == "number" then
        value = math.round(value)
    end

    if MP.Settings[key] then
        MP.Set(MP.Settings[key], value)
    end
    M.Data[key] = value
    BJCTx.cache.invalidateByPermissions(BJCCache.CACHES.CORE, BJCPerm.PERMISSIONS.SET_CORE)

    BJCDao.core.save(M.Data)
end

local function init()
    M.Data = BJCDao.core.findAll()

    Table(M.Data):forEach(function(v, k)
        if MP.Settings[k] and (not MP.Get or MP.Get(MP.Settings[k]) ~= v) then
            MP.Set(MP.Settings[k], v)
        end
    end)

    local serverUnhandledValues = Table(MP.Settings):keys()
        :filter(function(k) return not BJC_CORE_CONFIG[k] end)
    if #serverUnhandledValues > 0 then
        LogDebug("Server has unhandled config values: " .. table.join(serverUnhandledValues, ", "))
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
    local mapName = M.Data.Map:gsub(M._mapFullNamePrefix, ""):gsub(M._mapFullNameSuffix, "")
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
        _set("Map", newFullName)

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
    if not BJC_CORE_CONFIG[key] or BJC_CORE_CONFIG[key].prevent then
        error({ key = "rx.errors.invalidKey", data = { key = key } })
    elseif BJC_CORE_CONFIG[key].type ~= type(value) then
        error({ key = "rx.errors.invalidValue", data = { value = value } })
    end

    if key == "Map" then
        setMap(value)
    elseif BJC_CORE_CONFIG:filter(function(k) return not k.prevent end)[key] then
        if key == "Description" then
            value = value:gsub("\n", "^p")
        end
        _set(key, value)
    end
end

local function consoleSet(key, value)
    if not BJC_CORE_CONFIG[key] or BJC_CORE_CONFIG[key].prevent then
        error({ key = "rx.errors.invalidKey", data = { key = key } })
    end

    -- value types validation
    if BJC_CORE_CONFIG[key].type == "number" then
        value = tonumber(value)
        if not value then
            error({ key = "rx.errors.invalidValue", data = { value = value } })
        end
    elseif BJC_CORE_CONFIG[key].type == "boolean" then
        if value == "true" then
            value = true
        elseif value == "false" then
            value = false
        else
            error({ key = "rx.errors.invalidValue", data = { value = value } })
        end
    end

    if key == "Map" then
        -- not an actual error but will be printed next instead of default message
        error({ key = M.consoleSetMap({ value }) })
    else
        M.set(key, value)
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
    return BJC_CORE_CONFIG:filter(function(k) return not k.prevent end):reduce(function(res, _, k)
        res[k] = M.Data[k]
        if k == "Description" then
            res[k] = res[k]:gsub("%^p", "\n")
        end
        return res
    end, Table()), M.getCacheHash()
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
