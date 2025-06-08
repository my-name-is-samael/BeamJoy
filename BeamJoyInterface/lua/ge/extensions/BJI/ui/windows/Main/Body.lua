local energyIndicator = require("ge/extensions/BJI/ui/windows/Main/Body/VehicleEnergyIndicator")
local healthIndicator = require("ge/extensions/BJI/ui/windows/Main/Body/VehicleHealthIndicator")
local deliveryLeaderboard = require("ge/extensions/BJI/ui/windows/Main/Body/DeliveryLeaderBoard")

local cache = {
    name = "MainBody",

    data = {
        showVehIndicators = false,
        showDeliveryLeaderboard = false,
        raceLeaderboard = {
            show = false,
        },
        scenarioUIFn = nil,
        playersFn = nil,

        players = {
            waiting = Table(),
            list = Table(),
            moderationInputs = {
                muteReason = "",
                kickReason = "",
                banReason = "",
                tempBanDuration = 0,
            },
            canBan = false,
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
            leave = "",
            loop = "",
            vehicle = {
                currentConfig = "",
            },
            package = {
                streak = "",
                streakTooltip = "",
            },
        },
        busMission = {
            line = "",
            stopCount = "",
            leave = "",
            loop = "",
        },
        players = {
            moderation = {
                waiting = "",
                list = "",
                muteReason = "",
                kickReason = "",
                banReason = "",
                savedReason = "",
                tempBanDuration = "",
                vehicles = "",
                buttons = {
                    kick = "",
                    ban = "",
                    tempban = "",
                    show = "",
                    freeze = "",
                    engine = "",
                    delete = "",
                    explode = "",
                    mute = "",
                    deleteAllVehicles = "",
                    promoteTo = "",
                    demoteTo = "",
                },
            },
            waiting = "",
            list = "",
        }
    },

    widths = {
        players = {
            moderation = {
                labels = 0,
                buttons = 0,
            }
        }
    }
}

local function updateCacheRaces()
    cache.data.raceLeaderboard.show = table.some({
            BJI.Managers.Scenario.TYPES.FREEROAM,
            BJI.Managers.Scenario.TYPES.RACE_SOLO,
            BJI.Managers.Scenario.TYPES.RACE_MULTI,
        }, function(type) return BJI.Managers.Scenario.is(type) end) and
        BJI.Managers.Context.Scenario.Data.Races and
        #BJI.Managers.Context.Scenario.Data.Races > 0

    if cache.data.raceLeaderboard.show and
        #table.filter(BJI.Managers.Context.Scenario.Data.Races, function(race) return race.record end):values() == 0 then
        cache.data.raceLeaderboard.show = false
    end
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI.Managers.Tick.getContext()

    cache.data.showVehIndicators = ctxt.isOwner and
        not BJI.Managers.Scenario.isServerScenarioInProgress() and
        BJI.Managers.Context.Scenario.Data.EnergyStations
    cache.data.showDeliveryLeaderboard = table.some({
            BJI.Managers.Scenario.TYPES.FREEROAM,
            BJI.Managers.Scenario.TYPES.VEHICLE_DELIVERY,
            BJI.Managers.Scenario.TYPES.PACKAGE_DELIVERY,
            BJI.Managers.Scenario.TYPES.DELIVERY_MULTI,
        }, function(type) return BJI.Managers.Scenario.is(type) end) and
        BJI.Managers.Context.Scenario.Data.Deliveries and
        BJI.Managers.Context.Scenario.Data.DeliveryLeaderboard and
        #BJI.Managers.Context.Scenario.Data.DeliveryLeaderboard > 0

    cache.data.scenarioUIFn = nil
    if BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.VEHICLE_DELIVERY) then
        cache.data.scenarioUIFn = BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.VEHICLE_DELIVERY).drawUI
    elseif BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.PACKAGE_DELIVERY) then
        cache.data.scenarioUIFn = BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.PACKAGE_DELIVERY).drawUI
    elseif BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.BUS_MISSION) then
        cache.data.scenarioUIFn = BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.BUS_MISSION).drawUI
    elseif BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.TAG_DUO) then
        cache.data.scenarioUIFn = BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.TAG_DUO).drawUI
    end

    if BJI.Managers.Perm.isStaff() then
        cache.data.playersFn = require("ge/extensions/BJI/ui/windows/Main/Body/Moderation")
    else
        cache.data.playersFn = require("ge/extensions/BJI/ui/windows/Main/Body/Players")
    end

    energyIndicator.updateCache(ctxt)
    healthIndicator.updateCache(ctxt)
end

