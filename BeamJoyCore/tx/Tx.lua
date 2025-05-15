local logTag = "Tx"
SetLogType(logTag, CONSOLE_COLORS.FOREGROUNDS.LIGHT_GREEN)

BJCTx = {
    ALL_PLAYERS = -1,
    PAYLOAD_LIMIT_SIZE = 20000,
}

---@param controller string
---@param endpoint string
---@param targetID integer
---@param data? any
function BJCTx.sendToPlayer(controller, endpoint, targetID, data)
    if type(data) ~= "table" then
        data = { data }
    end
    if targetID == BJCTx.ALL_PLAYERS or
        (BJCPlayers.Players[targetID] and BJCPlayers.Players[targetID].ready) then
        local id = UUID()
        local parts = {}
        local payload = JSON.stringifyRaw(data)
        while #payload > 0 do
            table.insert(parts, payload:sub(1, BJCTx.PAYLOAD_LIMIT_SIZE))
            payload = payload:sub(BJCTx.PAYLOAD_LIMIT_SIZE + 1)
        end

        MP.TriggerClientEvent(targetID, BJC_EVENTS.SERVER_EVENT, JSON.stringifyRaw({
            id = id,
            parts = #parts,
            controller = controller,
            endpoint = endpoint,
        }))
        for i, p in ipairs(parts) do
            MP.TriggerClientEvent(targetID, BJC_EVENTS.SERVER_EVENT_PARTS, JSON.stringifyRaw({
                id = id,
                part = i,
                data = p,
            }))
        end
    end
end

function BJCTx.sendByPermissions(eventName, endpoint, data, ...)
    local permissionNames = {}
    if type(...) ~= "table" then
        permissionNames = { ... }
    else
        permissionNames = ...
    end
    local targets = {}
    for playerID in pairs(BJCPlayers.Players) do
        for _, permissionName in ipairs(permissionNames) do
            if BJCPerm.hasPermission(playerID, permissionName) then
                table.insert(targets, playerID)
                break
            end
        end
    end
    for _, targetID in ipairs(targets) do
        BJCTx.sendToPlayer(eventName, endpoint, targetID, data)
    end
end

-- TODO auto parse
require("tx/CacheTx")
require("tx/DatabaseTx")
require("tx/PlayerTx")
require("tx/ScenarioTx")
