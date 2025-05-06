local utils = {}

---@return table<string, {step: number, stepFast?: number, min: number, max: number}>
function utils.numericData()
    return {
        -- SUN
        ToD = { step = .001, stepFast = .01, min = 0, max = .999 },
        dayLength = { step = 1, stepFast = 10, min = 1, max = 14400 },
        dayScale = { step = .01, stepFast = .1, min = .01, max = 100 },
        nightScale = { step = .01, stepFast = .1, min = .01, max = 100 },
        sunAzimuthOverride = { step = .1, stepFast = .5, min = .001, max = 6.25 },
        sunSize = { step = .01, stepFast = .1, min = 0, max = 100 },
        skyBrightness = { step = .1, stepFast = 1, min = 0, max = 200 },
        sunLightBrightness = { step = .01, stepFast = .1, min = 0, max = 10 },
        rayleighScattering = { step = .001, stepFast = .005, min = .001, max = .15 },
        flareScale = { step = .01, stepFast = .1, min = 0, max = 25 },
        occlusionScale = { step = .001, stepFast = .01, min = 0, max = 1 },
        exposure = { step = .01, stepFast = .1, min = 0, max = 3 },
        shadowDistance = { step = 1, min = 0, max = 12800 },
        shadowSoftness = { step = .001, stepFast = .01, min = -10, max = 10 },
        shadowSplits = { step = 1, min = 0, max = 4 },
        shadowTexSize = { step = 1, min = 32, max = 2048 },
        shadowLogWeight = { step = .001, stepFast = .01, min = .001, max = .999 },
        visibleDistance = { step = 1, min = 1000, max = 32000 },
        moonAzimuth = { step = .1, stepFast = 1, min = 0, max = 360 },
        moonElevation = { step = .1, stepFast = 1, min = 0, max = 360 },
        moonScale = { step = .001, stepFast = .01, min = .005, max = 1 },
        -- WEATHER
        fogDensity = { step = .001, stepFast = .01, min = 0, max = .2 },
        fogDensityOffset = { step = 1, stepFast = 1000, min = 0, max = 100 },
        fogAtmosphereHeight = { step = 1, stepFast = 1000, min = 0, max = 10000 },
        cloudHeight = { step = 1, stepFast = 1000, min = 0, max = 20 },
        cloudHeightOne = { step = 1, stepFast = 1000, min = 0, max = 20 },
        cloudCover = { step = 1, stepFast = 100, min = 0, max = 5 },
        cloudCoverOne = { step = 1, stepFast = 100, min = 0, max = 5 },
        cloudSpeed = { step = 1, stepFast = 10, min = 0, max = 10 },
        cloudSpeedOne = { step = 1, stepFast = 10, min = 0, max = 10 },
        cloudExposure = { step = 1, stepFast = 10, min = 0, max = 10 },
        cloudExposureOne = { step = 1, stepFast = 10, min = 0, max = 10 },
        rainDrops = { step = 1, stepFast = 20000, min = 0, max = 20000 },
        dropSize = { step = 1, stepFast = 10, min = 0, max = 2 },
        dropMinSpeed = { step = 1, stepFast = 10, min = 0, max = 2 },
        dropMaxSpeed = { step = 1, stepFast = 10, min = 0, max = 2 },
        -- GRAVITY
        gravityRate = { step = .5, stepFast = 10, min = -280, max = 10 },
        --TEMPERATURE
        tempCurveNoon = { step = 1, stepFast = 2, min = -50, max = 50 },
        tempCurveDusk = { step = 1, stepFast = 2, min = -50, max = 50 },
        tempCurveMidnight = { step = 1, stepFast = 2, min = -50, max = 50 },
        tempCurveDawn = { step = 1, stepFast = 2, min = -50, max = 50 },
        --SPEED
        simSpeed = { step = .01, stepFast = .1, min = .01, max = 10 },
    }
end

---@return {key: string, value: number}[]
function utils.gravityPresets()
    return {
        { key = "zero",    value = 0, },
        { key = "pluto",   value = -0.58, },
        { key = "moon",    value = -1.62, },
        { key = "mars",    value = -3.71, },
        { key = "mercury", value = -3.7, },
        { key = "uranus",  value = -8.87, },
        { key = "earth",   value = -9.81,  default = true },
        { key = "saturn",  value = -10.44, },
        { key = "neptune", value = -11.15, },
        { key = "jupiter", value = -24.92, },
        { key = "sun",     value = -274, },
    }
end

---@return {key: string, value: number}[]
function utils.speedPresets()
    return {
        { key = "slowextreme", value = 0.01 },
        { key = "slowest",     value = 0.1 },
        { key = "slower",      value = 0.5 },
        { key = "slow",        value = 0.75 },
        { key = "normal",      value = 1,   default = true },
        { key = "fast",        value = 1.25 },
        { key = "faster",      value = 2 },
        { key = "fastest",     value = 5 },
        { key = "fastextreme", value = 10 },
    }
