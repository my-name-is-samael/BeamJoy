local M = {
    cache = {
        label = "",
        elems = {},
    },
}

---@param ctxt TickContext
local function menuSoloRace(ctxt)
    if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_PLAYER_SCENARIO) and
        BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.RACE_SOLO) and
        BJI.Managers.Context.Scenario.Data.Races and
        BJI.Managers.Scenario.isFreeroam() and BJI.Managers.Perm.canSpawnVehicle() then
        local rawRaces = {}
        for _, race in ipairs(BJI.Managers.Context.Scenario.Data.Races) do
            if race.enabled then
                table.insert(rawRaces, race)
            end
        end

        local errorMessage = nil
        if #rawRaces == 0 then
            errorMessage = BJI.Managers.Lang.get("menu.scenario.soloRace.noRace")
        elseif not ctxt.isOwner or BJI.Managers.Veh.isUnicycle(ctxt.veh:getID()) then
            errorMessage = BJI.Managers.Lang.get("menu.scenario.soloRace.missingOwnVehicle")
        end

        if errorMessage then
            table.insert(M.cache.elems, {
                render = function()
                    LineBuilder()
                        :text(BJI.Managers.Lang.get("menu.scenario.soloRace.start"), BJI.Utils.Style.TEXT_COLORS
                            .DISABLED)
                        :text(string.var("({1})", { errorMessage }), BJI.Utils.Style.TEXT_COLORS.DISABLED)
                        :build()
                end
            })
        else
            local races = {}
            for _, race in ipairs(rawRaces) do
                local respawnStrategies = table.filter(BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES, function(rs)
                        return race.hasStand or rs.key ~= BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.STAND.key
                    end)
                    :sort(function(a, b) return a.order < b.order end)
                    :map(function(el) return el.key end)

                table.insert(races, {
                    label = race.name,
                    onClick = function()
                        BJI.Windows.RaceSettings.open({
                            multi = false,
                            raceID = race.id,
                            raceName = race.name,
                            loopable = race.loopable,
                            laps = 1,
                            defaultRespawnStrategy = BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.LAST_CHECKPOINT.key,
                            respawnStrategies = respawnStrategies,
                        })
                    end
                })
            end
            table.sort(races, function(a, b)
                return a.label < b.label
            end)
            table.insert(M.cache.elems, {
                label = BJI.Managers.Lang.get("menu.scenario.soloRace.start"),
                elems = races
            })
        end
    elseif BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.RACE_SOLO) and
        BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.RACE_SOLO).isRaceStarted() then
        table.insert(M.cache.elems, {
            label = BJI.Managers.Lang.get("menu.scenario.soloRace.stop"),
            onClick = function()
                BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.FREEROAM, ctxt)
            end,
        })
    end
end

---@param ctxt TickContext
local function menuVehicleDelivery(ctxt)
    if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_PLAYER_SCENARIO) and
        BJI.Managers.Scenario.isFreeroam() and
        BJI.Managers.Cache.isFirstLoaded(BJI.Managers.Cache.CACHES.DELIVERIES) then
        local errorMessage = nil
        if not BJI.Managers.Context.Scenario.Data.Deliveries or
            #BJI.Managers.Context.Scenario.Data.Deliveries < 2 then
            errorMessage = BJI.Managers.Lang.get("menu.scenario.vehicleDelivery.noDelivery")
        end

        if errorMessage then
            table.insert(M.cache.elems, {
                render = function()
                    LineBuilder()
                        :text(BJI.Managers.Lang.get("menu.scenario.vehicleDelivery.start"),
                            BJI.Utils.Style.TEXT_COLORS.DISABLED)
                        :text(string.var("({1})", { errorMessage }), BJI.Utils.Style.TEXT_COLORS.DISABLED)
                        :build()
                end
            })
        else
            table.insert(M.cache.elems, {
                label = BJI.Managers.Lang.get("menu.scenario.vehicleDelivery.start"),
                onClick = function()
                    BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.VEHICLE_DELIVERY).start()
                end,
            })
        end
    elseif BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.VEHICLE_DELIVERY) and
        BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.VEHICLE_DELIVERY) then
        table.insert(M.cache.elems, {
            label = BJI.Managers.Lang.get("menu.scenario.vehicleDelivery.stop"),
            onClick = BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.VEHICLE_DELIVERY).onStopDelivery,
        })
    end
end

