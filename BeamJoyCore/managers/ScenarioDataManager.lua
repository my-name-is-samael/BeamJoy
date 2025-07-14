---@class _BJRace
---@field id integer unique per map
---@field hash string
---@field name string unique per map
---@field enabled boolean
---@field loopable boolean
---@field hasStand boolean
---@field record {playerName: string, time: integer, model: string}?

---@class BJRace: _BJRace
---@field author string
---@field previewPosition BJIPositionRotation
---@field startPositions BJIPositionRotation[]
---@field steps {name: string, pos: vec3, rot: quat, radius: number, stand: boolean?, zOffset: number?}[][]

---@class BJRacePayload: BJRace
---@field keepRecord boolean

---@class BJRaceLight: _BJRace
---@field places integer
---@field markerPos vec3

---@class BJBusLine
---@field name string
---@field distance number
---@field loopable boolean
---@field stops {name: string, pos: vec3, rot:quat, radius: number}[]

local M = {
    ENERGY_TYPES = {
        GASOLINE = "gasoline",
        DIESEL = "diesel",
        KEROSINE = "kerosine",
        ELECTRIC = "electricEnergy"
    },
    ---@type BJRace[]
    Races = {},
    EnergyStations = {},
    Garages = {},
    Deliveries = {},
    DeliveryLeaderboard = {},
    BusLines = {},
    HunterInfected = {},
    Derby = {},
}

-- INIT

--- Update 2.0.0<br/>
--- Add races hashes
local function checkRacesUpdate2_0_0()
    table.forEach(M.Races, function(race)
        if not race.hash then
            race.hash = Hash({ race.loopable, race.startPositions, race.steps })
            BJCDao.scenario.Races.save(race)
            LogDebug(string.var("Added hash to race \"{1}\"({2}): {3}", { race.name, race.id, race.hash }))
        end
    end)
end

--- Update 2.0.0<br/>
--- Update hunter data to hunter/infected
local function checkHunterUpdate2_0_0()
    if M.HunterInfected.enabled ~= nil and M.HunterInfected.enabledHunter == nil then
        M.HunterInfected.enabledHunter = M.HunterInfected.enabled
        M.HunterInfected.enabledInfected = M.HunterInfected.enabled
        M.HunterInfected.waypoints = M.HunterInfected.targets
        M.HunterInfected.majorPositions = M.HunterInfected.hunterPositions
        M.HunterInfected.minorPositions = M.HunterInfected.huntedPositions

        M.HunterInfected.enabled = nil
        M.HunterInfected.targets = nil
        M.HunterInfected.hunterPositions = nil
        M.HunterInfected.huntedPositions = nil
        BJCDao.scenario.HunterInfected.save(M.HunterInfected)
        LogDebug("Updated hunter data to hunter/infected new format")
    end
end

--- Update 2.0.0<br/>
--- Add arenas center positions and radiuses
local function checkDerbyUpdate2_0_0()
    if table.any(M.Derby, function(arena)
            return not arena.centerPosition
        end) then
        ---@param arena BJArena
        table.forEach(M.Derby, function(arena, i)
            if not arena.centerPosition and #arena.startPositions > 0 then
                arena.centerPosition = table.reduce(arena.startPositions, function(pos, sp)
                    pos.x = pos.x + sp.pos.x
                    pos.y = pos.y + sp.pos.y
                    pos.z = pos.z + sp.pos.z
                    return pos
                end, { x = 0, y = 0, z = 0 })
                arena.centerPosition.x = arena.centerPosition.x / #arena.startPositions
                arena.centerPosition.y = arena.centerPosition.y / #arena.startPositions
                arena.centerPosition.z = arena.centerPosition.z / #arena.startPositions

                ---@param sp BJIPositionRotation
                local maxDistance = table.reduce(arena.startPositions, function(res, sp)
                    local dist = math.horizontalDistance(sp.pos, arena.centerPosition)
                    return dist > res and dist or res
                end, 0)
                arena.radius = math.round(maxDistance + 5)

                LogDebug(string.var("Added center position and radius to arena \"{1}\"({2})", { arena.name, i }))
            end
        end)
        BJCDao.scenario.Derby.save(M.Derby)
    end
end

local function reload()
    M.Races = BJCDao.scenario.Races.findAll()
    M.EnergyStations = BJCDao.scenario.EnergyStations.findAll()
    M.Garages = BJCDao.scenario.Garages.findAll()
    M.Deliveries = BJCDao.scenario.Delivery.findAll()
    M.BusLines = BJCDao.scenario.BusLines.findAll()
    M.HunterInfected = BJCDao.scenario.HunterInfected.findAll()
    M.Derby = BJCDao.scenario.Derby.findAll()

    M.updateDeliveryLeaderboard()

    checkRacesUpdate2_0_0()
    checkHunterUpdate2_0_0()
    checkDerbyUpdate2_0_0()
