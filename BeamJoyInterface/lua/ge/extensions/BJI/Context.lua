---@class BJIUser
---@field playerID integer
---@field playerName string
---@field group string
---@field lang string
---@field freeze boolean
---@field engine boolean
---@field vehicles table<integer, BJIVehicleData>
---@field currentVehicle? integer gameVehID

local C = {
    _name = "BJIContext",
    DEBUG = false,
    GUI = {
        setupEditorGuiTheme = nop,
    },

    physics = {
        physmult = 1,
        VehiclePristineThreshold = 100,
    },

    WorldReadyState = 0,
    WorldCache = {},

    UI = {
        mapName = "",
        mapLabel = "",
        dropSizeRatio = 1,
        ---@type {value: number, key: string, default: boolean}
        gravity = nil, -- save current gravity preset if there is one
        ---@type {value: number, key: string, default: boolean}
        speed = nil,   -- save current speed preset if not default
    },

    User = {
        playerID = 0,
        playerName = "",
        group = nil,
        lang = nil,
        freeze = false,
        engine = true,
        currentVehicle = nil,
        delivery = 0,
        vehicles = {},
    },

    UserStats = {},

    -- CONFIG DATA
    BJC = {},     -- BeamJoy config
    Players = {}, -- player list
    Scenario = {
        FreeroamSettingsOpen = false,
        Data = {}, -- Scenarii data
        RaceSettings = nil,
        BusSettings = nil,
        Race = nil,

        RaceEdit = nil,
        EnergyStationsEdit = nil,
        GaragesEdit = nil,
        DeliveryEdit = nil,
        HunterEdit = nil,
    },
    Database = {},

    -- CONFIG WINDOWS STATES
    ServerEditorOpen = false,
    EnvironmentEditorOpen = false,
    DatabaseEditorOpen = false,
}

local function loadUser()
    BJICache.addRxHandler(BJICache.CACHES.USER, function(cacheData)
        local previous = table.clone(C.User) or {}

        C.User.playerID = cacheData.playerID
        C.User.playerName = cacheData.playerName
        C.User.group = cacheData.group
        C.User.lang = cacheData.lang
        C.User.freeze = cacheData.freeze == true
        C.User.engine = cacheData.engine == true
        BJIAsync.task(function()
            return BJICache.areBaseCachesFirstLoaded()
        end, function()
            local group = BJIPerm.Groups[C.User.group]
            BJIAI.toggle(group.canSpawnAI)
            if not group.canSpawn and BJIVeh.hasVehicle() then
                BJIVeh.deleteAllOwnVehicles()
            end
        end, "BJIUpdateUserByGroup")

        -- vehicles
        C.User.currentVehicle = cacheData.currentVehicle
        for vehID, vehicle in pairs(cacheData.vehicles) do
            if not C.User.vehicles[vehID] then
                C.User.vehicles[vehID] = {
                    freezeStation = false,
                    engineStation = true,
                }
            end
            table.assign(C.User.vehicles[vehID], vehicle)
        end
        -- remove obsolete vehicles
        for vehID in pairs(C.User.vehicles) do
            if not cacheData.vehicles[vehID] then
                C.User.vehicles[vehID] = nil
            end
        end
        BJIScenario.updateVehicles()

        BJIReputation.updateReputationSmooth(cacheData.reputation)

        C.UserStats = cacheData.stats

        BJIAsync.task(function()
            return not not C.BJC.Freeroam
        end, function()
            -- update quick travel
            if BJIScenario.isFreeroam() then
                BJIBigmap.toggleQuickTravel(C.BJC.Freeroam.QuickTravel or BJIPerm.isStaff())
            end
            -- update nametags
            BJINametags.tryUpdate()
        end, "BJICacheFreeroamReady")

        if C.User.group ~= previous.group then
            BJIAsync.task(function()
                return BJICache.areBaseCachesFirstLoaded() and BJICONNECTED
            end, function()
                -- update AI restriction
                BJIRestrictions.update({ {
                    restrictions = BJIRestrictions.OTHER.AI_CONTROL,
                    state = not BJIPerm.canSpawnAI(),
                } })

                -- update vehSelector restriction
                BJIRestrictions.update({ {
                    restrictions = Table({
                        BJIRestrictions.OTHER.VEHICLE_SELECTOR,
                        BJIRestrictions.OTHER.VEHICLE_PARTS_SELECTOR,
                    }):flat(),
                    state = not BJIPerm.canSpawnVehicle(),
                } })
            end)
        end

        -- events detection
        local previousVehCount = table.length(previous.vehicles)
        local currentVehCount = table.length(C.User.vehicles)
        if previousVehCount ~= currentVehCount then
            if previousVehCount < currentVehCount then
                -- new veh
                table.find(C.User.vehicles, function(_, vehID)
                    return not previous.vehicles[vehID]
                end, function(veh)
                    BJIEvents.trigger(BJIEvents.EVENTS.VEHICLE_SPAWNED, {
                        self = true,
                        playerID = C.User.playerID,
                        vehID = veh.vehID,
                        gameVehID = veh.gameVehID,
                        vehData = veh,
                    })
                end)
            else
                -- removed veh
                table.find(previous.vehicles, function(_, vehID)
                    return not C.User.vehicles[vehID]
                end, function(veh)
                    BJIEvents.trigger(BJIEvents.EVENTS.VEHICLE_REMOVED, {
                        self = true,
                        playerID = C.User.playerID,
                        vehID = veh.vehID,
                        gameVehID = veh.gameVehID,
                        vehData = veh,
                    })
                end)
            end
        end

        if previous.group ~= C.User.group then
            BJIEvents.trigger(BJIEvents.EVENTS.PERMISSION_CHANGED, {
                self = true,
                type = "group_assign",
            })
        end
    end)
