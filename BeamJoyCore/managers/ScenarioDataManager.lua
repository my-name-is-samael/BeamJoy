local M = {
    ENERGY_TYPES = {
        GASOLINE = "gasoline",
        DIESEL = "diesel",
        KEROSINE = "kerosine",
        ELECTRIC = "electricEnergy"
    },
    Races = {},
    EnergyStations = {},
    Garages = {},
    Deliveries = {},
    DeliveryLeaderboard = {},
    BusLines = {},
    Hunter = {},
    Derby = {},
}

local function checkRacesData()
    table.forEach(M.Races, function(race)
        if not race.hash then
            race.hash = Hash({ race.loopable, race.startPositions, race.steps })
            BJCDao.scenario.Races.save(race)
            LogDebug(string.var("Added hash to race \"{1}\"({2}): {3}", { race.name, race.id, race.hash }))
        end
    end)
end

local function reload()
    M.Races = BJCDao.scenario.Races.findAll()
    M.EnergyStations = BJCDao.scenario.EnergyStations.findAll()
    M.Garages = BJCDao.scenario.Garages.findAll()
    M.Deliveries = BJCDao.scenario.Delivery.findAll()
    M.BusLines = BJCDao.scenario.BusLines.findAll()
    M.Hunter = BJCDao.scenario.Hunter.findAll()
    M.Derby = BJCDao.scenario.Derby.findAll()

    BJCAsync.delayTask(function()
        if #M.DeliveryLeaderboard == 0 then
            M.updateDeliveryLeaderboard()
        end
    end, 0)

    checkRacesData()
end

local function getCacheRaces(senderID)
    local cache = {}
    if BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.START_SERVER_SCENARIO) or
        BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.VOTE_SERVER_SCENARIO) or
        BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO) then
        if #M.Races > 0 then
            local editor = BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.SCENARIO)
            for _, race in ipairs(M.Races) do
                if editor or race.enabled then
                    local record = nil
                    if race.record then
                        record = {
                            playerName = race.record.playerName,
                            time = race.record.time,
                            model = race.record.model,
                        }
                    end
                    table.insert(cache, {
                        id = race.id,
                        name = race.name,
                        enabled = race.enabled == true,
                        hasStand = race.hasStand == true,
                        loopable = race.loopable == true,
                        places = #race.startPositions,
                        record = record,
                        hash = race.hash,
                    })
                end
            end
        end
    end
    cache.mapName = BJCCore.getMap()

    return cache, M.getCacheRacesHash()
end

local function getCacheRacesHash()
    return Hash(M.Races)
end

local function getCacheDeliveries(senderID)
    local cache = {
        Deliveries = table.deepcopy(M.Deliveries),
        DeliveryLeaderboard = table.deepcopy(M.DeliveryLeaderboard),
    }

    return cache, M.getCacheDeliveriesHash()
end

local function getCacheDeliveriesHash()
    return Hash({ M.Deliveries, M.DeliveryLeaderboard })
end

local function getCacheStations(senderID)
    local cache = {
        EnergyStations = table.deepcopy(M.EnergyStations),
        Garages = table.deepcopy(M.Garages),
    }

    return cache, M.getCacheStationsHash()
end

local function getCacheStationsHash()
    return Hash({ M.EnergyStations, M.Garages })
end

local function getCacheBusLines(senderID)
    local cache = {
        BusLines = table.deepcopy(M.BusLines),
    }

    return cache, M.getCacheBusLinesHash()
end

local function getCacheBusLinesHash()
    return Hash(M.BusLines)
end

local function getCacheHunter(senderID)
    local cache = {
        enabled = false,
    }
    if M.Hunter.enabled or
        BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.SCENARIO) then
        cache = table.deepcopy(M.Hunter) or {}
    end

    return cache, M.getCacheHunterHash()
end

local function getCacheHunterHash()
    return Hash(M.Hunter)
end

local function getCacheDerby(senderID)
    local cache = {}
    if BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.SCENARIO) or
        BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.START_SERVER_SCENARIO) then
        for _, arena in ipairs(M.Derby) do
            table.insert(cache, table.deepcopy(arena))
        end
    end
    return cache, M.getCacheDerbyHash()
end

local function getCacheDerbyHash()
    return Hash(M.Derby)
