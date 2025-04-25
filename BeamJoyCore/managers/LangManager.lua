local logTag = "Lang"
SetLogType(logTag, CONSOLE_COLORS.FOREGROUNDS.LIGHT_MAGENTA)

local langPath = svar("{1}/lang/", { BJCPluginPath })

local M = {
    FallbackLang = "en",
    Langs = {},
}

-- INIT

local function loadLangs()
    for _, filename in pairs(FS.ListFiles(langPath)) do
        if filename:find(".json") then
            local lang = filename:gsub(".json", "")
            Log(svar("Loading lang \"{1}\"", { lang }), logTag)

            local file, error = io.open(svar("{1}/{2}", { langPath, filename }), "r")
            if file and not error then
                local data = file:read("*a")
                file:close()
                local parsed = JSON.parse(data)
                if not parsed then
                    LogError(svar("Cannot parse lang file \"{1}\"", { filename }))
                else
                    M.Langs[lang] = parsed
                end
            else
                LogError(svar("Cannot open lang file \"{1}\"", { filename }))
            end
        end
    end
end

local function _init()
    if not FS.Exists(langPath) then
        LogError("Lang folder not found")
        Exit()
    end

    loadLangs()

    if not M.Langs[M.FallbackLang] then
        LogError(svar("Fallback lang \"{1}\" is missing, please fix", { M.FallbackLang }))
        Exit()
    end

    M.checkConsoleLang(BJCConfig.Data.Server.Lang)
end

-- ON CHANGE

local function checkConsoleLang(consoleLang)
    if not consoleLang or not M.Langs[consoleLang] or not M.Langs[consoleLang].console then
        LogError(svar("Server lang \"{1}\" is missing, using and saving fallback \"{2}\"",
            { consoleLang, M.FallbackLang }))
        local ctxt = {}
        BJCInitContext(ctxt)
        BJCConfig.set(ctxt, "Server.Lang", M.FallbackLang)
    end
end

-- GETTERS

local function getLangsList()
    local langs = {}
    for k in pairs(M.Langs) do
        table.insert(langs, k)
    end
    return langs
end

local function _getMessage(lang, key)
    if key:find(" ") then
        return key
    end
    local parts = ssplit(key, ".")
    local obj = lang or M.Langs[M.FallbackLang]
    for i = 1, #parts do
        obj = obj[parts[i]]
        if obj == nil then
            LogError(svar(M.getConsoleMessage("messages.missing"), { key = key }))
            return key
        end
    end
    if type(obj) == "string" then
        return obj
    else
        LogError(svar(M.getConsoleMessage("messages.invalidKey"), { key = key }))
        return key
    end
end

local function getConsoleMessage(key)
    M.checkConsoleLang(BJCConfig.Data.Server.Lang)
    local lang = tdeepcopy(M.Langs[M.FallbackLang])
    tdeepassign(lang, M.Langs[BJCConfig.Data.Server.Lang])
    local compiledKey = "console." .. tostring(key)
    local message = _getMessage(lang, compiledKey)
    return message ~= compiledKey and message or key
end

local function _getPlayerLang(playerID)
    local lang = tdeepcopy(M.Langs[M.FallbackLang])
    local playerLang = (BJCPlayers.Players[playerID] or {}).lang
    if M.Langs[playerLang] ~= nil then
        tdeepassign(lang, M.Langs[playerLang])
    end
    return lang
end

local function getServerMessage(targetLang, key)
    local lang = tdeepcopy(M.Langs[M.FallbackLang])
    if tincludes(M.getLangsList(), targetLang) then
        tdeepassign(lang, M.Langs[targetLang])
    end
    local compiledKey = "server." .. tostring(key)
    local message = _getMessage(lang, compiledKey)
    return message ~= compiledKey and message or key
end

local function getCache(playerID)
    return {
        langs = M.getLangsList(),
        messages = _getPlayerLang(playerID).client
    }, M.getCacheHash()
end

local function getCacheHash()
    return Hash(M.Langs)
end

M.checkConsoleLang = checkConsoleLang
M.getLangsList = getLangsList
M.getConsoleMessage = getConsoleMessage
M.getServerMessage = getServerMessage
M.getCache = getCache
M.getCacheHash = getCacheHash

_init()

RegisterBJCManager(M)
return M