---@param ctxt TickContext
local function menuPackageDelivery(ctxt)
    if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_PLAYER_SCENARIO) and
        BJI.Managers.Scenario.isFreeroam() and
        BJI.Managers.Cache.isFirstLoaded(BJI.Managers.Cache.CACHES.DELIVERIES) then
        local errorMessage = nil
        if not BJI.Managers.Context.Scenario.Data.Deliveries or
            #BJI.Managers.Context.Scenario.Data.Deliveries < 2 then
            errorMessage = BJI.Managers.Lang.get("menu.scenario.packageDelivery.noDelivery")
        elseif not ctxt.isOwner or BJI.Managers.Veh.isUnicycle(ctxt.veh:getID()) then
            errorMessage = BJI.Managers.Lang.get("menu.scenario.packageDelivery.missingOwnVehicle")
        end

        if errorMessage then
            table.insert(M.cache.elems, {
                render = function()
                    LineBuilder()
                        :text(BJI.Managers.Lang.get("menu.scenario.packageDelivery.start"),
                            BJI.Utils.Style.TEXT_COLORS.DISABLED)
                        :text(string.var("({1})", { errorMessage }), BJI.Utils.Style.TEXT_COLORS.DISABLED)
                        :build()
                end
            })
        else
            table.insert(M.cache.elems, {
                label = BJI.Managers.Lang.get("menu.scenario.packageDelivery.start"),
                onClick = function()
                    BJI.Managers.Async.delayTask(function()
                        BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.PACKAGE_DELIVERY, ctxt)
                    end, 0, "BJIPackageDeliveryStart")
                end,
            })
        end
    elseif BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.PACKAGE_DELIVERY) and
        BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.PACKAGE_DELIVERY) then
        table.insert(M.cache.elems, {
            label = BJI.Managers.Lang.get("menu.scenario.packageDelivery.stop"),
            onClick = BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.PACKAGE_DELIVERY).onStopDelivery,
        })
    end
end

---@param ctxt TickContext
local function menuDeliveryMulti(ctxt)
    if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_PLAYER_SCENARIO) and
        BJI.Managers.Scenario.isFreeroam() then
        local errorMessage = nil
        if not BJI.Managers.Context.Scenario.Data.Deliveries or
            #BJI.Managers.Context.Scenario.Data.Deliveries < 2 then
            errorMessage = BJI.Managers.Lang.get("menu.scenario.deliveryMulti.noDelivery")
        elseif not ctxt.isOwner or BJI.Managers.Veh.isUnicycle(ctxt.veh:getID()) then
            errorMessage = BJI.Managers.Lang.get("menu.scenario.deliveryMulti.missingOwnVehicle")
        end

        if errorMessage then
            table.insert(M.cache.elems, {
                render = function()
                    LineBuilder()
                        :text(BJI.Managers.Lang.get("menu.scenario.deliveryMulti.join"),
                            BJI.Utils.Style.TEXT_COLORS.DISABLED)
                        :text(string.var("({1})", { errorMessage }), BJI.Utils.Style.TEXT_COLORS.DISABLED)
                        :build()
                end
            })
        else
            table.insert(M.cache.elems, {
                label = BJI.Managers.Lang.get("menu.scenario.deliveryMulti.join"),
                onClick = function()
                    BJI.Tx.scenario.DeliveryMultiJoin(ctxt.veh:getID(), ctxt.vehPosRot.pos)
                end,
            })
        end
    elseif BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.DELIVERY_MULTI) and
        BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.DELIVERY_MULTI) then
        table.insert(M.cache.elems, {
            label = BJI.Managers.Lang.get("menu.scenario.deliveryMulti.leave"),
            onClick = function()
                BJI.Tx.scenario.DeliveryMultiLeave()
            end,
        })
    end
end

-- later update TODO
---@param ctxt TickContext
local function menuTagDuo(ctxt)
    if BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.TAG_DUO) then
        if BJI.Managers.Scenario.isFreeroam() and
            BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.TAG_DUO).canChangeTo(ctxt) then
            local lobbies = {}
            table.insert(lobbies, {
                label = "Create a lobby",
                onClick = function()
                    BJI.Tx.scenario.TagDuoJoin(nil, ctxt.veh:getID())
                end,
            })
            for i, l in ipairs(BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.TAG_DUO).lobbies) do
                if table.length(l.players) < 2 then
                    table.insert(lobbies, {
                        label = string.var("Join {1}'s lobby", { BJI.Managers.Context.Players[l.host].playerName }),
                        onClick = function()
                            BJI.Tx.scenario.TagDuoJoin(i, ctxt.veh:getID())
                        end,
                    })
                end
            end
            table.insert(M.cache.elems, {
                label = "Tag Duo",
                elems = lobbies,
            })
        elseif BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.TAG_DUO) then
            table.insert(M.cache.elems, {
                label = "Stop Tag Duo",
                onClick = function()
                    BJI.Tx.scenario.TagDuoLeave()
                end,
            })
        end
    end
end

