local im = ui_imgui

---@class BJIManagerChat : BJIManager
local M = {
    _name = "Chat",

    EVENTS = {
        PLAYER_CHAT = "playerchat",
        SERVER_CHAT = "serverchat",
        EVENT = "event",
        DIRECT_MESSAGE = "directmessage",
        DIRECT_MESSAGE_SENT = "directmessagesent",
    },

    msgCounter = 1,
    queue = {},
}
local chatWindow = require("multiplayer.ui.chat")

-- color is not working for now
local function _printChat(senderName, message, color)
    guihooks.trigger("chatMessage", {
        id = M.msgCounter,
        color = color,
        message = senderName and string.var("{1}: {2}", { senderName, message }) or message,
    })
    chatWindow.addMessage(senderName or "", message, M.msgCounter, color)

    M.msgCounter = M.msgCounter + 1
end

local function parseColor(color)
    color = color and BJI.Utils.Style.RGBA(color[1], color[2], color[3], color[4]) or BJI.Utils.Style.RGBA(1, 1, 1, 1)
    return { [0] = color.x * 255, [1] = color.y * 255, [2] = color.z * 255, [3] = color.w * 255 }
end

local function _onPlayerChat(playerName, message, color)
    local player
    for _, p in pairs(BJI.Managers.Context.Players) do
        if p.playerName == playerName then
            player = p
            break
        end
    end
    if not player then
        LogError("Invalid player chat data (playerName)", M._name)
        return
    end
    local playerTag = player.staff and BJI.Managers.Lang.get("chat.staffTag") or
        string.var("{1}{2}",
            { BJI.Managers.Lang.get("chat.reputationTag"), BJI.Managers.Reputation.getReputationLevel(player.reputation) })
    playerName = string.var("[{1}]{2}", { playerTag, playerName })

    _printChat(playerName, message, color)
end

---@param eventKey string
---@param data table
local function printChatEvent(eventKey, data, color)
    local str = BJI.Managers.Lang.get(eventKey)
    data = Table(data):map(function(s)
        return BJI.Managers.Lang.get(tostring(s), tostring(s))
    end)
    str = string.var(str, data)

    _printChat(nil, str, color)
end

local function onChat(event, data)
    table.insert(M.queue, {
        event = event,
        data = data
    })
end

local function fastTick(ctxt)
    if BJI.Managers.Cache.isFirstLoaded(BJI.Managers.Cache.CACHES.LANG) and M.queue[1] then
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
            _printChat(BJI.Managers.Lang.get("chat.directMessage"):var({ playerName = data.playerName }),
                data.message, data.color)
        elseif event == M.EVENTS.DIRECT_MESSAGE_SENT then
            _printChat(BJI.Managers.Lang.get("chat.directMessageSent"):var({ playerName = data.playerName }),
                data.message, data.color)
        elseif event == M.EVENTS.EVENT then
            printChatEvent(data.event, data.data, data.color)
        end
        table.remove(M.queue, 1)
    end
end

M.onChat = onChat

local listeners = Table()
M.onLoad = function()
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.FAST_TICK, fastTick, M._name))
end
M.onUnload = function()
    listeners:forEach(BJI.Managers.Events.removeListener)
    M.msgCounter = 1
    M.queue = {}
end

return M