end

local function getRace(raceID)
    for _, r in ipairs(M.Races) do
        if r.id == raceID then
            return table.deepcopy(r)
        end
    end
    return nil
end

local function checkVehPos(vehData)
    return vehData and
        vehData.pos and
        type(vehData.pos.x) == "number" and type(vehData.pos.y) == "number" and type(vehData.pos.z) == "number" and
        vehData.rot and
        type(vehData.rot.x) == "number" and type(vehData.rot.y) == "number" and type(vehData.rot.z) == "number" and
        type(vehData.rot.w) == "number"
end

local function checkCameraPos(camData)
    return checkVehPos(camData)
end

---@param race table
---@return integer raceID
local function saveRace(race)
    local function checkParents(raceData, wpData, wpStep)
        if type(wpData.parents) ~= "table" or #wpData.parents == 0 or table.includes(wpData.parents, wpData.name) then
            return false
        end
        if wpStep == 1 then
            return true -- no parent in first step
        end
        for _, parent in ipairs(wpData.parents) do
            if parent ~= "start" then
                for iStep, step in ipairs(raceData.steps) do
                    if iStep == wpStep then
                        -- wp step have been reached without founding the parent > error
                        return false
                    end
                    for _, wp in ipairs(step) do
                        if wp.name == parent then
                            goto nextParent
                        end
                    end
                end
            end
            ::nextParent::
        end
        return true
    end

    local function checkChildren(raceData, wpName, wpStep)
        if wpStep == #raceData.steps then
            return true -- no child in last step
        end
        for iStep, step in ipairs(raceData.steps) do
            if iStep > wpStep then
                for _, wp in ipairs(step) do
                    for _, parent in ipairs(wp.parents) do
                        if parent == wpName then
                            return true
                        end
                    end
                end
            end
        end
        return false
    end

    local function checkWP(raceData, wpData, wpStep)
        return checkVehPos(wpData) and
            type(wpData.name) == "string" and #wpData.name > 0 and
            checkParents(raceData, wpData, wpStep) and
            checkChildren(raceData, wpData.name, wpStep) and
            type(wpData.radius) == "number" and wpData.radius > 0 and
            (not wpData.zOffset or (wpData.zOffset >= 0 and wpData.zOffset <= 10))
    end

    local function checkWPNames(stepsData)
        local names = {}
        for _, steps in ipairs(stepsData) do
            for _, wp in ipairs(steps) do
                if table.includes(names, wp.name) then
                    return false
                else
                    table.insert(names, wp.name)
                end
            end
        end
        return true
    end

    local baseRace = race.id and M.getRace(race.id) or nil
    if race.id then
        -- should be an existing race
        if not baseRace then
            error({ key = "rx.errors.invalidData" })
        end
        race.author = baseRace.author
    end

    if type(race.name) ~= "string" or #race.name == 0 or
        type(race.author) ~= "string" or #race.author == 0 or
        type(race.previewPosition) ~= "table" or
        not checkCameraPos(race.previewPosition) then
        error({ key = "rx.errors.invalidData" })
    elseif race.keepRecord ~= true then
        if type(race.loopable) ~= "boolean" or
            type(race.startPositions) ~= "table" or #race.startPositions == 0 or
            type(race.steps) ~= "table" or #race.steps == 0 then
            error({ key = "rx.errors.invalidData" })
        end
        for _, sp in ipairs(race.startPositions) do
            if not checkVehPos(sp) then
                error({ key = "rx.errors.invalidData" })
            end
        end
        if not checkWPNames(race.steps) then
            error({ key = "rx.errors.invalidData" })
        end
        for iStep, step in ipairs(race.steps) do
            for _, wp in ipairs(step) do
                if not checkWP(race, wp, iStep) then
                    error({ key = "rx.errors.invalidData" })
                end
            end
        end

        -- STAND FLAG
        for _, step in ipairs(race.steps) do
            for _, wp in ipairs(step) do
                if wp.stand then
                    race.hasStand = true
                    break
                end
            end
        end

        -- update hash
        race.hash = Hash({ race.loopable, race.startPositions, race.steps })
    elseif race.keepRecord == true then
        if not baseRace then
            error({ key = "rx.errors.invalidData" })
        end

        race.record = baseRace.record
        race.loopable = baseRace.loopable
        race.startPositions = baseRace.startPositions
        race.steps = baseRace.steps
    end

    race.enabled = race.enabled == true

    -- removing unwanted values
    race.keepRecord = nil

    local raceID = BJCDao.scenario.Races.save(race)
    M.Races = BJCDao.scenario.Races.findAll()

    BJCTx.cache.invalidateByPermissions(BJCCache.CACHES.RACES,
        BJCPerm.PERMISSIONS.SCENARIO,
        BJCPerm.PERMISSIONS.START_SERVER_SCENARIO,
        BJCPerm.PERMISSIONS.VOTE_SERVER_SCENARIO)

    return raceID
