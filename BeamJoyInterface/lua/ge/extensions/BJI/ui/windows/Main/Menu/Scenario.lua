local M = {
    cache = {
        label = "",
        ---@type MenuDropdownElement[]
        elems = {},
    },
}

---@param ctxt TickContext
local function menuSoloRace(ctxt)
    if BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.START_PLAYER_SCENARIO) and
        BJI_Scenario.get(BJI_Scenario.TYPES.RACE_SOLO) and
        BJI_Scenario.Data.Races and
        BJI_Scenario.isFreeroam() and BJI_Perm.canSpawnVehicle() then
        local rawRaces = Table(BJI_Scenario.Data.Races)
            :filter(function(race) return race.enabled end)

        local errorMessage = nil
        if #rawRaces == 0 then
            errorMessage = BJI_Lang.get("menu.scenario.soloRace.noRace")
        elseif not ctxt.isOwner or ctxt.veh.jbeam == "unicycle" then
            errorMessage = BJI_Lang.get("errors.missingOwnVehicle")
        elseif ctxt.veh.isAi then
            errorMessage = BJI_Lang.get("error.cannotStartWodeWithAI")
        end

        if errorMessage then
            table.insert(M.cache.elems, {
                type = "custom",
                render = function()
                    Text(BJI_Lang.get("menu.scenario.soloRace.start"),
                        { color = BJI.Utils.Style.TEXT_COLORS.DISABLED })
                    TooltipText(errorMessage)
                end
            })
        else
            local respawnStrategies = Table(BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES)
                :sort(function(a, b) return a.order < b.order end)
                :map(function(el) return el.key end)

            if #rawRaces <= BJI_Win_Selection.LIMIT_ELEMS_THRESHOLD then
                -- sub elems
                table.insert(M.cache.elems, {
                    type = "menu",
                    label = BJI_Lang.get("menu.scenario.soloRace.start"),
                    elems = rawRaces:map(function(race)
                        return {
                            type = "item",
                            label = race.name,
                            onClick = function()
                                BJI_Win_RaceSettings.open({
                                    multi = false,
                                    raceID = race.id,
                                    raceName = race.name,
                                    loopable = race.loopable,
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
                    type = "item",
                    label = BJI_Lang.get("menu.scenario.soloRace.start"),
                    onClick = function()
                        BJI_Win_Selection.open("menu.vote.race.title", rawRaces
                            :map(function(race)
                                return { label = race.name, value = race.id }
                            end):sort(function(a, b) return a.label < b.label end) or Table(), nil,
                            function(raceID)
                                rawRaces:find(function(r) return r.id == raceID end,
                                    function(race)
                                        BJI_Win_RaceSettings.open({
                                            multi = false,
                                            raceID = race.id,
                                            raceName = race.name,
                                            loopable = race.loopable,
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
    elseif BJI_Scenario.is(BJI_Scenario.TYPES.RACE_SOLO) then
        table.insert(M.cache.elems, {
            type = "item",
            label = BJI_Lang.get("menu.scenario.soloRace.stop"),
            onClick = function()
                BJI_Scenario.switchScenario(BJI_Scenario.TYPES.FREEROAM, ctxt)
            end,
        })
    end
end

---@param ctxt TickContext
local function menuVehicleDelivery(ctxt)
    if BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.START_PLAYER_SCENARIO) and
        BJI_Scenario.isFreeroam() and
        BJI_Cache.isFirstLoaded(BJI_Cache.CACHES.DELIVERIES) then
        local errorMessage = nil
        if not BJI_Scenario.Data.Deliveries or
            #BJI_Scenario.Data.Deliveries < 2 then
            errorMessage = BJI_Lang.get("menu.scenario.vehicleDelivery.noDelivery")
        end

        if errorMessage then
            table.insert(M.cache.elems, {
                type = "custom",
                render = function()
                    Text(BJI_Lang.get("menu.scenario.vehicleDelivery.start"),
                        { color = BJI.Utils.Style.TEXT_COLORS.DISABLED })
                    TooltipText(errorMessage)
                end
            })
        else
            table.insert(M.cache.elems, {
                type = "item",
                label = BJI_Lang.get("menu.scenario.vehicleDelivery.start"),
                onClick = function()
                    BJI_Scenario.get(BJI_Scenario.TYPES.VEHICLE_DELIVERY).start()
                end,
            })
        end
    elseif BJI_Scenario.is(BJI_Scenario.TYPES.VEHICLE_DELIVERY) and
        BJI_Scenario.get(BJI_Scenario.TYPES.VEHICLE_DELIVERY) then
        table.insert(M.cache.elems, {
            type = "item",
            label = BJI_Lang.get("menu.scenario.vehicleDelivery.stop"),
            onClick = BJI_Scenario.get(BJI_Scenario.TYPES.VEHICLE_DELIVERY).onStopDelivery,
        })
    end
end

---@param ctxt TickContext
local function menuPackageDelivery(ctxt)
    if BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.START_PLAYER_SCENARIO) and
        BJI_Scenario.isFreeroam() and
        BJI_Cache.isFirstLoaded(BJI_Cache.CACHES.DELIVERIES) then
        local errorMessage = nil
        if not BJI_Scenario.Data.Deliveries or
            #BJI_Scenario.Data.Deliveries < 2 then
            errorMessage = BJI_Lang.get("menu.scenario.packageDelivery.noDelivery")
        elseif not ctxt.isOwner or ctxt.veh.jbeam == "unicycle" then
            errorMessage = BJI_Lang.get("errors.missingOwnVehicle")
        elseif ctxt.veh.isAi then
            errorMessage = BJI_Lang.get("error.cannotStartWodeWithAI")
        end

        if errorMessage then
            table.insert(M.cache.elems, {
                type = "custom",
                render = function()
                    Text(BJI_Lang.get("menu.scenario.packageDelivery.start"),
                        { color = BJI.Utils.Style.TEXT_COLORS.DISABLED })
                    TooltipText(errorMessage)
                end
            })
        else
            table.insert(M.cache.elems, {
                type = "item",
                label = BJI_Lang.get("menu.scenario.packageDelivery.start"),
                onClick = function()
                    BJI_Async.delayTask(function()
                        BJI_Scenario.switchScenario(BJI_Scenario.TYPES.PACKAGE_DELIVERY, ctxt)
                    end, 0, "BJIPackageDeliveryStart")
                end,
            })
        end
    elseif BJI_Scenario.is(BJI_Scenario.TYPES.PACKAGE_DELIVERY) and
        BJI_Scenario.get(BJI_Scenario.TYPES.PACKAGE_DELIVERY) then
        table.insert(M.cache.elems, {
            type = "item",
            label = BJI_Lang.get("menu.scenario.packageDelivery.stop"),
            onClick = BJI_Scenario.get(BJI_Scenario.TYPES.PACKAGE_DELIVERY).onStopDelivery,
        })
    end
end

---@param ctxt TickContext
local function menuDeliveryMulti(ctxt)
    if BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.START_PLAYER_SCENARIO) and
        BJI_Scenario.isFreeroam() then
        local errorMessage = nil
        if not BJI_Scenario.Data.Deliveries or
            #BJI_Scenario.Data.Deliveries < 2 then
            errorMessage = BJI_Lang.get("menu.scenario.deliveryMulti.noDelivery")
        elseif not ctxt.isOwner or ctxt.veh.jbeam == "unicycle" then
            errorMessage = BJI_Lang.get("errors.missingOwnVehicle")
        elseif ctxt.veh.isAi then
            errorMessage = BJI_Lang.get("error.cannotStartWodeWithAI")
        end

        if errorMessage then
            table.insert(M.cache.elems, {
                type = "custom",
                render = function()
                    Text(BJI_Lang.get("menu.scenario.deliveryMulti.join"),
                        { color = BJI.Utils.Style.TEXT_COLORS.DISABLED })
                    TooltipText(errorMessage)
                end
            })
        else
            table.insert(M.cache.elems, {
                type = "item",
                label = BJI_Lang.get("menu.scenario.deliveryMulti.join"),
                onClick = function()
                    BJI_Tx_scenario.DeliveryMultiJoin(ctxt.veh.gameVehicleID, ctxt.veh.position)
                end,
            })
        end
    elseif BJI_Scenario.is(BJI_Scenario.TYPES.DELIVERY_MULTI) and
        BJI_Scenario.get(BJI_Scenario.TYPES.DELIVERY_MULTI) then
        table.insert(M.cache.elems, {
            type = "item",
            label = BJI_Lang.get("menu.scenario.deliveryMulti.leave"),
            onClick = function()
                BJI_Tx_scenario.DeliveryMultiLeave()
            end,
        })
    end
end

---@param ctxt TickContext
local function menuTagDuo(ctxt)
    if BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.START_PLAYER_SCENARIO) and
        BJI_Scenario.isFreeroam() then
        local errorMessage
        if not ctxt.isOwner or ctxt.veh.jbeam == "unicycle" then
            errorMessage = BJI_Lang.get("errors.missingOwnVehicle")
        elseif ctxt.veh.isAi then
            errorMessage = BJI_Lang.get("error.cannotStartWodeWithAI")
        end

        if errorMessage then
            table.insert(M.cache.elems, {
                type = "custom",
                render = function()
                    Text(BJI_Lang.get("menu.scenario.tagduo.join"),
                        { color = BJI.Utils.Style.TEXT_COLORS.DISABLED })
                    TooltipText(errorMessage)
                end
            })
        else
            local lobbyEntries = {}
            table.insert(lobbyEntries, {
                type = "item",
                label = BJI_Lang.get("menu.scenario.tagduo.createLobby"),
                onClick = function()
                    BJI_Tx_scenario.TagDuoJoin(-1, ctxt.veh.gameVehicleID)
                end,
            })
            for i, l in ipairs(BJI_Scenario.get(BJI_Scenario.TYPES.TAG_DUO).lobbies) do
                if table.length(l.players) < 2 then
                    table.insert(lobbyEntries, {
                        type = "item",
                        label = string.var(BJI_Lang.get("menu.scenario.tagduo.joinLobby"),
                            { playerName = ctxt.players[l.host].playerName }),
                        onClick = function()
                            BJI_Tx_scenario.TagDuoJoin(i, ctxt.veh.gameVehicleID)
                        end,
                    })
                end
            end
            table.insert(M.cache.elems, {
                type = "menu",
                label = BJI_Lang.get("menu.scenario.tagduo.join"),
                elems = lobbyEntries,
            })
        end
    elseif BJI_Scenario.is(BJI_Scenario.TYPES.TAG_DUO) then
        table.insert(M.cache.elems, {
            type = "item",
            label = BJI_Lang.get("menu.scenario.tagduo.leave"),
            onClick = function()
                BJI_Tx_scenario.TagDuoLeave()
            end,
        })
    end
end

---@param ctxt TickContext
local function menuBusMission(ctxt)
    if BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.START_PLAYER_SCENARIO) and
        BJI_Scenario.isFreeroam() and
        BJI_Cache.isFirstLoaded(BJI_Cache.CACHES.BUS_LINES) then
        local errorMessage = nil
        if not BJI_Scenario.Data.BusLines or
            #BJI_Scenario.Data.BusLines == 0 then
            errorMessage = BJI_Lang.get("menu.scenario.busMission.noBusMission")
        end

        if errorMessage then
            table.insert(M.cache.elems, {
                type = "custom",
                render = function()
                    Text(BJI_Lang.get("menu.scenario.busMission.start"),
                        { color = BJI.Utils.Style.TEXT_COLORS.DISABLED })
                    TooltipText(errorMessage)
                end
            })
        else
            table.insert(M.cache.elems, {
                type = "item",
                label = BJI_Lang.get("menu.scenario.busMission.start"),
                onClick = function()
                    BJI_Win_BusMissionPreparation.show = true
                end,
            })
        end
    elseif BJI_Scenario.is(BJI_Scenario.TYPES.BUS_MISSION) and
        BJI_Scenario.get(BJI_Scenario.TYPES.BUS_MISSION) then
        table.insert(M.cache.elems, {
            type = "item",
            label = BJI_Lang.get("menu.scenario.busMission.stop"),
            onClick = BJI_Scenario.get(BJI_Scenario.TYPES.BUS_MISSION).onStopBusMission,
        })
    end
end

---@param ctxt TickContext
local function menuSpeedGame(ctxt)
    local potentialPlayers = BJI_Perm.getCountPlayersCanSpawnVehicle()
    local minimumParticipants = BJI_Scenario.get(BJI_Scenario.TYPES.SPEED).MINIMUM_PARTICIPANTS
    local errorMessage = nil
    if potentialPlayers < minimumParticipants then
        errorMessage = BJI_Lang.get("errors.missingPlayers"):var({
            amount = minimumParticipants - potentialPlayers
        })
    end

    if errorMessage then
        table.insert(M.cache.elems, {
            type = "custom",
            render = function()
                Text(BJI_Lang.get("menu.scenario.speed.start"),
                    { color = BJI.Utils.Style.TEXT_COLORS.DISABLED })
                TooltipText(errorMessage)
            end
        })
    else
        table.insert(M.cache.elems, {
            type = "item",
            label = BJI_Lang.get("menu.scenario.speed.start"),
            onClick = function()
                BJI_Tx_vote.ScenarioStart(BJI_Votes.SCENARIO_TYPES.SPEED, false)
            end,
        })
    end
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI_Tick.getContext()
    M.cache = {
        label = BJI_Lang.get("menu.scenario.title"),
        elems = {},
    }

    if not BJI_Win_ScenarioEditor.getState() and
        not BJI_Tournament.state and
        not BJI_Pursuit.getState() then
        menuSoloRace(ctxt)
        menuBusMission(ctxt)
        menuVehicleDelivery(ctxt)
        menuPackageDelivery(ctxt)
        menuDeliveryMulti(ctxt)
        menuTagDuo(ctxt)
        if not BJI_Scenario.isServerScenarioInProgress() and
            BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.START_SERVER_SCENARIO) and
            not BJI_Votes.Map.started() and
            not BJI_Votes.Scenario.started() then
            table.insert(M.cache.elems, { type = "separator" })
            menuSpeedGame(ctxt)
            local common = require("ge/extensions/BJI/ui/windows/Main/Menu/Common")
            common.menuRace(ctxt, M.cache.elems)
            common.menuHunter(ctxt, M.cache.elems)
            common.menuInfected(ctxt, M.cache.elems)
            common.menuDerby(ctxt, M.cache.elems)
        end
    end

    -- STOP Server Scenario
    if BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.START_SERVER_SCENARIO) then
        if BJI_Scenario.isServerScenarioInProgress() then
            if BJI_Scenario.is(BJI_Scenario.TYPES.RACE_MULTI) then
                table.insert(M.cache.elems, {
                    type = "item",
                    label = BJI_Lang.get("menu.scenario.race.stop"),
                    onClick = BJI_Tx_scenario.RaceMultiStop,
                })
            elseif BJI_Scenario.is(BJI_Scenario.TYPES.SPEED) then
                table.insert(M.cache.elems, {
                    type = "item",
                    label = BJI_Lang.get("menu.scenario.speed.stop"),
                    onClick = BJI_Tx_scenario.SpeedStop,
                })
            elseif BJI_Scenario.is(BJI_Scenario.TYPES.HUNTER) then
                table.insert(M.cache.elems, {
                    type = "item",
                    label = BJI_Lang.get("menu.scenario.hunter.stop"),
                    onClick = BJI_Tx_scenario.HunterStop,
                })
            elseif BJI_Scenario.is(BJI_Scenario.TYPES.INFECTED) then
                table.insert(M.cache.elems, {
                    type = "item",
                    label = BJI_Lang.get("menu.scenario.infected.stop"),
                    onClick = BJI_Tx_scenario.InfectedStop,
                })
            elseif BJI_Scenario.is(BJI_Scenario.TYPES.DERBY) then
                table.insert(M.cache.elems, {
                    type = "item",
                    label = BJI_Lang.get("menu.scenario.derby.stop"),
                    onClick = BJI_Tx_scenario.DerbyStop,
                })
            end
        end

        if not BJI_Tournament.state then
            table.insert(M.cache.elems, {
                type = "item",
                label = BJI_Lang.get("menu.scenario.tournament"),
                active = BJI_Win_Tournament.manualShow,
                onClick = function()
                    if BJI_Win_Tournament.manualShow and
                        BJI_Win_Tournament.onClose then
                        BJI_Win_Tournament.onClose()
                    else
                        BJI_Win_Tournament.open()
                    end
                end,
            })
        end
    end

    MenuDropdownSanitize(M.cache.elems)
end

local listeners = Table()
function M.onLoad()
    updateCache()
    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.PLAYER_CONNECT,
        BJI_Events.EVENTS.PLAYER_DISCONNECT,
        BJI_Events.EVENTS.VEHICLE_SPAWNED,
        BJI_Events.EVENTS.VEHICLE_REMOVED,
        BJI_Events.EVENTS.VEHICLE_SPEC_CHANGED,
        BJI_Events.EVENTS.VEHICLES_UPDATED,
        BJI_Events.EVENTS.SCENARIO_CHANGED,
        BJI_Events.EVENTS.SCENARIO_UPDATED,
        BJI_Events.EVENTS.SCENARIO_EDITOR_UPDATED,
        BJI_Events.EVENTS.PERMISSION_CHANGED,
        BJI_Events.EVENTS.VOTE_UPDATED,
        BJI_Events.EVENTS.LANG_CHANGED,
        BJI_Events.EVENTS.WINDOW_VISIBILITY_TOGGLED,
        BJI_Events.EVENTS.TOURNAMENT_UPDATED,
        BJI_Events.EVENTS.PURSUIT_UPDATE,
        BJI_Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateCache, "MainMenuScenario"))

    ---@param data {cache: string}
    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.CACHE_LOADED, function(ctxt, data)
        if table.includes({
                BJI_Cache.CACHES.RACES,
                BJI_Cache.CACHES.DELIVERIES,
                BJI_Cache.CACHES.BUS_LINES,
            }, data.cache) then
            updateCache(ctxt)
        end
    end, "MainMenuScenario"))
end

function M.onUnload()
    listeners:forEach(BJI_Events.removeListener)
end

---@param ctxt TickContext
function M.draw(ctxt)
    if #M.cache.elems > 0 then
        RenderMenuDropdown(M.cache.label, M.cache.elems)
    end
end

return M
