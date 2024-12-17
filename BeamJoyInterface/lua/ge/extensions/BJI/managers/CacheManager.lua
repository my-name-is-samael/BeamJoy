local M = {
    _name = "BJICache",
    CACHES = {
        -- default
        LANG = "lang",
        USER = "user",
        GROUPS = "groups",
        PERMISSIONS = "permissions",
        -- player
        PLAYERS = "players",
        MAP = "map",
        ENVIRONMENT = "environment",
        BJC = "bjc",
        VOTE = "vote",
        RACES = "races",
        RACE = "race",
        DELIVERIES = "deliveries",
        DELIVERY_MULTI = "deliverymulti",
        STATIONS = "stations",
        BUS_LINES = "buslines",
        SPEED = "speed",
        HUNTER_DATA = "hunterdata",
        HUNTER = "hunter",
        DERBY_DATA = "derbydata",
        DERBY = "derby",
        -- admin
        DATABASE_PLAYERS = "databasePlayers",
        DATABASE_VEHICLES = "databaseVehicles",
        -- owner
        CORE = "core",
        MAPS = "maps",
    },
    CACHE_STATES = {
        EMPTY = 0,
        PROCESSING = 1,
        READY = 2,
    },
    _hashes = {},
    _states = {},
    _firstLoaded = {},
    _firstInit = false, -- true if all base caches are ready at least once
}
M.BASE_CACHES = {
    M.CACHES.USER,
    M.CACHES.GROUPS,
    M.CACHES.PERMISSIONS,
    M.CACHES.LANG
}
M.CACHE_PERMISSIONS = {
    [M.CACHES.DELIVERIES] = BJIPerm.PERMISSIONS.START_PLAYER_SCENARIO,

    [M.CACHES.DATABASE_PLAYERS] = BJIPerm.PERMISSIONS.DATABASE_PLAYERS,

    [M.CACHES.CORE] = BJIPerm.PERMISSIONS.SET_CORE,
    [M.CACHES.MAPS] = BJIPerm.PERMISSIONS.VOTE_MAP,
}
for _, cacheType in pairs(M.CACHES) do
    M._states[cacheType] = M.CACHE_STATES.EMPTY
end

local function _markCacheReady(cacheType)
    M._states[cacheType] = M.CACHE_STATES.READY
    if not tincludes(M._firstLoaded, cacheType) then
        table.insert(M._firstLoaded, cacheType)
    end
end

local function isCacheReady(cacheType)
    return M._states[cacheType] == M.CACHE_STATES.READY
end

local function isFirstLoaded(cacheType)
    return tincludes(M._firstLoaded, cacheType)
end

local function areBaseCachesFirstLoaded()
    if M._firstInit then
        return true
    end

    local loaded = true
    for _, cacheType in pairs(M.BASE_CACHES) do
        if not M.isCacheReady(cacheType) then
            loaded = false
        end
    end
    if loaded then
        M._firstInit = true
    end
    return loaded
end

local function _tryRequestCache(cacheType)
    local permissionName = M.CACHE_PERMISSIONS[cacheType]
    if permissionName then
        if BJIPerm.hasPermission(permissionName) then
            LogDebug(svar("Requesting cache {1}", { cacheType }), M._name)
            M._states[cacheType] = M.CACHE_STATES.PROCESSING
            BJITx.cache.require(cacheType)
        end
    else
        -- no permission on this cache
        LogDebug(svar("Requesting cache {1}", { cacheType }), M._name)
        M._states[cacheType] = M.CACHE_STATES.PROCESSING
        BJITx.cache.require(cacheType)
    end
end

local function invalidate(cacheType)
    M._states[cacheType] = M.CACHE_STATES.EMPTY
end

