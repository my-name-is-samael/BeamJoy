local energyIndicator = require("ge/extensions/BJI/ui/WindowBJI/Body/VehicleEnergyIndicator")
local healthIndicator = require("ge/extensions/BJI/ui/WindowBJI/Body/VehicleHealthIndicator")
local deliveryLeaderboard = require("ge/extensions/BJI/ui/WindowBJI/Body/DeliveryLeaderBoard")
local raceLeaderboard = require("ge/extensions/BJI/ui/WindowBJI/Body/RaceLeaderboard")

local cache = {
    data = {
        showVehIndicators = false,
        showDeliveryLeaderboard = false,
        raceLeaderboard = {
            show = false,
        },
        scenarioUIFn = nil,
        playersFn = nil,

        players = {
            waiting = {},
            list = {},
        },
    },

    labels = {
        loading = "",
        raceLeaderboard = {
            title = "",
        },
        delivery = {
            current = "",
            distanceLeft = "",
            vehicle = {
                currentConfig = "",
            },
            package = {
                streak = "",
                streakTooltip = "",
            }
        },
        busMission = {
            line = "",
            stopCount = "",
        },
        players = {
            moderation = {
                waiting = "",
                list = "",
                promoteWaitingTo = "",
                muteReason = "",
                kickReason = "",
                banReason = "",
                tempBanDuration = "",
                vehicles = "",
            },
            waiting = "",
            list = "",
        }
    },

    widths = {
        players = {
            moderation = {
                labels = 0,
            }
        }
    }
}

local function updateCacheRaces()
    cache.data.raceLeaderboard.show = table.some({
            BJIScenario.TYPES.FREEROAM,
            BJIScenario.TYPES.RACE_SOLO,
            BJIScenario.TYPES.RACE_MULTI,
        }, function(type) return BJIScenario.is(type) end) and
        BJIContext.Scenario.Data.Races and
        #BJIContext.Scenario.Data.Races > 0
    cache.data.raceLeaderboard.races = {}

    if cache.data.raceLeaderboard.show then
        cache.data.raceLeaderboard.races = table.filter(BJIContext.Scenario.Data.Races, function(race)
            return race.record
        end):map(function(race) return { name = race.name, record = race.record } end)
        if #cache.data.raceLeaderboard.races > 0 then
            cache.data.raceLeaderboard.races:sort(function(a, b)
                if a.name:find(b.name) then
                    return false
                elseif b.name:find(a.name) then
                    return true
                end
                return a.name < b.name
            end)
        else
            cache.data.raceLeaderboard.show = false
        end
    end
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJITick.getContext()

    cache.data.showVehIndicators = ctxt.isOwner and
        not BJIScenario.isServerScenarioInProgress() and
        BJIContext.Scenario.Data.EnergyStations
    cache.data.showDeliveryLeaderboard = table.some({
            BJIScenario.TYPES.FREEROAM,
            BJIScenario.TYPES.VEHICLE_DELIVERY,
            BJIScenario.TYPES.PACKAGE_DELIVERY,
            BJIScenario.TYPES.DELIVERY_MULTI,
        }, function(type) return BJIScenario.is(type) end) and
        BJIContext.Scenario.Data.Deliveries and
        BJIContext.Scenario.Data.DeliveryLeaderboard and
        #BJIContext.Scenario.Data.DeliveryLeaderboard > 0

    if BJIScenario.is(BJIScenario.TYPES.VEHICLE_DELIVERY) then
        cache.data.scenarioUIFn = BJIScenario.get(BJIScenario.TYPES.VEHICLE_DELIVERY).drawUI
    elseif BJIScenario.is(BJIScenario.TYPES.PACKAGE_DELIVERY) then
        cache.data.scenarioUIFn = BJIScenario.get(BJIScenario.TYPES.PACKAGE_DELIVERY).drawUI
    elseif BJIScenario.is(BJIScenario.TYPES.BUS_MISSION) then
        cache.data.scenarioUIFn = BJIScenario.get(BJIScenario.TYPES.BUS_MISSION).drawUI
    else
        cache.data.scenarioUIFn = nil
    end

    if BJIPerm.isStaff() then
        cache.data.playersFn = require("ge/extensions/BJI/ui/WindowBJI/Body/Moderation")
    else
        cache.data.playersFn = require("ge/extensions/BJI/ui/WindowBJI/Body/Players")
    end

    energyIndicator.updateCache(ctxt)
    healthIndicator.updateCache(ctxt)
