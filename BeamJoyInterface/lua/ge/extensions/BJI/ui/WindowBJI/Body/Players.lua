local function drawWaiting(players)
    LineBuilder()
        :text(BJILang.get("playersBlock.waitingPlayers"))
        :text(svar("({1}):", { tlength(players) }))
        :build()
    local playerList = ""
    local length = 0
    local maxLineLength = 60
    for i, player in ipairs(players) do
        local playerName = player.playerName
        if i > 1 then
            if length + #playerName + 2 > maxLineLength then
                -- linebreak if cannot add space, playerName and comma
                playerList = svar("{1}\n", { playerList })
                length = 0
            end
        end

        playerList = svar("{1} {2}", { playerList, playerName })
        length = length + 1 + #playerName

        if i < tlength(players) then
            playerList = svar("{1},", { playerList })
        end
    end
    LineBuilder()
        :text(playerList)
        :build()
end

local function drawPlayers(players, ctxt)
    LineBuilder()
        :text(svar("{1}:", { BJILang.get("playersBlock.players") }))
        :build()
    Indent(1)
    for _, player in ipairs(players) do
        local playerTag = player.staff and
            BJILang.get("chat.staffTag") or
            svar("{1}{2}", {
                BJILang.get("chat.reputationTag"),
                BJIReputation.getReputationLevel(player.reputation)
            })
        local playerColor = BJIContext.isSelf(player.playerID) and TEXT_COLORS.HIGHLIGHT or TEXT_COLORS.DEFAULT
        LineBuilder()
            :text(player.playerName, playerColor)
            :text(svar("({1})", { playerTag }), playerColor)
            :build()

        Indent(1)
        local actions = BJIScenario.getPlayerListActions(player, ctxt)
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

local function draw(ctxt)
    local waitingPlayers, players = {}, {}
    for playerID, player in pairs(BJIContext.Players) do
        if BJIPerm.canSpawnVehicle(playerID) then
            table.insert(players, tdeepcopy(player))
        else
            table.insert(waitingPlayers, tdeepcopy(player))
        end
    end
    table.sort(waitingPlayers, function(a, b)
        return a.playerName < b.playerName
    end)
    table.sort(players, function(a, b)
        return a.playerName < b.playerName
    end)

    if #waitingPlayers > 0 then
        drawWaiting(waitingPlayers)
    end

    if #players > 0 then
        drawPlayers(players, ctxt)
    end
end
return draw