end

local function raceDelete(raceID)
    local raceFound = false
    for _, race in ipairs(M.Races) do
        if race.id == raceID then
            raceFound = true
            break
        end
    end

    if not raceFound then
        error({ key = "rx.errors.invalidData" })
    end

    BJCDao.scenario.Races.delete(raceID)
    M.Races = BJCDao.scenario.Races.findAll()

    BJCTx.cache.invalidateByPermissions(BJCCache.CACHES.RACES,
        BJCPerm.PERMISSIONS.SCENARIO,
        BJCPerm.PERMISSIONS.START_SERVER_SCENARIO,
        BJCPerm.PERMISSIONS.VOTE_SERVER_SCENARIO)
end

local function saveRaceRecord(raceID, record)
    local race = M.getRace(raceID)
    if not race then
        error({ key = "rx.errors.invalidData" })
    end

    race.record = record

    BJCDao.scenario.Races.save(race)
    M.Races = BJCDao.scenario.Races.findAll()

    BJCTx.cache.invalidateByPermissions(BJCCache.CACHES.RACES,
        BJCPerm.PERMISSIONS.SCENARIO,
        BJCPerm.PERMISSIONS.START_SERVER_SCENARIO,
        BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO,
        BJCPerm.PERMISSIONS.VOTE_SERVER_SCENARIO)
end

local function broadcastRaceRecord(raceName, playerName, time)
    for playerID in pairs(BJCPlayers.Players) do
        BJCChat.onServerChat(playerID,
            BJCLang.getServerMessage(playerID, "broadcast.newRaceRecord")
            :var({
                playerName = playerName,
                raceName = raceName,
                time = RaceDelay(time),
            }))
    end
end

local function broadcastRaceTime(raceName, playerName, time)
    for playerID in pairs(BJCPlayers.Players) do
        BJCChat.onServerChat(playerID,
            BJCLang.getServerMessage(playerID, "broadcast.raceTime")
            :var({
                playerName = playerName,
                raceName = raceName,
                time = RaceDelay(time),
            }))
    end
end

local function onRaceSoloTime(playerID, raceID, time, model)
    local player = BJCPlayers.Players[playerID]
    local race = M.getRace(raceID)
    if not player or not race then
        error({ key = "rx.errors.invalidData" })
    end

    local isRecord = not race.record or race.record.time > time
    if isRecord then
        BJCPlayers.reward(playerID, BJCConfig.Data.Reputation.RaceRecordReward)
        M.saveRaceRecord(raceID, {
            playerName = player.playerName,
            model = model,
            time = time,
        })
        M.broadcastRaceRecord(race.name, player.playerName, time)
    elseif BJCConfig.Data.Race.RaceSoloTimeBroadcast then
        broadcastRaceTime(race.name, player.playerName, time)
    end
end

local function saveEnergyStations(stations)
    if not stations then
        error({ key = "rx.errors.invalidData" })
    end
    for _, s in ipairs(stations) do
        if type(s.name) ~= "string" or #s.name:trim() == 0 then
            error({ key = "rx.errors.invalidData" })
        elseif type(s.pos) ~= "table" or
            type(s.pos.x) ~= "number" or
            type(s.pos.y) ~= "number" or
            type(s.pos.z) ~= "number" then
            error({ key = "rx.errors.invalidData" })
        elseif type(s.radius) ~= "number" then
            error({ key = "rx.errors.invalidData" })
        elseif type(s.types) ~= "table" or #s.types == 0 then
            error({ key = "rx.errors.invalidData" })
        end
        for _, type in ipairs(s.types) do
            if not table.includes(M.ENERGY_TYPES, type) then
                error({ key = "rx.errors.invalidData" })
            end
        end
    end

    BJCDao.scenario.EnergyStations.save(stations)
    M.EnergyStations = BJCDao.scenario.EnergyStations.findAll()
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.STATIONS)
end

