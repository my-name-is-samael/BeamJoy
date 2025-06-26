---@class BJIUser
---@field playerID integer
---@field playerName string
---@field group string?
---@field lang string?
---@field freeze boolean
---@field engine boolean
---@field vehicles table<integer, BJIVehicleData>
---@field currentVehicle integer? gameVehID
---@field stationProcess boolean? (auto injected)
---@field previousVehConfig table?

---@class BJIPlayerVehicle
---@field vehID integer
---@field gameVehID integer
---@field finalGameVehID? integer (auto injected)
---@field model string
---@field isAi boolean (auto injected)
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
---@field ai tablelib<integer, integer>
---@field isGhost boolean
---@field vehicles tablelib<integer, BJIPlayerVehicle> index vehServerID

---@class BJIManagerContext : BJIManager
local M = {
    _name = "Context",

    GUI = {
        setupEditorGuiTheme = nop,
    },

    WorldReadyState = 0,
    VehiclePristineThreshold = 100,

    UI = {
        mapName = "",
        mapLabel = "",
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
        previousVehConfig = nil,
    },

    ---@type table<string, integer>
    UserStats = {},
    ---@type tablelib<string, BJIPlayer> index playerID
    Players = Table(),

    -- CONFIG DATA
    BJC = {
        CEN = {
            Console = true,
            Editor = true,
            NodeGrabber = true,
        },
        Freeroam = {
            Nametags = true,
            VehicleSpawning = true,
            AllowUnicycle = true,
        },
        Server = {
            AllowClientMods = true,
            ClientMods = {},
            Theme = {},
        },
    },
    ---@type table<string, {}> techName index
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

        -- vehicles
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
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PERMISSION_CHANGED)
        end
    end)
end

local function updateAllVehicles(ctxt)
    ---@param veh BJIMPVehicle
    BJI.Managers.Veh.getMPVehicles():forEach(function(veh)
        M.Players:find(function(p) return p.playerID == veh.ownerID end, function(p)
            p.vehicles:find(function(v) return v.gameVehID == veh.gameVehicleID end, function(v)
                v.finalGameVehID = ctxt.user.playerID == veh.ownerID and veh.gameVehicleID or veh.remoteVehID
                v.isAi = veh.isAi
            end)
        end)
    end)
    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.VEHICLES_UPDATED)
end

local function loadPlayers()
    BJI.Managers.Cache.addRxHandler(BJI.Managers.Cache.CACHES.PLAYERS, function(cacheData)
        ---@type tablelib<integer, BJIPlayer> playerID index
        local previousPlayers = M.Players:clone()
        Table(cacheData):forEach(function(p)
            if not M.Players[p.playerID] then
                M.Players[p.playerID] = table.assign({
                    muteReason = "",
                    kickReason = "",
                    banReason = "",
                    tempBanDuration = M.BJC.TempBan and M.BJC.TempBan.minTime or 0, -- input for mods+
                    hideNametag = false,                                            -- future use ?
                    tagName = BJI.Managers.Nametags.getPlayerTagName(p.playerName),
                }, p)
            else
                table.assign(M.Players[p.playerID], p)
                M.Players[p.playerID].vehicles = Table(p.vehicles or {})
            end
        end)

        -- remove obsolete players
        M.Players:forEach(function(p, pid)
            if not cacheData[pid] or cacheData[pid].playerName ~= p.playerName then
                M.Players[pid] = nil
            end
        end)

        BJI.Managers.Async.removeTask("BJILoadPlayersUpdateVehicles")
        BJI.Managers.Async.task(function()
            return Table(MPVehicleGE.getVehicles()):every(function(v)
                return v.gameVehicleID ~= -1 and v.isSpawned
            end)
        end, updateAllVehicles, "BJILoadPlayersUpdateVehicles")

        -- events detection
        local previousPlayersCount = previousPlayers:length()
        local currentPlayersCount = M.Players:length()
        if previousPlayersCount ~= currentPlayersCount then
            if previousPlayersCount < currentPlayersCount then
                -- player connected
                M.Players:find(function(_, playerID)
                    return not previousPlayers[playerID]
                end, function(player)
                    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PLAYER_CONNECT, {
                        playerID = player.playerID,
                        playerName = player.playerName,
                    })
                end)
            else
                -- player disconnected
                previousPlayers:find(function(_, playerID)
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
                BJI.Managers.Toast.info(string.var(BJI.Managers.Lang.get("presets.gravity.toastChanged"),
                    { gravity = label }))
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
            BJI.Managers.Toast.info(string.var(BJI.Managers.Lang.get("presets.speed.toastChanged"),
                { speed = label }))
        end

        previousUI.gravityRate = cacheData.gravityRate
        previousUI.simSpeed = cacheData.simSpeed
    end)

    -- map data for UI
    BJI.Managers.Cache.addRxHandler(BJI.Managers.Cache.CACHES.MAP, function(cacheData)
        M.UI.mapName = cacheData.name
        M.UI.mapLabel = cacheData.label
    end)