end

-- CACHES

local function getCacheRaces(senderID)
    ---@type BJRaceLight[]
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
                        markerPos = race.startPositions[1].pos,
                    })
                end
            end
        end
    end
    cache.mapName = BJCCore.getMap() ---@diagnostic disable-line custom field

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
    local cache = table.deepcopy(M.BusLines)

    return cache, M.getCacheBusLinesHash()
end

local function getCacheBusLinesHash()
    return Hash(M.BusLines)
end

local function getCacheHunterInfected(senderID)
    local cache = {
        enabledHunter = false,
        enabledInfected = false,
    }
    if M.HunterInfected.enabledHunter or M.HunterInfected.enabledInfected or
        BJCPerm.hasPermission(senderID, BJCPerm.PERMISSIONS.SCENARIO) then
        cache = table.deepcopy(M.HunterInfected)
    end

    return cache, M.getCacheHunterInfectedHash()
end

local function getCacheHunterInfectedHash()
    return Hash(M.HunterInfected)
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

-- VALIDATORS

---@param val any
---@return boolean
local function checkValidVec3(val)
    return type(val) == "table" and
        type(val.x) == "number" and
        type(val.y) == "number" and
        type(val.z) == "number"
end

---@param val any
---@return boolean
local function checkValidQuat(val)
    return type(val) == "table" and
        type(val.x) == "number" and
        type(val.y) == "number" and
        type(val.z) == "number" and
        type(val.w) == "number"
end

---@param val any
---@return boolean
local function checkValidPosRot(val)
    return type(val) == "table" and
        checkValidVec3(val.pos) and
        checkValidQuat(val.rot)
end

---@param val any
---@return boolean
local function checkValidPosAndRadius(val)
    return type(val) == "table" and
        checkValidVec3(val.pos) and
        type(val.radius) == "number"
end

-- FUNCTIONAL

local function getRace(raceID)
    for _, r in ipairs(M.Races) do
        if r.id == raceID then
            return table.deepcopy(r)
        end
    end
    return nil
end

---@param race BJRacePayload
---@return integer raceID
local function saveRace(race)
    local function checkParents(raceData, wpData, wpStep)
        if type(wpData.parents) ~= "table" or #wpData.parents == 0 or
            table.includes(wpData.parents, wpData.name) or
            #Table(wpData.parents):values():duplicates() > 0 then
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
        return checkValidPosRot(wpData) and
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
        not checkValidPosRot(race.previewPosition) then
        error({ key = "rx.errors.invalidData" })
    elseif not race.keepRecord then
        if type(race.loopable) ~= "boolean" or
            type(race.startPositions) ~= "table" or #race.startPositions == 0 or
            type(race.steps) ~= "table" or #race.steps == 0 then
            error({ key = "rx.errors.invalidData" })
        end
        for _, sp in ipairs(race.startPositions) do
            if not checkValidPosRot(sp) then
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
        LogDebug(string.var("Race \"{1}\" hash saved: {2}", { race.name, race.hash }))
    else
        if not baseRace then
            error({ key = "rx.errors.invalidData" })
        end

        race.record = baseRace.record
        race.loopable = baseRace.loopable
        race.startPositions = baseRace.startPositions
        race.steps = baseRace.steps
    end

    race.enabled = race.enabled == true

    -- removing payload temp values
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

---@param raceName string
---@param playerName string
---@param time integer
---@param isRecord boolean?
local function broadcastRaceTime(raceName, playerName, time, isRecord)
    for playerID in pairs(BJCPlayers.Players) do
        BJCChat.onServerChat(playerID,
            BJCLang.getServerMessage(playerID, isRecord and
                "broadcast.newRaceRecord" or "broadcast.raceTime")
            :var({
                playerName = playerName,
                raceName = raceName,
                time = RaceDelay(time),
            }))
    end
end

---@param playerID integer
---@param raceID integer
---@param time integer
---@param model string
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
        broadcastRaceTime(race.name, player.playerName, time, true)
    elseif BJCConfig.Data.Race.RaceSoloTimeBroadcast then
        broadcastRaceTime(race.name, player.playerName, time)
    end

    if BJCTournament.state then
        BJCTournament.saveSoloRaceTime(player.playerName, time)
    end
end

