---@class BJIManagerScenario : BJIManager
local M = {
    _name = "Scenario",

    Data = {
        ---@type string?
        RacesCurrentMap = nil,
        ---@type tablelib<integer, BJRaceLight> index 1-N
        Races = Table(),
        Deliveries = {
            ---@type tablelib<integer, BJIPositionRotationRadius> index 1-N
            Points = Table(),
            ---@type tablelib<integer, BJIPositionRotationRadius> index 1-N
            Hubs = Table(),
            Leaderboard = {},
        },
        ---@type tablelib<integer, BJBusLine> index 1-N
        BusLines = Table(),
        HunterInfected = {},
        ---@type tablelib<integer, BJArena>
        Derby = Table(),
    },

    ---@type table<string, tablelib<integer, string>>
    markersIDs = {
        [BJI_Cache.CACHES.RACES] = Table(),
        [BJI_Cache.CACHES.DELIVERIES] = Table(),
        [BJI_Cache.CACHES.BUS_LINES] = Table(),
        [BJI_Cache.CACHES.DERBY_DATA] = Table(),
    },

    TYPES = {},
    solo = {},
    multi = {},
    CurrentScenario = nil,
    scenarii = {},
}

-- DATA HANDLING

---@param cacheType string?
local function updateMarkers(cacheType)
    local function getID(prefix, name, i)
        return string.format("%s_%s_%d", prefix, name:gsub(" ", "_"), i)
    end
    local status
    if not cacheType then
        for _, ids in pairs(M.markersIDs) do
            ids:forEach(BJI_InteractiveMarker.deleteMarker)
            ids:clear()
        end
    elseif M.markersIDs[cacheType] then
        M.markersIDs[cacheType]:forEach(BJI_InteractiveMarker.deleteMarker)
        M.markersIDs[cacheType]:clear()
    end

    local labels = {}

    -- races
    if not cacheType or cacheType == BJI_Cache.CACHES.RACES then
        labels.race = {
            typeSolo = BJI_Lang.get("interactiveMarkers.race.typeSolo"),
            typeMulti = BJI_Lang.get("interactiveMarkers.race.typeMulti"),
            button = BJI_Lang.get("interactiveMarkers.race.button"),
        }
        local previousPositions = Table()
        M.Data.Races:forEach(function(r, i)
            local id = getID("race", r.name, i)
            local pos
            if not previousPositions:find(function(p)
                    return p:distance(r.markerPos) < 20
                end, function(p) pos = p end) then
                pos = r.markerPos
                previousPositions:insert(pos)
            end
            status = pcall(BJI_InteractiveMarker.upsertMarker, id, BJI_InteractiveMarker.TYPES.RACE_MULTI.icon,
                pos, 3, {
                    color = BJI_InteractiveMarker.TYPES.RACE_MULTI.color,
                    visibleFreeCam = true,
                    visibleAnyVeh = true,
                    visibleWalking = true,
                    condition = function(ctxt)
                        return not BJI_Win_ScenarioEditor.is(BJI_Win_ScenarioEditor.TYPES.RACE) and
                            BJI_Scenario.isFreeroam() and BJI_Perm.canSpawnVehicle() and
                            not BJI_Tournament.state
                    end,
                }, {
                    {
                        condition = function(ctxt)
                            return not BJI_Win_RaceSettings.getState() and
                                ctxt.isOwner and ctxt.veh.isVehicle and
                                BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.START_PLAYER_SCENARIO)
                        end,
                        icon = BJI_InteractiveMarker.TYPES.RACE_SOLO.icon,
                        type = labels.race.typeSolo,
                        label = r.name,
                        buttonLabel = labels.race.button,
                        callback = function(ctxt)
                            BJI_Win_RaceSettings.openPromptFlow({
                                multi = false,
                                raceID = r.id,
                                raceName = r.name,
                                loopable = r.loopable,
                                defaultRespawnStrategy = BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.LAST_CHECKPOINT.key,
                                respawnStrategies = Table(BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES)
                                    :filter(function(rs)
                                        return r.hasStand or
                                            rs ~= BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.STAND
                                    end)
                                    :sort(function(a, b) return a.order < b.order end)
                                    :map(function(el) return el.key end),
                            })
                        end
                    },
                    {
                        condition = function(ctxt)
                            return not BJI_Win_RaceSettings.getState() and r.places > 1 and
                                BJI_Votes.Scenario.canStartVote() and BJI_Perm.getCountPlayersCanSpawnVehicle() >=
                                BJI_Scenario.get(BJI_Scenario.TYPES.RACE_MULTI).MINIMUM_PARTICIPANTS and
                                (BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.VOTE_SERVER_SCENARIO) or
                                    BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.START_SERVER_SCENARIO))
                        end,
                        icon = BJI_InteractiveMarker.TYPES.RACE_MULTI.icon,
                        type = labels.race.typeMulti,
                        label = r.name,
                        buttonLabel = labels.race.button,
                        callback = function(ctxt)
                            BJI_Win_RaceSettings.openPromptFlow({
                                multi = true,
                                raceID = r.id,
                                raceName = r.name,
                                loopable = r.loopable,
                                defaultRespawnStrategy = BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.LAST_CHECKPOINT.key,
                                respawnStrategies = Table(BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES)
                                    :filter(function(rs)
                                        return r.hasStand or
                                            rs ~= BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.STAND
                                    end)
                                    :sort(function(a, b) return a.order < b.order end)
                                    :map(function(el) return el.key end),
                            })
                        end
                    },
                })
            if status then
                M.markersIDs[BJI_Cache.CACHES.RACES]:insert(id)
            else
                BJI_InteractiveMarker.deleteMarker(id)
            end
        end)
    end

    -- delivery hubs
    if not cacheType or cacheType == BJI_Cache.CACHES.DELIVERIES then
        labels.delivery = {
            type = BJI_Lang.get("interactiveMarkers.delivery.type"),
            labelVehicle = BJI_Lang.get("interactiveMarkers.delivery.labelVehicle"),
            buttonVehicle = BJI_Lang.get("interactiveMarkers.delivery.buttonVehicle"),
            labelPackage = BJI_Lang.get("interactiveMarkers.delivery.labelPackage"),
            buttonPackage = BJI_Lang.get("interactiveMarkers.delivery.buttonPackage"),
            labelMulti = BJI_Lang.get("interactiveMarkers.delivery.labelMulti"),
            buttonMulti = BJI_Lang.get("interactiveMarkers.delivery.buttonMulti"),
        }
        M.Data.Deliveries.Hubs:forEach(function(a, i)
            local id = getID("delivery", "hub", i)
            status = pcall(BJI_InteractiveMarker.upsertMarker, id, BJI_InteractiveMarker.TYPES.DELIVERY_HUBS.icon,
                a.pos, 6, {
                    color = BJI_InteractiveMarker.TYPES.DELIVERY_HUBS.color,
                    visibleFreeCam = true,
                    visibleAnyVeh = true,
                    visibleWalking = true,
                    condition = function(ctxt)
                        return not BJI_Win_ScenarioEditor.is(BJI_Win_ScenarioEditor.TYPES.DELIVERIES) and
                            BJI_Scenario.isFreeroam() and not BJI_Tournament.state and
                            BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.START_PLAYER_SCENARIO)
                    end,
                }, {
                    {
                        condition = function(ctxt)
                            return not BJI_Votes.Map.started() and not BJI_Votes.Scenario.started()
                        end,
                        icon = BJI.Utils.Icon.ICONS.mission_g2g_triangle,
                        type = labels.delivery.type,
                        label = labels.delivery.labelVehicle,
                        buttonLabel = labels.delivery.buttonVehicle,
                        callback = function(ctxt)
                            BJI_Scenario.get(BJI_Scenario.TYPES.VEHICLE_DELIVERY).start()
                        end
                    },
                    {
                        condition = function(ctxt)
                            return not BJI_Votes.Map.started() and not BJI_Votes.Scenario.started() and
                                ctxt.isOwner and ctxt.veh.isVehicle
                        end,
                        icon = BJI_InteractiveMarker.TYPES.DELIVERY_HUBS.icon,
                        type = labels.delivery.type,
                        label = labels.delivery.labelPackage,
                        buttonLabel = labels.delivery.buttonPackage,
                        callback = function(ctxt)
                            BJI_Scenario.switchScenario(BJI_Scenario.TYPES.PACKAGE_DELIVERY, ctxt)
                        end
                    },
                    {
                        condition = function(ctxt)
                            return not BJI_Votes.Map.started() and not BJI_Votes.Scenario.started() and
                                ctxt.isOwner and ctxt.veh.isVehicle
                        end,
                        icon = BJI_InteractiveMarker.TYPES.DELIVERY_HUBS.icon,
                        type = labels.delivery.type,
                        label = labels.delivery.labelMulti,
                        buttonLabel = labels.delivery.buttonMulti,
                        callback = function(ctxt)
                            BJI_Tx_scenario.DeliveryMultiJoin(ctxt.veh.gameVehicleID, ctxt.veh.position)
                        end
                    },
                })
            if status then
                M.markersIDs[BJI_Cache.CACHES.DELIVERIES]:insert(id)
            else
                BJI_InteractiveMarker.deleteMarker(id)
            end
        end)
    end

    -- bus lines
    if not cacheType or cacheType == BJI_Cache.CACHES.BUS_LINES then
        labels.busline = {
            type = BJI_Lang.get("interactiveMarkers.busMission.type"),
            button = BJI_Lang.get("interactiveMarkers.busMission.button"),
        }
        local previousPositions = Table()

        M.Data.BusLines:forEach(function(bl, i)
            local id = getID("busmission", bl.name, i)
            local pos
            if not previousPositions:find(function(p)
                    return p:distance(bl.stops[1].pos) < 20
                end, function(p) pos = p end) then
                pos = bl.stops[1].pos
                previousPositions:insert(pos)
            end
            status = pcall(BJI_InteractiveMarker.upsertMarker, id, BJI_InteractiveMarker.TYPES.BUS_MISSION.icon,
                pos, bl.stops[1].radius * 2, {
                    color = BJI_InteractiveMarker.TYPES.BUS_MISSION.color,
                    visibleFreeCam = true,
                    visibleAnyVeh = true,
                    visibleWalking = true,
                    condition = function(ctxt)
                        return not BJI_Win_ScenarioEditor.is(BJI_Win_ScenarioEditor.TYPES.BUS_LINES) and
                            BJI_Scenario.isFreeroam() and BJI_Perm.canSpawnVehicle() and
                            not BJI_Tournament.state
                    end,
                }, {
                    {
                        condition = function(ctxt)
                            return not BJI_Win_BusMissionPreparation.getState() and
                                not BJI_Votes.Map.started() and not BJI_Votes.Scenario.started() and
                                BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.START_PLAYER_SCENARIO)
                        end,
                        icon = BJI_InteractiveMarker.TYPES.BUS_MISSION.icon,
                        type = labels.busline.type,
                        label = bl.name,
                        buttonLabel = labels.busline.button,
                        callback = function(ctxt)
                            BJI_Win_BusMissionPreparation.openPromptFlow(i)
                        end
                    },
                })
            if status then
                M.markersIDs[BJI_Cache.CACHES.BUS_LINES]:insert(id)
            else
                BJI_InteractiveMarker.deleteMarker(id)
            end
        end)
    end

    -- derby arenas
    if not cacheType or cacheType == BJI_Cache.CACHES.DERBY_DATA then
        labels.derby = {
            type = BJI_Lang.get("interactiveMarkers.derby.type"),
            places = BJI_Lang.get("derby.settings.places"),
            button = BJI_Lang.get("interactiveMarkers.derby.button"),
        }
        M.Data.Derby:forEach(function(a, i)
            local id = getID("derbyarena", a.name, i)
            status = pcall(BJI_InteractiveMarker.upsertMarker, id, BJI_InteractiveMarker.TYPES.DERBY_ARENA.icon,
                a.centerPosition, 6, {
                    color = BJI_InteractiveMarker.TYPES.DERBY_ARENA.color,
                    visibleFreeCam = true,
                    visibleAnyVeh = true,
                    visibleWalking = true,
                    condition = function(ctxt)
                        return not BJI_Win_ScenarioEditor.is(BJI_Win_ScenarioEditor.TYPES.DERBY) and
                            not BJI_Tournament.state and BJI_Votes.Scenario.canStartVote() and
                            BJI_Perm.getCountPlayersCanSpawnVehicle() >=
                            BJI_Scenario.get(BJI_Scenario.TYPES.RACE_MULTI).MINIMUM_PARTICIPANTS and
                            (BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.VOTE_SERVER_SCENARIO) or
                                BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.START_SERVER_SCENARIO))
                    end,
                }, {
                    {
                        condition = function(ctxt)
                            return not BJI_Win_DerbySettings.getState() and
                                not BJI_Votes.Map.started() and not BJI_Votes.Scenario.started()
                        end,
                        icon = BJI_InteractiveMarker.TYPES.DERBY_ARENA.icon,
                        type = labels.derby.type,
                        label = string.format("%s (%s)", a.name,
                            labels.derby.places:var({ places = #a.startPositions })),
                        buttonLabel = labels.derby.button,
                        callback = function(ctxt)
                            BJI_Win_DerbySettings.openPromptFlow(i)
                        end
                    },
                })
            if status then
                M.markersIDs[BJI_Cache.CACHES.DERBY_DATA]:insert(id)
            else
                BJI_InteractiveMarker.deleteMarker(id)
            end
        end)
    end
end

local function initCacheHandlers()
    -- races data
    local _
    BJI_Cache.addRxHandler(BJI_Cache.CACHES.RACES, function(cacheData)
        M.Data.Races = table.map(cacheData, function(r)
            if type(r) == "string" then return nil end -- mapName
            _, r.markerPos = pcall(vec3, r.markerPos.x, r.markerPos.y, r.markerPos.z)
            r.route = table.map(r.route, function(pos)
                _, pos = pcall(vec3, pos.x, pos.y, pos.z)
                return _ and pos or vec3()
            end)
            return r
        end)
        M.Data.RacesCurrentMap = cacheData.mapName
        updateMarkers(BJI_Cache.CACHES.RACES)
    end)

    -- deliveries data
    BJI_Cache.addRxHandler(BJI_Cache.CACHES.DELIVERIES, function(cacheData)
        M.Data.Deliveries.Points = table.map(cacheData.Points, function(d)
            _, d.pos = pcall(vec3, d.pos.x, d.pos.y, d.pos.z)
            _, d.rot = pcall(quat, d.rot.x, d.rot.y, d.rot.z, d.rot.w)
            return d
        end)
        M.Data.Deliveries.Hubs = table.map(cacheData.Hubs, function(d)
            _, d.pos = pcall(vec3, d.pos.x, d.pos.y, d.pos.z)
            _, d.rot = pcall(quat, d.rot.x, d.rot.y, d.rot.z, d.rot.w)
            return d
        end)
        M.Data.Deliveries.Leaderboard = cacheData.Leaderboard
        updateMarkers(BJI_Cache.CACHES.DELIVERIES)
    end)

    -- bus lines
    BJI_Cache.addRxHandler(BJI_Cache.CACHES.BUS_LINES, function(cacheData)
        M.Data.BusLines = table.map(cacheData, function(bl)
            for _, stop in ipairs(bl.stops) do
                _, stop.pos = pcall(vec3, stop.pos.x, stop.pos.y, stop.pos.z)
                _, stop.rot = pcall(quat, stop.rot.x, stop.rot.y, stop.rot.z, stop.rot.w)
            end
            return bl
        end)
        updateMarkers(BJI_Cache.CACHES.BUS_LINES)
    end)

    -- hunter/infected data
    BJI_Cache.addRxHandler(BJI_Cache.CACHES.HUNTER_INFECTED_DATA, function(cacheData)
        M.Data.HunterInfected = cacheData
        M.Data.HunterInfected.majorPositions = table.map(M.Data.HunterInfected.majorPositions, function(p)
            _, p.pos = pcall(vec3, p.pos.x, p.pos.y, p.pos.z)
            _, p.rot = pcall(quat, p.rot.x, p.rot.y, p.rot.z, p.rot.w)
            return p
        end)
        M.Data.HunterInfected.minorPositions = table.map(M.Data.HunterInfected.minorPositions, function(p)
            _, p.pos = pcall(vec3, p.pos.x, p.pos.y, p.pos.z)
            _, p.rot = pcall(quat, p.rot.x, p.rot.y, p.rot.z, p.rot.w)
            return p
        end)
        M.Data.HunterInfected.waypoints = table.map(M.Data.HunterInfected.waypoints, function(p)
            _, p.pos = pcall(vec3, p.pos.x, p.pos.y, p.pos.z)
            return p
        end)
    end)

    -- derby data
    BJI_Cache.addRxHandler(BJI_Cache.CACHES.DERBY_DATA, function(cacheData)
        BJI_Scenario.Data.Derby = table.map(cacheData, function(a)
            _, a.centerPosition = pcall(vec3, a.centerPosition.x, a.centerPosition.y, a.centerPosition.z)
            _, a.previewPosition.pos = pcall(vec3, a.previewPosition.pos.x, a.previewPosition.pos.y,
                a.previewPosition.pos.z)
            _, a.previewPosition.rot = pcall(quat, a.previewPosition.rot.x, a.previewPosition.rot.y,
                a.previewPosition.rot.z, a.previewPosition.rot.w)
            for _, sp in ipairs(a.startPositions) do
                _, sp.pos = pcall(vec3, sp.pos.x, sp.pos.y, sp.pos.z)
                _, sp.rot = pcall(quat, sp.rot.x, sp.rot.y, sp.rot.z, sp.rot.w)
            end
            return a
        end)
        updateMarkers(BJI_Cache.CACHES.DERBY_DATA)
    end)
end

-- LIVE STATE

---@return BJIScenario
local function _curr()
    return M.scenarii[M.CurrentScenario] or {}
end

local function registerSoloScenario(type, module)
    M.TYPES[type] = type
    M.scenarii[type] = module
    if not table.includes(M.solo, type) then
        table.insert(M.solo, type)
    end
end

local function registerMultiScenario(type, module)
    M.TYPES[type] = type
    M.scenarii[type] = module
    if not table.includes(M.multi, type) then
        table.insert(M.multi, type)
    end
end

local function initScenarii()
    M.TYPES.FREEROAM = "FREEROAM"
    M.scenarii[M.TYPES.FREEROAM] = require("ge/extensions/BJI/scenario/ScenarioFreeroam")

    Table(FS:directoryList("/lua/ge/extensions/BJI/scenario"))
        :filter(function(path)
            return path:endswith(".lua")
        end):map(function(el)
        return el:gsub("^/lua/", ""):gsub(".lua$", "")
    end):forEach(function(scenarioPath)
        ---@type boolean, BJIScenario
        local ok, s = pcall(require, scenarioPath)
        if ok then
            if not M.scenarii[s._key] and not s._skip then
                if s._isSolo then
                    registerSoloScenario(s._key, s)
                else
                    registerMultiScenario(s._key, s)
                end
                LogInfo(string.var("Scenario {1} loaded", { s._name }))
            end
        else
            LogError(string.var("Error loading scenario {1} : {2}", { scenarioPath, s }))
        end
    end)

    M.CurrentScenario = M.TYPES.FREEROAM
    if _curr().onLoad then
        _curr().onLoad(BJI_Tick.getContext())
    end
end

---@param mpVeh BJIMPVehicle
local function onVehicleSpawned(mpVeh)
    BJI_Reputation.vehicleResetted()
    if _curr().onVehicleSpawned then
        _curr().onVehicleSpawned(mpVeh)
    end
end

local function onVehicleResetted(gameVehID)
    if gameVehID == -1 or BJI_AI.isAIVehicle(gameVehID) or
        table.includes({ BJI_Veh.TYPES.TRAILER, BJI_Veh.TYPES.PROP },
            BJI_Veh.getType(gameVehID)) then
        return
    end

    BJI_Reputation.vehicleResetted()
    if _curr().onVehicleResetted then
        _curr().onVehicleResetted(gameVehID)
    end
end

local function onVehicleSwitched(oldGameVehID, newGameVehID)
    if _curr().onVehicleSwitched then
        _curr().onVehicleSwitched(oldGameVehID, newGameVehID)
    end
end

local function onVehicleDestroyed(gameVehID)
    if _curr().onVehicleDestroyed then
        _curr().onVehicleDestroyed(gameVehID)
    end
end

local function updateVehicles()
    if _curr().updateVehicles then
        _curr().updateVehicles()
    end
end

local function onGarageRepair()
    if _curr().onGarageRepair then
        _curr().onGarageRepair()
    end
end

local function onDropPlayerAtCamera()
    BJI_Reputation.vehicleTeleported()
    if _curr().onDropPlayerAtCamera then
        _curr().onDropPlayerAtCamera()
    end
end

local function onDropPlayerAtCameraNoReset()
    BJI_Reputation.vehicleTeleported()
    if _curr().onDropPlayerAtCameraNoReset then
        _curr().onDropPlayerAtCameraNoReset()
    end
end

---@param targetID integer
---@param forced boolean?
local function tryTeleportToPlayer(targetID, forced)
    BJI_Reputation.vehicleTeleported()
    if _curr().tryTeleportToPlayer then
        _curr().tryTeleportToPlayer(targetID, forced)
    end
end

---@param pos vec3
---@param saveHome boolean?
local function tryTeleportToPos(pos, saveHome)
    BJI_Reputation.vehicleTeleported()
    if _curr().tryTeleportToPos then
        _curr().tryTeleportToPos(pos, saveHome)
    end
end

---@param targetID integer
local function tryFocus(targetID)
    if _curr().tryFocus then
        _curr().tryFocus(targetID)
    end
end

---@param model string
---@param config table|string?
local function trySpawnNew(model, config)
    if _curr().trySpawnNew then
        _curr().trySpawnNew(model, config)
    end
end

---@param model string
---@param config table|string?
local function tryReplaceOrSpawn(model, config)
    if _curr().tryReplaceOrSpawn then
        _curr().tryReplaceOrSpawn(model, config)
    end
end

---@param paintIndex integer
---@param paint NGPaint
local function tryPaint(paintIndex, paint)
    if _curr().tryPaint then
        _curr().tryPaint(paintIndex, paint)
    end
end

---@param gameVehID integer
local function saveHome(gameVehID)
    local ctxt = BJI_Tick.getContext()
    if ctxt.isOwner and ctxt.veh.gameVehicleID == gameVehID then
        if not _curr().saveHome or not _curr().saveHome(ctxt) then
            local canReset = _curr().canReset and _curr().canReset()
            local canRecover = _curr().canRecoverVehicle and _curr().canRecoverVehicle()
            if not canReset and not canRecover then
                BJI_Toast.error(BJI_Lang.get("errors.cannotResetNow"), 3)
            end
        end
    end
end

---@param gameVehID integer
local function loadHome(gameVehID)
    local ctxt = BJI_Tick.getContext()
    if ctxt.isOwner and ctxt.veh.gameVehicleID == gameVehID then
        if not _curr().loadHome or not _curr().loadHome(ctxt) then
            local canReset = _curr().canReset and _curr().canReset()
            local canRecover = _curr().canRecoverVehicle and _curr().canRecoverVehicle()
            if not canReset and not canRecover then
                BJI_Toast.error(BJI_Lang.get("errors.cannotResetNow"), 3)
            end
        end
    end
end

---@return boolean
local function canRefuelAtStation()
    if _curr().canRefuelAtStation then
        return _curr().canRefuelAtStation()
    end
    return false
end

---@return boolean
local function canRepairAtGarage()
    if _curr().canRepairAtGarage then
        return _curr().canRepairAtGarage()
    end
    return false
end

---@return boolean
local function canReset()
    if _curr().canReset then
        return _curr().canReset()
    end
    return false
end

---@return boolean
local function canRecoverVehicle()
    if _curr().canRecoverVehicle then
        return _curr().canRecoverVehicle()
    end
    return false
end

---@return boolean
local function canSpawnNewVehicle()
    if _curr().canSpawnNewVehicle then
        return _curr().canSpawnNewVehicle()
    end
    return true
end

---@return boolean
local function canReplaceVehicle()
    if _curr().canReplaceVehicle then
        return _curr().canReplaceVehicle()
    end
    return true
end

---@return boolean
local function canPaintVehicle()
    if _curr().canPaintVehicle then
        return _curr().canPaintVehicle()
    end
    return true
end

---@return boolean
local function canDeleteVehicle()
    if _curr().canDeleteVehicle then
        return _curr().canDeleteVehicle()
    end
    return true
end

---@return boolean
local function canDeleteOtherVehicles()
    if _curr().canDeleteOtherVehicles then
        return _curr().canDeleteOtherVehicles()
    end
    return true
end

---@return boolean
local function canDeleteOtherPlayersVehicle()
    if _curr().canDeleteOtherPlayersVehicle then
        return _curr().canDeleteOtherPlayersVehicle()
    end
    return false
end

---@return boolean
local function canSpawnAI()
    if _curr().canSpawnAI then
        return _curr().canSpawnAI()
    end
    return false
end

---@return boolean
local function canWalk()
    if _curr().canWalk then
        return _curr().canWalk()
    end
    return false
end

---@return table<string, table> models
local function getModelList()
    if _curr().getModelList then
        return _curr().getModelList()
    end
    return {}
end

---@param player BJIPlayer
---@param ctxt? TickContext
---@return table<integer, table> buttons
local function getPlayerListActions(player, ctxt)
    if _curr().getPlayerListActions then
        return _curr().getPlayerListActions(player, ctxt or BJI_Tick.getContext())
    else
        return {}
    end
end

---@param ctxt TickContext
---@return boolean
local function canQuickTravel(ctxt)
    if _curr().canQuickTravel then
        return _curr().canQuickTravel(ctxt)
    end
    return false
end

---@param ctxt TickContext
local function canUseNodegrabber(ctxt)
    if _curr().canUseNodegrabber then
        return _curr().canUseNodegrabber(ctxt)
    end
    return false
end

---@return boolean
local function canBoost()
    if _curr().canBoost then
        return _curr().canBoost()
    end
    return false
end

---@return boolean
local function canShowNametags()
    if _curr().canShowNametags then
        return _curr().canShowNametags()
    end
    return true
end

---@param vehData BJIMPVehicle
---@return boolean, BJIColor?, BJIColor?
local function doShowNametag(vehData)
    if _curr().doShowNametag then
        return _curr().doShowNametag(vehData)
    else
        return true, nil, nil
    end
end

---@param vehData {gameVehicleID: integer, ownerID: integer}
---@return boolean, BJIColor?, BJIColor?
local function doShowNametagsSpecs(vehData)
    if _curr().doShowNametagsSpecs then
        return _curr().doShowNametagsSpecs(vehData)
    else
        return false, nil, nil
    end
end

---@return integer
local function getCollisionsType(ctxt)
    if _curr().getCollisionsType then
        return _curr().getCollisionsType(ctxt or BJI_Tick.getContext())
    else
        return BJI_Collisions.TYPES.GHOSTS
    end
end

local function getUIRenderFn()
    if _curr().drawUI then
        return _curr().drawUI
    else
        return nil
    end
end

---@param ctxt TickContext
---@return string[]
local function getRestrictions(ctxt)
    if _curr().getRestrictions then
        return _curr().getRestrictions(ctxt)
    end
    return {}
end

local tickErrorProcess = { countRender = 0, countFast = 0, countSlow = 0 }

---@param ctxt TickContext
local function renderTick(ctxt)
    if type(_curr().renderTick) == "function" then
        local status, err = pcall(_curr().renderTick, ctxt)
        if not status then
            LogError(string.var("Error during scenario render tick : {1}", { err }))
            tickErrorProcess.countRender = tickErrorProcess.countRender + 1
            if tickErrorProcess.countRender >= 20 then
                BJI_Toast.error("Continuous error during scenario render tick, backup to Freeroam")
                tickErrorProcess.countRender = 0
                M.switchScenario(M.TYPES.FREEROAM)
            end
        elseif tickErrorProcess.countRender > 0 then
            tickErrorProcess.countRender = 0
        end
    end
end

---@param ctxt TickContext
local function fastTick(ctxt)
    if type(_curr().fastTick) == "function" then
        local status, err = pcall(_curr().fastTick, ctxt)
        if not status then
            LogError(string.var("Error during scenario fast tick : {1}", { err }))
            tickErrorProcess.countFast = tickErrorProcess.countFast + 1
            if tickErrorProcess.countFast >= 20 then
                BJI_Toast.error("Continuous error during scenario fast tick, backup to Freeroam")
                tickErrorProcess.countFast = 0
                M.switchScenario(M.TYPES.FREEROAM)
            end
        elseif tickErrorProcess.countFast > 0 then
            tickErrorProcess.countFast = 0
        end
    end
end

---@param ctxt TickContext
local function slowTick(ctxt)
    if type(_curr().slowTick) == "function" then
        local status, err = pcall(_curr().slowTick, ctxt)
        if not status then
            LogError(string.var("Error during scenario slow tick : {1}", { err }))
            tickErrorProcess.countSlow = tickErrorProcess.countSlow + 1
            if tickErrorProcess.countSlow >= 5 then
                BJI_Toast.error("Continuous error during scenario slow tick, backup to Freeroam")
                tickErrorProcess.countSlow = 0
                M.switchScenario(M.TYPES.FREEROAM)
            end
        elseif tickErrorProcess.countSlow > 0 then
            tickErrorProcess.countSlow = 0
        end
    end
end

local function getAvailableScenarii()
    local res = {}
    for k, v in pairs(M.scenarii) do
        if v.canChangeTo() then
            table.insert(res, k)
        end
    end
    return res
end

local function switchScenario(newType, ctxt)
    if not table.includes(M.TYPES, newType) then
        LogError(string.var("Invalid scenario {1}", { newType }))
        return
    end

    if M.CurrentScenario == newType then
        return
    end

    ctxt = ctxt or BJI_Tick.getContext()
    if not M.scenarii[newType].canChangeTo(ctxt) then
        BJI_Toast.error(BJI_Lang.get("errors.scenarioUnavailable"))
        return
    end

    local previousScenario = M.CurrentScenario
    local status, err
    if _curr().onUnload then
        status, err = pcall(_curr().onUnload, ctxt)
        if not status then
            BJI_Toast.error("Error unloading scenario")
            error(err)
        end
    end
    M.CurrentScenario = newType
    if _curr().onLoad then
        status, err = pcall(_curr().onLoad, ctxt)
        if not status then
            BJI_Toast.error("Error loading scenario")
            M.CurrentScenario = previousScenario
            error(err)
        end
    end

    BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_CHANGED, {
        previousScenario = previousScenario,
        newScenario = newType,
        type = M.solo[newType] and "solo" or M.multi[newType] and "multi" or "other",
    })
    BJI_Restrictions.update()
