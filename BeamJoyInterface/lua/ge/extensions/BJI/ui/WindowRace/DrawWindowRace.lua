local function drawHeader(ctxt)
    if BJIScenario.is(BJIScenario.TYPES.RACE_SOLO) then
        require("ge/extensions/BJI/ui/WindowRace/RaceSolo").header(ctxt)
    elseif BJIScenario.is(BJIScenario.TYPES.RACE_MULTI) then
        require("ge/extensions/BJI/ui/WindowRace/RaceMulti").header(ctxt)
    end
end

local function drawBody(ctxt)
    if BJIScenario.is(BJIScenario.TYPES.RACE_SOLO) then
        require("ge/extensions/BJI/ui/WindowRace/RaceSolo").body(ctxt)
    elseif BJIScenario.is(BJIScenario.TYPES.RACE_MULTI) then
        require("ge/extensions/BJI/ui/WindowRace/RaceMulti").body(ctxt)
    end
end

return {
    flags = function()
        return {
            WINDOW_FLAGS.NO_COLLAPSE
        }
    end,
    header = drawHeader,
    body = drawBody,
}
