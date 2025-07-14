---@class BJIManagerBigmap : BJIManager
local M = {
    _name = "Bigmap",

    baseFunctions = {},

    quickTravel = true, -- default state when joining

    POIs = {
        races = Table(),
        busLines = Table(),
        derbyArenas = Table(),
        garages = Table(),
        gasStations = Table(),
    },
    rawPOIs = Table(),
    rawPOIsGen = 0,

    baseImgs = {
        races = "/art/thumbnails/races.jpg",
        busLines = "/art/thumbnails/busLines.jpg",
        derbyArenas = "/art/thumbnails/derbyArenas.jpg",
        garages = "/art/thumbnails/garages.jpg",
        gasStations = "/art/thumbnails/gasStations.jpg",
    },

    cachedMissions = {},
    _routeParams = {
        cutOffDrivability = .7,
        dirMult = 1,
        penaltyAboveCutoff = 1,
        penaltyBelowCutoff = 5,
        wD = 2,
        wZ = 1,
    },
}

local function generateRawPOIs()
    M.rawPOIs:clear()
    M.rawPOIsGen = M.rawPOIsGen + 1

    local icons = {
        races = BJI.Utils.Icon.ICONS.mission_airace02_triangle,
        busLines = BJI.Utils.Icon.ICONS.mission_busRoute_triangle,
        derbyArenas = BJI.Utils.Icon.ICONS.mission_cup_triangle,
        garages = BJI.Utils.Icon.ICONS.poi_garage_2_round,
        gasStations = BJI.Utils.Icon.ICONS.poi_fuel_round,
    }
    for type, list in pairs(M.POIs) do
        list:forEach(function(el)
            M.rawPOIs:insert({
                id = el.id,
                data = {
                    type = "mission",
                    missionId = el.id,
                    date = 0,
                },
                markerInfo = {
                    bigmapMarker = {
                        cluster = true,
                        icon = icons[type],
                        pos = el.pos,
                        quickTravelPosRotFunction = function()
                            return el.pos, quat()
                        end,
                        thumbnail = M.baseImgs[type],
                        preview = { M.baseImgs[type] },
                    }
                }
            })
        end)
    end
end