end

local function updateCENRestrictions()
    local restrictions = Table()
    if not BJI.Managers.Context.BJC.CEN then
        restrictions:addAll(BJI.Managers.Restrictions.CEN.CONSOLE)
        restrictions:addAll(BJI.Managers.Restrictions.CEN.EDITOR)
        restrictions:addAll(BJI.Managers.Restrictions.CEN.NODEGRABBER)
    else
        if not BJI.Managers.Perm.hasMinimumGroup(BJI.CONSTANTS.GROUP_NAMES.ADMIN) and
            not BJI.Managers.Context.BJC.CEN.Console then
            restrictions:addAll(BJI.Managers.Restrictions.CEN.CONSOLE)
        end
        if not BJI.Managers.Perm.hasMinimumGroup(BJI.CONSTANTS.GROUP_NAMES.ADMIN) and
            not BJI.Managers.Context.BJC.CEN.Editor then
            restrictions:addAll(BJI.Managers.Restrictions.CEN.EDITOR)
        end
        if not BJI.Managers.Scenario.isFreeroam() or
            (not BJI.Managers.Perm.hasMinimumGroup(BJI.CONSTANTS.GROUP_NAMES.ADMIN) and
                not BJI.Managers.Context.BJC.CEN.NodeGrabber) then
            restrictions:addAll(BJI.Managers.Restrictions.CEN.NODEGRABBER)
        end
    end
    BJI.Managers.Restrictions.updateCEN(restrictions)
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
        local permissionChanged = false

        M.BJC.CEN = cacheData.CEN
        updateCENRestrictions()

        if BJI.Managers.Scenario.isFreeroam() and (
                not M.BJC.Freeroam or
                M.BJC.Freeroam.VehicleSpawning ~= cacheData.Freeroam.VehicleSpawning or
                M.BJC.Freeroam.AllowUnicycle ~= cacheData.Freeroam.AllowUnicycle
            ) then
            permissionChanged = true
        end
        M.BJC.Freeroam = cacheData.Freeroam

        M.BJC.Server = cacheData.Server
        BJI.Managers.Mods.update(M.BJC.Server.AllowClientMods)
        BJI.Utils.Style.LoadTheme(M.BJC.Server.Theme)
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

        if cacheData.Race then
            M.BJC.Race = cacheData.Race
        end

        if cacheData.Speed then
            M.BJC.Speed = cacheData.Speed
        end

        if cacheData.Hunter then
            M.BJC.Hunter = cacheData.Hunter
        end

        if cacheData.Derby then
            M.BJC.Derby = cacheData.Derby
        end

        if cacheData.VehicleDelivery then
            M.BJC.VehicleDelivery = cacheData.VehicleDelivery
        end

        if cacheData.Reputation then
            M.BJC.Reputation = cacheData.Reputation
        end

        if permissionChanged then
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.PERMISSION_CHANGED)
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

    BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.SCENARIO_CHANGED,
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
    }, updateCENRestrictions, M._name)
end

local function isSelf(playerID)
    return M.User.playerID == playerID
end

M.isSelf = isSelf

M.onLoad = onLoad

return M
