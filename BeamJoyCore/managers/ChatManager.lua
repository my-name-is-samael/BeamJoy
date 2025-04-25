SetLogType("BJCChat", CONSOLE_COLORS.FOREGROUNDS.LIGHT_GREEN, nil, CONSOLE_COLORS.FOREGROUNDS.LIGHT_GREEN)

local M = {
    EVENTS = {
        JOIN = "join",
        LEAVE = "leave",
        PLAYER_CHAT = "playerchat",
        SERVER_CHAT = "serverchat",
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

local function onPlayerJoin(playerID, playerName)
    BJCTx.player.chat(BJCTx.ALL_PLAYERS, M.EVENTS.JOIN, {
        playerName = playerName,
    })
    onWelcome(playerID)
end

local function onPlayerChat(playerName, message)
    BJCTx.player.chat(BJCTx.ALL_PLAYERS, M.EVENTS.PLAYER_CHAT, {
        playerName = playerName,
        message = message,
    })
end

local function onServerChat(targetID, message, color)
    local targetName = ""
    if targetID == BJCTx.ALL_PLAYERS then
        targetName = BJCLang.getConsoleMessage("common.allPlayers")
    else
        local target = BJCPlayers.Players[targetID]
        targetName = target and target.playerName or svar("? (id = {1})", { targetID })
    end
    Log(svar(BJCLang.getConsoleMessage("messages.serverBroadcast"), {
        targetName = targetName,
        message = message,
    }), "BJCChat")

    BJCTx.player.chat(targetID, M.EVENTS.SERVER_CHAT, {
        message = message,
        color = color,
    })
end

local function onPlayerDisconnect(playerID, playerName)
    BJCAsync.delayTask(function()
        BJCTx.player.chat(BJCTx.ALL_PLAYERS, M.EVENTS.LEAVE, {
            playerName = playerName,
        })
    end, 1)
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

M.onPlayerJoin = onPlayerJoin
M.onPlayerChat = onPlayerChat
M.onServerChat = onServerChat
M.onPlayerDisconnect = onPlayerDisconnect

M.broadcastTick = broadcastTick

init()

RegisterBJCManager(M)
return M
