local M = {
    _dbPath = nil,
    _tournamentPath = nil,
    _TYPES = {
        RACES = "_races",
        STATIONS = "_stations",
        DELIVERIES = "_deliveries",
        BUS_LINES = "_buslines",
        HUNTER_INFECTED = "_hunter",
        DERBY = "_derby",
    },
    Races = {},
    EnergyStations = {},
    Garages = {},
    Delivery = {},
    BusLines = {},
    HunterInfected = {},
    Derby = {},
    Tournament = {},
}

function M.init(dbPath)
    M._dbPath = string.var("{1}/scenarii", { dbPath })
    M._tournamentPath = string.var("{1}/tournaments.json", { dbPath })

    if not FS.Exists(M._dbPath) then
        FS.CreateDirectory(M._dbPath)
    end
end

local function _getFilePath(type)
    local mapName = BJCCore.getMap()
    return string.var("{1}/{2}{3}.json", { M._dbPath, mapName, type })
end

-- RACES
---@return table
function M.Races.findAll()
    local filePath = _getFilePath(M._TYPES.RACES)

    local defaultRaces = {}
    if FS.Exists(filePath) then
        local file, err = io.open(filePath, "r")
        if file and not err then
            local data = file:read("*a")
            file:close()
            data = JSON.parse(data)
            if type(data) ~= "table" then
                LogError(string.var("Cannot read file {1}: Invalid content data", { filePath }))
                data = defaultRaces
            end
            return data
        end
    end
    return defaultRaces
end

---@param race table
function M.Races.save(race)
    local races = M.Races.findAll()

    local existingIndex
    if race.id == nil then
        -- find first available id
        local id = 1
        local found = true
        while found do
            found = false
            for _, r in ipairs(races) do
                if r.id == id then
                    found = true
                    break
                end
            end
            if found then
                id = id + 1
            end
        end
        race.id = id
    else
        for i, r in ipairs(races) do
            if r.id == race.id then
                existingIndex = i
                break
            end
        end
    end

    if not existingIndex then
        -- creation
        table.insert(races, race)
    else
        -- update
        races[existingIndex] = race
    end

    local filePath = _getFilePath(M._TYPES.RACES)
    BJCDao._saveFile(filePath, races)

    return race.id
end

---@param id integer
function M.Races.delete(id)
    local races = M.Races.findAll()
    for i, race in ipairs(races) do
        if race.id == id then
            table.remove(races, i)
            break
        end
    end
    local filePath = _getFilePath(M._TYPES.RACES)
    if #races == 0 then
        FS.Remove(filePath)
    else
        BJCDao._saveFile(filePath, races)
    end
end

-- ENERGY STATIONS / GARAGES
---@return table
local function _loadMapStations()
    local filePath = _getFilePath(M._TYPES.STATIONS)

    local defaultStations = {
        EnergyStations = {},
        Garages = {},
    }

    if FS.Exists(filePath) then
        local file, err = io.open(filePath, "r")
        if file and not err then
            local data = file:read("*a")
            file:close()
            data = JSON.parse(data)
            if type(data) ~= "table" then
                LogError(string.var("Cannot read file {1}: Invalid content data", { filePath }))
                data = defaultStations
            end
            return data
        end
    end
    return defaultStations
end

---@return table
function M.EnergyStations.findAll()
    return _loadMapStations().EnergyStations
end

---@param energyStations table
function M.EnergyStations.save(energyStations)
    local data = _loadMapStations()
    data.EnergyStations = energyStations
    local filePath = _getFilePath(M._TYPES.STATIONS)
    if #data.EnergyStations == 0 and #data.Garages == 0 then
        FS.Remove(filePath)
    else
        BJCDao._saveFile(filePath, data)
    end
end

---@return table
function M.Garages.findAll()
    return _loadMapStations().Garages
end

---@param garages table
function M.Garages.save(garages)
    local data = _loadMapStations()
    data.Garages = garages
    local filePath = _getFilePath(M._TYPES.STATIONS)
    if #data.EnergyStations == 0 and #data.Garages == 0 then
        FS.Remove(filePath)
    else
        BJCDao._saveFile(filePath, data)
    end
end

-- DELIVERIES
---@return table
function M.Delivery.findAll()
    local filePath = _getFilePath(M._TYPES.DELIVERIES)

    local defaultDeliveries = {}

    if FS.Exists(filePath) then
        local file, err = io.open(filePath, "r")
        if file and not err then
            local data = file:read("*a")
            file:close()
            data = JSON.parse(data)
            if type(data) ~= "table" then
                LogError(string.var("Cannot read file {1}: Invalid content data", { filePath }))
                data = defaultDeliveries
            end
            return data
        end
    end
    return defaultDeliveries
