local M = {
    Data = {},
    TYPES = {
        SUN = "sun",
        WEATHER = "weather",
        GRAVITY = "gravity",
        TEMPERATURE = "temperature",
        SPEED = "speed"
    },
    PRECIP_TYPES = { "rain_medium", "rain_drop", "Snow_menu" }
}

local function init()
    M.Data = BJCDao.environment.findAll()
end

local function getRanges()
    return {
        ToD = { min = 0, max = 1 },
        dayLength = { min = 1, max = 14400 },
        dayScale = { min = .01, max = 100 },
        nightScale = { min = .01, max = 100 },
        sunAzimuthOverride = { min = .001, max = 6.25 },
        sunSize = { min = 0, max = 100 },
        skyBrightness = { min = 0, max = 200 },
        sunLightBrightness = { min = 0, max = 10 },
        rayleighScattering = { min = .001, max = .15 },
        flareScale = { min = 0, max = 25 },
        occlusionScale = { min = 0, max = 1 },
        exposure = { min = 0, max = 3 },
        shadowDistance = { min = 0, max = 12800 },
        shadowSoftness = { min = -10, max = 10 },
        shadowSplits = { min = 0, max = 4 },
        shadowTexSize = { min = 32, max = 2048 },
        shadowLogWeight = { min = .001, max = .999 },
        visibleDistance = { min = 1000, max = 32000 },
        moonAzimuth = { min = 0, max = 360 },
        moonElevation = { min = 0, max = 360 },
        moonScale = { min = .005, max = 1 },

        fogDensity = { min = 0, max = .2 },
        fogDensityOffset = { min = 0, max = 100 },
        fogAtmosphereHeight = { min = 0, max = 10000 },
        cloudHeight = { min = 0, max = 20 },
        cloudHeightOne = { min = 0, max = 20 },
        cloudCover = { min = 0, max = 5 },
        cloudCoverOne = { min = 0, max = 5 },
        cloudSpeed = { min = 0, max = 10 },
        cloudSpeedOne = { min = 0, max = 10 },
        cloudExposure = { min = 0, max = 10 },
        cloudExposureOne = { min = 0, max = 10 },
        rainDrops = { min = 0, max = 20000 },
        dropSize = { min = 0, max = 2 },
        dropMinSpeed = { min = 0, max = 2 },
        dropMaxSpeed = { min = 0, max = 2 },

        simSpeed = { min = .01, max = 10 },

        gravityRate = { min = -280, max = 10 },

        tempCurveNoon = { min = -50, max = 50 },
        tempCurveDusk = { min = -50, max = 50 },
        tempCurveMidnight = { min = -50, max = 50 },
        tempCurveDawn = { min = -50, max = 50 },
    }
end

local function set(key, value)
    if M.Data[key] == nil then
        error({ key = "rx.errors.invalidKey", data = { key = key } })
    end

    if value == nil then
        value = BJCDefaults.environment()[key]
    else
        if M.Data[key] ~= nil and type(M.Data[key]) ~= type(value) then
            error({ key = "rx.errors.invalidValue", data = { value = value } })
        end

        -- specific field restrictions
        if key == "shadowTexSize" and not table.includes({ 32, 64, 128, 256, 512, 1024, 2048 }, value) then
            error({ key = "rx.errors.invalidValue", { value = value } })
        elseif key == "precipType" and not table.includes(M.PRECIP_TYPES, value) then
            error({ key = "rx.errors.invalidValue", { value = value } })
        end

        -- parse ints
        local intFields = { "dayLength", "shadowDistance", "shadowSplits", "visibleDistance", "fogAtmosphereHeight",
            "rainDrops", "tempCurveNoon", "tempCurveDusk", "tempCurveMidnight", "tempCurveDawn" }
        if table.includes(intFields, key) then
            value = math.floor(value)
        end

        -- clamp numerics
        if type(value) == "number" then
            local range = getRanges()[key]
            value = math.clamp(value, range.min, range.max)
        end
    end

    M.Data[key] = value
    BJCDao.environment.save(key, value)

    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.ENVIRONMENT)
end