local function updateLabels()
    cache.labels.loading = BJI.Managers.Lang.get("common.loading")

    cache.labels.raceLeaderboard.title = BJI.Managers.Lang.get("races.leaderboard.title")

    -- GLOBAL DELIVERIES
    cache.labels.delivery.current = BJI.Managers.Lang.get("delivery.currentDelivery")
    cache.labels.delivery.distanceLeft = BJI.Managers.Lang.get("delivery.distanceLeft")
    cache.labels.delivery.leave = BJI.Managers.Lang.get("common.buttons.leave")
    cache.labels.delivery.loop = BJI.Managers.Lang.get("common.buttons.loop")
    -- VEHICLE DELIVERY
    cache.labels.delivery.vehicle.currentConfig = BJI.Managers.Lang.get("vehicleDelivery.vehicle")
    -- PACKAGE DELIVERY
    cache.labels.delivery.package.streak = BJI.Managers.Lang.get("packageDelivery.currentStreak")
    cache.labels.delivery.package.streakTooltip = BJI.Managers.Lang.get("packageDelivery.streakTooltip")
    -- BUS MISSION
    cache.labels.busMission.line = BJI.Managers.Lang.get("buslines.play.line")
    cache.labels.busMission.stopCount = BJI.Managers.Lang.get("buslines.play.stopCount")
    cache.labels.busMission.leave = BJI.Managers.Lang.get("common.buttons.leave")
    cache.labels.busMission.loop = BJI.Managers.Lang.get("common.buttons.loop")

    -- PLAYERS LIST
    cache.labels.players.moderation.waiting = string.var("{1}:",
        { BJI.Managers.Lang.get("moderationBlock.waitingPlayers") })
    cache.labels.players.moderation.list = string.var("{1}:", { BJI.Managers.Lang.get("moderationBlock.players") })
    cache.labels.players.moderation.muteReason = BJI.Managers.Lang.get("moderationBlock.muteReason")
    cache.labels.players.moderation.kickReason = BJI.Managers.Lang.get("moderationBlock.kickReason")
    cache.labels.players.moderation.banReason = BJI.Managers.Lang.get("moderationBlock.banReason")
    cache.labels.players.moderation.savedReason = BJI.Managers.Lang.get("moderationBlock.savedReason")
    cache.labels.players.moderation.tempBanDuration = BJI.Managers.Lang.get("moderationBlock.tempBanDuration")
    cache.labels.players.moderation.vehicles = BJI.Managers.Lang.get("moderationBlock.vehicles")
    cache.labels.players.moderation.buttons.kick = BJI.Managers.Lang.get("moderationBlock.buttons.kick")
    cache.labels.players.moderation.buttons.ban = BJI.Managers.Lang.get("moderationBlock.buttons.ban")
    cache.labels.players.moderation.buttons.tempban = BJI.Managers.Lang.get("moderationBlock.buttons.tempBan")
    cache.labels.players.moderation.buttons.show = BJI.Managers.Lang.get("common.buttons.show")
    cache.labels.players.moderation.buttons.freeze = BJI.Managers.Lang.get("moderationBlock.buttons.freeze")
    cache.labels.players.moderation.buttons.engine = BJI.Managers.Lang.get("moderationBlock.buttons.engine")
    cache.labels.players.moderation.buttons.delete = BJI.Managers.Lang.get("common.buttons.delete")
    cache.labels.players.moderation.buttons.explode = BJI.Managers.Lang.get("common.buttons.explode")
    cache.labels.players.moderation.buttons.mute = BJI.Managers.Lang.get("moderationBlock.buttons.mute")
    cache.labels.players.moderation.buttons.deleteAllVehicles = BJI.Managers.Lang.get(
        "moderationBlock.buttons.deleteAllVehicles")
    cache.labels.players.moderation.buttons.promoteTo = BJI.Managers.Lang.get("moderationBlock.buttons.promoteTo")
    cache.labels.players.moderation.buttons.demoteTo = BJI.Managers.Lang.get("moderationBlock.buttons.demoteTo")
    cache.labels.players.waiting = BJI.Managers.Lang.get("playersBlock.waitingPlayers")
    cache.labels.players.list = string.var("{1}:", { BJI.Managers.Lang.get("playersBlock.players") })
end

