local M = {
    Data = {
        controlSun = false,
        ToD = .78,
        timePlay = true,
        dayLength = 1800,
        dayScale = .02,
        nightScale = 5,
        sunAzimuthOverride = 0.0,
        skyBrightness = 40,
        sunSize = 10,
        rayleighScattering = 0.003,
        sunLightBrightness = 1,
        flareScale = 25,
        occlusionScale = 1,
        exposure = 1,
        shadowDistance = 1000,
        shadowSoftness = 0.1,
        shadowSplits = 4,
        shadowTexSize = 2048,
        shadowTexSizeInput = 11,
        shadowLogWeight = 0.99,
        visibleDistance = 8000,
        moonAzimuth = 0.0,
        moonElevation = 45,
        moonScale = 0.03,

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

    PRECIP_TYPES = { "rain_medium", "rain_drop", "Snow_menu" }
}

local function _getObjectWithCache(category)
    if BJIContext.WorldCache[category] then
        return scenetree.findObjectById(BJIContext.WorldCache[category])
    end
    local names = scenetree.findClassObjects(category)
    if names and tlength(names) > 0 then
        for _, name in pairs(names) do
            local obj = scenetree.findObject(name)
            if obj then
                BJIContext.WorldCache[category] = obj:getID()
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

local function _tryApplyTimeFromServer(ToD)
    if ToD ~= nil and M.Data.controlSun and M.Data.timePlay then
        M.Data.ToD = ToD
    end
end

local function _tryApplySun()
    if M.Data.controlSun then
        local ToD = core_environment.getTimeOfDay()
        if ToD then
            ToD.play = M.Data.timePlay
            ToD.dayLength = M.Data.dayLength
            ToD.dayScale = M.Data.dayScale / BJIContext.physics.physmult
            ToD.nightScale = M.Data.nightScale / BJIContext.physics.physmult
            ToD.azimuthOverride = M.Data.sunAzimuthOverride
            core_environment.setTimeOfDay(ToD)
        end

        local scatterSky = _getObjectWithCache("ScatterSky")
        if scatterSky then
            scatterSky.sunSize = M.Data.sunSize
            scatterSky.skyBrightness = M.Data.skyBrightness
            scatterSky.rayleighScattering = M.Data.rayleighScattering
            scatterSky.brightness = M.Data.sunLightBrightness
            scatterSky.flareScale = M.Data.flareScale
            scatterSky.occlusionScale = M.Data.occlusionScale
            scatterSky.exposure = M.Data.exposure
            scatterSky.shadowDistance = M.Data.shadowDistance
            scatterSky.shadowSoftness = M.Data.shadowSoftness
            scatterSky.shadowSplits = M.Data.shadowSplits
            scatterSky.texSize = M.Data.shadowTexSize
            scatterSky.logWeight = M.Data.shadowLogWeight
            scatterSky.moonAzimuth = M.Data.moonAzimuth
            scatterSky.moonElevation = M.Data.moonElevation
            scatterSky.moonScale = M.Data.moonScale
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
            precipitation.dropSize = M.Data.dropSize * (BJIContext.UI.dropSizeRatio or 1)
            precipitation.minSpeed = M.Data.dropMinSpeed
            precipitation.maxSpeed = M.Data.dropMaxSpeed
            if tincludes(M.PRECIP_TYPES, M.Data.precipType) then
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
        local g = Round(core_environment.getGravity(), 3)
        if g ~= M.Data.gravityRate then
            core_environment.setGravity(M.Data.gravityRate)
        end
    end
end

local function slowTick(ctxt) -- server tick
    if BJIContext.WorldReadyState == 2 and BJICache.isFirstLoaded(BJICache.CACHES.ENVIRONMENT) then
        _tryApplySun()
        _tryApplyWeather()
        _tryApplyTemperature()
        M.init = true

        if ctxt.ToD then
            _tryApplyTimeFromServer(ctxt.ToD)


            -- when updating time, updating hash as well to prevent cache invalidation and preserve bandwidth
            -- /!\ THIS MANAGER MUST BE DECLARED BEFORE CACHE MANAGER /!\
            BJICache._hashes[BJICache.CACHES.ENVIRONMENT] = ctxt.cachesHashes[BJICache.CACHES.ENVIRONMENT]
        end
    end
end

local function renderTick(ctxt) -- render tick
    if BJIContext.WorldReadyState == 2 then
        -- disable pause on multiplayer
        if bullettime:getPause() then
            --_be:toggleEnabled()
            bullettime.togglePause()
        end

        -- applying environment
        if BJICache.isFirstLoaded(BJICache.CACHES.ENVIRONMENT) then
            _tryApplyTime()
            _tryApplySimSpeed()
            _tryApplyGravity()
        end

        -- remove fog in bigmap view
        if ctxt.camera == BJICam.CAMERAS.BIG_MAP and not BJIAsync.exists("bigmapFog") then
            local oldFog = M.Data.fogDensity
            M.Data.fogDensity = 0
            BJIAsync.task(
                function(ctxt2)
                    return ctxt2.camera ~= BJICam.CAMERAS.BIG_MAP
                end,
                function()
                    M.Data.fogDensity = oldFog
                end,
                "bigmapFog"
            )
        end
    end
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
                if Round(M.Data[k], 4) ~= Round(v, 4) then
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

M.slowTick = slowTick
M.renderTick = renderTick

M.updateCurrentPreset = updateCurrentPreset

RegisterBJIManager(M)
return M
