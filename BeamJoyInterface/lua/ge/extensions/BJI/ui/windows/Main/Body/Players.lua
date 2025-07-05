local maxLineLength = 60
-- gc prevention
local playerColor, actions

local function drawWaiting(cache)
    if #cache.data.players.waiting == 0 then
        return
    end

    Text(cache.labels.players.waiting)
    SameLine()
    Text(string.var("({1}):", { #cache.data.players.waiting }))
    Indent()
    Text(Table(cache.data.players.waiting):reduce(function(acc, player, i)
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
    Unindent()
end

local function drawPlayers(cache, ctxt)
    if #cache.data.players.list == 0 then
        return
    end

    Text(cache.labels.players.list)
    Indent()
    for _, player in ipairs(cache.data.players.list) do
        playerColor = player.self and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT
        Text(player.playerName, { color = playerColor })
        SameLine()
        Text(player.nameSuffix, { color = playerColor })

        actions = BJI.Managers.Scenario.getPlayerListActions(player, ctxt)
        if #actions > 0 then
            for _, action in ipairs(actions) do
                SameLine()
                if IconButton(action.id, action.icon, {
                        btnStyle = action.style,
                        disabled = action.disabled,
                    }) then
                    action.onClick()
                end
                if action.tooltip then
                    TooltipText(action.tooltip)
                end
            end
        end
    end
    Unindent()
end

---@param ctxt TickContext
---@param cache table
return function(ctxt, cache)
    if #cache.data.players.list + #cache.data.players.waiting == 0 then
        Text(cache.labels.loading)
        return
    end

    drawWaiting(cache)
    drawPlayers(cache, ctxt)
end
