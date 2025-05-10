local raceSolo = require("ge/extensions/BJI/ui/WindowRace/RaceSolo")
local raceMulti = require("ge/extensions/BJI/ui/WindowRace/RaceMulti")
local type

local function onLoad()
    type = BJIScenario.is(BJIScenario.TYPES.RACE_SOLO) and raceSolo or raceMulti
    type.onLoad()
end

local function onUnload()
    type.onUnload()
    type = nil
end

local function header(ctxt)
    if type and type.header then
        type.header(ctxt)
    end
end

local function body(ctxt)
    if type and type.body then
        type.body(ctxt)
    end
end

local function footer()
    if type and type.footer then
        return type.footer()
    end
end

return {
    flags = function()
        return {
            WINDOW_FLAGS.NO_COLLAPSE
        }
    end,
    onLoad = onLoad,
    onUnload = onUnload,
    header = header,
    body = body,
    footer = footer,
}