end

local function updateLabels()
    cache.labels.loading = BJILang.get("common.loading")

    cache.labels.raceLeaderboard.title = BJILang.get("races.leaderboard.title")

    -- GLOBAL DELIVERIES
    cache.labels.delivery.current = BJILang.get("delivery.currentDelivery")
    cache.labels.delivery.distanceLeft = BJILang.get("delivery.distanceLeft")
    -- VEHICLE DELIVERY
    cache.labels.delivery.vehicle.currentConfig = BJILang.get("vehicleDelivery.vehicle")
    -- PACKAGE DELIVERY
    cache.labels.delivery.package.streak = BJILang.get("packageDelivery.currentStreak")
    cache.labels.delivery.package.streakTooltip = BJILang.get("packageDelivery.streakTooltip")
    -- BUS MISSION
    cache.labels.busMission.line = BJILang.get("buslines.play.line")
    cache.labels.busMission.stopCount = BJILang.get("buslines.play.stopCount")

    -- PLAYERS LIST
    cache.labels.players.moderation.waiting = string.var("{1}:", { BJILang.get("moderationBlock.waitingPlayers") })
    cache.labels.players.moderation.list = string.var("{1}:", { BJILang.get("moderationBlock.players") })
    cache.labels.players.moderation.promoteWaitingTo = BJILang.get("moderationBlock.buttons.promoteTo")
    cache.labels.players.moderation.muteReason = BJILang.get("moderationBlock.muteReason")
    cache.labels.players.moderation.kickReason = BJILang.get("moderationBlock.kickReason")
    cache.labels.players.moderation.banReason = BJILang.get("moderationBlock.banReason")
    cache.labels.players.moderation.tempBanDuration = BJILang.get("moderationBlock.tempBanDuration")
    cache.labels.players.moderation.vehicles = BJILang.get("moderationBlock.vehicles")
    cache.labels.players.waiting = BJILang.get("playersBlock.waitingPlayers")
    cache.labels.players.list = string.var("{1}:", { BJILang.get("playersBlock.players") })
end

