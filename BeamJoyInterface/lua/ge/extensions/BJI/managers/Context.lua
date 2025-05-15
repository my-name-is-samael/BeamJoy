---@class BJIUser
---@field playerID integer
---@field playerName string
---@field group? string
---@field lang? string
---@field freeze boolean
---@field engine boolean
---@field vehicles table<integer, BJIVehicleData>
---@field currentVehicle? integer gameVehID
---@field stationProcess? boolean (auto injected)

---@class BJIPlayerVehicle
---@field vehID integer
---@field gameVehID integer
---@field finalGameVehID? integer (auto injected)
---@field model string
---@field freeze? boolean (only when self is staff)
---@field engine? boolean (only when self is staff)
---@field muted? boolean (only when self is staff)
---@field muteReason? string (only when self is staff)
---@field kickReason? string (only when self is staff)
---@field banReason? string (only when self is staff)

---@class BJIPlayer
---@field playerID integer
---@field playerName string
---@field tagName? string (auto injected)
---@field group? string
---@field guest boolean
---@field reputation integer
---@field staff boolean
---@field currentVehicle? integer
---@field ai integer[]
---@field isGhost boolean
---@field vehicles table<integer, BJIPlayerVehicle>

---@class BJIManagerContext : BJIManager
local M = {
    _name = "Context",

    GUI = {
        setupEditorGuiTheme = nop,
    },

    WorldReadyState = 0,
    WorldCache = {},
    VehiclePristineThreshold = 100,

    UI = {
        mapName = "",
        mapLabel = "",
        dropSizeRatio = 1,
        ---@type {value: number, key: string, default: boolean}
        gravity = nil, -- save current gravity preset if there is one
        ---@type {value: number, key: string, default: boolean}
        speed = nil,   -- save current speed preset if not default
    },

    ---@type BJIUser
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
    BJC = {},      -- BeamJoy config
    ---@type table<string, BJIPlayer>
    Players = {},  -- player list
    ---@type table<string, {}>
    Maps = {},
    Scenario = {
        Data = {}, -- Scenarii data
    },
    Database = {},
}