end

---@param deliveries table
function M.Delivery.save(deliveries)
    local filePath = _getFilePath(M._TYPES.DELIVERIES)
    if #deliveries == 0 then
        FS.Remove(filePath)
    else
        BJCDao._saveFile(filePath, deliveries)
    end
end

-- BUS LINES
---@return table
function M.BusLines.findAll()
    local filePath = _getFilePath(M._TYPES.BUS_LINES)

    local defaultBusLines = {}

    if FS.Exists(filePath) then
        local file, err = io.open(filePath, "r")
        if file and not err then
            local data = file:read("*a")
            file:close()
            data = JSON.parse(data)
            if type(data) ~= "table" then
                LogError(string.var("Cannot read file {1}: Invalid content data", { filePath }))
                data = defaultBusLines
            end
            return data
        end
    end
    return defaultBusLines
end

---@param busLines table
function M.BusLines.save(busLines)
    local filePath = _getFilePath(M._TYPES.BUS_LINES)
    if #busLines == 0 then
        FS.Remove(filePath)
    else
        BJCDao._saveFile(filePath, busLines)
    end
end

-- HUNTER
---@return table
function M.HunterInfected.findAll()
    local filePath = _getFilePath(M._TYPES.HUNTER_INFECTED)

    local defaultHunterInfectedData = {
        enabled = false,
        waypoints = {},
        majorPositions = {},
        minorPositions = {},
    }

    if FS.Exists(filePath) then
        local file, err = io.open(filePath, "r")
        if file and not err then
            local data = file:read("*a")
            file:close()
            data = JSON.parse(data)
            if type(data) ~= "table" then
                LogError(string.var("Cannot read file {1}: Invalid content data", { filePath }))
                data = defaultHunterInfectedData
            end
            return data
        end
    end
    return defaultHunterInfectedData
end

---@param hunterInfectedData table
function M.HunterInfected.save(hunterInfectedData)
    local filePath = _getFilePath(M._TYPES.HUNTER_INFECTED)
    BJCDao._saveFile(filePath, hunterInfectedData)
end

-- DERBY
---@return table
function M.Derby.findAll()
    local filePath = _getFilePath(M._TYPES.DERBY)

    local defaultDerbyData = {}

    if FS.Exists(filePath) then
        local file, err = io.open(filePath, "r")
        if file and not err then
            local data = file:read("*a")
            file:close()
            data = JSON.parse(data)
            if type(data) ~= "table" then
                LogError(string.var("Cannot read file {1}: Invalid content data", { filePath }))
                data = defaultDerbyData
            end
            return data
        end
    end
    return defaultDerbyData
end

---@param derbyData table
function M.Derby.save(derbyData)
    local filePath = _getFilePath(M._TYPES.DERBY)
    if #derbyData == 0 then
        FS.Remove(filePath)
    else
        BJCDao._saveFile(filePath, derbyData)
    end
end

-- TOURNAMENT
---@return table
function M.Tournament.get()
    local defaultTournamentData = {
        activities = {},
        players = {},
        whitelist = false,
        whitelistPlayers = {},
    }

    if FS.Exists(M._tournamentPath) then
        local file, err = io.open(M._tournamentPath, "r")
        if file and not err then
            local data = file:read("*a")
            file:close()
            data = JSON.parse(data)
            if type(data) ~= "table" then
                LogError(string.var("Cannot read file {1}: Invalid content data", { M._tournamentPath }))
                data = defaultTournamentData
            end
            return data
        end
    end
    return defaultTournamentData
end

---@param activities BJTournamentActivity[]
---@param players BJTournamentPlayer[]
---@param whitelist boolean
---@param whitelistPlayers string[]
function M.Tournament.save(activities, players, whitelist, whitelistPlayers)
    if whitelist and #whitelistPlayers == 0 then
        whitelist = false
    end
    if #whitelistPlayers == 0 and #players == 0 and #activities == 0 then
        if FS.Exists(M._tournamentPath) then
            FS.Remove(M._tournamentPath)
        end
    else
        BJCDao._saveFile(M._tournamentPath, {
            activities = activities,
            players = players,
            whitelist = whitelist,
            whitelistPlayers = whitelistPlayers,
        })
    end
end

return M
