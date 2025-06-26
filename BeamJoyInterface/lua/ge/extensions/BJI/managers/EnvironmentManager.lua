---@class BJIManagerEnvironment : BJIManager
local M = {
    _name = "Env",

    baseFunctions = {},

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
        fogDensity = .001,
        fogColor = { .66, .87, .99 },
        fogDensityOffset = 2,
        fogAtmosphereHeight = 1000,
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
    cachedWorldObjects = {
        ---@type table?
        LevelInfo = nil,
        ---@type table?
        ScatterSky = nil,
        ---@type table?
        CloudLayer = nil,
        ---@type table?
        Precipitation = nil,
        ---@type table?
        WaterPlane = nil,
    },
    init = false,    -- true if env is applied at least once after joining

    ToDEdit = false, -- flag when editing ToD in env configurator window

    PRECIP_TYPES = { "rain_medium", "rain_drop", "Snow_menu" },
    duskLimits = { .245, .25 },
    dawnLimits = { .75, .755 },
    freecamFogLimits = { min = 700, max = 1300 },
    freecamFogEnabled = false,
}

local function cacheWorldObjects()
    Table({ "LevelInfo", "ScatterSky", "CloudLayer", "Precipitation", "WaterPlane" })
        :forEach(function(k)
            local names = scenetree.findClassObjects(k)
            if names and table.length(names) > 0 then
                for _, name in pairs(names) do
                    local obj = scenetree.findObject(name)
                    if obj then
                        M.cachedWorldObjects[k] = obj
                    end
                end
            end
        end)
end

--- Fog color needs to be applied after core_env update
local function applyFogColor()
    local newFogColor = Point4F(M.Data.fogColor[1],
        M.Data.fogColor[2], M.Data.fogColor[3], 1)
    if M.cachedWorldObjects.LevelInfo then
        M.cachedWorldObjects.LevelInfo.visibleDistance = M.Data.visibleDistance
        M.cachedWorldObjects.LevelInfo.fogColor = newFogColor
        M.cachedWorldObjects.LevelInfo:postApply()
    end

    if M.cachedWorldObjects.ScatterSky then
        M.cachedWorldObjects.ScatterSky.fogScale = newFogColor
        M.cachedWorldObjects.ScatterSky:postApply()
    end
end

local function _tryApplyTime()
    if M.Data.controlSun then
        local ToD = core_environment.getTimeOfDay()
        if ToD then
            ToD.time = M.Data.ToD
            core_environment.setTimeOfDay(ToD)
            if M.Data.controlWeather then
                applyFogColor()
            end
        end
    end
end

local function tryApplyTimeFromServer(ToD)
    if not M.ToDEdit and ToD ~= nil and
        M.Data.controlSun and
        math.abs(M.Data.ToD - ToD) > .0001 then
        -- sync only if client got offset
        M.Data.ToD = ToD
    end
end

