local energyIndicator = require("ge/extensions/BJI/ui/windows/Main/Body/VehicleEnergyIndicator")
local healthIndicator = require("ge/extensions/BJI/ui/windows/Main/Body/VehicleHealthIndicator")
local deliveryLeaderboard = require("ge/extensions/BJI/ui/windows/Main/Body/DeliveryLeaderBoard")

local cache = {
    name = "MainBody",

    data = {
        showVehEnergy = false,
        showVehDamages = false,
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
}
-- gc prevention
local needSpace, needSeparator, showHealthIndicator

local function updateCacheRaces()
    cache.data.raceLeaderboard.show = table.some({
            BJI_Scenario.TYPES.FREEROAM,
            BJI_Scenario.TYPES.RACE_SOLO,
            BJI_Scenario.TYPES.RACE_MULTI,
        }, function(type) return BJI_Scenario.is(type) end) and
        BJI_Context.Scenario.Data.Races and
        #BJI_Context.Scenario.Data.Races > 0

    if cache.data.raceLeaderboard.show and
        #table.filter(BJI_Context.Scenario.Data.Races, function(race) return race.record end):values() == 0 then
        cache.data.raceLeaderboard.show = false
    end
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI_Tick.getContext()

    cache.data.showVehEnergy = ctxt.isOwner and
        BJI_Scenario.canRefuelAtStation() and
        BJI_Context.Scenario.Data.EnergyStations
    cache.data.showVehDamages = ctxt.isOwner and
        BJI_Scenario.canRepairAtGarage() and
        BJI_Context.Scenario.Data.Garages
    cache.data.showDeliveryLeaderboard = table.some({
            BJI_Scenario.TYPES.FREEROAM,
            BJI_Scenario.TYPES.VEHICLE_DELIVERY,
            BJI_Scenario.TYPES.PACKAGE_DELIVERY,
            BJI_Scenario.TYPES.DELIVERY_MULTI,
        }, function(type) return BJI_Scenario.is(type) end) and
        BJI_Context.Scenario.Data.Deliveries and
        BJI_Context.Scenario.Data.DeliveryLeaderboard and
        #BJI_Context.Scenario.Data.DeliveryLeaderboard > 0

    cache.data.scenarioUIFn = BJI_Scenario.getUIRenderFn()

    if BJI_Perm.isStaff() then
        cache.data.playersFn = require("ge/extensions/BJI/ui/windows/Main/Body/Moderation")
    else
        cache.data.playersFn = require("ge/extensions/BJI/ui/windows/Main/Body/Players")
    end

    energyIndicator.updateCache(ctxt)
    healthIndicator.updateCache(ctxt)
end

local function updateLabels()
    cache.labels.loading = BJI_Lang.get("common.loading")

    cache.labels.raceLeaderboard.title = BJI_Lang.get("races.leaderboard.title")

    -- PLAYERS LIST
    cache.labels.players.moderation.waiting = BJI_Lang.get("moderationBlock.waitingPlayers") .. " :"
    cache.labels.players.moderation.list = BJI_Lang.get("moderationBlock.players") .. " :"
    cache.labels.players.moderation.muteReason = BJI_Lang.get("moderationBlock.muteReason")
    cache.labels.players.moderation.kickReason = BJI_Lang.get("moderationBlock.kickReason")
    cache.labels.players.moderation.banReason = BJI_Lang.get("moderationBlock.banReason")
    cache.labels.players.moderation.savedReason = BJI_Lang.get("moderationBlock.savedReason")
    cache.labels.players.moderation.tempBanDuration = BJI_Lang.get("moderationBlock.tempBanDuration")
    cache.labels.players.moderation.vehicles = BJI_Lang.get("moderationBlock.vehicles")
    cache.labels.players.moderation.buttons.kick = BJI_Lang.get("moderationBlock.buttons.kick")
    cache.labels.players.moderation.buttons.ban = BJI_Lang.get("moderationBlock.buttons.ban")
    cache.labels.players.moderation.buttons.tempban = BJI_Lang.get("moderationBlock.buttons.tempBan")
    cache.labels.players.moderation.buttons.show = BJI_Lang.get("common.buttons.show")
    cache.labels.players.moderation.buttons.freeze = BJI_Lang.get("moderationBlock.buttons.freeze")
    cache.labels.players.moderation.buttons.engine = BJI_Lang.get("moderationBlock.buttons.engine")
    cache.labels.players.moderation.buttons.delete = BJI_Lang.get("common.buttons.delete")
    cache.labels.players.moderation.buttons.explode = BJI_Lang.get("common.buttons.explode")
    cache.labels.players.moderation.buttons.mute = BJI_Lang.get("moderationBlock.buttons.mute")
    cache.labels.players.moderation.buttons.deleteAllVehicles = BJI_Lang.get(
        "moderationBlock.buttons.deleteAllVehicles")
    cache.labels.players.moderation.buttons.promoteTo = BJI_Lang.get("moderationBlock.buttons.promoteTo")
    cache.labels.players.moderation.buttons.demoteTo = BJI_Lang.get("moderationBlock.buttons.demoteTo")
    cache.labels.players.waiting = BJI_Lang.get("playersBlock.waitingPlayers")
    cache.labels.players.list = BJI_Lang.get("playersBlock.players") .. " :"
end

---@param ctxt TickContext
local function updateCachePlayers(ctxt)
    local selfStaff = BJI_Perm.isStaff()

    cache.data.players.waiting = Table()
    ctxt.players:filter(function(_, playerID)
        return not BJI_Perm.canSpawnVehicle(playerID) and not BJI_Perm.isStaff(playerID)
    end):forEach(function(player, playerID)
        local playerGroup = BJI_Perm.Groups[player.group] or { level = 0 }
        local isGroupLower = ctxt.group.level > playerGroup.level or BJI.DEBUG ~= nil

        local previousGroupName = BJI_Perm.getPreviousGroup(player.group)
        local previousGroup = BJI_Perm.Groups[previousGroupName]
        local showDemote = isGroupLower and previousGroup ~= nil
        local demoteGroup = showDemote and previousGroupName or nil
        local demoteLabel = showDemote and BJI_Lang.get("groups." .. demoteGroup, demoteGroup) or nil

        local nextGroupName = BJI_Perm.getNextGroup(player.group)
        local nextGroup = BJI_Perm.Groups[nextGroupName]
        local showPromote = isGroupLower and nextGroup ~= nil and nextGroup.level < ctxt.group.level
        local promoteGroup = showPromote and nextGroupName or nil
        local promoteLabel = showPromote and BJI_Lang.get("groups." .. promoteGroup, promoteGroup) or nil

        table.insert(cache.data.players.waiting, {
            playerID = playerID,
            playerName = player.playerName,
            grouplabel = string.var("({1})", { BJI_Lang.get("groups." .. player.group, player.group) }),
            demoteGroup = selfStaff and demoteGroup,
            demoteLabel = selfStaff and demoteLabel,
            promoteGroup = selfStaff and promoteGroup,
            promoteLabel = selfStaff and promoteLabel
        })
    end)

    cache.data.players.list = Table()
    ctxt.players:filter(function(_, playerID)
        return BJI_Perm.canSpawnVehicle(playerID) or BJI_Perm.isStaff(playerID)
    end):forEach(function(p, playerID)
        local isSelf = BJI_Context.isSelf(playerID) and not BJI.DEBUG ~= nil
        local groupLabel = BJI_Lang.get(string.var("groups.{1}", { p.group }), p.group)
        local playerGroup = BJI_Perm.Groups[p.group] or { level = 0 }
        local isGroupLower = ctxt.group.level > playerGroup.level or BJI.DEBUG ~= nil
        local vehiclesCount = table.length(p.vehicles or {})
        local nameSuffix
        if selfStaff then
            nameSuffix = string.var("({1})", { groupLabel })
        else
            nameSuffix = BJI_Perm.isStaff(playerID) and
                string.var("({1})", { BJI_Lang.get("chat.staffTag") }) or
                string.var("({1} | {2}{3})", {
                    groupLabel,
                    BJI_Lang.get("chat.reputationTag"),
                    BJI_Reputation.getReputationLevel(p.reputation)
                })
        end

        local showDemote = isGroupLower and
            not table.includes({ BJI.CONSTANTS.GROUP_NAMES.NONE, BJI.CONSTANTS.GROUP_NAMES.OWNER }, p.group)
        local demoteGroup = showDemote and BJI_Perm.getPreviousGroup(p.group) or nil
        local demoteLabel = (showDemote and demoteGroup) and
            BJI_Lang.get("groups." .. demoteGroup, demoteGroup) or nil
        local showPromote = isGroupLower and
            BJI_Perm.getNextGroup(p.group) ~= BJI.CONSTANTS.GROUP_NAMES.OWNER
        local promoteGroup = showPromote and BJI_Perm.getNextGroup(p.group) or nil
        local promoteLabel = (showPromote and promoteGroup) and
            BJI_Lang.get("groups." .. promoteGroup, promoteGroup) or nil

        local vehicleCursor = "@ => "

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
            vehicles = table.clone(p.vehicles or {}),
            vehicleCursor = vehicleCursor,
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

        cache.data.players.canBan = selfStaff and BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.BAN)
    end)
    if selfStaff and type(BJI_Context.BJC.TempBan) == "table" then
        cache.data.players.moderationInputs.tempBanDuration = math.clamp(
            cache.data.players.moderationInputs.tempBanDuration,
            BJI_Context.BJC.TempBan.minTime, BJI_Context.BJC.TempBan.maxTime
        )
    end

    table.forEach({ cache.data.players.waiting, cache.data.players.list }, function(players)
        table.sort(players, function(a, b)
            return a.playerName < b.playerName
        end)
    end)