---@param ctxt TickContext
local function menuBusMission(ctxt)
    if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_PLAYER_SCENARIO) and
        BJI.Managers.Scenario.isFreeroam() and
        BJI.Managers.Cache.isFirstLoaded(BJI.Managers.Cache.CACHES.BUS_LINES) then
        local errorMessage = nil
        if not BJI.Managers.Context.Scenario.Data.BusLines or
            #BJI.Managers.Context.Scenario.Data.BusLines == 0 then
            errorMessage = BJI.Managers.Lang.get("menu.scenario.busMission.noBusMission")
        end

        if errorMessage then
            table.insert(M.cache.elems, {
                render = function()
                    LineBuilder()
                        :text(BJI.Managers.Lang.get("menu.scenario.busMission.start"),
                            BJI.Utils.Style.TEXT_COLORS.DISABLED)
                        :text(string.var("({1})", { errorMessage }), BJI.Utils.Style.TEXT_COLORS.DISABLED)
                        :build()
                end
            })
        else
            table.insert(M.cache.elems, {
                label = BJI.Managers.Lang.get("menu.scenario.busMission.start"),
                onClick = function()
                    BJI.Windows.BusMissionPreparation.show = true
                end,
            })
        end
    elseif BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.BUS_MISSION) and
        BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.BUS_MISSION) then
        table.insert(M.cache.elems, {
            label = BJI.Managers.Lang.get("menu.scenario.busMission.stop"),
            onClick = BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.BUS_MISSION).onStopBusMission,
        })
    end
end

---@param ctxt TickContext
local function menuSpeedGame(ctxt)
    if not BJI.Managers.Scenario.isServerScenarioInProgress() and
        BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_SERVER_SCENARIO) then
        local potentialPlayers = BJI.Managers.Perm.getCountPlayersCanSpawnVehicle()
        local minimumParticipants = BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.SPEED).MINIMUM_PARTICIPANTS
        local errorMessage = nil
        if potentialPlayers < minimumParticipants then
            errorMessage = BJI.Managers.Lang.get("menu.scenario.speed.missingPlayers"):var({
                amount = minimumParticipants - potentialPlayers
            })
        end

        if errorMessage then
            table.insert(M.cache.elems, {
                render = function()
                    LineBuilder()
                        :text(BJI.Managers.Lang.get("menu.scenario.speed.start"), BJI.Utils.Style.TEXT_COLORS.DISABLED)
                        :text(string.var("({1})", { errorMessage }), BJI.Utils.Style.TEXT_COLORS.DISABLED)
                        :build()
                end
            })
        else
            table.insert(M.cache.elems, {
                label = BJI.Managers.Lang.get("menu.scenario.speed.start"),
                onClick = function()
                    BJI.Tx.scenario.SpeedStart(false)
                end,
            })
        end
    elseif BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_SERVER_SCENARIO) and
        BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.SPEED) then
        table.insert(M.cache.elems, {
            label = BJI.Managers.Lang.get("menu.scenario.speed.stop"),
            onClick = BJI.Tx.scenario.SpeedStop,
        })
    end
end

---@param ctxt TickContext
local function menuHunter(ctxt)
    if not BJI.Managers.Scenario.isServerScenarioInProgress() and
        BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_SERVER_SCENARIO) and
        BJI.Managers.Context.Scenario.Data.Hunter then
        local potentialPlayers = BJI.Managers.Perm.getCountPlayersCanSpawnVehicle()
        local minimumParticipants = BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.HUNTER).MINIMUM_PARTICIPANTS
        local errorMessage = nil
        if not BJI.Managers.Context.Scenario.Data.Hunter or
            not BJI.Managers.Context.Scenario.Data.Hunter.enabled then
            errorMessage = BJI.Managers.Lang.get("menu.scenario.hunter.modeDisabled")
        elseif potentialPlayers < minimumParticipants then
            errorMessage = BJI.Managers.Lang.get("menu.scenario.hunter.missingPlayers"):var({
                amount = minimumParticipants - potentialPlayers
            })
        end

        if errorMessage then
            table.insert(M.cache.elems, {
                render = function()
                    LineBuilder()
                        :text(BJI.Managers.Lang.get("menu.scenario.hunter.start"), BJI.Utils.Style.TEXT_COLORS.DISABLED)
                        :text(string.var("({1})", { errorMessage }), BJI.Utils.Style.TEXT_COLORS.DISABLED)
                        :build()
                end
            })
        else
            table.insert(M.cache.elems, {
                label = BJI.Managers.Lang.get("menu.scenario.hunter.start"),
                active = BJI.Windows.HunterSettings.show,
                onClick = function()
                    if BJI.Windows.HunterSettings.show then
                        BJI.Windows.HunterSettings.onClose()
                    else
                        BJI.Windows.HunterSettings.open()
                    end
                end,
            })
        end
    elseif BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_SERVER_SCENARIO) and
        BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.HUNTER) then
        table.insert(M.cache.elems, {
            label = BJI.Managers.Lang.get("menu.scenario.hunter.stop"),
            onClick = BJI.Tx.scenario.HunterStop,
        })
    end
