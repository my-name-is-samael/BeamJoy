local M = {
    ---@type table<string, any>
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

local function updateEnvToV2_0()
    M.Data.skyDay = {
        dayScale = M.Data.dayScale,
        sunAzimuthOverride = M.Data.sunAzimuthOverride / 6.25 * 360,
        sunSize = M.Data.sunSize,
        skyBrightness = M.Data.skyBrightness,
        rayleighScattering = M.Data.rayleighScattering,
        brightness = M.Data.sunLightBrightness,
        exposure = M.Data.exposure,
        flareScale = M.Data.flareScale,
        occlusionScale = M.Data.occlusionScale,
    }
    M.Data.skyNight = {
        nightScale = M.Data.nightScale,
        moonAzimuth = M.Data.moonAzimuth,
        moonScale = M.Data.moonScale,
        brightness = 30,
        moonElevation = 45,
    }
    M.Data.dayScale = nil
    M.Data.nightScale = nil
    M.Data.sunAzimuthOverride = nil
    M.Data.sunSize = nil
    M.Data.skyBrightness = nil
    M.Data.rayleighScattering = nil
    M.Data.sunLightBrightness = nil
    M.Data.flareScale = nil
    M.Data.occlusionScale = nil
    M.Data.exposure = nil
    M.Data.moonAzimuth = nil
    M.Data.moonElevation = nil
    M.Data.moonScale = nil
    M.Data.fogColor = { 0.275, 0.325, 0.359 }

    BJCDao.environment.save(M.Data)
end

local function init()
    M.Data = BJCDao.environment.findAll()

    if not M.Data.skyDay then
        -- 2.0.0 update data conversion
        updateEnvToV2_0()
    end

    M.Data = table.assign(BJCDefaults.environment(), M.Data)

    if not M.Data.presets or not Table(BJC_ENV_PRESETS)
        :any(function(pkey) return not M.Data.presets[pkey] end) then
        ---@type table<string, any>
        M.Data.presets = BJCDefaults.envPresets()
        BJCDao.environment.save(M.Data)
    end
end

local function getRanges()
    return {
        ToD = { min = 0, max = 1 },
        dayLength = { min = 60, max = 86400 },
        visibleDistance = { min = 1000, max = 32000 },
        dayScale = { min = .01, max = .99 },
        nightScale = { min = .01, max = .99 },
        sunAzimuthOverride = { min = 1, max = 360 },
        moonAzimuth = { min = 0, max = 360 },
        sunSize = { min = 0, max = 10 },
        moonScale = { min = 0, max = 2 },
        skyBrightness = { min = 0, max = 100 },
        brightness = { min = -1, max = 50 },
        rayleighScattering = { min = -.002, max = .3 },
        exposure = { min = .001, max = 3 },
        flareScale = { min = 0, max = 10 },
        moonElevation = { min = 10, max = 80 },
        occlusionScale = { min = 0, max = 1.6 },
        shadowDistance = { min = 1000, max = 12800 },
        shadowSoftness = { min = 0, max = 3 },
        shadowSplits = { min = 1, max = 4 },
        shadowTexSize = { min = 32, max = 2048 },
        shadowLogWeight = { min = 0, max = .99 },

        fogDensity = { min = 0, max = .1 },
        fogDensityOffset = { min = 0, max = 5000 },
        fogAtmosphereHeight = { min = 50, max = 2000 },
        cloudHeight = { min = 2, max = 10 },
        cloudHeightOne = { min = 2, max = 10 },
        cloudCover = { min = 0, max = 1 },
        cloudCoverOne = { min = 0, max = 1 },
        cloudSpeed = { min = 0, max = 3 },
        cloudSpeedOne = { min = 0, max = 3 },
        cloudExposure = { min = .2, max = 5 },
        cloudExposureOne = { min = .2, max = 5 },
        rainDrops = { min = 0, max = 10000 },
        dropSize = { min = 0, max = 1 },
        dropMinSpeed = { min = .01, max = 5 },
        dropMaxSpeed = { min = .01, max = 5 },

        simSpeed = { min = .01, max = 10 },

        gravityRate = { min = -280, max = 10 },

        tempCurveNoon = { min = -50, max = 50 },
        tempCurveDusk = { min = -50, max = 50 },
        tempCurveMidnight = { min = -50, max = 50 },
        tempCurveDawn = { min = -50, max = 50 },
    }
end

local function set(key, value)
    local function _get()
        local parts = key:split(".")
        if #parts == 1 then
            return M.Data[key]
        else
            return M.Data[parts[1]][parts[2]]
        end
    end
    local function getDefault()
        local parts = key:split(".")
        if #parts == 1 then
            return BJCDefaults.environment()[key]
        else
            return BJCDefaults.environment()[parts[1]][parts[2]]
        end
    end
    local function getRange()
        local parts = key:split(".")
        if #parts == 1 then
            return getRanges()[key]
        else
            return getRanges()[parts[2]]
        end
    end
    local function _set(val)
        local parts = key:split(".")
        if #parts == 1 then
            M.Data[key] = val
        else
            M.Data[parts[1]][parts[2]] = val
        end
    end
    if _get() == nil then
        error({ key = "rx.errors.invalidKey", data = { key = key } })
    end

    if value == nil then
        value = getDefault()
    else
        if type(_get()) ~= type(value) then
            error({ key = "rx.errors.invalidValue", data = { value = value } })
        end

        -- specific field restrictions
        if key == "shadowTexSize" and not table.includes({ 32, 64, 128, 256, 512, 1024, 2048 }, value) then
            error({ key = "rx.errors.invalidValue", { value = value } })
        elseif key == "precipType" and not table.includes(M.PRECIP_TYPES, value) then
            error({ key = "rx.errors.invalidValue", { value = value } })
        elseif key == "fogColor" and (not table.isArray(value) or table.length(value) ~= 3 or
                Table(value):any(function(v) return type(v) ~= "number" end)) then
            error({ key = "rx.errors.invalidValue", { value = value } })
        end

        -- parse ints
        local intFields = Table({ "dayLength", "sunAzimuthOverride", "moonAzimuth", "shadowDistance", "shadowSplits",
            "shadowTexSize", "visibleDistance", "fogAtmosphereHeight", "rainDrops", "tempCurveNoon", "tempCurveDusk",
            "tempCurveMidnight", "tempCurveDawn" })
        if intFields:any(function(k) return k:endswith(key) end) then
            value = math.round(value)
        end

        -- clamp numerics
        if type(value) == "number" then
            local range = getRange()
            value = math.clamp(value, range.min, range.max)
        end

        if key == "fogColor" then
            value = Table(value):map(function(c) return math.round(c, 3) end)
        end
    end

    _set(value)
    BJCDao.environment.save(M.Data)

    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.ENVIRONMENT)