local function onUpdateData()
    for _, list in pairs(M.POIs) do
        list:clear()
    end
    M.selectedPreview = nil
    table.clear(M.cachedMissions)

    BJI_Scenario.Data.Races
        :sort(function(a, b) return a.id < b.id end)
    ---@param r BJRaceLight
        :forEach(function(r)
            local id = "race" .. tostring(r.id) .. "_"
            M.POIs.races[id] = {
                id = id,
                label = BJI_Lang.get("bigmap.activities.race"):var({ places = r.places }),
                name = r.name,
                description = BJI_Lang.get(r.loopable and "bigmap.descriptions.raceLoopable" or
                    "bigmap.descriptions.raceSprint"),
                rating = {},
                quickTravelAvailable = M.quickTravel,
                quickTravelUnlocked = M.quickTravel,
                canSetRoute = true,
                thumbnailFile = M.baseImgs.races,
                previewFiles = { M.baseImgs.races },
                pos = r.markerPos,
                tab = 1,
                group = 1,
            }
        end)

    ---@param bl BJBusLine
    BJI_Scenario.Data.BusLines:forEach(function(bl, i)
        local id = "busLine" .. tostring(i) .. "_"
        M.POIs.busLines[id] = {
            id = id,
            label = BJI_Lang.get("bigmap.activities.busMission")
                :var({ distance = BJI.Utils.UI.PrettyDistance(bl.distance) }),
            name = bl.name,
            description = BJI_Lang.get("bigmap.descriptions.busMission")
                :var({
                    stops = table.map(bl.stops, function(s) return s.name end):join(" - ")
                }),
            rating = {},
            canSetRoute = true,
            thumbnailFile = M.baseImgs.busLines,
            previewFiles = { M.baseImgs.busLines },
            pos = bl.stops[1].pos,
            tab = 1,
            group = 2,
        }
    end)

    ---@param a BJArena
    BJI_Scenario.Data.Derby:forEach(function(a, i)
        local id = "derbyArena" .. tostring(i) .. "_"
        M.POIs.derbyArenas[id] = {
            id = id,
            label = BJI_Lang.get("bigmap.activities.derby")
                :var({ places = #a.startPositions }),
            name = a.name,
            description = BJI_Lang.get("bigmap.descriptions.derby"),
            rating = {},
            canSetRoute = true,
            thumbnailFile = M.baseImgs.derbyArenas,
            previewFiles = { M.baseImgs.derbyArenas },
            pos = a.centerPosition,
            tab = 1,
            group = 3,
        }
    end)

    ---@param g BJIStation
    BJI_Stations.Data.Garages:forEach(function(g, i)
        local id = "garage" .. tostring(i) .. "_"
        M.POIs.garages[id] = {
            id = id,
            label = BJI_Lang.get("bigmap.activities.garage"),
            name = g.name,
            description = BJI_Lang.get("bigmap.descriptions.garage"),
            rating = {},
            canSetRoute = true,
            thumbnailFile = M.baseImgs.garages,
            previewFiles = { M.baseImgs.garages },
            pos = g.pos,
            tab = 2,
            group = 1,
        }
    end)

    local previousPositions = Table()
    ---@param es BJIStation
    BJI_Stations.Data.EnergyStations:forEach(function(es, i)
        if not previousPositions:any(function(prev)
                return prev.name == es.name and
                    prev.pos:distance(es.pos) < 20
            end) then
            local id = "gasStation" .. tostring(i) .. "_"
            M.POIs.gasStations[id] = {
                id = id,
                label = BJI_Lang.get((#es.types == 1 and es.types[1] == BJI_Veh.FUEL_TYPES.ELECTRIC) and
                        "bigmap.activities.electricStation" or "bigmap.activities.gasStation")
                    :var({
                        energyTypes = table.map(es.types, function(t)
                            return BJI_Lang.get("energy.energyTypes." .. t)
                        end):join(", ")
                    }),
                name = es.name,
                description = BJI_Lang.get((#es.types == 1 and es.types[1] == BJI_Veh.FUEL_TYPES.ELECTRIC) and
                    "bigmap.descriptions.electricStation" or "bigmap.descriptions.gasStation"),
                rating = {},
                canSetRoute = true,
                thumbnailFile = M.baseImgs.gasStations,
                previewFiles = { M.baseImgs.gasStations },
                pos = es.pos,
                tab = 2,
                group = 2,
            }
            previousPositions:insert({
                name = es.name,
                pos = es.pos,
            })
        end
    end)

    generateRawPOIs()
end

local function sendCurrentLevelMissionsToBigmap()
    local res = {
        branchIcons = {},
        levelData = {
            title = BJI_Context.UI.mapName,
        },
        poiData = {},
        rules = {
            canSetRoute = true,
        },
        filterData = {
            {
                key = "scenarios",
                icon = BJI_Prompt.ICONS.flag,
                groups = {
                    {
                        label = BJI_Lang.get("bigmap.groups.races"),
                        elements = {},
                    },
                    {
                        label = BJI_Lang.get("bigmap.groups.busMissions"),
                        elements = {},
                    },
                    {
                        label = BJI_Lang.get("bigmap.groups.derbyArenas"),
                        elements = {},
                    },
                }
            },
            {
                key = "facilities",
                icon = BJI_Prompt.ICONS.mapPoint,
                groups = {
                    {
                        label = BJI_Lang.get("bigmap.groups.garages"),
                        elements = {},
                    },
                    {
                        label = BJI_Lang.get("bigmap.groups.gasStations"),
                        elements = {},
                    },
                }
            },
        },
        gameMode = "freeroam",
    }

    for _, type in pairs(M.POIs) do
        type:forEach(function(el, id)
            res.poiData[id] = el
            table.insert(res.filterData[el.tab].groups[el.group].elements, id)
        end)
    end

    guihooks.trigger("BigmapMissionData", res)
end

local function getRawPOIs(levelIdentifier)
    return M.rawPOIs, M.rawPOIsGen
end

---@param positions vec3[]
---@return table
local function createNavGraphRoute(positions)
    local route = require('/lua/ge/extensions/gameplay/route/route')()
    route:setRouteParams(M._routeParams.cutOffDrivability, M._routeParams.dirMult,
        M._routeParams.penaltyAboveCutoff, M._routeParams.penaltyBelowCutoff,
        M._routeParams.wD, M._routeParams.wZ)
    route:setupPathMulti(positions)
    return route.path
end

local function getMissionById(id)
    if not id then return {} end
    if not M.cachedMissions[id] then
        local poi, missionType
        Table(M.POIs):forEach(function(list, elType)
            if not poi then
                if list[id] then
                    poi = list[id]
                    missionType = elType
                end
            end
        end)
        M.cachedMissions[id] = {
            name = poi and poi.name or nil,
            unlocks = {},
        }
        if poi then
            if missionType == "races" then
                local raceId = id:gsub("^race", ""):gsub("_$", "")
                local race = BJI_Scenario.Data.Races:find(function(r) return r.id == tonumber(raceId) end)
                if race then
                    M.cachedMissions[id].getWorldPreviewRoute = function()
                        return createNavGraphRoute(race.route)
                    end
                end
            elseif missionType == "busLines" then
                local lineId = id:gsub("^busLine", ""):gsub("_$", "")
                local busLine = BJI_Scenario.Data.BusLines[tonumber(lineId)]
                M.cachedMissions[id].getWorldPreviewRoute = function()
                    return createNavGraphRoute(table.map(busLine.stops, function(s)
                        return s.pos
                    end))
                end
            end
        end
    end
    return M.cachedMissions[id]
end

local function updateQuickTravelState()
    local function _update()
        M.quickTravel = BJI_Scenario.canQuickTravel()
    end

    if BJI_Cache.areBaseCachesFirstLoaded() and BJI.CLIENT_READY then
        _update()
    else
        BJI_Async.task(function()
            return BJI_Cache.areBaseCachesFirstLoaded() and BJI.CLIENT_READY
        end, _update)
    end
end

local function onUnload()
    RollBackNGFunctionsWrappers(M.baseFunctions)
end

local function onLoad()
    extensions.load("freeroam_bigMapPoiProvider", "freeroam_bigMapMarkers", "gameplay_missions_missions")
    M.baseFunctions = {
        freeroam_bigMapPoiProvider = {
            sendCurrentLevelMissionsToBigmap = extensions.freeroam_bigMapPoiProvider.sendCurrentLevelMissionsToBigmap,
        },
        gameplay_rawPois = {
            getRawPoiListByLevel = extensions.gameplay_rawPois.getRawPoiListByLevel,
        },
        gameplay_missions_missions = {
            getMissionById = extensions.gameplay_missions_missions.getMissionById
        }
    }
    extensions.freeroam_bigMapPoiProvider.sendCurrentLevelMissionsToBigmap = sendCurrentLevelMissionsToBigmap
    extensions.gameplay_rawPois.getRawPoiListByLevel = getRawPOIs
    extensions.gameplay_missions_missions.getMissionById = getMissionById


    BJI_Events.addListener(BJI_Events.EVENTS.ON_UNLOAD, onUnload, M._name)
    BJI_Events.addListener({
        BJI_Events.EVENTS.CACHE_LOADED,
        BJI_Events.EVENTS.SCENARIO_CHANGED,
        BJI_Events.EVENTS.SCENARIO_UPDATED,
    }, function(_, data)
        if data.event ~= BJI_Events.EVENTS.CACHE_LOADED or
            data.cache == BJI_Cache.CACHES.BJC then
            updateQuickTravelState()
        end
    end, M._name .. "QuickTravel")

    onUpdateData()
    BJI_Events.addListener({
        BJI_Events.EVENTS.LANG_CHANGED,
        BJI_Events.EVENTS.CACHE_LOADED,
    }, function(_, data)
        if data.events ~= BJI_Events.EVENTS.CACHE_LOADED or
            table.includes({
                BJI_Cache.CACHES.STATIONS,
                BJI_Cache.CACHES.RACES,
                BJI_Cache.CACHES.DERBY_DATA,
                BJI_Cache.CACHES.BUS_LINES
            }, data.cache) then
            onUpdateData()
        end
    end, M._name .. "POIsUpdate")
end

M.onLoad = onLoad

return M