local function saveGarages(garages)
    if not garages then
        error({ key = "rx.errors.invalidData" })
    end
    for _, g in ipairs(garages) do
        if type(g.name) ~= "string" or #g.name:trim() == 0 then
            error({ key = "rx.errors.invalidData" })
        elseif type(g.pos) ~= "table" or
            type(g.pos.x) ~= "number" or
            type(g.pos.y) ~= "number" or
            type(g.pos.z) ~= "number" then
            error({ key = "rx.errors.invalidData" })
        elseif type(g.radius) ~= "number" then
            error({ key = "rx.errors.invalidData" })
        end
    end

    BJCDao.scenario.Garages.save(garages)
    M.Garages = BJCDao.scenario.Garages.findAll()
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.STATIONS)
end

local function saveDeliveryPositions(positions)
    positions = positions or {}

    for _, position in ipairs(positions) do
        if type(position) ~= "table" then
            error({ key = "rx.errors.invalidData" })
        elseif type(position.radius) ~= "number" then
            error({ key = "rx.errors.invalidData" })
        elseif not position.pos or not position.rot then
            error({ key = "rx.errors.invalidData" })
        end
    end

    BJCDao.scenario.Delivery.save(positions)
    M.Deliveries = BJCDao.scenario.Delivery.findAll()
    BJCTx.cache.invalidateByPermissions(BJCCache.CACHES.DELIVERIES, BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO)
end

local function updateDeliveryLeaderboard()
    local playersScores = {}

    local players = BJCDao.players.findAll()
    for _, player in ipairs(players) do
        if player.stats then
            if player.stats.delivery and player.stats.delivery > 0 then
                table.insert(playersScores, {
                    playerName = player.playerName,
                    delivery = player.stats.delivery
                })
            end
        end
    end

    M.DeliveryLeaderboard = {}
    if #playersScores > 0 then
        table.sort(playersScores, function(a, b)
            if a.delivery ~= b.delivery then
                return a.delivery > b.delivery
            else
                return a.playerName < b.playerName
            end
        end)

        for i = 1, 3 do
            if playersScores[i] then
                table.insert(M.DeliveryLeaderboard, playersScores[i])
            end
        end
    end
end

local function saveBusLines(lines)
    if type(lines) ~= "table" then
        error({ key = "rx.errors.invalidData" })
    end
    for _, line in ipairs(lines) do
        if type(line.name) ~= "string" or #line.name:trim() == 0 or
            type(line.loopable) ~= "boolean" or
            type(line.stops) ~= "table" or #line.stops < 2 or
            type(line.distance) ~= "number" then
            error({ key = "rx.errors.invalidData" })
        end

        for _, stop in ipairs(line.stops) do
            if type(stop.name) ~= "string" or #stop.name:trim() == 0 or
                type(stop.pos) ~= "table" or
                type(stop.pos.x) ~= "number" or
                type(stop.pos.y) ~= "number" or
                type(stop.pos.z) ~= "number" or
                type(stop.rot) ~= "table" or
                type(stop.rot.x) ~= "number" or
                type(stop.rot.y) ~= "number" or
                type(stop.rot.z) ~= "number" or
                type(stop.rot.w) ~= "number" or
                type(stop.radius) ~= "number" then
                error({ key = "rx.errors.invalidData" })
            end
        end
    end

    BJCDao.scenario.BusLines.save(lines)
    M.BusLines = BJCDao.scenario.BusLines.findAll()
    BJCTx.cache.invalidateByPermissions(BJCCache.CACHES.BUS_LINES,
        BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO,
        BJCPerm.PERMISSIONS.SCENARIO)
end

