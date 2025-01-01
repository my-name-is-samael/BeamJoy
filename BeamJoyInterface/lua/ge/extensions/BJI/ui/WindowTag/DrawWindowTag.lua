local function drawHeader(ctxt)
    if BJIScenario.is(BJIScenario.TYPES.TAG_DUO) then
        require("ge/extensions/BJI/ui/WindowTag/TagDuo").header(ctxt)
    end
end

local function drawBody(ctxt)
    if BJIScenario.is(BJIScenario.TYPES.TAG_DUO) then
        require("ge/extensions/BJI/ui/WindowTag/TagDuo").body(ctxt)
    end
end

return {
    header = drawHeader,
    body = drawBody,
}
