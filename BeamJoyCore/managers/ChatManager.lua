SetLogType("BJCChat", CONSOLE_COLORS.FOREGROUNDS.LIGHT_GREEN, nil, CONSOLE_COLORS.FOREGROUNDS.LIGHT_GREEN)

local M = {
    EVENTS = {
        PLAYER_CHAT = "playerchat",
        SERVER_CHAT = "serverchat",
        EVENT = "event",
        DIRECT_MESSAGE = "directmessage",
        DIRECT_MESSAGE_SENT = "directmessagesent",
    },

    broadcast = {
        count = 0,
        langsIndices = {},
    },
}

local function init()
    for _, lang in ipairs(BJCLang.getLangsList()) do
        M.broadcast.langsIndices[lang] = 1
    end
end

local function onWelcome(playerID)
    local player = BJCPlayers.Players[playerID]
    local lang = player and player.lang or BJCLang.FallbackLang

    local message = BJCConfig.Data.Server.WelcomeMessage[lang]
    if not message then
        message = BJCConfig.Data.Server.WelcomeMessage[BJCLang.FallbackLang]
    end

    if message then
        M.onServerChat(playerID, message)
    end
end

local function onPlayerConnected(playerID)
    local player = Table(BJCPlayers.Players):find(function(_, pid) return pid == playerID end)
    if player then
        M.sendChatEvent("chat.events.playerJoined", {
            playerName = player.playerName
        })
    end
    onWelcome(playerID)
end

local function onChatMessage(senderID, name, chatMessage)
    local player = BJCPlayers.Players[senderID]
    if not player then
        LogError(BJCLang.getConsoleMessage("players.invalidPlayer"):var({ playerID = senderID }))
        return 1
    end

    local group = BJCGroups.Data[player.group]
    if not group then
        LogError(BJCLang.getConsoleMessage("players.invalidGroup"):var({ group = player.group }))
        return 1
    end

    chatMessage = BJCChatCommand.sanitizeMessage(chatMessage)

    if BJCChatCommand.isCommand(chatMessage) then
        pcall(BJCChatCommand.handle, player, chatMessage:sub(2))
        return 1
    end

    if player.muted or group.muted then
        BJCChat.onServerChat(senderID, BJCLang.getServerMessage(senderID, "players.cantSendMessage"))
        return 1
    end

    table.insert(player.messages, {
        time = GetCurrentTime(),
        message = chatMessage
    })
    Log(string.var("OnChatMessage - {1} : {2}", { player.playerName, chatMessage }), "BJCChat")
    -- send to mods+ players cache invalidation
    BJCTx.cache.invalidateByPermissions(BJCCache.CACHES.PLAYERS, BJCPerm.PERMISSIONS.KICK)

    BJCTx.player.chat(BJCTx.ALL_PLAYERS, M.EVENTS.PLAYER_CHAT, {
        playerName = player.playerName,
        message = chatMessage,
    })
    return 1
end

local function onServerChat(targetID, message, color)
    local target, targetName = { lang = BJCLang.FallbackLang }, ""
    if targetID == BJCTx.ALL_PLAYERS then
        targetName = BJCLang.getConsoleMessage("common.allPlayers")
    else
        target = BJCPlayers.Players[targetID]
        targetName = target and target.playerName or string.var("? (id = {1})", { targetID })
    end
    Log(BJCLang.getConsoleMessage("messages.serverBroadcast"):var({
        targetName = string.var("{1} ({2})", { targetName, target.lang }),
        message = message,
    }), "BJCChat")

    BJCTx.player.chat(targetID, M.EVENTS.SERVER_CHAT, {
        message = message,
        color = color,
    })
end

local function sendChatEvent(eventKey, eventData, color)
    BJCTx.player.chat(BJCTx.ALL_PLAYERS, M.EVENTS.EVENT, {
        event = eventKey,
        data = eventData,
        color = color or { .6, .6, .6, 1 }, -- RGBA (COLORS NOT WORKING YET IN THE CHAT)
    })
end

local function onPlayerDisconnect(playerID, playerName)
    M.sendChatEvent("chat.events.playerLeft", {
        playerName = playerName
    })
end

local function broadcastTick()
    M.broadcast.count = M.broadcast.count + 1
    if M.broadcast.count >= BJCConfig.Data.Server.Broadcasts.delay then
        M.broadcast.count = 0
        local color = { .2, 1, .2, 1 } -- RGBA (COLORS NOT WORKING YET IN THE CHAT)

        for _, player in pairs(BJCPlayers.Players) do
            local broads = BJCConfig.Data.Server.Broadcasts[player.lang]
            local index = M.broadcast.langsIndices[player.lang]
            if broads and broads[index] then
                onServerChat(player.playerID, broads[index], color)
            end
        end

        -- offset broads
        for lang, i in pairs(M.broadcast.langsIndices) do
            if BJCConfig.Data.Server.Broadcasts[lang] and
                #BJCConfig.Data.Server.Broadcasts[lang] > 0 then
                M.broadcast.langsIndices[lang] = (i % #BJCConfig.Data.Server.Broadcasts[lang]) + 1
            end
        end
    end
end

BJCEvents.addListener(BJCEvents.EVENTS.PLAYER_CONNECTED, onPlayerConnected, "ChatManager")
BJCEvents.addListener(BJCEvents.EVENTS.MP_CHAT_MESSAGE, onChatMessage, "ChatManager")
M.onServerChat = onServerChat
M.sendChatEvent = sendChatEvent
M.onPlayerDisconnect = onPlayerDisconnect

BJCEvents.addListener(BJCEvents.EVENTS.SLOW_TICK, broadcastTick, "ChatManager")


init()
return M