local function _tryApplyDayNightSunValues()
    local ToD = core_environment.getTimeOfDay()
    if not M.cachedWorldObjects.ScatterSky or not ToD then
        return
    end
    if ToD.time > M.duskLimits[1] and ToD.time <= M.duskLimits[2] then
        -- dusk
        M.cachedWorldObjects.ScatterSky.brightness = math.scale(ToD.time, M.duskLimits[1], M.duskLimits[2],
            M.Data.skyDay.brightness,
            M.Data.skyNight.brightness)
    elseif ToD.time > M.duskLimits[2] and ToD.time <= M.dawnLimits[1] then
        -- night
        M.cachedWorldObjects.ScatterSky.brightness = M.Data.skyNight.brightness
        M.cachedWorldObjects.ScatterSky.moonAzimuth = (M.Data.skyNight.moonAzimuth +
            math.scale(ToD.time, M.duskLimits[2], M.dawnLimits[1], -45, 45) + 360) % 360
    elseif ToD.time > M.dawnLimits[1] and ToD.time <= M.dawnLimits[2] then
        -- dawn
        M.cachedWorldObjects.ScatterSky.brightness = math.scale(ToD.time, M.dawnLimits[1], M.dawnLimits[2],
            M.Data.skyNight.brightness,
            M.Data.skyDay.brightness)
    else
        -- day
        M.cachedWorldObjects.ScatterSky.brightness = M.Data.skyDay.brightness
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
            if M.Data.controlWeather then
                applyFogColor()
            end
        end

        if M.cachedWorldObjects.ScatterSky then
            local core = { M.cachedWorldObjects.ScatterSky.shadowDistance, M.cachedWorldObjects.ScatterSky
                .shadowSoftness, M.cachedWorldObjects.ScatterSky.numSplits,
                M.cachedWorldObjects.ScatterSky.texSize, M.cachedWorldObjects.ScatterSky.logWeight, M.cachedWorldObjects
                .ScatterSky.sunSize, M.cachedWorldObjects.ScatterSky.skyBrightness,
                M.cachedWorldObjects.ScatterSky.rayleighScattering, M.cachedWorldObjects.ScatterSky.exposure, M
                .cachedWorldObjects.ScatterSky.flareScale,
                M.cachedWorldObjects.ScatterSky.occlusionScale, M.cachedWorldObjects.ScatterSky.moonElevation, M
                .cachedWorldObjects.ScatterSky.moonScale }
            local cached = { M.Data.shadowDistance, M.Data.shadowSoftness, M.Data.shadowSplits, M.Data.shadowTexSize,
                M.Data.shadowLogWeight, M.Data.skyDay.sunSize, M.Data.skyDay.skyBrightness,
                M.Data.skyDay.rayleighScattering, M.Data.skyDay.exposure, M.Data.skyDay.flareScale,
                M.Data.skyDay.occlusionScale, M.Data.skyNight.moonElevation, M.Data.skyNight.moonScale }
            if not table.compare(core, cached) then
                M.cachedWorldObjects.ScatterSky.shadowDistance = M.Data.shadowDistance
                M.cachedWorldObjects.ScatterSky.shadowSoftness = M.Data.shadowSoftness
                M.cachedWorldObjects.ScatterSky.numSplits = M.Data.shadowSplits
                M.cachedWorldObjects.ScatterSky.texSize = M.Data.shadowTexSize
                M.cachedWorldObjects.ScatterSky.logWeight = M.Data.shadowLogWeight
                M.cachedWorldObjects.ScatterSky.sunSize = M.Data.skyDay.sunSize
                M.cachedWorldObjects.ScatterSky.skyBrightness = M.Data.skyDay.skyBrightness
                M.cachedWorldObjects.ScatterSky.rayleighScattering = M.Data.skyDay.rayleighScattering
                M.cachedWorldObjects.ScatterSky.exposure = M.Data.skyDay.exposure
                M.cachedWorldObjects.ScatterSky.flareScale = M.Data.skyDay.flareScale
                M.cachedWorldObjects.ScatterSky.occlusionScale = M.Data.skyDay.occlusionScale
                M.cachedWorldObjects.ScatterSky.moonElevation = M.Data.skyNight.moonElevation
                M.cachedWorldObjects.ScatterSky.moonScale = M.Data.skyNight.moonScale
                M.cachedWorldObjects.ScatterSky:postApply()
            end
        end

        if M.cachedWorldObjects.LevelInfo and M.cachedWorldObjects.LevelInfo.visibleDistance ~= M.Data.visibleDistance then
            M.cachedWorldObjects.LevelInfo.visibleDistance = M.Data.visibleDistance
            M.cachedWorldObjects.LevelInfo:postApply()
        end
    end
end

local function _tryApplyWeather()
    if M.Data.controlWeather then
        local core = { core_environment.getFogDensity(), core_environment.getFogDensityOffset(), core_environment
            .getFogAtmosphereHeight() }
        local cached = { M.Data.fogDensity, M.Data.fogDensityOffset, M.Data.fogAtmosphereHeight }
        if not table.compare(core, cached) then
            core_environment.setFogDensity(M.Data.fogDensity)
            core_environment.setFogDensityOffset(M.Data.fogDensityOffset)
            core_environment.setFogAtmosphereHeight(M.Data.fogAtmosphereHeight)
            applyFogColor()
        end

        if M.cachedWorldObjects.CloudLayer then
            local id = M.cachedWorldObjects.CloudLayer:getId()
            core = { core_environment.getCloudHeightByID(id), core_environment.getCloudHeightByID(id + 1),
                core_environment.getCloudCoverByID(id), core_environment.getCloudCoverByID(id + 1),
                core_environment.getCloudWindByID(id), core_environment.getCloudWindByID(id + 1),
                core_environment.getCloudExposureByID(id), core_environment.getCloudExposureByID(id + 1) }
            cached = { M.Data.cloudHeight, M.Data.cloudHeightOne, M.Data.cloudCover, M.Data.cloudCoverOne,
                M.Data.cloudSpeed, M.Data.cloudSpeedOne, M.Data.cloudExposure, M.Data.cloudExposureOne }
            if not table.compare(core, cached) then
                core_environment.setCloudHeightByID(id, M.Data.cloudHeight)
                core_environment.setCloudHeightByID(id + 1, M.Data.cloudHeightOne)
                core_environment.setCloudCoverByID(id, M.Data.cloudCover)
                core_environment.setCloudCoverByID(id + 1, M.Data.cloudCoverOne)
                core_environment.setCloudWindByID(id, M.Data.cloudSpeed)
                core_environment.setCloudWindByID(id + 1, M.Data.cloudSpeedOne)
                core_environment.setCloudExposureByID(id, M.Data.cloudExposure)
                core_environment.setCloudExposureByID(id + 1, M.Data.cloudExposureOne)
            end
        end

        if M.cachedWorldObjects.Precipitation then
            core = { M.cachedWorldObjects.Precipitation.numDrops, M.cachedWorldObjects.Precipitation.dropSize, M
                .cachedWorldObjects.Precipitation.minSpeed, M.cachedWorldObjects.Precipitation.maxSpeed }
            cached = { M.Data.rainDrops, M.Data.dropSize, M.Data.dropMinSpeed, M.Data.dropMaxSpeed }
            local compared = table.compare(core, cached)
            if not compared then
                M.cachedWorldObjects.Precipitation.numDrops = M.Data.rainDrops
                M.cachedWorldObjects.Precipitation.dropSize = M.Data.dropSize
                M.cachedWorldObjects.Precipitation.minSpeed = M.Data.dropMinSpeed
                M.cachedWorldObjects.Precipitation.maxSpeed = M.Data.dropMaxSpeed
                if table.includes(M.PRECIP_TYPES, M.Data.precipType) then
                    M.cachedWorldObjects.Precipitation.dataBlock = scenetree.findObject(M.Data.precipType)
                end
            end
        end
    end