end

---@return {label: string, ToD: number, icon: string}[]
function utils.timePresets()
    return {
        { label = "dawn",     ToD = .791, icon = ICONS.brightness_3 },
        { label = "midday",   ToD = 0,    icon = ICONS.brightness_high },
        { label = "dusk",     ToD = .210, icon = ICONS.brightness_3 },
        { label = "midnight", ToD = .5,   icon = ICONS.brightness_low }
    }
end

---@return {label: string, keys: table, icon: string}[]
function utils.weatherPresets()
    return {
        {
            label = "clear",
            keys = {
                skyBrightness = 40,
                sunLightBrightness = 1,
                shadowSoftness = .1,
                fogDensity = 0,
                fogDensityOffset = 0,
                fogAtmosphereHeight = 1000,
                cloudHeight = 1.7,
                cloudHeightOne = 2.2,
                cloudCover = .05,
                cloudCoverOne = .03,
                cloudSpeed = .1,
                cloudSpeedOne = .2,
                cloudExposure = 4,
                cloudExposureOne = 6,
                rainDrops = 0,
            },
            icon = ICONS.simobject_sun,
        },
        {
            label = "cloud",
            keys = {
                skyBrightness = 30,
                sunLightBrightness = .5,
                shadowSoftness = 7,
                fogDensity = 0.003,
                fogDensityOffset = 20,
                fogAtmosphereHeight = 1000,
                cloudHeight = 1.15,
                cloudHeightOne = 1.17,
                cloudCover = 5,
                cloudCoverOne = 5,
                cloudSpeed = .8,
                cloudSpeedOne = 1,
                cloudExposure = 8,
                cloudExposureOne = 7,
                rainDrops = 0,
            },
            icon = ICONS.simobject_cloud_layer,
        },
        {
            label = "lightrain",
            keys = {
                skyBrightness = 20,
                sunLightBrightness = .2,
                shadowSoftness = 10,
                fogDensity = 0.001,
                fogDensityOffset = 20,
                fogAtmosphereHeight = 0,
                cloudHeight = 1.15,
                cloudHeightOne = 1.17,
                cloudCover = 5,
                cloudCoverOne = 5,
                cloudSpeed = .4,
                cloudSpeedOne = .6,
                cloudExposure = 3,
                cloudExposureOne = 3,
                rainDrops = 20000,
                dropSize = .15,
                dropMinSpeed = 1.5,
                dropMaxSpeed = 2,
                precipType = "rain_drop",
            },
            icon = ICONS.simobject_precipitation,
        },
        {
            label = "rain",
            keys = {
                skyBrightness = 10,
                sunLightBrightness = 0,
                shadowSoftness = 10,
                fogDensity = 0.008,
                fogDensityOffset = 5,
                fogAtmosphereHeight = 0,
                cloudHeight = 1.15,
                cloudHeightOne = 1.17,
                cloudCover = 5,
                cloudCoverOne = 5,
                cloudSpeed = .4,
                cloudSpeedOne = .6,
                cloudExposure = 3,
                cloudExposureOne = 3,
                rainDrops = 20000,
                dropSize = .5,
                dropMinSpeed = 1.8,
                dropMaxSpeed = 2,
                precipType = "rain_drop",
            },
            icon = ICONS.simobject_precipitation,
        },
        {
            label = "lightsnow",
            keys = {
                skyBrightness = 30,
                sunLightBrightness = .4,
                shadowSoftness = 2,
                fogDensity = 0.001,
                fogDensityOffset = 20,
                fogAtmosphereHeight = 1000,
                cloudHeight = 1.15,
                cloudHeightOne = 1.17,
                cloudCover = .35,
                cloudCoverOne = .1,
                cloudSpeed = .1,
                cloudSpeedOne = .05,
                cloudExposure = 10,
                cloudExposureOne = 10,
                rainDrops = 20000,
                dropSize = 1,
                dropMinSpeed = .1,
                dropMaxSpeed = .3,
                precipType = "Snow_menu",
            },
            icon = ICONS.ac_unit,
        },
        {
            label = "snow",
            keys = {
                skyBrightness = 10,
                sunLightBrightness = 0,
                shadowSoftness = 10,
                fogDensity = 0.01,
                fogDensityOffset = 5,
                fogAtmosphereHeight = 0,
                cloudHeight = 1.15,
                cloudHeightOne = 1.17,
                cloudCover = 2,
                cloudCoverOne = 2,
                cloudSpeed = 0,
                cloudSpeedOne = 0,
                cloudExposure = 0,
                cloudExposureOne = 0,
                rainDrops = 20000,
                dropSize = 2,
                dropMinSpeed = 1.8,
                dropMaxSpeed = 2,
                precipType = "Snow_menu",
            },
            icon = ICONS.ac_unit,
        }
    }
end

return utils
