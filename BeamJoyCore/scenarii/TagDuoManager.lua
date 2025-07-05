---@class BJTagDuoLobby
---@field host integer
---@field lastTagger integer?
---@field players tablelib<integer, {tagger: boolean, gameVehID: integer, ready: boolean}> index playerIDs #{1-2}

local M = {
    CLIENT_EVENTS = {
        READY = "ready",
        TAG = "tag",
    },
    ---@type tablelib<integer, BJTagDuoLobby>
    lobbies = Table(),
}

local function getCache()
    return {
        lobbies = M.lobbies
    }, M.getCacheHash()
end

local function getCacheHash()
    return Hash({ M.lobbies })
end

-- stops all lobbies for an incoming server scenario
local function stop()
    M.lobbies = Table()

    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.TAG_DUO)
end

local function onClientJoin(senderID, lobbyIndex, gameVehID)
    if not gameVehID then -- invalid vehicle
        error({ key = "rx.errors.invalidData" })
    end

    if M.lobbies:find(function(lobby) return lobby.players[senderID] end) then
        -- player already in a lobby
        error({ key = "rx.errors.invalidData" })
    end

    if lobbyIndex ~= -1 then -- joining an existing lobby
        local lobby = M.lobbies[lobbyIndex]
        if not lobby or
            lobby.host == senderID or
            lobby.players:length() > 1 then
            -- invalid lobby or already host or already 2 players in lobby
            error({ key = "rx.errors.invalidData" })
        end

        lobby.players[senderID] = {
            tagger = false,
            gameVehID = gameVehID,
            ready = false,
        }
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.TAG_DUO)

        BJCChat.sendChatEvent("chat.events.gamemodeJoin", {
            playerName = BJCPlayers.Players[senderID].playerName,
            gamemode = "chat.events.gamemodes.tagduo",
        })
    else -- creating a new lobby
        M.lobbies:insert({
            host = senderID,
            lastTagger = nil,
            players = Table({
                [senderID] = {
                    tagger = false,
                    gameVehID = gameVehID,
                    ready = false,
                }
            })
        })
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.TAG_DUO)

        BJCChat.sendChatEvent("chat.events.gamemodeCreatedLobby", {
            playerName = BJCPlayers.Players[senderID].playerName,
            gamemode = "chat.events.gamemodes.tagduo",
        })
    end
end

---@param senderID integer
---@param lobby BJTagDuoLobby
local function onClientReady(senderID, lobby)
    if lobby.players[senderID].ready then
        return
    end


    lobby.players[senderID].ready = true
    if #lobby.players:filter(function(p) return p.ready end):values() == 2 then
        -- both players ready > start tag
        LogWarn(string.var("both players ready", { senderID }))
        local nextTagger = lobby.lastTagger and lobby.players:keys()
            :filter(function(_, pid) return pid ~= lobby.lastTagger end)
            :find(function() return true end) or
            lobby.players:keys():random()

        lobby.players:forEach(function(p, id)
            p.tagger = id == nextTagger
        end)
        lobby.lastTagger = nextTagger
    end
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.TAG_DUO)
end

---@param senderID integer
---@param lobby BJTagDuoLobby
local function onClientTag(senderID, lobby)
    if not lobby.players[senderID].tagger then
        return
    end

    LogWarn(string.var("player {1} tag", { senderID }))

    lobby.players:forEach(function(p)
        p.ready = false
        p.tagger = false
    end)
    BJCPlayers.reward(senderID, BJCConfig.Data.Reputation.TagDuoReward)
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.TAG_DUO)
end

local function onClientUpdate(senderID, lobbyIndex, event)
    local lobby = M.lobbies[lobbyIndex]
    if not lobby or not lobby.players[senderID] then
        error({ key = "rx.errors.invalidData" })
    end

    if event == M.CLIENT_EVENTS.READY then
        onClientReady(senderID, lobby)
    elseif event == M.CLIENT_EVENTS.TAG then
        onClientTag(senderID, lobby)
    end
end

---@param player BJCPlayer
---@return boolean
local function isParticipant(player)
    return M.lobbies:any(function(lobby)
        return lobby.players[player.playerID] ~= nil
    end)
end

---@param senderID integer
---@param disconnect boolean?
local function onClientLeave(senderID, disconnect)
    M.lobbies:find(function(lobby)
        return lobby.players[senderID] ~= nil
    end, function(lobby, i)
        if lobby.host == senderID then
            lobby.players:find(function(_, pid)
                return pid ~= senderID
            end, function(_, pid)
                -- broadcasts other player in the lobby leaving it
                BJCChat.sendChatEvent("chat.events.gamemodeLeave", {
                    playerName = BJCPlayers.Players[pid].playerName,
                    gamemode = "chat.events.gamemodes.tagduo",
                })
            end)
            M.lobbies:remove(i)
        else
            lobby.players[senderID] = nil
            table.assign(lobby.players[lobby.host], {
                ready = false,
                tagger = false,
            })
        end
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.TAG_DUO)

        if not disconnect then
            BJCChat.sendChatEvent("chat.events.gamemodeLeave", {
                playerName = BJCPlayers.Players[senderID].playerName,
                gamemode = "chat.events.gamemodes.tagduo",
            })
        end
    end)
end

---@param player BJCPlayer
local function onPlayerDisconnect(player)
    onClientLeave(player.playerID, true)
end

M.getCache = getCache
M.getCacheHash = getCacheHash

M.isParticipant = isParticipant

M.onClientJoin = onClientJoin
M.onClientUpdate = onClientUpdate
M.onClientLeave = onClientLeave
M.onPlayerDisconnect = onPlayerDisconnect

M.stop = stop
M.forceStop = stop

return M