end

local function resetType(type)
    if not table.includes(M.TYPES, type) then
        error({ key = "rx.errors.invalidValue", data = { value = type } })
    end

    local fields = Table()
    if type == M.TYPES.SUN then
        fields:addAll({ "ToD", "timePlay", "dayLength", "visibleDistance", "shadowDistance", "shadowSoftness",
            "shadowSplits", "shadowTexSize", "skyDay", "skyNight" })
    elseif type == M.TYPES.WEATHER then
        fields:addAll({ "fogDensity", "fogColor", "fogDensityOffset", "fogAtmosphereHeight", "cloudHeight",
            "cloudHeightOne",
            "cloudCover", "cloudCoverOne", "cloudSpeed", "cloudSpeedOne", "cloudExposure", "cloudExposureOne",
            "rainDrops", "dropSize", "dropMinSpeed", "dropMaxSpeed", "precipType" })
    elseif type == M.TYPES.GRAVITY then
        fields:addAll({ "gravityRate" })
    elseif type == M.TYPES.TEMPERATURE then
        fields:addAll({ "tempCurveNoon", "tempCurveDusk", "tempCurveMidnight", "tempCurveDawn" })
    elseif type == M.TYPES.SPEED then
        fields:addAll({ "simSpeed" })
    else
        error({ key = "rx.errors.invalidValue", data = { value = type } })
    end

    local defaults = BJCDefaults.environment()
    fields:forEach(function(k)
        M.Data[k] = defaults[k]
    end)
    BJCDao.environment.save(M.Data)
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.ENVIRONMENT)
end

local function consoleEnv(args)
    local validKeys = Table({ "ToD", "dayLength", "simSpeed", "gravityRate" })

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

local function applyPreset(pkey)
    local preset = M.Data.presets[pkey]
    if not preset then
        error({ key = "rx.errors.invalidValue", data = { value = pkey } })
    end

    table.assign(M.Data, preset.keys)
    BJCDao.environment.save(M.Data)
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.ENVIRONMENT)
end

---@return string?
local function findAppliedPreset()
    local function comparePresetValues(data, presetKeys)
        return Table(presetKeys):every(function(v, k)
            if type(v) == "table" then
                return comparePresetValues(data[k], v)
            else
                return data[k] == v
            end
        end)
    end
    return Table(M.Data.presets):reduce(function(found, preset, pkey)
        if not found and comparePresetValues(M.Data, preset.keys) then
            return tostring(pkey)
        end
        return found
    end)
end

local function getCache(senderID)
    ---@type table<string, any>
    local cache = Table(M.Data):clone()
    if BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.SET_ENVIRONMENT_PRESET) then
        cache:assign({ preset = findAppliedPreset() })
        cache.presets = Table(M.Data.presets)
            :map(function(p) return p.icon end)
    else
        cache.presets = nil
    end
    return cache, M.getCacheHash()
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
        local partDuration
        if M.Data.ToD >= 0.25 and M.Data.ToD <= 0.75 then
            partDuration = M.Data.dayLength * M.Data.skyNight.nightScale
        else
            partDuration = M.Data.dayLength * M.Data.skyDay.dayScale
        end
        local step = .5 / partDuration
        if M.Data.controlSimSpeed and M.Data.simSpeed ~= 1 then
            step = step * M.Data.simSpeed
        end
        M.Data.ToD = math.round((M.Data.ToD + step) % 1, 7)
        BJCDao.environment.save(M.Data)
    end
end

M.set = set
M.resetType = resetType
M.consoleEnv = consoleEnv

M.applyPreset = applyPreset

M.getCache = getCache
M.getCacheHash = getCacheHash

M.tickTime = tickTime

init()
return M