local function loadUser()
    BJI.Managers.Cache.addRxHandler(BJI.Managers.Cache.CACHES.USER, function(cacheData)
        local previous = table.clone(M.User) or {}

        M.User.playerID = cacheData.playerID
        M.User.playerName = cacheData.playerName
        M.User.group = cacheData.group
        M.User.lang = cacheData.lang
        M.User.freeze = cacheData.freeze == true
        M.User.engine = cacheData.engine == true
        BJI.Managers.Async.task(function()
            return BJI.Managers.Cache.areBaseCachesFirstLoaded()
        end, function()
            local group = BJI.Managers.Perm.Groups[M.User.group]
            BJI.Managers.AI.toggle(group.canSpawnAI)
            if not group.canSpawn and BJI.Managers.Veh.hasVehicle() then
                BJI.Managers.Veh.deleteAllOwnVehicles()
            end
        end, "BJIUpdateUserByGroup")

        -- vehicles
        M.User.currentVehicle = cacheData.currentVehicle
        for vehID, vehicle in pairs(cacheData.vehicles) do
            if not M.User.vehicles[vehID] then
                M.User.vehicles[vehID] = table.assign(vehicle, {
                    freezeStation = false,
                    engineStation = true,
                })
            else
                table.assign(M.User.vehicles[vehID], vehicle)
            end
        end
        -- remove obsolete vehicles
        for vehID in pairs(M.User.vehicles) do
            if not cacheData.vehicles[vehID] then
                M.User.vehicles[vehID] = nil
            end
        end
        BJI.Managers.Scenario.updateVehicles()

        BJI.Managers.Reputation.updateReputationSmooth(cacheData.reputation)

        M.UserStats = cacheData.stats

        BJI.Managers.Async.task(function()
            return not not M.BJC.Freeroam
        end, function()
            -- update quick travel
            if BJI.Managers.Scenario.isFreeroam() then
                BJI.Managers.Bigmap.toggleQuickTravel(M.BJC.Freeroam.QuickTravel or BJI.Managers.Perm.isStaff())
            end
            -- update nametags
            BJI.Managers.Nametags.tryUpdate()
        end, "BJICacheFreeroamReady")

        if M.User.group ~= previous.group then
            BJI.Managers.Async.task(function()
                return BJI.Managers.Cache.areBaseCachesFirstLoaded() and BJI.CLIENT_READY
            end, function()
                BJI.Managers.Restrictions.update({
                    {
                        -- update AI restriction
                        restrictions = BJI.Managers.Restrictions.OTHER.AI_CONTROL,
                        state = BJI.Managers.Perm.canSpawnAI() and
                            BJI.Managers.Restrictions.STATE.ALLOWED,
                    },
                    {
                        -- update vehSelector restriction
                        restrictions = Table({
                            BJI.Managers.Restrictions.OTHER.VEHICLE_SELECTOR,
                            BJI.Managers.Restrictions.OTHER.VEHICLE_PARTS_SELECTOR,
                        }):flat(),
                        state = BJI.Managers.Perm.canSpawnVehicle() and
                            BJI.Managers.Restrictions.STATE.ALLOWED,
                    }
                })
            end)
        end

        -- events detection
        local previousVehCount = table.length(previous.vehicles)
        local currentVehCount = table.length(M.User.vehicles)
        if previousVehCount ~= currentVehCount then
            if previousVehCount < currentVehCount then
                -- new veh
                table.find(M.User.vehicles, function(_, vehID)
                    return not previous.vehicles[vehID]
                end, function(veh)
                    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.VEHICLE_SPAWNED, {
                        self = true,
                        playerID = M.User.playerID,
                        vehID = veh.vehID,
                        gameVehID = veh.gameVehID,
                        vehData = veh,
                    })
                end)
            else
                -- removed veh
                table.find(previous.vehicles, function(_, vehID)
                    return not M.User.vehicles[vehID]
                end, function(veh)
                    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.VEHICLE_REMOVED, {
                        self = true,
                        playerID = M.User.playerID,
                        vehID = veh.vehID,
                        gameVehID = veh.gameVehID,
                        vehData = veh,
                    })
                end)
            end
        end

        if previous.group ~= M.User.group then
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PERMISSION_CHANGED, {
                self = true,
                type = "group_assign",
            })
        end
    end)
end

