local sdm

local function drawHeader(ctxt)
    sdm = BJIScenario.get(BJIScenario.TYPES.DELIVERY_MULTI)
    if not sdm then return end

    local self = sdm.participants[BJIContext.User.playerID]
    LineBuilder()
        :text(self.nextTargetReward and
            string.var("{1} : {2}", { BJILang.get("deliveryTogether.streak"), self.streak }) or
            BJILang.get("deliveryTogether.resetted"),
            self.nextTargetReward and TEXT_COLORS.DEFAULT or TEXT_COLORS.ERROR)
        :build()
    if not self.reached and sdm.distance then
        -- distance
        LineBuilder()
            :text(string.var("{1} : {2}", { BJILang.get("deliveryTogether.distance"), PrettyDistance(sdm.distance) }))
            :build()
        if sdm.baseDistance then
            ProgressBar({
                floatPercent = 1 - math.max(sdm.distance / sdm.baseDistance, 0),
                width = 250,
            })
        end
    end
end

local function drawBody(ctxt)
    if not sdm then return end

    Indent(1)
    local cols = ColumnsBuilder("BJIDeliveryMultiParticipants",
        { sdm.ui.playerLabelWidth or 0, -1 })
    for playerID, p in pairs(sdm.participants) do
        local color = BJIContext.isSelf(playerID) and TEXT_COLORS.HIGHLIGHT or TEXT_COLORS.DEFAULT
        cols:addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(sdm.ui.participants[playerID], color)
                        :build()
                end,
                function()
                    LineBuilder()
                        :text(p.reached and BJILang.get("deliveryTogether.arrived") or
                            BJILang.get("deliveryTogether.onTheWay"), color)
                        :text(p.nextTargetReward and
                            string.var("({1} : {2})", { BJILang.get("deliveryTogether.streak"), p.streak }) or
                            string.var("({1})", { BJILang.get("deliveryTogether.resetted") }),
                            p.nextTargetReward and color or TEXT_COLORS.ERROR)
                        :build()
                end,
            }
        })
    end
    cols:build()
    Indent(-1)
end

local function drawFooter(ctxt)
    if not sdm then return end
    LineBuilder()
        :btnIcon({
            id = "deliveryMultiLeave",
            icon = ICONS.exit_to_app,
            style = BTN_PRESETS.ERROR,
            onClick = BJITx.scenario.DeliveryMultiLeave,
        })
        :build()
end

return {
    header = drawHeader,
    body = drawBody,
    footer = drawFooter,
}
