local function drawWaiting(cache)
    if table.length(cache.data.players.waiting) == 0 then
        return
    end

    LineBuilder():text(cache.labels.players.waiting):text(string.var("({1}):", {
        table.length(cache.data.players.waiting) })):build()
    local maxLineLength = 60
    Indent(1)
    LineLabel(Table(cache.data.players.waiting):reduce(function(acc, player, i)
        if i > 1 and acc.curr + #player.playerName > maxLineLength then
            acc.res = acc.res .. "\n"
            acc.curr = 0
        end
        if i > 1 then
            acc.res = acc.res .. ", "
            acc.curr = acc.curr + 2
        end
        acc.res = acc.res .. player.playerName
        acc.curr = acc.curr + #player.playerName
        return acc
    end, { res = "", curr = 0 }).res)
    Indent(-1)
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

---@param ctxt TickContext
---@param cache table
return function(ctxt, cache)
    local waitingPlayers, players = {}, {}
    ctxt.players:forEach(function(player, playerID)
        table.insert(BJI.Managers.Perm.canSpawnVehicle(playerID) and
            players or waitingPlayers, table.clone(player))
    end)
    table.sort(waitingPlayers, function(a, b)
        return a.playerName < b.playerName
    end)
    table.sort(players, function(a, b)
        return a.playerName < b.playerName
    end)

    drawWaiting(cache)
    drawPlayers(cache, ctxt)
end