end

---@param ctxt TickContext
local function menuDerby(ctxt)
    if not BJI.Managers.Scenario.isServerScenarioInProgress() and
        BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_SERVER_SCENARIO) and
        BJI.Managers.Context.Scenario.Data.Derby then
        local potentialPlayers = BJI.Managers.Perm.getCountPlayersCanSpawnVehicle()
        local minimumParticipants = BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.DERBY).MINIMUM_PARTICIPANTS
        local errorMessage = nil
        local countArena = #Table(BJI.Managers.Context.Scenario.Data.Derby)
            :filter(function(arena) return arena.enabled end)
        if countArena == 0 then
            errorMessage = BJI.Managers.Lang.get("menu.scenario.derby.noArena")
        elseif potentialPlayers < minimumParticipants then
            errorMessage = BJI.Managers.Lang.get("menu.scenario.derby.missingPlayers"):var({
                amount = minimumParticipants - potentialPlayers
            })
        end

        if errorMessage then
            table.insert(M.cache.elems, {
                render = function()
                    LineBuilder()
                        :text(BJI.Managers.Lang.get("menu.scenario.derby.start"), BJI.Utils.Style.TEXT_COLORS.DISABLED)
                        :text(string.var("({1})", { errorMessage }), BJI.Utils.Style.TEXT_COLORS.DISABLED)
                        :build()
                end
            })
        else
            local arenas = {}
            for i, arena in ipairs(BJI.Managers.Context.Scenario.Data.Derby) do
                if arena.enabled then
                    table.insert(arenas, {
                        label = string.var("{1} ({2})", {
                            arena.name,
                            BJI.Managers.Lang.get("derby.settings.places")
                                :var({ places = #arena.startPositions }),
                        }),
                        onClick = function()
                            BJI.Managers.Context.Scenario.DerbyEdit = nil
                            BJI.Windows.DerbySettings.open(i)
                        end
                    })
                end
            end
            table.sort(arenas, function(a, b)
                return a.label < b.label
            end)
            table.insert(M.cache.elems, {
                label = BJI.Managers.Lang.get("menu.scenario.derby.start"),
                elems = arenas
            })
        end
    elseif BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_SERVER_SCENARIO) and
        BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.DERBY) then
        table.insert(M.cache.elems, {
            label = BJI.Managers.Lang.get("menu.scenario.derby.stop"),
            onClick = BJI.Tx.scenario.DerbyStop,
        })
    end
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI.Managers.Tick.getContext()
    M.cache = {
        label = BJI.Managers.Lang.get("menu.scenario.title"),
        elems = {},
    }

    if not BJI.Windows.ScenarioEditor.getState() then
        menuSoloRace(ctxt)
        menuVehicleDelivery(ctxt)
        menuPackageDelivery(ctxt)
        menuDeliveryMulti(ctxt)
        --menuTagDuo(ctxt)
        menuBusMission(ctxt)
        menuSpeedGame(ctxt)
        menuHunter(ctxt)
        menuDerby(ctxt)
    end

    -- STOP MULTI RACE
    if BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.RACE_MULTI) and
        (BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_SERVER_SCENARIO) or
            BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SCENARIO)) then
        table.insert(M.cache.elems, {
            label = BJI.Managers.Lang.get("menu.scenario.raceStop"),
            onClick = BJI.Tx.scenario.RaceMultiStop,
        })
    end
end

local listeners = Table()
function M.onLoad()
    updateCache()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.PLAYER_CONNECT,
        BJI.Managers.Events.EVENTS.PLAYER_DISCONNECT,
        BJI.Managers.Events.EVENTS.VEHICLE_SPAWNED,
        BJI.Managers.Events.EVENTS.VEHICLE_REMOVED,
        BJI.Managers.Events.EVENTS.VEHICLE_SPEC_CHANGED,
        BJI.Managers.Events.EVENTS.SCENARIO_CHANGED,
        BJI.Managers.Events.EVENTS.SCENARIO_UPDATED,
        BJI.Managers.Events.EVENTS.SCENARIO_EDITOR_UPDATED,
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST
    }, updateCache))

    ---@param data {cache: string}
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.CACHE_LOADED, function(ctxt, data)
        if table.includes({
                BJI.Managers.Cache.CACHES.RACES,
                BJI.Managers.Cache.CACHES.DELIVERIES,
                BJI.Managers.Cache.CACHES.BUS_LINES,
                BJI.Managers.Cache.CACHES.HUNTER_DATA,
                BJI.Managers.Cache.CACHES.HUNTER,
                BJI.Managers.Cache.CACHES.DERBY_DATA,
                BJI.Managers.Cache.CACHES.DERBY,
            }, data.cache) then
            updateCache(ctxt)
        end
    end))
end

function M.onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

return M
