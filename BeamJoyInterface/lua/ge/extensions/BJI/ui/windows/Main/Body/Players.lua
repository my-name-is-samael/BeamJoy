local function drawWaiting(cache)
    if table.length(cache.data.players.waiting) == 0 then
        return
    end

    LineBuilder()
        :text(cache.labels.players.waiting)
        :text(string.var("({1}):", { table.length(cache.data.players.waiting) }))
        :build()
    local playerList = ""
    local length = 0
    local maxLineLength = 60
    for i, player in ipairs(cache.data.players.waiting) do
        local playerName = player.playerName
        if i > 1 then
            if length + #playerName + 2 > maxLineLength then
                -- linebreak if cannot add space, playerName and comma
                playerList = string.var("{1}\n", { playerList })
                length = 0
            end
        end

        playerList = string.var("{1} {2}", { playerList, playerName })
        length = length + 1 + #playerName

        if i < table.length(cache.data.players.waiting) then
            playerList = string.var("{1},", { playerList })
        end
    end
    LineBuilder()
        :text(playerList)
        :build()
end

local function drawPlayers(cache, ctxt)
    if #cache.data.players.list == 0 then
        return
    end

    LineBuilder():text(cache.labels.players.list):build()
    Indent(1)
    for _, player in ipairs(cache.data.players.list) do
        local playerColor = player.self and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT
        LineBuilder()
            :text(player.playerName, playerColor)
            :text(player.nameSuffix, playerColor)
            :build()

        Indent(1)
        local actions = BJI.Managers.Scenario.getPlayerListActions(player, ctxt)
        if #actions > 0 then
            local line = LineBuilder(true)
            for _, action in ipairs(actions) do
                if action.icon then
                    line:btnIcon(action)
                elseif action.labelOn then
                    line:btnSwitch(action)
                else
                    line:btn(action)
                end
            end
            line:build()
        end

        Indent(-1)
    end
    Indent(-1)
end

return function(ctxt, cache)
    local waitingPlayers, players = {}, {}
    for playerID, player in pairs(BJI.Managers.Context.Players) do
        if BJI.Managers.Perm.canSpawnVehicle(playerID) then
            table.insert(players, table.clone(player))
        else
            table.insert(waitingPlayers, table.clone(player))
        end
    end
    table.sort(waitingPlayers, function(a, b)
        return a.playerName < b.playerName
    end)
    table.sort(players, function(a, b)
        return a.playerName < b.playerName
    end)

    drawWaiting(cache)
    drawPlayers(cache, ctxt)
end
