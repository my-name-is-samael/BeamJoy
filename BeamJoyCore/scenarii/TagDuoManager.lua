local M = {
    CLIENT_EVENTS = {
        READY = "ready",
        TOUCH = "touch",
    },
    lobbies = {},
}
--[[singlelobby = {
    host = player1ID,
    lastTagger = player1ID,
    players = {
        [player1ID] = {
            tagger = true,
            gameVehID = veh1ID,
            ready = true,
        },
        [player2ID] = {
            tagger = false,
            gameVehID = veh2ID,
            ready = true,
        },
    }
}]]

-- stops all lobbies for an incoming server scenario
local function stop()
    M.lobbies = {}

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

local function onClientLeave(senderID)
    local foundIndex
    for i, lobby in ipairs(M.lobbies) do
        if lobby.players[senderID] then
            foundIndex = i
            break
        end
    end
    if foundIndex then
        local lobby = M.lobbies[foundIndex]
        if lobby.host == senderID then
            table.remove(M.lobbies, foundIndex)
        else
            M.lobbies[foundIndex].players[senderID] = nil
        end
        BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.TAG_DUO)
    end
end

local function onPlayerDisconnect(targetID)
    onClientLeave(targetID)
end

local function getCache()
    return {
        lobbies = M.lobbies
    }, M.getCacheHash()
end

local function getCacheHash()
    return Hash({ M.lobbies })
end

M.getCache = getCache
M.getCacheHash = getCacheHash

M.onClientJoin = onClientJoin
M.onClientUpdate = onClientUpdate
M.onClientLeave = onClientLeave
M.onPlayerDisconnect = onPlayerDisconnect

M.stop = stop


RegisterBJCManager(M)
return M
