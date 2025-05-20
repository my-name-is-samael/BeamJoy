---@class BJIManagerEnvironment : BJIManager
local M = {
    _name = "Env",

    Data = {
        controlSun = false,
        ToD = .78,
        timePlay = true,
        dayLength = 1800,
        visibleDistance = 8000,
        shadowDistance = 1000,
        shadowSoftness = 0.1,
        shadowSplits = 4,
        shadowTexSize = 1024,
        shadowTexSizeInput = 6,
        shadowLogWeight = 0.99,
        skyDay = {
            dayScale = .02,
            sunAzimuthOverride = 0.0,
            sunSize = 10,
            skyBrightness = 40,
            rayleighScattering = 0.003,
            brightness = 1,
            exposure = 1,
            flareScale = 25,
            occlusionScale = 1,
        },
        skyNight = {
            nightScale = 5,
            moonAzimuth = 0.0,
            moonScale = 0.03,
            brightness = 1,
            moonElevation = 45,
        },

        controlWeather = false,
        fogDensity = 10,
        fogDensityOffset = 0,
        fogAtmosphereHeight = 0,
        cloudHeight = 2.5,
        cloudHeightOne = 5,
        cloudCover = 0.2,
        cloudCoverOne = 0.2,
        cloudSpeed = 0.2,
        cloudSpeedOne = 0.2,
        cloudExposure = 1.4,
        cloudExposureOne = 1.6,
        rainDrops = 0,
        dropSize = 1,
        dropMinSpeed = 0.1,
        dropMaxSpeed = 0.2,
        precipType = "rain_medium",

        controlSimSpeed = false,
        simSpeed = 1,

        controlGravity = false,
        gravityRate = -9.81,

        useTempCurve = false,
        tempCurveNoon = 38,
        tempCurveDusk = 12,
        tempCurveMidnight = -15,
        tempCurveDawn = 12,
    },
    init = false, -- true if env is applied at least once after joining

    PRECIP_TYPES = { "rain_medium", "rain_drop", "Snow_menu" },
    duskLimits = { .245, .25 },
    dawnLimits = { .75, .755 },
}

local function _getObjectWithCache(category)
    if BJI.Managers.Context.WorldCache[category] then
        return scenetree.findObjectById(BJI.Managers.Context.WorldCache[category])
    end
    local names = scenetree.findClassObjects(category)
    if names and table.length(names) > 0 then
        for _, name in pairs(names) do
            local obj = scenetree.findObject(name)
            if obj then
                BJI.Managers.Context.WorldCache[category] = obj:getID()
                return obj
            end
        end
    end
end

local function _tryApplyTime()
    if M.Data.controlSun then
        local ToD = core_environment.getTimeOfDay()
        if ToD then
            ToD.time = M.Data.ToD
            core_environment.setTimeOfDay(ToD)
        end
    end
end

local function tryApplyTimeFromServer(ToD)
    if ToD ~= nil and M.Data.controlSun and
        math.abs(M.Data.ToD - ToD) > .01 then
        -- sync only if client got offset
        M.Data.ToD = ToD
    end
end

local function _tryApplyDayNightSunValues()
    local scatterSky = _getObjectWithCache("ScatterSky")
    local ToD = core_environment.getTimeOfDay()
    if not scatterSky or not ToD then
        return
    end
    if ToD.time > M.duskLimits[1] and ToD.time <= M.duskLimits[2] then
        -- dusk
        scatterSky.brightness = math.scale(ToD.time, M.duskLimits[1], M.duskLimits[2], M.Data.skyDay.brightness,
            M.Data.skyNight.brightness)
    elseif ToD.time > M.duskLimits[2] and ToD.time <= M.dawnLimits[1] then
        -- night
        scatterSky.brightness = M.Data.skyNight.brightness
    elseif ToD.time > M.dawnLimits[1] and ToD.time <= M.dawnLimits[2] then
        -- dawn
        scatterSky.brightness = math.scale(ToD.time, M.dawnLimits[1], M.dawnLimits[2], M.Data.skyNight.brightness,
            M.Data.skyDay.brightness)
    else
        -- day
        scatterSky.brightness = M.Data.skyDay.brightness
    end
end

