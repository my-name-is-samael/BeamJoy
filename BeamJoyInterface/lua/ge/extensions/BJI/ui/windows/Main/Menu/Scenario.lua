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
        local rawRaces = Table(BJI.Managers.Context.Scenario.Data.Races)
            :filter(function(race) return race.enabled end)

        local errorMessage = nil
        if #rawRaces == 0 then
            errorMessage = BJI.Managers.Lang.get("menu.scenario.soloRace.noRace")
        elseif not ctxt.isOwner or ctxt.veh.jbeam == "unicycle" then
            errorMessage = BJI.Managers.Lang.get("errors.missingOwnVehicle")
        elseif ctxt.veh.isAi then
            errorMessage = BJI.Managers.Lang.get("error.cannotStartWodeWithAI")
        end

        if errorMessage then
            table.insert(M.cache.elems, {
                render = function()
                    LineLabel(BJI.Managers.Lang.get("menu.scenario.soloRace.start"),
                        BJI.Utils.Style.TEXT_COLORS.DISABLED, false, errorMessage)
                end
            })
        else
            local respawnStrategies = Table(BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES)
                :sort(function(a, b) return a.order < b.order end)
                :map(function(el) return el.key end)

            if #rawRaces <= BJI.Windows.Selection.LIMIT_ELEMS_THRESHOLD then
                -- sub elems
                table.insert(M.cache.elems, {
                    label = BJI.Managers.Lang.get("menu.scenario.soloRace.start"),
                    elems = rawRaces:map(function(race)
                        return {
                            label = race.name,
                            onClick = function()
                                BJI.Windows.RaceSettings.open({
                                    multi = false,
                                    raceID = race.id,
                                    raceName = race.name,
                                    loopable = race.loopable,
                                    laps = 1,
                                    defaultRespawnStrategy = BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.LAST_CHECKPOINT.key,
                                    respawnStrategies = respawnStrategies:filter(function(rs)
                                        return race.hasStand or
                                            rs ~= BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.STAND.key
                                    end),
                                })
                            end
                        }
                    end):sort(function(a, b) return a.label < b.label end)
                })
            else
                -- selection window
                table.insert(M.cache.elems, {
                    label = BJI.Managers.Lang.get("menu.scenario.soloRace.start"),
                    onClick = function()
                        BJI.Windows.Selection.open("menu.vote.race.title", rawRaces
                            :map(function(race)
                                return { label = race.name, value = race.id }
                            end):sort(function(a, b) return a.label < b.label end) or Table(), nil,
                            function(raceID)
                                rawRaces:find(function(r) return r.id == raceID end,
                                    function(race)
                                        BJI.Windows.RaceSettings.open({
                                            multi = false,
                                            raceID = race.id,
                                            raceName = race.name,
                                            loopable = race.loopable,
                                            laps = 1,
                                            defaultRespawnStrategy = BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES
                                                .LAST_CHECKPOINT.key,
                                            respawnStrategies = respawnStrategies:filter(function(rs)
                                                return race.hasStand or
                                                    rs ~= BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.STAND.key
                                            end),
                                        })
                                    end)
                            end)
                    end,
                })
            end
        end
    elseif BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.RACE_SOLO) then
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
                    LineLabel(BJI.Managers.Lang.get("menu.scenario.vehicleDelivery.start"),
                        BJI.Utils.Style.TEXT_COLORS.DISABLED, false, errorMessage)
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
        elseif not ctxt.isOwner or ctxt.veh.jbeam == "unicycle" then
            errorMessage = BJI.Managers.Lang.get("errors.missingOwnVehicle")
        elseif ctxt.veh.isAi then
            errorMessage = BJI.Managers.Lang.get("error.cannotStartWodeWithAI")
        end

        if errorMessage then
            table.insert(M.cache.elems, {
                render = function()
                    LineLabel(BJI.Managers.Lang.get("menu.scenario.packageDelivery.start"),
                        BJI.Utils.Style.TEXT_COLORS.DISABLED, false, errorMessage)
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
        elseif not ctxt.isOwner or ctxt.veh.jbeam == "unicycle" then
            errorMessage = BJI.Managers.Lang.get("errors.missingOwnVehicle")
        elseif ctxt.veh.isAi then
            errorMessage = BJI.Managers.Lang.get("error.cannotStartWodeWithAI")
        end

        if errorMessage then
            table.insert(M.cache.elems, {
                render = function()
                    LineLabel(BJI.Managers.Lang.get("menu.scenario.deliveryMulti.join"),
                        BJI.Utils.Style.TEXT_COLORS.DISABLED, false, errorMessage)
                end
            })
        else
            table.insert(M.cache.elems, {
                label = BJI.Managers.Lang.get("menu.scenario.deliveryMulti.join"),
                onClick = function()
                    BJI.Tx.scenario.DeliveryMultiJoin(ctxt.veh.gameVehicleID, ctxt.veh.position)
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
    if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_PLAYER_SCENARIO) and
        BJI.Managers.Scenario.isFreeroam() then
        local errorMessage
        if not ctxt.isOwner or ctxt.veh.jbeam == "unicycle" then
            errorMessage = BJI.Managers.Lang.get("errors.missingOwnVehicle")
        elseif ctxt.veh.isAi then
            errorMessage = BJI.Managers.Lang.get("error.cannotStartWodeWithAI")
        end

        if errorMessage then
            table.insert(M.cache.elems, {
                render = function()
                    LineLabel(BJI.Managers.Lang.get("menu.scenario.tagduo.join"),
                        BJI.Utils.Style.TEXT_COLORS.DISABLED, false, errorMessage)
                end
            })
        else
            local lobbyEntries = {}
            table.insert(lobbyEntries, {
                label = BJI.Managers.Lang.get("menu.scenario.tagduo.createLobby"),
                onClick = function()
                    BJI.Tx.scenario.TagDuoJoin(-1, ctxt.veh.gameVehicleID)
                end,
            })
            for i, l in ipairs(BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.TAG_DUO).lobbies) do
                if table.length(l.players) < 2 then
                    table.insert(lobbyEntries, {
                        label = string.var(BJI.Managers.Lang.get("menu.scenario.tagduo.joinLobby"),
                            { playerName = ctxt.players[l.host].playerName }),
                        onClick = function()
                            BJI.Tx.scenario.TagDuoJoin(i, ctxt.veh.gameVehicleID)
                        end,
                    })
                end
            end
            table.insert(M.cache.elems, {
                label = BJI.Managers.Lang.get("menu.scenario.tagduo.join"),
                elems = lobbyEntries,
            })
        end
    elseif BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.TAG_DUO) then
        table.insert(M.cache.elems, {
            label = BJI.Managers.Lang.get("menu.scenario.tagduo.leave"),
            onClick = function()
                BJI.Tx.scenario.TagDuoLeave()
            end,
        })
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
                    LineLabel(BJI.Managers.Lang.get("menu.scenario.busMission.start"),
                        BJI.Utils.Style.TEXT_COLORS.DISABLED, false, errorMessage)
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
            errorMessage = BJI.Managers.Lang.get("errors.missingPlayers"):var({
                amount = minimumParticipants - potentialPlayers
            })
        end

        if errorMessage then
            table.insert(M.cache.elems, {
                render = function()
                    LineLabel(BJI.Managers.Lang.get("menu.scenario.speed.start"),
                        BJI.Utils.Style.TEXT_COLORS.DISABLED, false, errorMessage)
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
            errorMessage = BJI.Managers.Lang.get("errors.missingPlayers"):var({
                amount = minimumParticipants - potentialPlayers
            })
        end

        if errorMessage then
            table.insert(M.cache.elems, {
                render = function()
                    LineLabel(BJI.Managers.Lang.get("menu.scenario.hunter.start"),
                        BJI.Utils.Style.TEXT_COLORS.DISABLED, false, errorMessage)
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
    end
end

---@param ctxt TickContext
local function menuDerby(ctxt)
    if not BJI.Managers.Scenario.isServerScenarioInProgress() and
        BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_SERVER_SCENARIO) and
        BJI.Managers.Context.Scenario.Data.Derby then
        local rawArenas = Table(BJI.Managers.Context.Scenario.Data.Derby)
            :filter(function(arena) return arena.enabled end)

        local potentialPlayers = BJI.Managers.Perm.getCountPlayersCanSpawnVehicle()
        local minimumParticipants = BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.DERBY).MINIMUM_PARTICIPANTS
        local errorMessage = nil
        if #rawArenas == 0 then
            errorMessage = BJI.Managers.Lang.get("menu.scenario.derby.noArena")
        elseif potentialPlayers < minimumParticipants then
            errorMessage = BJI.Managers.Lang.get("errors.missingPlayers"):var({
                amount = minimumParticipants - potentialPlayers
            })
        end

        if errorMessage then
            table.insert(M.cache.elems, {
                render = function()
                    LineLabel(BJI.Managers.Lang.get("menu.scenario.derby.start"),
                        BJI.Utils.Style.TEXT_COLORS.DISABLED, false, errorMessage)
                end
            })
        else
            if #rawArenas <= BJI.Windows.Selection.LIMIT_ELEMS_THRESHOLD then
                -- sub elems
                table.insert(M.cache.elems, {
                    label = BJI.Managers.Lang.get("menu.scenario.derby.start"),
                    elems = rawArenas:map(function(arena, iArena)
                        return {
                            label = string.var("{1} ({2})", { arena.name,
                                BJI.Managers.Lang.get("derby.settings.places")
                                    :var({ places = #arena.startPositions })
                            }),
                            onClick = function()
                                BJI.Windows.DerbySettings.open(iArena)
                            end
                        }
                    end):sort(function(a, b)
                        return a.label < b.label
                    end)
                })
            else
                -- selection window
                table.insert(M.cache.elems, {
                    label = BJI.Managers.Lang.get("menu.scenario.derby.start"),
                    onClick = function()
                        BJI.Windows.Selection.open("menu.scenario.derby.start", rawArenas:map(function(arena, iArena)
                            return {
                                label = string.var("{1} ({2})", { arena.name,
                                    BJI.Managers.Lang.get("derby.settings.places")
                                        :var({ places = #arena.startPositions })
                                }),
                                value = iArena,
                            }
                        end), nil, function(iArena)
                            BJI.Windows.DerbySettings.open(iArena)
                        end, { BJI.Managers.Perm.PERMISSIONS.START_SERVER_SCENARIO })
                    end,
                })
            end
        end
    end
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI.Managers.Tick.getContext()
    M.cache = {
        label = BJI.Managers.Lang.get("menu.scenario.title"),
        elems = {},
    }

    if not BJI.Windows.ScenarioEditor.getState() and
        not BJI.Managers.Tournament.state and
        not BJI.Managers.Pursuit.getState() then
        menuSoloRace(ctxt)
        menuBusMission(ctxt)
        menuVehicleDelivery(ctxt)
        menuPackageDelivery(ctxt)
        menuDeliveryMulti(ctxt)
        menuTagDuo(ctxt)
        table.insert(M.cache.elems, { separator = true })
        menuSpeedGame(ctxt)
        menuHunter(ctxt)
        menuDerby(ctxt)
    end

    -- STOP Server Scenario
    if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_SERVER_SCENARIO) then
        if BJI.Managers.Scenario.isServerScenarioInProgress() then
            if BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.RACE_MULTI) then
                table.insert(M.cache.elems, {
                    label = BJI.Managers.Lang.get("menu.scenario.raceStop"),
                    onClick = BJI.Tx.scenario.RaceMultiStop,
                })
            elseif BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.SPEED) then
                table.insert(M.cache.elems, {
                    label = BJI.Managers.Lang.get("menu.scenario.speed.stop"),
                    onClick = BJI.Tx.scenario.SpeedStop,
                })
            elseif BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.HUNTER) then
                table.insert(M.cache.elems, {
                    label = BJI.Managers.Lang.get("menu.scenario.hunter.stop"),
                    onClick = BJI.Tx.scenario.HunterStop,
                })
            elseif BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.DERBY) then
                table.insert(M.cache.elems, {
                    label = BJI.Managers.Lang.get("menu.scenario.derby.stop"),
                    onClick = BJI.Tx.scenario.DerbyStop,
                })
            end
        end

        if not BJI.Managers.Tournament.state then
            table.insert(M.cache.elems, {
                label = BJI.Managers.Lang.get("menu.scenario.tournament"),
                active = BJI.Windows.Tournament.manualShow,
                onClick = function()
                    if BJI.Windows.Tournament.manualShow and
                        BJI.Windows.Tournament.onClose then
                        BJI.Windows.Tournament.onClose()
                    else
                        BJI.Windows.Tournament.open()
                    end
                end,
            })
        end
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
        BJI.Managers.Events.EVENTS.VEHICLES_UPDATED,
        BJI.Managers.Events.EVENTS.SCENARIO_CHANGED,
        BJI.Managers.Events.EVENTS.SCENARIO_UPDATED,
        BJI.Managers.Events.EVENTS.SCENARIO_EDITOR_UPDATED,
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.WINDOW_VISIBILITY_TOGGLED,
        BJI.Managers.Events.EVENTS.TOURNAMENT_UPDATED,
        BJI.Managers.Events.EVENTS.PURSUIT_UPDATE,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateCache, "MainMenuScenario"))

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
    end, "MainMenuScenario"))
end

function M.onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

return M
