local utils = {}

---@return table<string, {type: "int"|"float", min: number, max: number, precision: integer?}>
function utils.numericData()
    return {
        -- SUN
        visibleDistance = { type = "int", min = 1000, max = 32000 },
        shadowDistance = { type = "int", min = 1000, max = 12800 },
        shadowSoftness = { type = "float", min = 0, max = 3, precision = 2 },
        shadowSplits = { type = "int", min = 1, max = 4 },
        shadowLogWeight = { type = "float", min = 0, max = .99, precision = 2 },
        brightness = { type = "float", min = -1, max = 50, precision = 1 },
        sunAzimuthOverride = { type = "int", min = 1, max = 360 },
        moonAzimuth = { type = "int", min = 0, max = 360 },
        sunSize = { type = "float", min = 0, max = 10, precision = 2 },
        moonScale = { type = "float", min = 0, max = 2, precision = 2 },
        skyBrightness = { type = "float", min = 0, max = 100, precision = 1 },
        moonElevation = { type = "float", min = 10, max = 80, precision = 1 },
        rayleighScattering = { type = "float", min = -.002, max = .3 },
        exposure = { type = "float", min = .001, max = 3 },
        flareScale = { type = "float", min = 0, max = 10, precision = 1 },
        occlusionScale = { type = "float", min = 0, max = 1.6, precision = 1 },
        -- WEATHER
        fogDensity = { type = "float", min = 0, max = .1 },
        fogDensityOffset = { type = "int", min = 0, max = 5000 },
        fogAtmosphereHeight = { type = "float", min = 50, max = 2000, precision = 1 },
        cloudHeight = { type = "float", min = 2, max = 20, precision = 2 },
        cloudCover = { type = "float", min = 0, max = 1, precision = 2 },
        cloudSpeed = { type = "float", min = 0, max = 3, precision = 2 },
        cloudExposure = { type = "float", min = .2, max = 5, precision = 1 },
        rainDrops = { type = "int", min = 0, max = 10000 },
        dropSize = { type = "float", min = 0, max = 1, precision = 2 },
        dropMinSpeed = { type = "float", min = .01, max = 5, precision = 2 },
        dropMaxSpeed = { type = "float", min = .01, max = 5, precision = 2 },
        -- GRAVITY
        gravityRate = { type = "float", min = -280, max = 10, precision = 2 },
        --TEMPERATURE
        tempCurveNoon = { type = "int", min = -50, max = 50 },
        tempCurveDusk = { type = "int", min = -50, max = 50 },
        tempCurveMidnight = { type = "int", min = -50, max = 50 },
        tempCurveDawn = { type = "int", min = -50, max = 50 },
        --SPEED
        simSpeed = { type = "float", min = .01, max = 10, precision = 2 },
    }
end

---@return tablelib<integer, {key: string, value: number, default?: boolean}>
function utils.gravityPresets()
    return Table({
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
    })
end

---@return tablelib<integer, {key: string, value: number, default?: boolean}>
function utils.speedPresets()
    return Table({
        { key = "slowextreme", value = 0.01 },
        { key = "slowest",     value = 0.1 },
        { key = "slower",      value = 0.5 },
        { key = "slow",        value = 0.75 },
        { key = "normal",      value = 1,   default = true },
        { key = "fast",        value = 1.25 },
        { key = "faster",      value = 2 },
        { key = "fastest",     value = 5 },
        { key = "fastextreme", value = 10 },
    })
end

---@return tablelib<integer, {label: string, ToD: number, icon: string}>
function utils.timePresets()
    return Table({
        { label = "dawn",     ToD = .791, icon = BJI.Utils.Icon.ICONS.brightness_3 },
        { label = "midday",   ToD = 0,    icon = BJI.Utils.Icon.ICONS.brightness_high },
        { label = "dusk",     ToD = .210, icon = BJI.Utils.Icon.ICONS.brightness_3 },
        { label = "midnight", ToD = .5,   icon = BJI.Utils.Icon.ICONS.brightness_low }
    })
end

---@return tablelib<integer, {label: string, keys: table, icon: string}>
function utils.weatherPresets()
    return Table()
end

return utils