local function _tryApplySun()
    if M.Data.controlSun then
        local ToD = core_environment.getTimeOfDay()
        if ToD then
            -- TimePlay is manually done in rendertick (sync purpose)
            ToD.play = false      --M.Data.timePlay
            ToD.dayLength = 84600 --M.Data.dayLength
            ToD.dayScale = 1      -- M.Data.skyDay.dayScale * 2
            ToD.nightScale = 1    -- M.Data.skyNight.nightScale * 2
            ToD.azimuthOverride = M.Data.skyDay.sunAzimuthOverride / 360 * 6.25
            core_environment.setTimeOfDay(ToD)
        end

        local scatterSky = _getObjectWithCache("ScatterSky")
        if scatterSky then
            scatterSky.shadowDistance = M.Data.shadowDistance
            scatterSky.shadowSoftness = M.Data.shadowSoftness
            scatterSky.numSplits = M.Data.shadowSplits
            scatterSky.texSize = M.Data.shadowTexSize
            scatterSky.logWeight = M.Data.shadowLogWeight
            scatterSky.sunSize = M.Data.skyDay.sunSize
            scatterSky.skyBrightness = M.Data.skyDay.skyBrightness
            scatterSky.rayleighScattering = M.Data.skyDay.rayleighScattering
            scatterSky.exposure = M.Data.skyDay.exposure
            scatterSky.flareScale = M.Data.skyDay.flareScale
            scatterSky.occlusionScale = M.Data.skyDay.occlusionScale
            scatterSky.moonAzimuth = M.Data.skyNight.moonAzimuth
            scatterSky.moonElevation = M.Data.skyNight.moonElevation
            scatterSky.moonScale = M.Data.skyNight.moonScale
            scatterSky:postApply()
        end

        local levelInfo = _getObjectWithCache("LevelInfo")
        if levelInfo then
            levelInfo.visibleDistance = M.Data.visibleDistance
            levelInfo:postApply()
        end
    end
end

local function _tryApplyWeather()
    if M.Data.controlWeather then
        core_environment.setFogDensity(M.Data.fogDensity)
        core_environment.setFogDensityOffset(M.Data.fogDensityOffset)
        core_environment.setFogAtmosphereHeight(M.Data.fogAtmosphereHeight)

        local cloudLayer = _getObjectWithCache("CloudLayer")
        if cloudLayer then
            local id = cloudLayer:getId()
            core_environment.setCloudHeightByID(id, M.Data.cloudHeight)
            core_environment.setCloudHeightByID(id + 1, M.Data.cloudHeightOne)
            core_environment.setCloudCoverByID(id, M.Data.cloudCover)
            core_environment.setCloudCoverByID(id + 1, M.Data.cloudCoverOne)
            core_environment.setCloudWindByID(id, M.Data.cloudSpeed)
            core_environment.setCloudWindByID(id + 1, M.Data.cloudSpeedOne)
            core_environment.setCloudExposureByID(id, M.Data.cloudExposure)
            core_environment.setCloudExposureByID(id + 1, M.Data.cloudExposureOne)
        end

        local precipitation = _getObjectWithCache("Precipitation")
        if precipitation then
            precipitation.numDrops = M.Data.rainDrops
            precipitation.dropSize = M.Data.dropSize * (BJI.Managers.Context.UI.dropSizeRatio or 1)
            precipitation.minSpeed = M.Data.dropMinSpeed
            precipitation.maxSpeed = M.Data.dropMaxSpeed
            if table.includes(M.PRECIP_TYPES, M.Data.precipType) then
                precipitation.dataBlock = scenetree.findObject(M.Data.precipType)
            end
        end
    end
end

local function _tryApplyTemperature()
    if M.Data.useTempCurve then
        local levelInfo = _getObjectWithCache("LevelInfo")
        if levelInfo then
            levelInfo:setTemperatureCurveC({
                { 0,    M.Data.tempCurveNoon },
                { 0.25, M.Data.tempCurveDusk },
                { 0.5,  M.Data.tempCurveMidnight },
                { 0.75, M.Data.tempCurveDawn },
                { 1,    M.Data.tempCurveNoon }
            })
        end
    end
end

local function _tryApplySimSpeed()
    if M.Data.controlSimSpeed then
        be:setSimulationTimeScale(M.Data.simSpeed)
    end
end

local function _tryApplyGravity()
    if M.Data.controlGravity then
        local g = math.round(core_environment.getGravity(), 3)
        if g ~= M.Data.gravityRate then
            core_environment.setGravity(M.Data.gravityRate)
        end
    end
end

local function forceUpdate()
    _tryApplyTime()
    _tryApplySun()
    _tryApplyWeather()
    _tryApplyTemperature()
    _tryApplyDayNightSunValues()
end

local function slowTick()
    if BJI.Managers.Context.WorldReadyState == 2 and
        BJI.Managers.Cache.isFirstLoaded(BJI.Managers.Cache.CACHES.ENVIRONMENT) then
        _tryApplyTime()
        _tryApplySun()
        _tryApplyWeather()
        _tryApplyTemperature()
        M.init = true
    end