---@param ctxt TickContext
local function updateCachePlayers(ctxt)
    cache.data.players.waiting = {}
    cache.data.players.list = {}

    local selfStaff = BJIPerm.isStaff()

    cache.data.players.waiting = {}
    table.filter(BJIContext.Players, function(_, playerID)
        return not BJIPerm.canSpawnVehicle(playerID) and not BJIPerm.isStaff(playerID)
    end):forEach(function(player, playerID)
        local showPromote = player.isGroupLower and
            not table.includes({ BJI_GROUP_NAMES.OWNER }, BJIPerm.getNextGroup(player.group))
        local promoteGroup = showPromote and BJIPerm.getNextGroup(player.group)
        local promoteLabel = showPromote and BJILang.get("moderationBlock.buttons.promoteTo")
            :var({ groupName = BJILang.get("groups." .. promoteGroup, promoteGroup) }) or nil

        table.insert(cache.data.players.waiting, {
            playerID = playerID,
            playerName = player.playerName,
            grouplabel = string.var("({1})", { BJILang.get("groups." .. player.group, player.group) }),
            promoteGroup = selfStaff and promoteGroup,
            promoteLabel = selfStaff and promoteLabel
        })
    end)

    cache.data.players.list = {}
    table.filter(BJIContext.Players, function(_, playerID)
        return BJIPerm.canSpawnVehicle(playerID) or BJIPerm.isStaff(playerID)
    end):forEach(function(p, playerID)
        local isSelf = BJIContext.isSelf(playerID)
        local groupLabel = BJILang.get(string.var("groups.{1}", { p.group }), p.group)
        local targetGroup = BJIPerm.Groups[p.group] or { level = 0 }
        local isGroupLower = ctxt.group.level > targetGroup.level
        local vehiclesCount = table.length(p.vehicles or {})
        local showVehicles = isSelf or isGroupLower
        local nameSuffix
        if selfStaff then
            nameSuffix = string.var("({1})", { groupLabel })
        else
            nameSuffix = BJIPerm.isStaff(playerID) and
                string.var("({1})", { BJILang.get("chat.staffTag") }) or
                string.var("({1} | {2}{3})", {
                    groupLabel,
                    BJILang.get("chat.reputationTag"),
                    BJIReputation.getReputationLevel(p.reputation)
                })
        end

        local showDemote = isGroupLower and
            not table.includes({ BJI_GROUP_NAMES.NONE, BJI_GROUP_NAMES.OWNER }, p.group)
        local demoteGroup = showDemote and BJIPerm.getPreviousGroup(p.group)
        local demoteLabel = showDemote and BJILang.get("moderationBlock.buttons.demoteTo")
            :var({ groupName = BJILang.get("groups." .. demoteGroup, demoteGroup) }) or nil
        local showPromote = isGroupLower and
            not table.includes({ BJI_GROUP_NAMES.OWNER }, BJIPerm.getNextGroup(p.group))
        local promoteGroup = showPromote and BJIPerm.getNextGroup(p.group)
        local promoteLabel = showPromote and BJILang.get("moderationBlock.buttons.promoteTo")
            :var({ groupName = BJILang.get("groups." .. promoteGroup, promoteGroup) }) or nil

        local vehicleCursor = "@ => "
        local vehiclesLabelWidth = 0
        if selfStaff and vehiclesCount > 0 then
            table.forEach(p.vehicles, function(veh)
                local w = GetColumnTextWidth(string.var("{1} {2}", { vehicleCursor, veh.model }))
                if w > vehiclesLabelWidth then
                    vehiclesLabelWidth = w
                end
            end)
        end

        table.insert(cache.data.players.list, {
            playerID = playerID,
            self = isSelf,
            playerName = p.playerName,
            nameSuffix = nameSuffix,
            group = p.group,
            groupLabel = groupLabel,
            showVehicles = showVehicles,
            vehiclesCount = vehiclesCount,
            currentVehicle = p.currentVehicle,
            vehicles = p.vehicles,
            vehicleCursor = vehicleCursor,
            vehiclesLabelWidth = vehiclesLabelWidth,
            promoteGroup = promoteGroup,
            promoteLabel = promoteLabel,
            demoteGroup = demoteGroup,
            demoteLabel = demoteLabel
        })
    end)

    table.forEach({ cache.data.players.waiting, cache.data.players.list }, function(players)
        table.sort(players, function(a, b)
            return a.playerName < b.playerName
        end)
    end)

    cache.widths.players.moderation.labels = 0
    if BJIPerm.isStaff() then
        for _, k in ipairs({
            "moderationBlock.muteReason",
            "moderationBlock.kickReason",
            "moderationBlock.banReason",
            "moderationBlock.tempBanDuration",
        }) do
            local label = BJILang.get(k)
            local w = GetColumnTextWidth(label .. ":")
            if w > cache.widths.players.moderation.labels then
                cache.widths.players.moderation.labels = w
            end
        end
    end
end