local function parseCache(cacheType, cacheData, cacheHash)
    LogDebug(svar("Received cache {1}", { cacheType }), M._name)
    local foundCache = true
    if cacheType == M.CACHES.USER then
        BJIContext.User.playerID = cacheData.playerID
        BJIContext.User.playerName = cacheData.playerName
        BJIContext.User.group = cacheData.group
        BJIContext.User.lang = cacheData.lang
        BJIContext.User.freeze = cacheData.freeze == true
        BJIContext.User.engine = cacheData.engine == true
        BJIAsync.task(function()
            return BJICache.areBaseCachesFirstLoaded()
        end, function()
            local group = BJIPerm.Groups[BJIContext.User.group]
            BJIAI.update(group.canSpawnAI)
            if not group.canSpawn and BJIVeh.hasVehicle() then
                BJIVeh.deleteAllOwnVehicles()
            end
        end, "BJIUpdateUserByGroup")

        -- vehicles
        BJIContext.User.currentVehicle = cacheData.currentVehicle
        for vehID, vehicle in pairs(cacheData.vehicles) do
            if not BJIContext.User.vehicles[vehID] then
                BJIContext.User.vehicles[vehID] = {
                    freezeStation = false,
                    engineStation = true,
                }
            end
            tdeepassign(BJIContext.User.vehicles[vehID], vehicle)
        end
        -- remove obsolete vehicles
        for vehID in pairs(BJIContext.User.vehicles) do
            if not cacheData.vehicles[vehID] then
                BJIContext.User.vehicles[vehID] = nil
            end
        end
        BJIScenario.updateVehicles()

        BJIReputation.updateReputationSmooth(cacheData.reputation)

        for k, v in pairs(cacheData.settings) do
            BJIContext.UserSettings[k] = v
        end
        BJIContext.UserStats = cacheData.stats


        BJIAsync.task(function()
            return not not BJIContext.BJC.Freeroam
        end, function()
            -- update quick travel
            if BJIScenario.isFreeroam() then
                BJIQuickTravel.toggle(BJIContext.BJC.Freeroam.QuickTravel or BJIPerm.isStaff())
            end
            -- update nametags
            BJINametags.tryUpdate()
        end, "BJICacheFreeroamReady")
    elseif cacheType == M.CACHES.GROUPS then
        for groupName, group in pairs(cacheData) do
            if not BJIPerm.Groups[groupName] then
                BJIPerm.Groups[groupName] = {}
            end
            -- bind values
            for k, v in pairs(group) do
                BJIPerm.Groups[groupName][k] = v
            end
            -- remove obsolete keys
            for k in pairs(BJIPerm.Groups[groupName]) do
                if not tincludes({ "_new" }, k, true) and
                    not tincludes(tkeys(group), k, true) then
                    BJIPerm.Groups[groupName][k] = nil
                end
            end
            -- new permission input
            if not BJIPerm.Groups[groupName]._new then
                BJIPerm.Groups[groupName]._new = ""
            end
        end
        -- remove obsolete groups
        for k in pairs(BJIPerm.Groups) do
            if not tincludes({ "_new", "_newLevel" }, k) and
                not tincludes(tkeys(cacheData), k, true) then
                BJIPerm.Groups[k] = nil
            end
        end

        -- new group inputs
        if not BJIPerm.Groups._new then
            BJIPerm.Groups._new = ""
            BJIPerm.Groups._newLevel = 0
        end
    elseif cacheType == M.CACHES.PERMISSIONS then
        for k, v in pairs(cacheData) do
            BJIPerm.Permissions[k] = v
        end
    elseif cacheType == M.CACHES.LANG then
        BJILang.Langs = cacheData.langs
        table.sort(BJILang.Langs, function(a, b) return a:lower() < b:lower() end)
        BJILang.Messages = cacheData.messages
    elseif cacheType == M.CACHES.ENVIRONMENT then
        local previous = {
            gravityRate = BJIEnv.Data.gravityRate and BJIEnv.Data.gravityRate or nil,
            simSpeed = BJIEnv.Data.simSpeed and BJIEnv.Data.simSpeed or nil,
        }

        for k, v in pairs(cacheData) do
            BJIEnv.Data[k] = v

            if k == "shadowTexSize" then
                local shadowTexVal = 5
                while 2 ^ shadowTexVal < v do
                    shadowTexVal = shadowTexVal + 1
                end
                BJIEnv.Data.shadowTexSizeInput = shadowTexVal - 4
            end
        end

        BJIEnv.updateCurrentPreset()

        local presetsUtils = require("ge/extensions/utils/EnvironmentUtils")

        BJIContext.UI.gravity = {
            value = BJIEnv.Data.gravityRate,
        }
        if BJIEnv.Data.gravityRate ~= nil then
            for _, p in ipairs(presetsUtils.gravityPresets()) do
                if Round(p.value, 3) == Round(BJIEnv.Data.gravityRate, 3) then
                    BJIContext.UI.gravity.key = p.key
                    BJIContext.UI.gravity.default = p.default
                end
            end
            if previous.gravityRate ~= BJIEnv.Data.gravityRate and BJIContext.UI.gravity.key then
                local label = BJILang.get(svar("presets.gravity.{1}", { BJIContext.UI.gravity.key }))
                BJIToast.info(svar("Gravity changed to {1}", { label }))
            end
        end

        BJIContext.UI.speed = {
            value = BJIEnv.Data.simSpeed,
        }
        for _, p in ipairs(presetsUtils.speedPresets()) do
            if Round(p.value, 3) == Round(BJIEnv.Data.simSpeed, 3) then
                BJIContext.UI.speed.key = p.key
                BJIContext.UI.speed.default = p.default
            end
        end
        if previous.simSpeed ~= BJIEnv.Data.simSpeed and BJIContext.UI.speed.key then
            local label = BJILang.get(svar("presets.speed.{1}", { BJIContext.UI.speed.key }))
            BJIToast.info(svar("Speed changed to {1}", { label }))
        end
    elseif cacheType == M.CACHES.PLAYERS then
        for _, pData in pairs(cacheData) do
            if not BJIContext.Players[pData.playerID] then
                BJIContext.Players[pData.playerID] = {
                    playerID = pData.playerID,
                    playerName = pData.playerName,
                    guest = true,
                    muteReason = "",
                    kickReason = "",
                    banReason = "",
                    tempBanDuration = BJIContext.BJC.TempBan and BJIContext.BJC.TempBan.minTime or 0,
                    hideNametag = false,
                    currentVehicle = nil,
                    vehicles = {},
                    ai = {},
                }
            end
            local player = BJIContext.Players[pData.playerID]
            for k, v in pairs(pData) do
                player[k] = v
            end
        end

        -- remove obsolete players
        for k, v in pairs(BJIContext.Players) do
            local found = false
            for _, v2 in pairs(cacheData) do
                if v.playerName == v2.playerName then
                    found = true
                end
            end
            if not found then
                BJIContext.Players[k] = nil
            end
        end

        -- update AI vehicles (to hide their nametags)
        BJIAI.updateVehicles()
    elseif cacheType == M.CACHES.MAP then
        BJIContext.UI.mapName = cacheData.name
        BJIContext.UI.mapLabel = cacheData.label
        BJIContext.UI.dropSizeRatio = cacheData.dropSizeRatio or 1
    elseif cacheType == M.CACHES.VOTE then
        if cacheData.Kick then
            BJIVote.Kick.threshold = cacheData.Kick.threshold
            BJIVote.Kick.creatorID = cacheData.Kick.creatorID
            BJIVote.Kick.targetID = cacheData.Kick.targetID
            BJIVote.Kick.endsAt = BJITick.applyTimeOffset(cacheData.Kick.endsAt)
            BJIVote.Kick.amountVotes = cacheData.Kick.voters and tlength(cacheData.Kick.voters) or 0
            BJIVote.Kick.selfVoted = cacheData.Kick.voters and
                tincludes(cacheData.Kick.voters, BJIContext.User.playerID, true) or false
        end
        if cacheData.Map then
            BJIVote.Map.threshold = cacheData.Map.threshold
            BJIVote.Map.creatorID = cacheData.Map.creatorID
            BJIVote.Map.mapLabel = cacheData.Map.mapLabel
            BJIVote.Map.mapCustom = cacheData.Map.mapCustom == true
            BJIVote.Map.endsAt = BJITick.applyTimeOffset(cacheData.Map.endsAt)
            BJIVote.Map.amountVotes = cacheData.Map.voters and tlength(cacheData.Map.voters) or 0
            BJIVote.Map.selfVoted = cacheData.Map.voters and
                tincludes(cacheData.Map.voters, BJIContext.User.playerID, true) or false
        end
        if cacheData.Race then
            BJIVote.Race.threshold = cacheData.Race.threshold
            BJIVote.Race.creatorID = cacheData.Race.creatorID
            BJIVote.Race.endsAt = BJITick.applyTimeOffset(cacheData.Race.endsAt)
            BJIVote.Race.isVote = cacheData.Race.isVote
            BJIVote.Race.raceName = cacheData.Race.raceName
            BJIVote.Race.places = cacheData.Race.places
            BJIVote.Race.record = cacheData.Race.record
            BJIVote.Race.timeLabel = cacheData.Race.timeLabel
            BJIVote.Race.weatherLabel = cacheData.Race.weatherLabel
            BJIVote.Race.laps = cacheData.Race.laps
            BJIVote.Race.model = cacheData.Race.model
            BJIVote.Race.specificConfig = cacheData.Race.specificConfig == true
            BJIVote.Race.respawnStrategy = cacheData.Race.respawnStrategy
            BJIVote.Race.amountVotes = cacheData.Race.voters and tlength(cacheData.Race.voters) or 0
            BJIVote.Race.selfVoted = cacheData.Race.voters and
                tincludes(cacheData.Race.voters, BJIContext.User.playerID, true) or false
        end
        if cacheData.Speed then
            BJIVote.Speed.creatorID = cacheData.Speed.creatorID
            BJIVote.Speed.isEvent = not cacheData.Speed.isVote
            BJIVote.Speed.endsAt = cacheData.Speed.endsAt
            BJIVote.Speed.participants = cacheData.Speed.participants
        end
    elseif cacheType == M.CACHES.BJC then
        local bjcConf = BJIContext.BJC

        if cacheData.Freeroam then
            if not bjcConf.Freeroam then
                bjcConf.Freeroam = {}
            end
            for k, v in pairs(cacheData.Freeroam) do
                bjcConf.Freeroam[k] = v
            end

            -- update quick travel
            if BJIScenario.isFreeroam() then
                BJIQuickTravel.toggle(bjcConf.Freeroam.QuickTravel or BJIPerm.isStaff())
            end
            -- update nametags
            if BJIScenario.isFreeroam() or BJIScenario.isPlayerScenarioInProgress() then
                BJINametags.toggle((bjcConf.Freeroam.Nametags or BJIPerm.isStaff()) and
                    BJIContext.UserSettings.nametags)
            end
        end

        if cacheData.TempBan then
            bjcConf.TempBan = cacheData.TempBan
        end

        if cacheData.Whitelist then
            if not bjcConf.Whitelist then
                bjcConf.Whitelist = {
                    PlayerName = "",
                }
            end
            for k, v in pairs(cacheData.Whitelist) do
                bjcConf.Whitelist[k] = v
            end
        end

        if cacheData.VoteKick then
            bjcConf.VoteKick = cacheData.VoteKick
        end

        if cacheData.VoteMap then
            bjcConf.VoteMap = cacheData.VoteMap
        end

        if cacheData.Server then
            if not bjcConf.Server then
                bjcConf.Server = {
                    BroadcastsLang = "en",
                    WelcomeMessageLang = "en",
                }
            end
            for k, v in pairs(cacheData.Server) do
                bjcConf.Server[k] = v
            end

            -- apply windows theme
            if bjcConf.Server.Theme then
                LoadTheme(bjcConf.Server.Theme)
            end

            -- fill in available langs
            if bjcConf.Server.Broadcasts then
                for _, lang in ipairs(BJILang.Langs) do
                    if not bjcConf.Server.Broadcasts[lang] then
                        bjcConf.Server.Broadcasts[lang] = {}
                    end
                    if not bjcConf.Server.WelcomeMessage[lang] then
                        bjcConf.Server.WelcomeMessage[lang] = ""
                    end
                end
            end

            BJIMods.update(bjcConf.Server.AllowClientMods)
        end

        if cacheData.CEN then
            bjcConf.CEN = cacheData.CEN
            BJIRestrictions.updateCEN()
        end

        if cacheData.Race then
            bjcConf.Race = cacheData.Race
        end

        if cacheData.Speed then
            bjcConf.Speed = cacheData.Speed
        end

        if cacheData.Hunter then
            bjcConf.Hunter = cacheData.Hunter
        end

        if cacheData.VehicleDelivery then
            bjcConf.VehicleDelivery = cacheData.VehicleDelivery
        end

        if cacheData.Reputation then
            bjcConf.Reputation = cacheData.Reputation
        end
    elseif cacheType == M.CACHES.DATABASE_PLAYERS then
        if not BJIContext.Database then
            BJIContext.Database = {}
        end

        BJIContext.Database.Players = cacheData
    elseif cacheType == M.CACHES.DATABASE_VEHICLES then
        if not BJIContext.Database then
            BJIContext.Database = {}
        end

        BJIContext.Database.Vehicles = cacheData
    elseif cacheType == M.CACHES.CORE then
        BJIContext.Core = cacheData
    elseif cacheType == M.CACHES.MAPS then
        if not BJIContext.Maps then
            BJIContext.Maps = {
                Data = {},
                new = "",
                newLabel = "",
                newArchive = "",
            }
        end
        BJIContext.Maps.Data = cacheData
    elseif cacheType == M.CACHES.RACES then
        BJIContext.Scenario.Data.Races = cacheData
        if BJIContext.Scenario.Data.Races and #BJIContext.Scenario.Data.Races > 0 then
            for _, r in ipairs(BJIContext.Scenario.Data.Races) do
                -- previewPosition
                local pp = r.previewPosition
                if pp then
                    _, pp.pos = pcall(vec3, pp.pos.x, pp.pos.y, pp.pos.z)
                    _, pp.rot = pcall(quat, pp.rot.x, pp.rot.y, pp.rot.z, pp.rot.w)
                end
                -- race steps
                if r.steps then
                    for _, step in ipairs(r.steps) do
                        for _, wp in ipairs(step) do
                            _, wp.pos = pcall(vec3, wp.pos.x, wp.pos.y, wp.pos.z)
                            _, wp.rot = pcall(quat, wp.rot.x, wp.rot.y, wp.rot.z, wp.rot.w)
                        end
                    end
                end
                -- startPositions
                if r.startPositions then
                    for _, sp in ipairs(r.startPositions) do
                        _, sp.pos = pcall(vec3, sp.pos.x, sp.pos.y, sp.pos.z)
                        _, sp.rot = pcall(quat, sp.rot.x, sp.rot.y, sp.rot.z, sp.rot.w)
                    end
                end
            end
        end
    elseif cacheType == M.CACHES.RACE then
        local fn = function()
            BJIScenario.get(BJIScenario.TYPES.RACE_MULTI).rxData(cacheData)
        end
        if BJIScenario.get(BJIScenario.TYPES.RACE_MULTI) then
            fn()
        else
            BJIAsync.task(function()
                return not not BJIScenario.get(BJIScenario.TYPES.RACE_MULTI)
            end, fn, "BJIInitRaceData")
        end
    elseif cacheType == M.CACHES.DELIVERIES then
        BJIContext.Scenario.Data.Deliveries = cacheData.Deliveries
        if BJIContext.Scenario.Data.Deliveries and #BJIContext.Scenario.Data.Deliveries > 0 then
            for _, position in ipairs(BJIContext.Scenario.Data.Deliveries) do
                _, position.pos = pcall(vec3, position.pos.x, position.pos.y, position.pos.z)
                _, position.rot = pcall(quat, position.rot.x, position.rot.y, position.rot.z, position.rot.w)
            end
        end
        BJIContext.Scenario.Data.DeliveryLeaderboard = cacheData.DeliveryLeaderboard
    elseif cacheType == M.CACHES.DELIVERY_MULTI then
        if BJIScenario.get(BJIScenario.TYPES.DELIVERY_MULTI) then
            BJIScenario.get(BJIScenario.TYPES.DELIVERY_MULTI).rxData(cacheData)
        else
            BJIAsync.task(function()
                return BJIScenario.get(BJIScenario.TYPES.DELIVERY_MULTI)
            end, function()
                BJIScenario.get(BJIScenario.TYPES.DELIVERY_MULTI).rxData(cacheData)
            end, "BJIDeliveryMultiRxData")
        end
    elseif cacheType == M.CACHES.STATIONS then
        BJIContext.Scenario.Data.EnergyStations = cacheData.EnergyStations
        if BJIContext.Scenario.Data.EnergyStations and #BJIContext.Scenario.Data.EnergyStations > 0 then
            for _, station in ipairs(BJIContext.Scenario.Data.EnergyStations) do
                _, station.pos = pcall(vec3, station.pos.x, station.pos.y, station.pos.z)
            end
        end
        BJIContext.Scenario.Data.Garages = cacheData.Garages
    elseif cacheType == M.CACHES.BUS_LINES then
        BJIContext.Scenario.Data.BusLines = cacheData.BusLines
        if BJIContext.Scenario.Data.BusLines and #BJIContext.Scenario.Data.BusLines > 0 then
            for _, line in ipairs(BJIContext.Scenario.Data.BusLines) do
                for _, stop in ipairs(line.stops) do
                    _, stop.pos = pcall(vec3, stop.pos.x, stop.pos.y, stop.pos.z)
                    _, stop.rot = pcall(quat, stop.rot.x, stop.rot.y, stop.rot.z, stop.rot.w)
                end
            end
        end
    elseif cacheType == M.CACHES.SPEED then
        local fn = function()
            BJIScenario.get(BJIScenario.TYPES.SPEED).rxData(cacheData)
        end
        if BJIScenario.get(BJIScenario.TYPES.SPEED) then
            fn()
        else
            BJIAsync.task(function()
                return not not BJIScenario.get(BJIScenario.TYPES.SPEED)
            end, fn, "BJIInitSpeedData")
        end
    elseif cacheType == M.CACHES.HUNTER_DATA then
        BJIContext.Scenario.Data.Hunter = cacheData
    elseif cacheType == M.CACHES.HUNTER then
        if BJIScenario.get(BJIScenario.TYPES.HUNTER) then
            BJIScenario.get(BJIScenario.TYPES.HUNTER).rxData(cacheData)
        else
            BJIAsync.task(function()
                return BJIScenario.get(BJIScenario.TYPES.HUNTER)
            end, function()
                BJIScenario.get(BJIScenario.TYPES.HUNTER).rxData(cacheData)
            end, "BJICacheHunterInit")
        end
    elseif cacheType == M.CACHES.DERBY_DATA then
        BJIContext.Scenario.Data.Derby = cacheData
    elseif cacheType == M.CACHES.DERBY then
        if BJIScenario.get(BJIScenario.TYPES.DERBY) then
            BJIScenario.get(BJIScenario.TYPES.DERBY).rxData(cacheData)
        else
            BJIAsync.task(function()
                return BJIScenario.get(BJIScenario.TYPES.DERBY)
            end, function()
                BJIScenario.get(BJIScenario.TYPES.DERBY).rxData(cacheData)
            end, "BJICacheDerbyInit")
        end
    else
        foundCache = false
    end

    if foundCache then
        M._hashes[cacheType] = cacheHash
    end

    _markCacheReady(cacheType)
end

local function slowTick(ctxt)
    if ctxt.cachesHashes then
        for cacheType, hash in pairs(ctxt.cachesHashes) do
            if M.isCacheReady(cacheType) and M._hashes[cacheType] ~= hash then
                _tryRequestCache(cacheType)
            end
        end
    end

    for _, cacheType in pairs(M.BASE_CACHES) do
        if M._states[cacheType] == M.CACHE_STATES.EMPTY then
            M._states[cacheType] = M.CACHE_STATES.PROCESSING
            LogDebug(svar("Requesting cache {1}", { cacheType }), M._name)
            BJITx.cache.require(cacheType)
        end
    end

    if M.areBaseCachesFirstLoaded() then
        for _, cacheType in pairs(M.CACHES) do
            if not tincludes(M.BASE_CACHES, cacheType, true) then
                if M._states[cacheType] == M.CACHE_STATES.EMPTY then
                    _tryRequestCache(cacheType)
                end
            end
        end
    end
end

M.isCacheReady = isCacheReady
M.isFirstLoaded = isFirstLoaded
M.areBaseCachesFirstLoaded = areBaseCachesFirstLoaded
M.invalidate = invalidate
M.parseCache = parseCache

M.slowTick = slowTick

RegisterBJIManager(M)
return M