local function saveEnergyStations(stations)
    if not stations then
        error({ key = "rx.errors.invalidData" })
    end
    for _, s in ipairs(stations) do
        if type(s.name) ~= "string" or
            #s.name:trim() == 0 or
            not checkValidPosAndRadius(s) or
            not table.isArray(s.types) or
            #s.types == 0 then
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
    if not table.isArray(garages) or
        Table(garages):any(function(garage)
            return type(garage.name) ~= "string" or
                #garage.name:trim() == 0 or
                not checkValidPosAndRadius(garage)
        end) then
        error({ key = "rx.errors.invalidData" })
    end

    BJCDao.scenario.Garages.save(garages)
    M.Garages = BJCDao.scenario.Garages.findAll()
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.STATIONS)
end

local function saveDeliveryPositions(positions)
    positions = positions or {}
    if not table.isArray(positions) or
        Table(positions):any(function(position)
            return not checkValidPosRot(position) or
                type(position.radius) ~= "number"
        end) then
        error({ key = "rx.errors.invalidData" })
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
    if not table.isArray(lines) or
        Table(lines):any(function(line)
            return type(line.name) ~= "string" or
                #line.name:trim() == 0 or
                type(line.loopable) ~= "boolean" or
                not table.isArray(line.stops) or
                #line.stops < 2 or
                type(line.distance) ~= "number" or
                Table(line.stops):any(function(stop)
                    return type(stop.name) ~= "string" or #stop.name:trim() == 0 or
                        not checkValidPosRot(stop) or
                        type(stop.radius) ~= "number"
                end)
        end) then
        error({ key = "rx.errors.invalidData" })
    end

    BJCDao.scenario.BusLines.save(lines)
    M.BusLines = BJCDao.scenario.BusLines.findAll()
    BJCTx.cache.invalidateByPermissions(BJCCache.CACHES.BUS_LINES,
        BJCPerm.PERMISSIONS.START_PLAYER_SCENARIO,
        BJCPerm.PERMISSIONS.SCENARIO)
end

local function saveHunterInfected(data)
    if type(data) ~= "table" then
        error({ key = "rx.errors.invalidData" })
    else
        data.enabledHunter = data.enabledHunter == true
        data.enabledInfected = data.enabledInfected == true

        if data.enabledHunter then
            if not table.isArray(data.waypoints) or
                #data.waypoints < 2 or
                not Table(data.waypoints):every(checkValidPosAndRadius) or
                not table.isArray(data.majorPositions) or
                #data.majorPositions < 5 or
                not Table(data.majorPositions):every(checkValidPosRot) or
                not table.isArray(data.minorPositions) or
                #data.minorPositions < 2 or
                not Table(data.minorPositions):every(checkValidPosRot) then
                error({ key = "rx.errors.invalidData" })
            end
        end
        if data.enabledInfected then
            if not table.isArray(data.majorPositions) or
                #data.majorPositions < 5 or
                not Table(data.majorPositions):every(checkValidPosRot) or
                not table.isArray(data.minorPositions) or
                #data.minorPositions < 2 or
                not Table(data.minorPositions):every(checkValidPosRot) then
                error({ key = "rx.errors.invalidData" })
            end
        end
    end

    BJCDao.scenario.HunterInfected.save(data)
    M.HunterInfected = BJCDao.scenario.HunterInfected.findAll()
    BJCTx.cache.invalidate(BJCTx.ALL_PLAYERS, BJCCache.CACHES.HUNTER_INFECTED_DATA)
end

---@param arenas BJArena[]
local function saveDerbyArenas(arenas)
    if not table.isArray(arenas) or
        Table(arenas):any(function(arena)
            return type(arena.name) ~= "string" or
                #arena.name:trim() == 0 or
                type(arena.enabled) ~= "boolean" or
                not checkValidPosRot(arena.previewPosition) or
                not table.isArray(arena.startPositions) or
                #arena.startPositions < 6 or
                not Table(arena.startPositions):every(checkValidPosRot) or
                not checkValidVec3(arena.centerPosition) or
                type(arena.radius) ~= "number"
        end) or
        #Table(arenas):map(function(a) return a.name:trim() end):duplicates() > 0 then
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
M.getCacheHunterInfected = getCacheHunterInfected
M.getCacheHunterInfectedHash = getCacheHunterInfectedHash
M.getCacheDerby = getCacheDerby
M.getCacheDerbyHash = getCacheDerbyHash

M.getRace = getRace
M.saveRace = saveRace
M.raceDelete = raceDelete
M.saveRaceRecord = saveRaceRecord
M.broadcastRaceTime = broadcastRaceTime
M.onRaceSoloTime = onRaceSoloTime

M.saveEnergyStations = saveEnergyStations
M.saveGarages = saveGarages

M.saveDeliveryPositions = saveDeliveryPositions
M.updateDeliveryLeaderboard = updateDeliveryLeaderboard

M.saveBusLines = saveBusLines

M.saveHunterInfected = saveHunterInfected

M.saveDerbyArenas = saveDerbyArenas

M.reload = reload
reload()

return M