end

local function isFreeroam()
    return not M.CurrentScenario or M.CurrentScenario == M.TYPES.FREEROAM
end

local function getFreeroam()
    return M.scenarii[M.TYPES.FREEROAM]
end

local function isSoloScenario()
    return table.includes(M.solo, M.CurrentScenario)
end

local function isServerScenario()
    return table.includes(M.multi, M.CurrentScenario)
end

local function is(type)
    return M.CurrentScenario == type
end

---@param type string
---@return any? BJIScenario
local function get(type)
    return M.scenarii[type]
end

local function onLoad()
    initCacheHandlers()

    BJI_Events.addListener(BJI_Events.EVENTS.LANG_CHANGED, function()
        updateMarkers()
    end, M._name)

    initScenarii()

    -- init cache handlers
    table.forEach({
        [BJI_Cache.CACHES.RACE] = M.TYPES.RACE_MULTI,
        [BJI_Cache.CACHES.DELIVERY_MULTI] = M.TYPES.DELIVERY_MULTI,
        [BJI_Cache.CACHES.SPEED] = M.TYPES.SPEED,
        [BJI_Cache.CACHES.HUNTER] = M.TYPES.HUNTER,
        [BJI_Cache.CACHES.INFECTED] = M.TYPES.INFECTED,
        [BJI_Cache.CACHES.DERBY] = M.TYPES.DERBY,
        [BJI_Cache.CACHES.TAG_DUO] = M.TYPES.TAG_DUO,
    }, function(scenarioType, cacheName)
        BJI_Cache.addRxHandler(tostring(cacheName), function(cacheData)
            local sc = M.get(scenarioType)
            if type(sc.rxData) == "function" then
                local ok, err = pcall(sc.rxData, cacheData)
                if not ok then
                    LogError(string.var("RxCache failed (cache {1}, scenario {2}): {3}",
                        { cacheName, scenarioType, err }))
                end
            end
        end)
    end)

    BJI_Events.addListener(BJI_Events.EVENTS.VEHICLE_INITIALIZED, onVehicleSpawned, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.NG_VEHICLE_RESETTED, onVehicleResetted, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.NG_VEHICLE_SWITCHED, onVehicleSwitched, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.NG_VEHICLE_DESTROYED, onVehicleDestroyed, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.NG_DROP_PLAYER_AT_CAMERA, onDropPlayerAtCamera, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.NG_DROP_PLAYER_AT_CAMERA_NO_RESET,
        onDropPlayerAtCameraNoReset, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.SLOW_TICK, slowTick, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.FAST_TICK, fastTick, M._name)