end

local listeners = Table()
local function onLoad()
    local ctxt = BJI_Tick.getContext()

    updateCache(ctxt)
    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.VEHICLE_SPAWNED,
        BJI_Events.EVENTS.VEHICLE_REMOVED,
        BJI_Events.EVENTS.VEHICLE_SPEC_CHANGED,
        BJI_Events.EVENTS.VEHDATA_UPDATED,
        BJI_Events.EVENTS.SCENARIO_CHANGED,
        BJI_Events.EVENTS.SCENARIO_UPDATED,
        BJI_Events.EVENTS.STATION_PROXIMITY_CHANGED,
        BJI_Events.EVENTS.CACHE_LOADED,
        BJI_Events.EVENTS.PERMISSION_CHANGED,
        BJI_Events.EVENTS.LANG_CHANGED,
        BJI_Events.EVENTS.UI_UPDATE_REQUEST
    }, function(ctxt2, data)
        if data._event ~= BJI_Events.EVENTS.CACHE_LOADED or
            table.includes({
                BJI_Cache.CACHES.GARAGES,
                BJI_Cache.CACHES.STATIONS
            }, data.cache) then
            updateCache(ctxt2)
        end
    end, cache.name .. "Cache"))

    updateLabels()
    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.LANG_CHANGED,
        BJI_Events.EVENTS.VEHDATA_UPDATED,
        BJI_Events.EVENTS.UI_UPDATE_REQUEST
    }, updateLabels, cache.name .. "Labels"))

    updateCacheRaces()
    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.CACHE_LOADED,
        BJI_Events.EVENTS.SCENARIO_CHANGED,
        BJI_Events.EVENTS.UI_UPDATE_REQUEST
    }, function(ctxt2, data)
        if data._event ~= BJI_Events.EVENTS.CACHE_LOADED or
            data.cache == BJI_Cache.CACHES.RACES then
            updateCacheRaces()
        end
    end, cache.name .. "Races"))

    updateCachePlayers(ctxt)
    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.PLAYER_CONNECT,
        BJI_Events.EVENTS.PLAYER_DISCONNECT,
        BJI_Events.EVENTS.UI_SCALE_CHANGED,
        BJI_Events.EVENTS.VEHICLES_UPDATED,
        BJI_Events.EVENTS.CACHE_LOADED,
        BJI_Events.EVENTS.SCENARIO_CHANGED,
        BJI_Events.EVENTS.PERMISSION_CHANGED,
        BJI_Events.EVENTS.LANG_CHANGED,
        BJI_Events.EVENTS.UI_UPDATE_REQUEST
    }, function(ctxt2, data)
        if data._event ~= BJI_Events.EVENTS.CACHE_LOADED or
            table.includes({
                BJI_Cache.CACHES.PLAYERS,
                BJI_Cache.CACHES.LANG
            }, data.cache) then
            updateCachePlayers(ctxt2)
        end
    end, cache.name .. "Players"))
