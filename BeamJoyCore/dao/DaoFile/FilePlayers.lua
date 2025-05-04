local M = {
    _dbPath = nil,
    _fields = {
        playerName = "string", -- PK
        beammp = "string",
        group = "string",
        lang = "string",
        ip = "string",
        muted = "boolean",
        muteReason = "string",
        kickReason = "string",
        tempBanUntil = "number",
        banned = "boolean",
        banReason = "string",

        reputation = "number",

        stats = "table",
    }
}

local function init(dbPath)
    M._dbPath = string.var("{1}/players", { dbPath })

    if not FS.Exists(M._dbPath) then
        FS.CreateDirectory(M._dbPath)
    end
end

local function findAll()
    local players = {}
    for _, filename in pairs(FS.ListFiles(M._dbPath)) do
        if filename:find(".json") and not filename:find("/") then
            local playerName = filename:gsub(".json", "")
            local player = M.findByPlayerName(playerName)
            if player ~= nil then
                table.insert(players, player)
            end
        end
    end
    return players
end

local function findByPlayerName(playerName)
    local player
    local file, error = io.open(string.var("{1}/{2}.json", { M._dbPath, playerName }), "r")
    if file and not error then
        player = {}
        local data = file:read("*a")
        file:close()
        data = JSON.parse(data)
        if data then
            for k, v in pairs(data) do
                if type(v) == M._fields[k] then
                    player[k] = v
                end
            end
        end
    end
    return player
end

local function existsByPlayerName(playerName)
    for _, filename in pairs(FS.ListFiles(M._dbPath)) do
        if filename:find(".json") and not filename:find("/") then
            if playerName == filename:gsub(".json", "") then
                return true
            end
        end
    end
    return false
end

local function save(player)
    if player then
        local playerName = player.playerName
        local filePath = string.var("{1}/{2}.json", { M._dbPath, playerName })
        local data = {}
        for k, v in pairs(player) do
            if type(v) == M._fields[k] then
                data[k] = v
            end
        end
        return BJCDao._saveFile(filePath, data)
    end
    return false
end

M.init = init

M.findAll = findAll
M.findByPlayerName = findByPlayerName
M.existsByPlayerName = existsByPlayerName

M.save = save

return M
