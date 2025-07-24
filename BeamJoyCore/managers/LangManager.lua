local logTag = "Lang"
SetLogType(logTag, CONSOLE_COLORS.FOREGROUNDS.LIGHT_MAGENTA)

local langPath = string.var("{1}/lang/", { BJCPluginPath })

local M = {
    FallbackLang = "en",
    Langs = {},
}

-- INIT

local function loadLangs()
    for _, filename in pairs(FS.ListFiles(langPath)) do
        if filename:find(".json") then
            local lang = filename:gsub(".json", "")
            Log(string.var("Loading lang \"{1}\"", { lang }), logTag)

            local file, error = io.open(string.var("{1}/{2}", { langPath, filename }), "r")
            if file and not error then
                local data = file:read("*a")
                file:close()
                local parsed = JSON.parse(data)
                if not parsed then
                    LogError(string.var("Cannot parse lang file \"{1}\"", { filename }))
                else
                    M.Langs[lang] = parsed
                end
            else
                LogError(string.var("Cannot open lang file \"{1}\"", { filename }))
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
        LogError(string.var("Fallback lang \"{1}\" is missing, please fix", { M.FallbackLang }))
        Exit()
    end

    M.checkConsoleLang(BJCConfig.Data.Server.Lang)
end

-- ON CHANGE

local function checkConsoleLang(consoleLang)
    if not consoleLang or not M.Langs[consoleLang] or not M.Langs[consoleLang].console then
        LogError(string.var("Server lang \"{1}\" is missing, using and saving fallback \"{2}\"",
            { consoleLang, M.FallbackLang }))
        local ctxt = {}
        BJCInitContext(ctxt)
        BJCConfig.set(ctxt, "Server.Lang", M.FallbackLang)
    end
end

-- GETTERS

---@return string[]
local function getLangsList()
    local langs = {}
    for k in pairs(M.Langs) do
        table.insert(langs, k)
    end
    return langs
end

---@param lang table
---@param key string
---@param skipError boolean?
---@return string
local function _getMessage(lang, key, skipError)
    if key:find(" ") then
        return key
    end
    local parts = key:split(".")
    local obj = lang or M.Langs[M.FallbackLang]
    for i = 1, #parts do
        obj = obj[parts[i]]
        if obj == nil then
            if not skipError then
                LogError(M.getConsoleMessage("messages.missing"):var({ key = key }))
            end
            return key
        end
    end
    if type(obj) == "string" then
        return obj
    else
        if not skipError then
            LogError(M.getConsoleMessage("messages.invalidKey"):var({ key = key }))
        end
        return key
    end
end

---@param key string
---@return string
local function getConsoleMessage(key)
    M.checkConsoleLang(BJCConfig.Data.Server.Lang)
    local lang = table.deepcopy(M.Langs[M.FallbackLang])
    table.assign(lang, M.Langs[BJCConfig.Data.Server.Lang])
    local compiledKey = "console." .. tostring(key)
    local message = _getMessage(lang, compiledKey)
    return message ~= compiledKey and message or key
end

---@param playerID integer
---@return table
local function _getPlayerLang(playerID)
    local lang = table.deepcopy(M.Langs[M.FallbackLang])
    local playerLang = (BJCPlayers.Players[playerID] or {}).lang
    if M.Langs[playerLang] ~= nil then
        table.assign(lang, M.Langs[playerLang])
    end
    return lang
end

---@param targetLang string
---@param key string
---@return string
local function getServerMessage(targetLang, key)
    local lang = table.deepcopy(M.Langs[M.FallbackLang])
    if table.includes(M.getLangsList(), targetLang) then
        table.assign(lang, M.Langs[targetLang])
    end
    local compiledKey = "server." .. tostring(key)
    local message = _getMessage(lang, compiledKey)
    return message ~= compiledKey and message or key
end

---@param targetLang string
---@param key string
---@return string
local function getClientMessage(targetLang, key)
    local lang = table.deepcopy(M.Langs[M.FallbackLang])
    if table.includes(M.getLangsList(), targetLang) then
        table.assign(lang, M.Langs[targetLang])
    end
    local compiledKey = "client." .. tostring(key)
    local message = _getMessage(lang, compiledKey, true)
    return message ~= compiledKey and message or key
end

---@param playerID integer
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
M.getClientMessage = getClientMessage
M.getCache = getCache
M.getCacheHash = getCacheHash

_init()
return M