end

local function onUnload()
    listeners:forEach(BJI_Events.removeListener)
end

local function Delim()
    if needSeparator then
        Separator()
    end
    if needSpace then
        EmptyLine()
    end
end

local function showRacesLeaderboardButton()
    if Button("toggleRacesLeaderboardWindow", cache.labels.raceLeaderboard.title,
            { btnStyle = BJI_Win_RacesLeaderboard.show and BJI.Utils.Style.BTN_PRESETS.ERROR or
                BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
        BJI_Win_RacesLeaderboard.show = not BJI_Win_RacesLeaderboard.show
    end
end

local function draw(ctxt)
    needSpace, needSeparator = false, false

    showHealthIndicator = cache.data.showVehDamages and healthIndicator.isVisible(ctxt)
    if cache.data.showVehEnergy or showHealthIndicator then
        if cache.data.showVehEnergy then
            energyIndicator.draw(ctxt)
            Separator()
        end
        if showHealthIndicator then
            healthIndicator.draw(ctxt)
            Separator()
        end
        needSpace, needSeparator = true, false
    end

    if cache.data.showDeliveryLeaderboard or cache.data.raceLeaderboard.show then
        Delim()
        if cache.data.showDeliveryLeaderboard then
            deliveryLeaderboard.draw(ctxt, cache.data.raceLeaderboard.show and
                showRacesLeaderboardButton or nil)
        elseif cache.data.raceLeaderboard.show then
            showRacesLeaderboardButton()
        end

        needSpace, needSeparator = true, false
    end

    if type(cache.data.scenarioUIFn) == "function" then
        Delim()
        cache.data.scenarioUIFn(ctxt)
        needSpace, needSeparator = true, true
    end

    if type(cache.data.playersFn) == "function" then
        Delim()
        cache.data.playersFn(ctxt, cache)
        needSpace, needSeparator = true, true
    end
end

return {
    onLoad = onLoad,
    onUnload = onUnload,
    draw = draw,
}