---@param ctxt TickContext
local function updateCachePlayers(ctxt)
    local selfStaff = BJI.Managers.Perm.isStaff()

    cache.data.players.waiting = Table()
    table.filter(BJI.Managers.Context.Players, function(_, playerID)
        return not BJI.Managers.Perm.canSpawnVehicle(playerID) and not BJI.Managers.Perm.isStaff(playerID)
    end):forEach(function(player, playerID)
        local playerGroup = BJI.Managers.Perm.Groups[player.group] or { level = 0 }
        local isGroupLower = ctxt.group.level > playerGroup.level or BJI.DEBUG ~= nil

        local previousGroupName = BJI.Managers.Perm.getPreviousGroup(player.group)
        local previousGroup = BJI.Managers.Perm.Groups[previousGroupName]
        local showDemote = isGroupLower and previousGroup ~= nil
        local demoteGroup = showDemote and previousGroupName or nil
        local demoteLabel = showDemote and BJI.Managers.Lang.get("groups." .. demoteGroup, demoteGroup) or nil

        local nextGroupName = BJI.Managers.Perm.getNextGroup(player.group)
        local nextGroup = BJI.Managers.Perm.Groups[nextGroupName]
        local showPromote = isGroupLower and nextGroup ~= nil and nextGroup.level < ctxt.group.level
        local promoteGroup = showPromote and nextGroupName or nil
        local promoteLabel = showPromote and BJI.Managers.Lang.get("groups." .. promoteGroup, promoteGroup) or nil

        table.insert(cache.data.players.waiting, {
            playerID = playerID,
            playerName = player.playerName,
            grouplabel = string.var("({1})", { BJI.Managers.Lang.get("groups." .. player.group, player.group) }),
            demoteGroup = selfStaff and demoteGroup,
            demoteLabel = selfStaff and demoteLabel,
            promoteGroup = selfStaff and promoteGroup,
            promoteLabel = selfStaff and promoteLabel
        })
    end)

    cache.data.players.list = Table()
    table.filter(BJI.Managers.Context.Players, function(_, playerID)
        return BJI.Managers.Perm.canSpawnVehicle(playerID) or BJI.Managers.Perm.isStaff(playerID)
    end):forEach(function(p, playerID)
        local isSelf = BJI.Managers.Context.isSelf(playerID) and not BJI.DEBUG ~= nil
        local groupLabel = BJI.Managers.Lang.get(string.var("groups.{1}", { p.group }), p.group)
        local playerGroup = BJI.Managers.Perm.Groups[p.group] or { level = 0 }
        local isGroupLower = ctxt.group.level > playerGroup.level or BJI.DEBUG ~= nil
        local vehiclesCount = table.length(p.vehicles or {})
        local nameSuffix
        if selfStaff then
            nameSuffix = string.var("({1})", { groupLabel })
        else
            nameSuffix = BJI.Managers.Perm.isStaff(playerID) and
                string.var("({1})", { BJI.Managers.Lang.get("chat.staffTag") }) or
                string.var("({1} | {2}{3})", {
                    groupLabel,
                    BJI.Managers.Lang.get("chat.reputationTag"),
                    BJI.Managers.Reputation.getReputationLevel(p.reputation)
                })
        end

        local showDemote = isGroupLower and
            not table.includes({ BJI.CONSTANTS.GROUP_NAMES.NONE, BJI.CONSTANTS.GROUP_NAMES.OWNER }, p.group)
        local demoteGroup = showDemote and BJI.Managers.Perm.getPreviousGroup(p.group) or nil
        local demoteLabel = (showDemote and demoteGroup) and
            BJI.Managers.Lang.get("groups." .. demoteGroup, demoteGroup) or nil
        local showPromote = isGroupLower and
            BJI.Managers.Perm.getNextGroup(p.group) ~= BJI.CONSTANTS.GROUP_NAMES.OWNER
        local promoteGroup = showPromote and BJI.Managers.Perm.getNextGroup(p.group) or nil
        local promoteLabel = (showPromote and promoteGroup) and
            BJI.Managers.Lang.get("groups." .. promoteGroup, promoteGroup) or nil

        local vehicleCursor = "@ => "
        local vehiclesLabelWidth = 0
        if selfStaff and vehiclesCount > 0 then
            table.forEach(p.vehicles, function(veh)
                local w = BJI.Utils.UI.GetColumnTextWidth(string.var("{1} {2}", { vehicleCursor, veh.model }))
                if w > vehiclesLabelWidth then
                    vehiclesLabelWidth = w
                end
            end)
        end

        local vehicles = table.clone(p.vehicles or {}):map(function(v)
            v.isAI = Table(p.ai):includes(v.finalGameVehID)
            return v
        end)

        table.insert(cache.data.players.list, {
            playerID = playerID,
            self = isSelf,
            playerName = p.playerName,
            nameSuffix = nameSuffix,
            group = p.group,
            isGroupLower = isGroupLower,
            groupLabel = groupLabel,
            showModeration = selfStaff and isGroupLower,
            showVehicles = (isSelf or isGroupLower) and vehiclesCount > 0,
            vehiclesCount = vehiclesCount,
            currentVehicle = p.currentVehicle,
            vehicles = vehicles,
            vehicleCursor = vehicleCursor,
            vehiclesLabelWidth = vehiclesLabelWidth,
            demoteGroup = demoteGroup,
            demoteLabel = demoteLabel,
            promoteGroup = promoteGroup,
            promoteLabel = promoteLabel,
            freeze = p.freeze,
            engine = p.engine,
            muted = p.muted,
            muteReason = p.muteReason,
            kickReason = p.kickReason,
            banReason = p.banReason,
            tempBanDuration = p.tempBanDuration
        })

        cache.data.players.canBan = selfStaff and BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.BAN)
    end)
    if selfStaff and type(BJI.Managers.Context.BJC.TempBan) == "table" then
        cache.data.players.moderationInputs.tempBanDuration = math.clamp(
            cache.data.players.moderationInputs.tempBanDuration,
            BJI.Managers.Context.BJC.TempBan.minTime, BJI.Managers.Context.BJC.TempBan.maxTime
        )
    end

    table.forEach({ cache.data.players.waiting, cache.data.players.list }, function(players)
        table.sort(players, function(a, b)
            return a.playerName < b.playerName
        end)
    end)

    cache.widths.players.moderation.labels = 0
    if BJI.Managers.Perm.isStaff() then
        for _, k in ipairs({
            "moderationBlock.muteReason",
            "moderationBlock.kickReason",
            "moderationBlock.banReason",
            "moderationBlock.tempBanDuration",
        }) do
            local label = BJI.Managers.Lang.get(k)
            local w = BJI.Utils.UI.GetColumnTextWidth(label .. ":")
            if w > cache.widths.players.moderation.labels then
                cache.widths.players.moderation.labels = w
            end
        end
    end
    cache.widths.players.moderation.buttons = math.max(BJI.Utils.UI.GetBtnIconSize(),
        BJI.Utils.UI.GetColumnTextWidth(cache.labels.players.moderation.buttons.kick))