end

local function loadPlayers()
    BJICache.addRxHandler(BJICache.CACHES.PLAYERS, function(cacheData)
        local previousPlayers = table.clone(C.Players)
        for _, p in pairs(cacheData) do
            if not C.Players[p.playerID] then
                C.Players[p.playerID] = {
                    playerID = p.playerID,
                    playerName = p.playerName,
                    guest = true,
                    muteReason = "",
                    kickReason = "",
                    banReason = "",
                    tempBanDuration = C.BJC.TempBan and C.BJC.TempBan.minTime or 0, -- input for mods+
                    hideNametag = false,
                    currentVehicle = nil,
                    vehicles = {},
                    ai = {},
                }
            end
            local player = C.Players[p.playerID]
            for k, v in pairs(p) do
                player[k] = v
            end
        end

        -- remove obsolete players
        for k, v in pairs(C.Players) do
            local found = false
            for _, v2 in pairs(cacheData) do
                if v.playerName == v2.playerName then
                    found = true
                end
            end
            if not found then
                C.Players[k] = nil
            end
        end

        -- update AI vehicles (to hide their nametags)
        BJIAI.updateVehicles(Table(C.Players)
            :filter(function(player) return #player.ai > 0 end)
            :map(function(player)
                local self = C.isSelf(player.playerID)
                player.ai = Table(player.ai):map(function(vid)
                    if not self then
                        vid = BJIVeh.getGameVehIDByRemoteVehID(vid)
                    end
                    return BJIVeh.getVehicleObject(vid) and vid or nil
                end):values()
                return player.ai
            end)
            :reduce(function(acc, aiVehs) return acc:addAll(aiVehs) end, Table()))

        -- events detection
        local previousPlayersCount = table.length(previousPlayers)
        local currentPlayersCount = table.length(C.Players)
        if previousPlayersCount ~= currentPlayersCount then
            if previousPlayersCount < currentPlayersCount then
                -- player connected
                table.find(C.Players, function(_, playerID)
                    return not previousPlayers[playerID]
                end, function(player)
                    BJIEvents.trigger(BJIEvents.EVENTS.PLAYER_CONNECT, {
                        playerID = player.playerID,
                        playerName = player.playerName,
                    })
                end)
            else
                -- player disconnected
                table.find(previousPlayers, function(_, playerID)
                    return not C.Players[playerID]
                end, function(player)
                    BJIEvents.trigger(BJIEvents.EVENTS.PLAYER_DISCONNECT, {
                        playerID = player.playerID,
                        playerName = player.playerName,
                    })
                end)
            end
        end
    end)
end

local previousUI = {}
local function loadUI()
    -- env data for UI
    previousUI.gravityRate = BJIEnv.Data.gravityRate
    previousUI.simSpeed = BJIEnv.Data.simSpeed
    BJICache.addRxHandler(BJICache.CACHES.ENVIRONMENT, function(cacheData)
        local presetsUtils = require("ge/extensions/utils/EnvironmentUtils")

        C.UI.gravity = {
            value = cacheData.gravityRate,
        }
        if cacheData.gravityRate ~= nil then
            for _, p in ipairs(presetsUtils.gravityPresets()) do
                if math.round(p.value, 3) == math.round(cacheData.gravityRate, 3) then
                    C.UI.gravity.key = p.key
                    C.UI.gravity.default = p.default
                end
            end
            if previousUI.gravityRate ~= cacheData.gravityRate and C.UI.gravity.key then
                local label = BJILang.get(string.var("presets.gravity.{1}", { C.UI.gravity.key }))
                BJIToast.info(string.var("Gravity changed to {1}", { label }))
            end
        end

        C.UI.speed = {
            value = cacheData.simSpeed,
        }
        for _, p in ipairs(presetsUtils.speedPresets()) do
            if math.round(p.value, 3) == math.round(cacheData.simSpeed, 3) then
                C.UI.speed.key = p.key
                C.UI.speed.default = p.default
            end
        end
        if previousUI.simSpeed ~= cacheData.simSpeed and C.UI.speed.key then
            local label = BJILang.get(string.var("presets.speed.{1}", { C.UI.speed.key }))
            BJIToast.info(string.var("Speed changed to {1}", { label }))
        end

        previousUI.gravityRate = cacheData.gravityRate
        previousUI.simSpeed = cacheData.simSpeed
    end)

    -- map data for UI
    BJICache.addRxHandler(BJICache.CACHES.MAP, function(cacheData)
        C.UI.mapName = cacheData.name
        C.UI.mapLabel = cacheData.label
        C.UI.dropSizeRatio = cacheData.dropSizeRatio or 1
    end)
end

local function loadConfig()
    -- core data
    BJICache.addRxHandler(BJICache.CACHES.CORE, function(cacheData)
        local previous = table.clone(C.Core) or {}
        C.Core = cacheData

        -- events detection
        local keyChanged = {}
        for k, v in pairs(C.Core) do
            if v ~= previous[k] then
                keyChanged[k] = {
                    previousValue = previous[k],
                    currentValue = v,
                }
            end
        end
        if table.length(keyChanged) > 0 then
            BJIEvents.trigger(BJIEvents.EVENTS.CORE_CHANGED, keyChanged)
        end
    end)

    -- bjc data
    BJICache.addRxHandler(BJICache.CACHES.BJC, function(cacheData)
        if cacheData.Freeroam then
            if not C.BJC.Freeroam then
                C.BJC.Freeroam = {}
            end
            for k, v in pairs(cacheData.Freeroam) do
                C.BJC.Freeroam[k] = v
            end

            if BJIScenario.isFreeroam() then
                --update unicycle policy
                if not C.BJC.Freeroam.AllowUnicycle and BJIVeh.isUnicycle() then
                    BJIVeh.deleteCurrentOwnVehicle()
                end
                BJIRestrictions.update({ {
                    restrictions = BJIRestrictions.OTHER.WALKING,
                    state = not C.BJC.Freeroam.AllowUnicycle,
                } })

                -- update quick travel
                BJIBigmap.toggleQuickTravel(C.BJC.Freeroam.QuickTravel or BJIPerm.isStaff())
            end

            -- update nametags
            if BJIScenario.isFreeroam() or BJIScenario.isPlayerScenarioInProgress() then
                BJINametags.toggle((C.BJC.Freeroam.Nametags or BJIPerm.isStaff()) and
                    not settings.getValue("hideNameTags", false))
            end
        end

        if cacheData.TempBan then
            C.BJC.TempBan = cacheData.TempBan
        end

        if cacheData.Whitelist then
            if not C.BJC.Whitelist then
                C.BJC.Whitelist = {
                    PlayerName = "",
                }
            end
            for k, v in pairs(cacheData.Whitelist) do
                C.BJC.Whitelist[k] = v
            end
        end

        if cacheData.VoteKick then
            C.BJC.VoteKick = cacheData.VoteKick
        end

        if cacheData.VoteMap then
            C.BJC.VoteMap = cacheData.VoteMap
        end

        if cacheData.Server then
            if not C.BJC.Server then
                C.BJC.Server = {
                    BroadcastsLang = "en",
                    WelcomeMessageLang = "en",
                }
            end
            for k, v in pairs(cacheData.Server) do
                C.BJC.Server[k] = v
            end

            -- apply windows theme
            if C.BJC.Server.Theme then
                LoadTheme(C.BJC.Server.Theme)
            end

            -- fill in available langs
            if C.BJC.Server.Broadcasts then
                for _, lang in ipairs(BJILang.Langs) do
                    if not C.BJC.Server.Broadcasts[lang] then
                        C.BJC.Server.Broadcasts[lang] = {}
                    end
                    if not C.BJC.Server.WelcomeMessage[lang] then
                        C.BJC.Server.WelcomeMessage[lang] = ""
                    end
                end
            end

            BJIMods.update(C.BJC.Server.AllowClientMods)
        end

        if cacheData.CEN then
            C.BJC.CEN = cacheData.CEN
            local restrictions = Table()
            if not BJIPerm.hasMinimumGroup(BJI_GROUP_NAMES.ADMIN) and
                not BJIContext.BJC.CEN.Console then
                restrictions:addAll(BJIRestrictions.CEN.CONSOLE)
            end
            if not BJIPerm.hasMinimumGroup(BJI_GROUP_NAMES.ADMIN) and
                not BJIContext.BJC.CEN.Editor then
                restrictions:addAll(BJIRestrictions.CEN.EDITOR)
            end
            if not BJIPerm.hasMinimumGroup(BJI_GROUP_NAMES.ADMIN) and
                not BJIContext.BJC.CEN.NodeGrabber then
                restrictions:addAll(BJIRestrictions.CEN.NODEGRABBER)
            end
            BJIRestrictions.updateCEN(restrictions)
        end

        if cacheData.Race then
            C.BJC.Race = cacheData.Race
        end

        if cacheData.Speed then
            C.BJC.Speed = cacheData.Speed
        end

        if cacheData.Hunter then
            C.BJC.Hunter = cacheData.Hunter
        end

        if cacheData.VehicleDelivery then
            C.BJC.VehicleDelivery = cacheData.VehicleDelivery
        end

        if cacheData.Reputation then
            C.BJC.Reputation = cacheData.Reputation
        end
    end)
end

local function loadDatabase()
    BJICache.addRxHandler(BJICache.CACHES.DATABASE_PLAYERS, function(cacheData)
        if not C.Database then
            C.Database = {}
        end

        C.Database.Players = cacheData
    end)

    BJICache.addRxHandler(BJICache.CACHES.DATABASE_VEHICLES, function(cacheData)
        if not C.Database then
            C.Database = {}
        end

        C.Database.Vehicles = cacheData
    end)
end

local function loadMaps()
    BJICache.addRxHandler(BJICache.CACHES.MAPS, function(cacheData)
        if not C.Maps then
            C.Maps = {
                Data = {},
                new = "",
                newLabel = "",
                newArchive = "",
            }
        end
        C.Maps.Data = cacheData
    end)
end

local function loadScenarii()
    -- races data
    BJICache.addRxHandler(BJICache.CACHES.RACES, function(cacheData)
        C.Scenario.Data.Races = cacheData
        if C.Scenario.Data.Races and #C.Scenario.Data.Races > 0 then
            for _, r in ipairs(C.Scenario.Data.Races) do
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
    end)

    -- deliveries data
    BJICache.addRxHandler(BJICache.CACHES.DELIVERIES, function(cacheData)
        C.Scenario.Data.Deliveries = cacheData.Deliveries
        if C.Scenario.Data.Deliveries and #C.Scenario.Data.Deliveries > 0 then
            for _, position in ipairs(C.Scenario.Data.Deliveries) do
                _, position.pos = pcall(vec3, position.pos.x, position.pos.y, position.pos.z)
                _, position.rot = pcall(quat, position.rot.x, position.rot.y, position.rot.z, position.rot.w)
            end
        end
        C.Scenario.Data.DeliveryLeaderboard = cacheData.DeliveryLeaderboard
    end)

    -- bus lines
    BJICache.addRxHandler(BJICache.CACHES.BUS_LINES, function(cacheData)
        C.Scenario.Data.BusLines = cacheData.BusLines
        if C.Scenario.Data.BusLines and #C.Scenario.Data.BusLines > 0 then
            for _, line in ipairs(C.Scenario.Data.BusLines) do
                for _, stop in ipairs(line.stops) do
                    _, stop.pos = pcall(vec3, stop.pos.x, stop.pos.y, stop.pos.z)
                    _, stop.rot = pcall(quat, stop.rot.x, stop.rot.y, stop.rot.z, stop.rot.w)
                end
            end
        end
    end)

    -- hunter data
    BJICache.addRxHandler(BJICache.CACHES.HUNTER_DATA, function(cacheData)
        C.Scenario.Data.Hunter = cacheData
    end)

    -- derby data
    BJICache.addRxHandler(BJICache.CACHES.DERBY_DATA, function(cacheData)
        BJIContext.Scenario.Data.Derby = cacheData
    end)

    -- stations data
    BJICache.addRxHandler(BJICache.CACHES.STATIONS, function(cacheData)
        C.Scenario.Data.EnergyStations = cacheData.EnergyStations
        if C.Scenario.Data.EnergyStations and #C.Scenario.Data.EnergyStations > 0 then
            for _, station in ipairs(C.Scenario.Data.EnergyStations) do
                _, station.pos = pcall(vec3, station.pos.x, station.pos.y, station.pos.z)
            end
        end
        C.Scenario.Data.Garages = cacheData.Garages
    end)
end

function C.onLoad()
    loadUser()
    loadPlayers()
    loadUI()
    loadConfig()
    loadDatabase()
    loadMaps()
    loadScenarii()
end

function C.Scenario.isEditorOpen()
    return C.Scenario.RaceEdit or
        C.Scenario.EnergyStationsEdit or
        C.Scenario.GaragesEdit or
        C.Scenario.DeliveryEdit or
        C.Scenario.BusLinesEdit or
        C.Scenario.HunterEdit or
        C.Scenario.DerbyEdit
end

function C.setPhysicsSpeed(val)
    C.physics.physmult = val
end

function C.isSelf(playerID)
    return C.User.playerID == playerID
end

RegisterBJIManager(C)
return C
