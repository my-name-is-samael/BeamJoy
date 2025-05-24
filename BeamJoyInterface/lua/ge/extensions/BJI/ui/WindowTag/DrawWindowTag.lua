local function drawHeader(ctxt)
    if BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.TAG_DUO) then
        require("ge/extensions/BJI/ui/WindowTag/TagDuo").header(ctxt)
    end
end

local function drawBody(ctxt)
    if BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.TAG_DUO) then
        require("ge/extensions/BJI/ui/WindowTag/TagDuo").body(ctxt)
    end
end

return {
    header = drawHeader,
    body = drawBody,
}