local function resetType(type)
    if not table.includes(M.TYPES, type) then
        error({ key = "rx.errors.invalidValue", data = { value = type } })
    end

    local fields = {}
    if type == M.TYPES.SUN then
        fields = { "ToD", "timePlay", "dayLength", "dayScale", "nightScale", "sunAzimuthOverride", "skyBrightness",
            "sunSize", "rayleighScattering", "sunLightBrightness", "flareScale", "occlusionScale", "exposure",
            "shadowDistance", "shadowSoftness", "shadowSplits", "shadowTexSize", "shadowLogWeight", "visibleDistance",
            "moonAzimuth", "moonElevation", "moonScale" }
    elseif type == M.TYPES.WEATHER then
        fields = { "fogDensity", "fogDensityOffset", "fogAtmosphereHeight", "cloudHeight", "cloudHeightOne",
            "cloudCover", "cloudCoverOne", "cloudSpeed", "cloudSpeedOne", "cloudExposure", "cloudExposureOne",
            "rainDrops", "dropSize", "dropMinSpeed", "dropMaxSpeed", "precipType" }
    elseif type == M.TYPES.GRAVITY then
        fields = { "gravityRate" }
    elseif type == M.TYPES.TEMPERATURE then
        fields = { "tempCurveNoon", "tempCurveDusk", "tempCurveMidnight", "tempCurveDawn" }
    elseif type == M.TYPES.SPEED then
        fields = { "simSpeed" }
    else
        error({ key = "rx.errors.invalidValue", data = { value = type } })
    end

    local defaults = BJCDefaults.environment()
    for _, k in ipairs(fields) do
        M.Data[k] = defaults[k]
        BJCDao.environment.save(k, defaults[k])
    end

    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.ENVIRONMENT)
end

local function consoleEnv(args)
    local validKeys = {}
    for k in pairs(M.Data) do
        table.insert(validKeys, k)
    end
    table.sort(validKeys, function(a, b) return a:lower() < b:lower() end)

    local key, value = args[1], args[2]
    if not key then -- print all keys and values
        local out = ""
        for i, k in ipairs(validKeys) do
            if i > 1 then
                out = string.var("{1}\n", { out })
            end
            out = string.var("{1}{2} = {3}", { out, k, M.Data[k] })
        end
        return out
    end

    if M.Data[key] == nil then -- invalid key
        return string.var("{1}\n{2}", {
            BJCLang.getConsoleMessage("command.errors.invalidEnvKey"):var({ key = key }),
            BJCLang.getConsoleMessage("command.envValues"):var({ values = table.join(validKeys, ", ") })
        })
    end

    if value == nil then -- print value and default
        value = M.Data[key]
        local default = BJCDefaults.environment()[key]
        return BJCLang.getConsoleMessage("command.envValueWithDefault"):var({
            key = key,
            value = value,
            defaultValue = default
        })
    end

    -- update value
    local typeKey = type(M.Data[key])
    local parsed
    if typeKey == "number" then
        parsed = tonumber(value)
    elseif typeKey == "boolean" then
        if value == "true" then
            parsed = true
        elseif value == "false" then
            parsed = false
        end
    elseif typeKey == "string" then
        parsed = tostring(value)
    end
    if parsed == nil then
        value = BJCDefaults.environment()[key]
    end
    value = parsed

    local status, err = pcall(set, key, value)
    if not status then
        err = type(err) == "table" and err or {}
        return BJCLang.getServerMessage(BJCConfig.Data.ServerLang, err.key or "rx.errors.serverError")
            :var(err.data or {})
    end

    return BJCLang.getConsoleMessage("command.envValueSetTo"):var({ key = key, value = value })
end

local function getCache()
    return Table(M.Data):clone(), M.getCacheHash()
end

local function getCacheHash()
    ---@type table<string, any>
    local data = Table(M.Data):clone()
    if data.timePlay then
        data.ToD = nil
    end
    return Hash(data)
end

local function tickTime()
    if M.Data.controlSun and M.Data.timePlay then
        if M.Data.ToD >= 0.25 and M.Data.ToD <= 0.75 then
            M.Data.ToD = M.Data.ToD + (M.Data.nightScale * (1 / M.Data.dayLength))
        else
            M.Data.ToD = M.Data.ToD + (M.Data.dayScale * (1 / M.Data.dayLength))
        end
        if M.Data.ToD > 1 then
            M.Data.ToD = M.Data.ToD % 1
        end
        BJCDao.environment.save("ToD", M.Data.ToD)
    end
end

M.set = set
M.resetType = resetType
M.consoleEnv = consoleEnv

M.getCache = getCache
M.getCacheHash = getCacheHash

M.tickTime = tickTime

init()
return M
