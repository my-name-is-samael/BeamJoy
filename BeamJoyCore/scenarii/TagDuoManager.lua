---@class BJCTagDuoLobby
---@field host integer
---@field lastTagger integer
---@field players {tagger: boolean, gameVehID: integer, ready: boolean}[] index playerIDs #{1-2}

local M = {
    CLIENT_EVENTS = {
        READY = "ready",
        TOUCH = "touch",
    },
    ---@type BJCTagDuoLobby[]
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

    local foundIndex
    for i, lobby in ipairs(M.lobbies) do
        if lobby.players[senderID] then
            foundIndex = i
            break
        end
    end
    if foundIndex then -- player already in a lobby
        error({ key = "rx.errors.invalidData" })
    end

    if lobbyIndex then -- joining an existing lobby
        local lobby = M.lobbies[lobbyIndex]
        if not lobby or
            lobby.host == senderID or
            table.length(lobby.players) > 1 then -- invalid lobby or already host or already 2 players in lobby
            error({ key = "rx.errors.invalidData" })
        end

        lobby.players[senderID] = {
            tagger = false,
            gameVehID = gameVehID,
            ready = false,
        }
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.TAG_DUO)
    else -- creating a new lobby
        table.insert(M.lobbies, {
            host = senderID,
            lastTagger = nil,
            players = {
                [senderID] = {
                    tagger = false,
                    gameVehID = gameVehID,
                    ready = false,
                }
            }
        })
    end
end

local function onClientReady(senderID, lobby)
    if lobby.players[senderID].ready then
        return
    end

    lobby.players[senderID].ready = true
    local readyCount = 0
    for _, p in pairs(lobby.players) do
        if p.ready then
            readyCount = readyCount + 1
        end
    end
    if readyCount == 2 then -- both players ready > start tag
        local tagger
        if not lobby.lastTagger then
            tagger = table.random(table.keys(lobby.players))
        else
            for id in pairs(lobby.players) do
                if id ~= lobby.lastTagger then
                    tagger = id
                    break
                end
            end
        end

        for id, p in pairs(lobby.players) do
            p.tagger = id == tagger
        end
        lobby.lastTagger = tagger
    end
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.TAG_DUO)
end

local function onClientTouch(senderID, lobby)
    if not lobby.players[senderID].tagger then
        return
    end

    for p in pairs(lobby.players) do
        p.ready = false
        p.tagger = nil
    end
    -- TODO RP reward
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.TAG_DUO)
end

local function onClientUpdate(senderID, lobbyIndex, event)
    local lobby = M.lobbies[lobbyIndex]
    if not lobby or not lobby.players[senderID] then
        error({ key = "rx.errors.invalidData" })
    end

    if event == M.CLIENT_EVENTS.READY then
        onClientReady(senderID, lobby)
    elseif event == M.CLIENT_EVENTS.TOUCH then
        onClientTouch(senderID, lobby)
    end
end

---@param player BJCPlayer
---@return boolean
local function isParticipant(player)
    return M.lobbies:any(function(lobby)
        return lobby.players[player.playerID] ~= nil
    end)
end

---@param player BJCPlayer
local function onPlayerDisconnect(player)
    M.lobbies:find(function(lobby)
        return lobby.players[player.playerID] ~= nil
    end, function(lobby, i)
        if lobby.host == player.playerID then
            table.remove(M.lobbies, i)
        else
            M.lobbies[i].players[player.playerID] = nil
        end
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.TAG_DUO)
    end)
end

M.getCache = getCache
M.getCacheHash = getCacheHash

M.isParticipant = isParticipant

M.onClientJoin = onClientJoin
M.onClientUpdate = onClientUpdate
M.onPlayerDisconnect = onPlayerDisconnect

M.stop = stop
M.forceStop = stop

return M