end

M.updateVehicles = updateVehicles
M.onGarageRepair = onGarageRepair

M.tryTeleportToPlayer = tryTeleportToPlayer
M.tryTeleportToPos = tryTeleportToPos
M.tryFocus = tryFocus

M.trySpawnNew = trySpawnNew
M.tryReplaceOrSpawn = tryReplaceOrSpawn
M.tryPaint = tryPaint
M.saveHome = saveHome
M.loadHome = loadHome

M.canRefuelAtStation = canRefuelAtStation
M.canRepairAtGarage = canRepairAtGarage
M.canReset = canReset
M.canRecoverVehicle = canRecoverVehicle
M.canSpawnNewVehicle = canSpawnNewVehicle
M.canReplaceVehicle = canReplaceVehicle
M.canPaintVehicle = canPaintVehicle
M.canDeleteVehicle = canDeleteVehicle
M.canDeleteOtherVehicles = canDeleteOtherVehicles
M.canDeleteOtherPlayersVehicle = canDeleteOtherPlayersVehicle
M.canSpawnAI = canSpawnAI
M.canWalk = canWalk
M.getModelList = getModelList
M.getPlayerListActions = getPlayerListActions
M.canQuickTravel = canQuickTravel
M.canUseNodegrabber = canUseNodegrabber
M.canBoost = canBoost
M.canShowNametags = canShowNametags
M.doShowNametag = doShowNametag
M.doShowNametagsSpecs = doShowNametagsSpecs
M.getCollisionsType = getCollisionsType
M.getUIRenderFn = getUIRenderFn
M.getRestrictions = getRestrictions

M.getAvailableScenarii = getAvailableScenarii
M.switchScenario = switchScenario

M.isFreeroam = isFreeroam
M.getFreeroam = getFreeroam
M.isPlayerScenarioInProgress = isSoloScenario
M.isServerScenarioInProgress = isServerScenario
M.is = is
M.get = get

M.onLoad = onLoad
M.renderTick = renderTick

return M