end

local listeners = Table()
local function onLoad()
    local ctxt = BJI.Managers.Tick.getContext()

    updateCache(ctxt)
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.VEHICLE_SPAWNED,
        BJI.Managers.Events.EVENTS.VEHICLE_REMOVED,
        BJI.Managers.Events.EVENTS.VEHICLE_SPEC_CHANGED,
        BJI.Managers.Events.EVENTS.VEHDATA_UPDATED,
        BJI.Managers.Events.EVENTS.SCENARIO_CHANGED,
        BJI.Managers.Events.EVENTS.STATION_PROXIMITY_CHANGED,
        BJI.Managers.Events.EVENTS.CACHE_LOADED,
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST
    }, function(ctxt2, data)
        if data._event ~= BJI.Managers.Events.EVENTS.CACHE_LOADED or
            table.includes({
                BJI.Managers.Cache.CACHES.GARAGES,
                BJI.Managers.Cache.CACHES.STATIONS
            }, data.cache) then
            updateCache(ctxt2)
        end
    end, cache.name .. "Cache"))

    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.VEHDATA_UPDATED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST
    }, updateLabels, cache.name .. "Labels"))

    deliveryLeaderboard.updateCache(ctxt)
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED,
        BJI.Managers.Events.EVENTS.CACHE_LOADED,
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST
    }, function(ctxt2, data)
        if data._event ~= BJI.Managers.Events.EVENTS.CACHE_LOADED or
            data.cache == BJI.Managers.Cache.CACHES.DELIVERIES then
            deliveryLeaderboard.updateCache(ctxt2)
        end
    end, cache.name .. "DeliveryLeaderboard"))

    updateCacheRaces()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.CACHE_LOADED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST
    }, function(ctxt2, data)
        if data._event ~= BJI.Managers.Events.EVENTS.CACHE_LOADED or
            data.cache == BJI.Managers.Cache.CACHES.RACES then
            updateCacheRaces()
        end
    end, cache.name .. "Races"))

    updateCachePlayers(ctxt)
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.PLAYER_CONNECT,
        BJI.Managers.Events.EVENTS.PLAYER_DISCONNECT,
        BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED,
        BJI.Managers.Events.EVENTS.VEHICLES_UPDATED,
        BJI.Managers.Events.EVENTS.CACHE_LOADED,
        BJI.Managers.Events.EVENTS.SCENARIO_CHANGED,
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST
    }, function(ctxt2, data)
        if data._event ~= BJI.Managers.Events.EVENTS.CACHE_LOADED or
            table.includes({
                BJI.Managers.Cache.CACHES.PLAYERS,
                BJI.Managers.Cache.CACHES.LANG
            }, data.cache) then
            updateCachePlayers(ctxt2)
        end
    end, cache.name .. "Players"))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
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
        LineBuilder()
            :btnSwitch({
                id = "toggleRacesLeaderboardWindow",
                labelOn = cache.labels.raceLeaderboard.title,
                labelOff = cache.labels.raceLeaderboard.title,
                state = not BJI.Windows.RacesLeaderboard.show,
                onClick = function()
                    BJI.Windows.RacesLeaderboard.show = not BJI.Windows.RacesLeaderboard.show
                end
            })
            :build()
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
