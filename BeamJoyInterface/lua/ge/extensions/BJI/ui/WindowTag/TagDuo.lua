local mgr, opponentID

local function drawHeader(ctxt)
    mgr = BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.TAG_SOLO)

    local line = LineBuilder()
        :text("Tag Duo")
    if table.length(mgr.selfLobby.players) == 1 then
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
        line:text(string.var("with {1}", { BJI.Managers.Context.Players[opponentID].playerName }))
    end
    line:build()
    EmptyLine()

    if mgr.waitForSpread then -- waiting for spread to begin
        LineBuilder()
            :text("Spread out to begin the chase !", BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT)
            :build()
    elseif mgr.tagMessage then -- recent tag
        LineBuilder()
            :text("Tagged !", BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT)
            :build()
    elseif mgr.isTagger() then -- tagger
        LineBuilder()
            :text("Chase your opponent !", BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT)
            :build()
    else -- tagged
        LineBuilder()
            :text("Flee from your opponent !", BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT)
            :build()
    end
    EmptyLine()
end

local function drawBody(ctxt)
    LineBuilder()
        :btnIcon({
            id = "tagLeave",
            icon = ICONS.exit_to_app,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            onClick = function()
                if BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.TAG_SOLO) then
                    BJI.Tx.scenario.TagDuoLeave()
                end
            end,
        })
        :build()

    local lobbies = {}
    for i, l in pairs(mgr.lobbies) do
        if not l.players[ctxt.user.playerID] and table.length(l.players) < 2 then
            table.insert(lobbies, {
                id = i,
                host = l.host,
            })
        end
    end
    if #lobbies > 0 then
        LineBuilder()
            :text("Join an available lobby :")
            :build()
        for i, l in ipairs(lobbies) do
            LineBuilder()
                :btnIcon({
                    id = string.var("joinLobby-{1}", { i }),
                    icon = ICONS.videogame_asset,
                    style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                    onClick = function()
                        BJI.Tx.scenario.TagDuoLeave()
                        BJI.Managers.Async.delayTask(function() -- clears properly the scenario with a delay
                            BJI.Tx.scenario.TagDuoJoin(l.id, ctxt.veh:getID())
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