end

local function _tryApplyTemperature()
    if M.Data.useTempCurve then
        if M.cachedWorldObjects.LevelInfo then
            M.cachedWorldObjects.LevelInfo:setTemperatureCurveC({
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

local function slowTick(ctxt)
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
    end
end

---@param ctxt TickContext
local function checkFreecamFog(ctxt)
    local isFlightCam = table.includes({
        BJI.Managers.Cam.CAMERAS.FREE,
        BJI.Managers.Cam.CAMERAS.BIG_MAP,
    }, ctxt.camera)
    local camPos = BJI.Managers.Cam.getPositionRotation().pos
    local waterLevel = M.cachedWorldObjects.WaterPlane and
        tonumber(tostring(M.cachedWorldObjects.WaterPlane.position):split2(", ")[10]) or 0
    local elevation = camPos.z - waterLevel
    if camPos.z > waterLevel then
        local surfaceDiff = be:getSurfaceHeightBelow(camPos)
        if surfaceDiff > 0 then
            elevation = camPos.z - surfaceDiff
        end
    end

    if M.freecamFogEnabled then
        if not isFlightCam or
            elevation < M.freecamFogLimits.min then
            M.freecamFogEnabled = false
            _tryApplyWeather()
        end
    else
        if isFlightCam and
            elevation >= M.freecamFogLimits.min then
            M.freecamFogEnabled = true
        end
    end

    if M.freecamFogEnabled then
        core_environment.setFogDensity(math.scale(elevation, M.freecamFogLimits.min, M.freecamFogLimits.max,
            M.Data.fogDensity, 0, true))
        applyFogColor()

        if M.cachedWorldObjects.LevelInfo.visibleDistance < 20000 then
            M.cachedWorldObjects.LevelInfo.visibleDistance = math.scale(elevation, M.freecamFogLimits.min,
                M.freecamFogLimits.max,
                M.Data.visibleDistance, 20000, true)
            M.cachedWorldObjects.LevelInfo:postApply()
        end
    end
end

local lastRenderTick = nil
local lastToD = nil
---@param ctxt TickContext
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
                local step = (.5 / partDuration) * (delta / 1000)
                if M.Data.controlSimSpeed and M.Data.simSpeed ~= 1 then
                    step = step * M.Data.simSpeed
                end
                M.Data.ToD = math.round((M.Data.ToD + step) % 1, 7)
                _tryApplyTime()
            end
            lastRenderTick = ctxt.now
        end

        if not lastToD or lastToD ~= M.Data.ToD then -- on ToD change (timePlay or server change)
            _tryApplyDayNightSunValues()
        end
        lastToD = M.Data.ToD

        checkFreecamFog(ctxt)
    end
end

local function initNGFunctionsWrappers()
    M.baseFunctions = {
        simTimeAuthority = {
            set = extensions.simTimeAuthority.set
        },
    }

    extensions.simTimeAuthority.set = function(val)
        if not M.Data.controlSimSpeed then
            M.baseFunctions.simTimeAuthority.set(val)
        end
    end
end

local function onUnload()
    RollBackNGFunctionsWrappers(M.baseFunctions)
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
            M.forceUpdate()
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.ENV_CHANGED, {
                keys = keysChanged
            })
        end
    end)

    BJI.Managers.Async.task(function()
        return BJI.Managers.Context.WorldReadyState == 2
    end, cacheWorldObjects)

    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.ON_POST_LOAD, initNGFunctionsWrappers, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.ON_UNLOAD, onUnload, M._name)

    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.SLOW_TICK, slowTick, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.FAST_TICK, fastTick, M._name)
end

local function getTime()
    return core_environment.getTimeOfDay()
end

local function getTemperature()
    return core_environment.getTemperatureK()
end

M.getTime = getTime
M.getTemperature = getTemperature
M.tryApplyTimeFromServer = tryApplyTimeFromServer
M.forceUpdate = forceUpdate

M.renderTick = renderTick

M.onLoad = onLoad

return M