end

local function fastTick(ctxt)
    if BJI.Managers.Context.WorldReadyState == 2 then
        -- disable pause on multiplayer
        if bullettime:getPause() then
            --_be:toggleEnabled()
            bullettime.togglePause()
        end

        -- applying environment
        if BJI.Managers.Cache.isFirstLoaded(BJI.Managers.Cache.CACHES.ENVIRONMENT) then
            _tryApplySimSpeed()
            _tryApplyGravity()
        end

        -- adjust environment settings in bigmap view
        if ctxt.camera == BJI.Managers.Cam.CAMERAS.BIG_MAP and
            not BJI.Managers.Async.exists("BJIBigmapEnv") then
            local oldFog = M.Data.fogDensity
            local oldVisibleDistance = M.Data.visibleDistance
            M.Data.fogDensity = 0
            M.Data.visibleDistance = 20000
            BJI.Managers.Async.task(
                function(ctxt2)
                    return ctxt2.camera ~= BJI.Managers.Cam.CAMERAS.BIG_MAP
                end,
                function()
                    M.Data.fogDensity = oldFog
                    M.Data.visibleDistance = oldVisibleDistance
                end,
                "BJIBigmapEnv"
            )
        end
    end
end

local lastRenderTick = nil
local lastToD = nil
local function renderTick(ctxt)
    if BJI.Managers.Context.WorldReadyState == 2 and
        BJI.Managers.Cache.isFirstLoaded(BJI.Managers.Cache.CACHES.ENVIRONMENT) then
        if M.Data.controlSun and M.Data.timePlay then -- ToD auto-update
            if lastRenderTick then
                local delta = ctxt.now - lastRenderTick
                local partDuration
                if M.Data.ToD >= 0.25 and M.Data.ToD <= 0.75 then
                    partDuration = M.Data.dayLength * M.Data.skyNight.nightScale
                else
                    partDuration = M.Data.dayLength * M.Data.skyDay.dayScale
                end
                local step = math.round(.5 / partDuration, 6) * (delta / 1000)
                M.Data.ToD = (M.Data.ToD + step) % 1
                _tryApplyTime()
            end
            lastRenderTick = ctxt.now
        end

        if not lastToD or lastToD ~= M.Data.ToD then -- on ToD change (timePlay or server change)
            _tryApplyDayNightSunValues()
        end
        lastToD = M.Data.ToD
    end
end

local function onLoad()
    BJI.Managers.Cache.addRxHandler(BJI.Managers.Cache.CACHES.ENVIRONMENT, function(cacheData)
        local previous = table.clone(M.Data)
        for k, v in pairs(cacheData) do
            M.Data[k] = v

            if k == "shadowTexSize" then
                local shadowTexVal = 5
                while 2 ^ shadowTexVal < v do
                    shadowTexVal = shadowTexVal + 1
                end
                M.Data.shadowTexSizeInput = shadowTexVal - 4
            end
        end

        M.updateCurrentPreset()

        -- events detection
        local keysChanged = {}
        for k, v in pairs(M.Data) do
            if v ~= previous[k] then
                keysChanged[k] = {
                    previousValue = previous[k],
                    currentValue = v,
                }
            end
        end

        if table.length(keysChanged) > 0 then
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.ENV_CHANGED, {
                keys = keysChanged
            })
        end
    end)

    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.SLOW_TICK, slowTick)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.FAST_TICK, fastTick)
end

local function getTime()
    return core_environment.getTimeOfDay()
end

local function getTemperature()
    return core_environment.getTemperatureK()
end

local function updateCurrentPreset()
    M.currentWeatherPreset = nil
    local presets = require("ge/extensions/utils/EnvironmentUtils").weatherPresets()
    for _, preset in ipairs(presets) do
        local allMatch = true
        for k, v in pairs(preset.keys) do
            if type(v) == "number" then
                if math.round(M.Data[k], 4) ~= math.round(v, 4) then
                    allMatch = false
                    break
                end
            else
                if M.Data[k] ~= v then
                    allMatch = false
                    break
                end
            end
        end
        if allMatch then
            M.currentWeatherPreset = preset.label
            break
        end
    end
end

M.getTime = getTime
M.getTemperature = getTemperature
M.updateCurrentPreset = updateCurrentPreset
M.tryApplyTimeFromServer = tryApplyTimeFromServer
M.forceUpdate = forceUpdate

M.renderTick = renderTick

M.onLoad = onLoad

return M