local function saveHunter(data)
    if not data or
        data.enabled == true and
        (
            type(data.targets) ~= "table" or
            type(data.hunterPositions) ~= "table" or
            type(data.huntedPositions) ~= "table"
        ) then
        error({ key = "rx.errors.invalidData" })
    end

    -- enabled validation
    if #data.targets < 2 or
        #data.hunterPositions < 5 or
        #data.huntedPositions < 2 then
        -- forced disabled
        data.enabled = false
        data.targets = {}
        data.hunterPositions = {}
        data.huntedPositions = {}
    end

    -- data validation
    if data.enabled then
        for _, waypoint in ipairs(data.targets) do
            if type(waypoint.pos) ~= "table" or
                type(waypoint.pos.x) ~= "number" or
                type(waypoint.pos.y) ~= "number" or
                type(waypoint.pos.z) ~= "number" or
                type(waypoint.radius) ~= "number" then
                error({ key = "rx.errors.invalidData" })
            end
        end

        for _, pos in ipairs(data.hunterPositions) do
            if type(pos.pos) ~= "table" or
                type(pos.pos.x) ~= "number" or
                type(pos.pos.y) ~= "number" or
                type(pos.pos.z) ~= "number" or
                type(pos.rot) ~= "table" or
                type(pos.rot.x) ~= "number" or
                type(pos.rot.y) ~= "number" or
                type(pos.rot.z) ~= "number" or
                type(pos.rot.w) ~= "number" then
                error({ key = "rx.errors.invalidData" })
            end
        end

        for _, pos in ipairs(data.huntedPositions) do
            if type(pos.pos) ~= "table" or
                type(pos.pos.x) ~= "number" or
                type(pos.pos.y) ~= "number" or
                type(pos.pos.z) ~= "number" or
                type(pos.rot) ~= "table" or
                type(pos.rot.x) ~= "number" or
                type(pos.rot.y) ~= "number" or
                type(pos.rot.z) ~= "number" or
                type(pos.rot.w) ~= "number" then
                error({ key = "rx.errors.invalidData" })
            end
        end
    end

    BJCDao.scenario.Hunter.save(data)
    M.Hunter = BJCDao.scenario.Hunter.findAll()
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.HUNTER_DATA)
end

local function saveDerbyArenas(arenas)
    if type(arenas) ~= "table" then
        error({ key = "rx.errors.invalidData" })
    else
        for _, arena in ipairs(arenas) do
            if type(arena.name) ~= "string" or
                #arena.name:trim() == 0 or
                type(arena.enabled) ~= "boolean" or
                type(arena.previewPosition) ~= "table" or
                not checkCameraPos(arena.previewPosition) or
                type(arena.startPositions) ~= "table" or
                #arena.startPositions < 6 then
                error({ key = "rx.errors.invalidData" })
            else
                for _, pos in ipairs(arena.startPositions) do
                    if not checkVehPos(pos) then
                        error({ key = "rx.errors.invalidData" })
                    end
                end
            end
        end
    end
    if #Table(arenas):map(function(a) return a.name:trim() end):duplicates() > 0 then
        error({ key = "rx.errors.invalidData" })
    end

    BJCDao.scenario.Derby.save(arenas)
    M.Derby = BJCDao.scenario.Derby.findAll()
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.DERBY_DATA)
end

M.getCacheRaces = getCacheRaces
M.getCacheRacesHash = getCacheRacesHash
M.getCacheDeliveries = getCacheDeliveries
M.getCacheDeliveriesHash = getCacheDeliveriesHash
M.getCacheStations = getCacheStations
M.getCacheStationsHash = getCacheStationsHash
M.getCacheBusLines = getCacheBusLines
M.getCacheBusLinesHash = getCacheBusLinesHash
M.getCacheHunter = getCacheHunter
M.getCacheHunterHash = getCacheHunterHash
M.getCacheDerby = getCacheDerby
M.getCacheDerbyHash = getCacheDerbyHash

M.getRace = getRace
M.saveRace = saveRace
M.raceDelete = raceDelete
M.saveRaceRecord = saveRaceRecord
M.broadcastRaceRecord = broadcastRaceRecord
M.onRaceSoloTime = onRaceSoloTime

M.saveEnergyStations = saveEnergyStations
M.saveGarages = saveGarages

M.saveDeliveryPositions = saveDeliveryPositions
M.updateDeliveryLeaderboard = updateDeliveryLeaderboard

M.saveBusLines = saveBusLines

M.saveHunter = saveHunter

M.saveDerbyArenas = saveDerbyArenas

M.reload = reload
reload()

return M
