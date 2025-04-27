local M = {
    _dbPath = nil,
    _TYPES = {
        RACES = "_races",
        STATIONS = "_stations",
        DELIVERIES = "_deliveries",
        BUS_LINES = "_buslines",
        HUNTER = "_hunter",
        DERBY = "_derby",
    },
    Races = {},
    EnergyStations = {},
    Garages = {},
    Delivery = {},
    BusLines = {},
    Hunter = {},
    Derby = {},
}

function M.init(dbPath)
    M._dbPath = string.var("{1}/scenarii", { dbPath })

    if not FS.Exists(M._dbPath) then
        FS.CreateDirectory(M._dbPath)
    end
end

local function _getFilePath(type)
    local mapName = BJCCore.getMap()
    return string.var("{1}/{2}{3}.json", { M._dbPath, mapName, type })
end

-- RACES
local function _loadMapRaces()
    local filePath = _getFilePath(M._TYPES.RACES)

    local defaultRaces = {}
    if FS.Exists(filePath) then
        local file, err = io.open(filePath, "r")
        if file and not err then
            local data = file:read("*a")
            file:close()
            return JSON.parse(data)
        end
    end
    return defaultRaces
end

function M.Races.findAll()
    return _loadMapRaces()
end

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
            return JSON.parse(data)
        end
    end
    return defaultStations
end

function M.EnergyStations.findAll()
    return _loadMapStations().EnergyStations
end

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

function M.Garages.findAll()
    return _loadMapStations().Garages
end

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
local function _loadMapDeliveries()
    local filePath = _getFilePath(M._TYPES.DELIVERIES)

    local defaultDeliveries = {}

    if FS.Exists(filePath) then
        local file, err = io.open(filePath, "r")
        if file and not err then
            local data = file:read("*a")
            file:close()
            return JSON.parse(data)
        end
    end
    return defaultDeliveries
end

function M.Delivery.findAll()
    return _loadMapDeliveries()
end

function M.Delivery.save(deliveries)
    local filePath = _getFilePath(M._TYPES.DELIVERIES)
    if #deliveries == 0 then
        FS.Remove(filePath)
    else
        BJCDao._saveFile(filePath, deliveries)
    end
end

-- BUS LINES
local function _loadMapBusLines()
    local filePath = _getFilePath(M._TYPES.BUS_LINES)

    local defaultBusLines = {}

    if FS.Exists(filePath) then
        local file, err = io.open(filePath, "r")
        if file and not err then
            local data = file:read("*a")
            file:close()
            return JSON.parse(data)
        end
    end
    return defaultBusLines
end

function M.BusLines.findAll()
    return _loadMapBusLines()
end

function M.BusLines.save(busLines)
    local filePath = _getFilePath(M._TYPES.BUS_LINES)
    if #busLines == 0 then
        FS.Remove(filePath)
    else
        BJCDao._saveFile(filePath, busLines)
    end
end

-- HUNTER
local function _loadMapHunter()
    local filePath = _getFilePath(M._TYPES.HUNTER)

    local defaultHunterData = {
        enabled = false,
        targets = {},
        hunterPositions = {},
        huntedPositions = {},
    }

    if FS.Exists(filePath) then
        local file, err = io.open(filePath, "r")
        if file and not err then
            local data = file:read("*a")
            file:close()
            return JSON.parse(data)
        end
    end
    return defaultHunterData
end

function M.Hunter.findAll()
    return _loadMapHunter()
end

function M.Hunter.save(hunterData)
    local filePath = _getFilePath(M._TYPES.HUNTER)
    BJCDao._saveFile(filePath, hunterData)
end

-- DERBY
local function _loadMapDerby()
    local filePath = _getFilePath(M._TYPES.DERBY)

    local defaultDerbyData = {}

    if FS.Exists(filePath) then
        local file, err = io.open(filePath, "r")
        if file and not err then
            local data = file:read("*a")
            file:close()
            return JSON.parse(data)
        end
    end
    return defaultDerbyData
end

function M.Derby.findAll()
    return _loadMapDerby()
end

function M.Derby.save(derbyData)
    local filePath = _getFilePath(M._TYPES.DERBY)
    if #derbyData == 0 then
        FS.Remove(filePath)
    else
        BJCDao._saveFile(filePath, derbyData)
    end
end

return M