local function loadPlayers()
    BJI.Managers.Cache.addRxHandler(BJI.Managers.Cache.CACHES.PLAYERS, function(cacheData)
        local previousPlayers = table.clone(M.Players)
        for _, p in pairs(cacheData) do
            if not M.Players[p.playerID] then
                M.Players[p.playerID] = table.assign(p, {
                    muteReason = "",
                    kickReason = "",
                    banReason = "",
                    tempBanDuration = M.BJC.TempBan and M.BJC.TempBan.minTime or 0, -- input for mods+
                    hideNametag = false,                                            -- future use ?
                })
            else
                table.assign(M.Players[p.playerID], p)
            end
        end

        table.forEach(M.Players, function(player)
            -- parse vehicles finalGameVehID
            table.forEach(player.vehicles or {}, function(veh)
                veh.finalGameVehID = M.isSelf(player.playerID) and veh.gameVehID or
                    BJI.Managers.Veh.getRemoteVehID(veh.gameVehID)
            end)

            -- parse ai final IDs
            if not M.isSelf(player.playerID) then
                player.ai = Table(player.ai):map(function(remoteVid)
                    return BJI.Managers.Veh.getRemoteVehID(remoteVid)
                end):values()
            end
        end)

        -- remove obsolete players
        for k, v in pairs(M.Players) do
            local found = false
            for _, v2 in pairs(cacheData) do
                if v.playerName == v2.playerName then
                    found = true
                end
            end
            if not found then
                M.Players[k] = nil
            end
        end

        -- update AI vehicles (to hide their nametags)
        BJI.Managers.AI.updateVehicles(Table(M.Players)
            :filter(function(player) return #player.ai > 0 end)
            :map(function(player) return player.ai end)
            :reduce(function(acc, aiVehs) return acc:addAll(aiVehs) end, Table()))

        -- events detection
        local previousPlayersCount = table.length(previousPlayers)
        local currentPlayersCount = table.length(M.Players)
        if previousPlayersCount ~= currentPlayersCount then
            if previousPlayersCount < currentPlayersCount then
                -- player connected
                table.find(M.Players, function(_, playerID)
                    return not previousPlayers[playerID]
                end, function(player)
                    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PLAYER_CONNECT, {
                        playerID = player.playerID,
                        playerName = player.playerName,
                    })
                end)
            else
                -- player disconnected
                table.find(previousPlayers, function(_, playerID)
                    return not M.Players[playerID]
                end, function(player)
                    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PLAYER_DISCONNECT, {
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
    previousUI.gravityRate = BJI.Managers.Env.Data.gravityRate
    previousUI.simSpeed = BJI.Managers.Env.Data.simSpeed
    BJI.Managers.Cache.addRxHandler(BJI.Managers.Cache.CACHES.ENVIRONMENT, function(cacheData)
        local presetsUtils = require("ge/extensions/utils/EnvironmentUtils")

        M.UI.gravity = {
            value = cacheData.gravityRate,
        }
        if cacheData.gravityRate ~= nil then
            for _, p in ipairs(presetsUtils.gravityPresets()) do
                if math.round(p.value, 3) == math.round(cacheData.gravityRate, 3) then
                    M.UI.gravity.key = p.key
                    M.UI.gravity.default = p.default
                end
            end
            if previousUI.gravityRate ~= cacheData.gravityRate and M.UI.gravity.key then
                local label = BJI.Managers.Lang.get(string.var("presets.gravity.{1}", { M.UI.gravity.key }))
                BJI.Managers.Toast.info(string.var("Gravity changed to {1}", { label }))
            end
        end

        M.UI.speed = {
            value = cacheData.simSpeed,
        }
        for _, p in ipairs(presetsUtils.speedPresets()) do
            if math.round(p.value, 3) == math.round(cacheData.simSpeed, 3) then
                M.UI.speed.key = p.key
                M.UI.speed.default = p.default
            end
        end
        if previousUI.simSpeed ~= cacheData.simSpeed and M.UI.speed.key then
            local label = BJI.Managers.Lang.get(string.var("presets.speed.{1}", { M.UI.speed.key }))
            BJI.Managers.Toast.info(string.var("Speed changed to {1}", { label }))
        end

        previousUI.gravityRate = cacheData.gravityRate
        previousUI.simSpeed = cacheData.simSpeed
    end)

    -- map data for UI
    BJI.Managers.Cache.addRxHandler(BJI.Managers.Cache.CACHES.MAP, function(cacheData)
        M.UI.mapName = cacheData.name
        M.UI.mapLabel = cacheData.label
        M.UI.dropSizeRatio = cacheData.dropSizeRatio or 1
    end)
end

local function loadConfig()
    -- core data
    BJI.Managers.Cache.addRxHandler(BJI.Managers.Cache.CACHES.CORE, function(cacheData)
        local previous = table.clone(M.Core) or {}
        M.Core = cacheData

        -- events detection
        local keyChanged = {}
        for k, v in pairs(M.Core) do
            if v ~= previous[k] then
                keyChanged[k] = {
                    previousValue = previous[k],
                    currentValue = v,
                }
            end
        end
        if table.length(keyChanged) > 0 then
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.CORE_CHANGED, keyChanged)
        end
    end)

    -- bjc data
    BJI.Managers.Cache.addRxHandler(BJI.Managers.Cache.CACHES.BJC, function(cacheData)
        if cacheData.Freeroam then
            if not M.BJC.Freeroam then
                M.BJC.Freeroam = {}
            end
            for k, v in pairs(cacheData.Freeroam) do
                M.BJC.Freeroam[k] = v
            end

            if BJI.Managers.Scenario.isFreeroam() then
                --update unicycle policy
                if not M.BJC.Freeroam.AllowUnicycle and BJI.Managers.Veh.isUnicycle() then
                    BJI.Managers.Veh.deleteCurrentOwnVehicle()
                end
                BJI.Managers.Restrictions.update({ {
                    restrictions = BJI.Managers.Restrictions.OTHER.WALKING,
                    state = M.BJC.Freeroam.AllowUnicycle and
                        BJI.Managers.Restrictions.STATE.ALLOWED,
                } })

                -- update quick travel
                BJI.Managers.Bigmap.toggleQuickTravel(M.BJC.Freeroam.QuickTravel or BJI.Managers.Perm.isStaff())
            end

            -- update nametags
            if BJI.Managers.Scenario.isFreeroam() or BJI.Managers.Scenario.isPlayerScenarioInProgress() then
                BJI.Managers.Nametags.toggle((M.BJC.Freeroam.Nametags or BJI.Managers.Perm.isStaff()) and
                    not settings.getValue("hideNameTags", false))
            end
        end

        if cacheData.TempBan then
            M.BJC.TempBan = cacheData.TempBan
        end

        if cacheData.Whitelist then
            if not M.BJC.Whitelist then
                M.BJC.Whitelist = {}
            end
            for k, v in pairs(cacheData.Whitelist) do
                M.BJC.Whitelist[k] = v
            end
        end

        if cacheData.VoteKick then
            M.BJC.VoteKick = cacheData.VoteKick
        end

        if cacheData.VoteMap then
            M.BJC.VoteMap = cacheData.VoteMap
        end

        if cacheData.Server then
            if not M.BJC.Server then
                M.BJC.Server = {}
            end
            for k, v in pairs(cacheData.Server) do
                M.BJC.Server[k] = v
            end

            -- apply windows theme
            if M.BJC.Server.Theme then
                BJI.Utils.Style.LoadTheme(M.BJC.Server.Theme)
            end

            -- fill in available langs
            if M.BJC.Server.Broadcasts then
                for _, lang in ipairs(BJI.Managers.Lang.Langs) do
                    if not M.BJC.Server.Broadcasts[lang] then
                        M.BJC.Server.Broadcasts[lang] = {}
                    end
                    if not M.BJC.Server.WelcomeMessage[lang] then
                        M.BJC.Server.WelcomeMessage[lang] = ""
                    end
                end
            end

            BJI.Managers.Mods.update(M.BJC.Server.AllowClientMods)
        end

        if cacheData.CEN then
            M.BJC.CEN = cacheData.CEN
            local restrictions = Table()
            if not BJI.Managers.Perm.hasMinimumGroup(BJI.CONSTANTS.GROUP_NAMES.ADMIN) and
                not BJI.Managers.Context.BJC.CEN.Console then
                restrictions:addAll(BJI.Managers.Restrictions.CEN.CONSOLE)
            end
            if not BJI.Managers.Perm.hasMinimumGroup(BJI.CONSTANTS.GROUP_NAMES.ADMIN) and
                not BJI.Managers.Context.BJC.CEN.Editor then
                restrictions:addAll(BJI.Managers.Restrictions.CEN.EDITOR)
            end
            if not BJI.Managers.Perm.hasMinimumGroup(BJI.CONSTANTS.GROUP_NAMES.ADMIN) and
                not BJI.Managers.Context.BJC.CEN.NodeGrabber then
                restrictions:addAll(BJI.Managers.Restrictions.CEN.NODEGRABBER)
            end
            BJI.Managers.Restrictions.updateCEN(restrictions)
        end

        if cacheData.Race then
            M.BJC.Race = cacheData.Race
        end

        if cacheData.Speed then
            M.BJC.Speed = cacheData.Speed
        end

        if cacheData.Hunter then
            M.BJC.Hunter = cacheData.Hunter
        end

        if cacheData.VehicleDelivery then
            M.BJC.VehicleDelivery = cacheData.VehicleDelivery
        end

        if cacheData.Reputation then
            M.BJC.Reputation = cacheData.Reputation
        end
    end)
end

local function loadDatabase()

    BJI.Managers.Cache.addRxHandler(BJI.Managers.Cache.CACHES.DATABASE_VEHICLES, function(cacheData)
        if not M.Database then
            M.Database = {}
        end

        M.Database.Vehicles = cacheData
    end)
end

local function loadMaps()
    BJI.Managers.Cache.addRxHandler(BJI.Managers.Cache.CACHES.MAPS, function(cacheData)
        M.Maps = cacheData
    end)
end

local function loadScenarii()
    -- races data
    BJI.Managers.Cache.addRxHandler(BJI.Managers.Cache.CACHES.RACES, function(cacheData)
        M.Scenario.Data.Races = cacheData
        if M.Scenario.Data.Races and #M.Scenario.Data.Races > 0 then
            for _, r in ipairs(M.Scenario.Data.Races) do
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
    BJI.Managers.Cache.addRxHandler(BJI.Managers.Cache.CACHES.DELIVERIES, function(cacheData)
        M.Scenario.Data.Deliveries = cacheData.Deliveries
        if M.Scenario.Data.Deliveries and #M.Scenario.Data.Deliveries > 0 then
            for _, position in ipairs(M.Scenario.Data.Deliveries) do
                _, position.pos = pcall(vec3, position.pos.x, position.pos.y, position.pos.z)
                _, position.rot = pcall(quat, position.rot.x, position.rot.y, position.rot.z, position.rot.w)
            end
        end
        M.Scenario.Data.DeliveryLeaderboard = cacheData.DeliveryLeaderboard
    end)

    -- bus lines
    BJI.Managers.Cache.addRxHandler(BJI.Managers.Cache.CACHES.BUS_LINES, function(cacheData)
        M.Scenario.Data.BusLines = cacheData.BusLines
        if M.Scenario.Data.BusLines and #M.Scenario.Data.BusLines > 0 then
            for _, line in ipairs(M.Scenario.Data.BusLines) do
                for _, stop in ipairs(line.stops) do
                    _, stop.pos = pcall(vec3, stop.pos.x, stop.pos.y, stop.pos.z)
                    _, stop.rot = pcall(quat, stop.rot.x, stop.rot.y, stop.rot.z, stop.rot.w)
                end
            end
        end
    end)

    -- hunter data
    BJI.Managers.Cache.addRxHandler(BJI.Managers.Cache.CACHES.HUNTER_DATA, function(cacheData)
        M.Scenario.Data.Hunter = cacheData
    end)

    -- derby data
    BJI.Managers.Cache.addRxHandler(BJI.Managers.Cache.CACHES.DERBY_DATA, function(cacheData)
        BJI.Managers.Context.Scenario.Data.Derby = cacheData
    end)

    -- stations data
    BJI.Managers.Cache.addRxHandler(BJI.Managers.Cache.CACHES.STATIONS, function(cacheData)
        M.Scenario.Data.EnergyStations = cacheData.EnergyStations
        if M.Scenario.Data.EnergyStations and #M.Scenario.Data.EnergyStations > 0 then
            for _, station in ipairs(M.Scenario.Data.EnergyStations) do
                _, station.pos = pcall(vec3, station.pos.x, station.pos.y, station.pos.z)
            end
        end
        M.Scenario.Data.Garages = cacheData.Garages
    end)
end

local function onLoad()
    loadUser()
    loadPlayers()
    loadUI()
    loadConfig()
    loadDatabase()
    loadMaps()
    loadScenarii()
end

local function isSelf(playerID)
    return M.User.playerID == playerID
end

M.isSelf = isSelf

M.onLoad = onLoad

return M
