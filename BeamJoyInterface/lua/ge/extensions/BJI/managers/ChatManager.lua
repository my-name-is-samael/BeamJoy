local im = ui_imgui

local M = {
    _name = "BJIChat",
    EVENTS = {
        JOIN = "join",
        LEAVE = "leave",
        PLAYER_CHAT = "playerchat",
        SERVER_CHAT = "serverchat",
        DIRECT_MESSAGE = "directmessage",
        DIRECT_MESSAGE_SENT = "directmessagesent",
    },

    msgCounter = 1,

    init = false, -- wait for chat to be ready before printing messages
    queue = {},
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
    color = color and RGBA(color[1], color[2], color[3], color[4]) or RGBA(1, 1, 1, 1)
    return { [0] = color.x * 255, [1] = color.y * 255, [2] = color.z * 255, [3] = color.w * 255 }
end

local function _onPlayerChat(playerName, message, color)
    local player
    for _, p in pairs(BJIContext.Players) do
        if p.playerName == playerName then
            player = p
            break
        end
    end
    if not player then
        LogError("Invalid player chat data (playerName)", M._name)
        return
    end
    local playerTag = player.staff and BJILang.get("chat.staffTag") or
        svar("{1}{2}", { BJILang.get("chat.reputationTag"), BJIReputation.getReputationLevel(player.reputation) })
    playerName = svar("[{1}]{2}", { playerTag, playerName })

    _printChat(playerName, message, color)
end

local function onChat(event, data)
    table.insert(M.queue, {
        event = event,
        data = data
    })
end

local function renderTick(ctxt)
    if not M.init and BJICache.isFirstLoaded(BJICache.CACHES.LANG) and
        BJIContext.WorldReadyState == 2 and im.GetIO().Framerate > 5 then
        M.init = true
    end

    if M.init and M.queue[1] then
        local event, data = M.queue[1].event, M.queue[1].data
        data.color = parseColor(data.color)
        if event == M.EVENTS.PLAYER_CHAT then
            if not data.message then
                LogError("Invalid player chat data (message)", M._name)
                return
            end
            _onPlayerChat(data.playerName, data.message, data.color)
        elseif event == M.EVENTS.SERVER_CHAT then
            _printChat(nil, data.message, data.color)
        elseif event == M.EVENTS.DIRECT_MESSAGE then
            _printChat(svar(BJILang.get("chat.directMessage"), { playerName = data.playerName }),
                data.message, data.color)
        elseif event == M.EVENTS.DIRECT_MESSAGE_SENT then
            _printChat(svar(BJILang.get("chat.directMessageSent"), { playerName = data.playerName }),
                data.message, data.color)
        elseif tincludes({ M.EVENTS.JOIN, M.EVENTS.LEAVE }, event, true) then
            local key = event == M.EVENTS.JOIN and "chat.playerJoined" or "chat.playerLeft"
            _printChat(nil, svar(BJILang.get(key), { playerName = data.playerName }))
        end
        table.remove(M.queue, 1)
    end
end

local function onUnload()
    M.msgCounter = 1
    M.init = false
    M.queue = {}
end

M.onChat = onChat

M.renderTick = renderTick

M.onUnload = onUnload

RegisterBJIManager(M)
return M
