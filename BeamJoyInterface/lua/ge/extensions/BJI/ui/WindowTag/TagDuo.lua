local mgr, opponentID

local function drawHeader(ctxt)
    mgr = BJIScenario.get(BJIScenario.TYPES.TAG_SOLO)

    local line = LineBuilder()
        :text("Tag Duo")
    if tlength(mgr.selfLobby.players) == 1 then
        opponentID = nil
        line:text("(Waiting for an opponent)")
    else
        if not opponentID then
            for id, p in pairs(mgr.selfLobby.players) do
                if p.veh:getID() ~= ctxt.veh:getID() then
                    opponentID = id
                    break
                end
            end
        end
        line:text(svar("with {1}", { BJIContext.Players[opponentID].playerName }))
    end
    line:build()
    EmptyLine()

    if mgr.waitForSpread then -- waiting for spread to begin
        LineBuilder()
            :text("Spread out to begin the chase !", TEXT_COLORS.HIGHLIGHT)
            :build()
    elseif mgr.tagMessage then -- recent tag
        LineBuilder()
            :text("Tagged !", TEXT_COLORS.HIGHLIGHT)
            :build()
    elseif mgr.isTagger() then -- tagger
        LineBuilder()
            :text("Chase your opponent !", TEXT_COLORS.HIGHLIGHT)
            :build()
    else -- tagged
        LineBuilder()
            :text("Flee from your opponent !", TEXT_COLORS.HIGHLIGHT)
            :build()
    end
    EmptyLine()
end

local function drawBody(ctxt)
    LineBuilder()
        :btnIcon({
            id = "tagLeave",
            icon = ICONS.exit_to_app,
            style = BTN_PRESETS.ERROR,
            onClick = function()
                if BJIScenario.is(BJIScenario.TYPES.TAG_SOLO) then
                    BJITx.scenario.TagDuoLeave()
                end
            end,
        })
        :build()

    local lobbies = {}
    for i, l in pairs(mgr.lobbies) do
        if not l.players[ctxt.user.playerID] and tlength(l.players) < 2 then
            table.insert(lobbies, {
                id = i,
                host = l.host,
            })
        end
    end
    if #lobbies > 0 then
        LineBuilder()
            :title("Join an available lobby :")
            :build()
        for i, l in ipairs(lobbies) do
            LineBuilder()
                :btnIcon({
                    id = svar("joinLobby-{1}", { i }),
                    icon = ICONS.videogame_asset,
                    style = BTN_PRESETS.SUCCESS,
                    onClick = function()
                        BJITx.scenario.TagDuoLeave()
                        BJIAsync.delayTask(function() -- clears properly the scenario with a delay
                            BJITx.scenario.TagDuoJoin(l.id, ctxt.veh:getID())
                        end, 500, "BJITagDuoChangeLobbyDelay")
                    end,
                })
        end
    end
end

return {
    header = drawHeader,
    body = drawBody,
}