local listeners = {}
local function onLoad()
    local ctxt = BJITick.getContext()

    updateCache(ctxt)
    table.insert(listeners, BJIEvents.addListener({
        BJIEvents.EVENTS.VEHICLE_SPAWNED,
        BJIEvents.EVENTS.VEHICLE_REMOVED,
        BJIEvents.EVENTS.VEHICLE_SPEC_CHANGED,
        BJIEvents.EVENTS.VEHDATA_UPDATED,
        BJIEvents.EVENTS.SCENARIO_CHANGED,
        BJIEvents.EVENTS.PERMISSION_CHANGED,
        BJIEvents.EVENTS.LANG_CHANGED,
        BJIEvents.EVENTS.UI_UPDATE_REQUEST
    }, updateCache))

    updateLabels()
    table.insert(listeners, BJIEvents.addListener({
        BJIEvents.EVENTS.LANG_CHANGED,
        BJIEvents.EVENTS.VEHDATA_UPDATED,
        BJIEvents.EVENTS.UI_UPDATE_REQUEST
    }, updateLabels))

    deliveryLeaderboard.updateCache(ctxt)
    table.insert(listeners, BJIEvents.addListener({
        BJIEvents.EVENTS.UI_SCALE_CHANGED,
        BJIEvents.EVENTS.CACHE_LOADED,
        BJIEvents.EVENTS.LANG_CHANGED,
        BJIEvents.EVENTS.UI_UPDATE_REQUEST
    }, function(ctxt2, data)
        if data._event ~= BJIEvents.EVENTS.CACHE_LOADED or
            data.cache == BJICache.CACHES.DELIVERIES then
            deliveryLeaderboard.updateCache(ctxt2)
        end
    end))

    updateCacheRaces()
    raceLeaderboard.updateCache(ctxt, cache)
    table.insert(listeners, BJIEvents.addListener({
        BJIEvents.EVENTS.UI_SCALE_CHANGED,
        BJIEvents.EVENTS.CACHE_LOADED,
        BJIEvents.EVENTS.UI_UPDATE_REQUEST
    }, function(ctxt2, data)
        if data._event ~= BJIEvents.EVENTS.CACHE_LOADED or
            data.cache == BJICache.CACHES.RACES then
            updateCacheRaces()
            raceLeaderboard.updateCache(ctxt2, cache)
        end
    end))

    updateCachePlayers(ctxt)
    table.insert(listeners, BJIEvents.addListener({
        BJIEvents.EVENTS.PLAYER_CONNECT,
        BJIEvents.EVENTS.PLAYER_DISCONNECT,
        BJIEvents.EVENTS.UI_SCALE_CHANGED,
        BJIEvents.EVENTS.CACHE_LOADED,
        BJIEvents.EVENTS.SCENARIO_CHANGED,
        BJIEvents.EVENTS.PERMISSION_CHANGED,
        BJIEvents.EVENTS.LANG_CHANGED,
        BJIEvents.EVENTS.UI_UPDATE_REQUEST
    }, function(ctxt2, data)
        if data._event ~= BJIEvents.EVENTS.CACHE_LOADED or
            table.includes({
                BJICache.CACHES.PLAYERS,
                BJICache.CACHES.LANG
            }, data.cache) then
            updateCachePlayers(ctxt2)
        end
    end))
end

local function onUnload()
    table.forEach(listeners, BJIEvents.removeListener)
end

local function draw(ctxt)
    if cache.data.showVehIndicators then
        energyIndicator.draw(ctxt)
        healthIndicator.draw(ctxt)
    end

    if cache.data.showDeliveryLeaderboard then
        deliveryLeaderboard.draw(ctxt)
    end

    if cache.data.raceLeaderboard.show then
        if #cache.data.raceLeaderboard.races <= BJIRacesLeaderboardWindow.AMOUNT_THRESHOLD then
            raceLeaderboard.draw()
        else
            LineBuilder()
                :btnSwitch({
                    id = "toggleRacesLeaderboardWindow",
                    labelOn = cache.labels.raceLeaderboard.title,
                    labelOff = cache.labels.raceLeaderboard.title,
                    state = not BJIRacesLeaderboardWindow.show,
                    onClick = function()
                        BJIRacesLeaderboardWindow.show = not BJIRacesLeaderboardWindow.show
                    end
                })
                :build()
        end
    end

    if type(cache.data.scenarioUIFn) == "function" then
        cache.data.scenarioUIFn(ctxt, cache)
        Separator()
    end

    if type(cache.data.playersFn) == "function" then
        cache.data.playersFn(ctxt, cache)
    end
end

return {
    onLoad = onLoad,
    onUnload = onUnload,
    draw = draw,
}
