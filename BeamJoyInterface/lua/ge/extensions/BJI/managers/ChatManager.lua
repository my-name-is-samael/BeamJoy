local tag = "BJIChat"

local M = {
    EVENTS = {
        JOIN = "join",
        LEAVE = "leave",
        PLAYER_CHAT = "playerchat",
        SERVER_CHAT = "serverchat",
        DIRECT_MESSAGE = "directmessage",
    },

    msgCounter = 1,
}
local chatWindow = require("multiplayer.ui.chat")

-- color is not working for now
local function _printChat(senderName, message, color)
    guihooks.trigger("chatMessage", {
        id = M.msgCounter,
        color = color,
        message = senderName and svar("{1}: {2}", { senderName, message }) or message,
    })
    chatWindow.addMessage(senderName or "", message, M.msgCounter, color)

    M.msgCounter = M.msgCounter + 1
end

local function parseColor(color)
    color = type(color) == "cdata" and color or RGBA(1, 1, 1, 1)
    return { [0] = color.x * 255, [1] = color.y * 255, [2] = color.z * 255, [3] = color.w * 255 }
end

local function _onPlayerChat(playerName, message, color)
    color = parseColor(color)

    local player
    for _, p in pairs(BJIContext.Players) do
        if p.playerName == playerName then
            player = p
            break
        end
    end
    if not player then
        LogError("Invalid player chat data (playerName)", tag)
        return
    end
    local playerTag = player.staff and BJILang.get("chat.staffTag") or
        svar("{1}{2}", { BJILang.get("chat.reputationTag"), BJIReputation.getReputationLevel(player.reputation) })
    playerName = svar("[{1}]{2}", { playerTag, playerName })

    _printChat(playerName, message, color)
end

local function onChat(event, data)
    data.color = parseColor(data.color)

    if event == M.EVENTS.PLAYER_CHAT then
        if not data.message then
            LogError("Invalid player chat data (message)", tag)
            return
        end
        _onPlayerChat(data.playerName, data.message, data.color)
    elseif event == M.EVENTS.SERVER_CHAT then
        _printChat(nil, data.message, data.color)
    elseif event == M.EVENTS.DIRECT_MESSAGE then
        local playerName, message = data.playerName, data.message
        _printChat(svar(BJILang.get("chat.directMessage", { playerName = playerName })), message)
    elseif tincludes({ M.EVENTS.JOIN, M.EVENTS.LEAVE }, event, true) then
        local key = event == M.EVENTS.JOIN and "chat.playerJoined" or "chat.playerLeft"
        _printChat(nil, svar(BJILang.get(key), { playerName = data.playerName }))
    end
end

M.onChat = onChat

RegisterBJIManager(M)
return M
