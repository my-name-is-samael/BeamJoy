local function menuSoloRace(ctxt, scenarioEntry)
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_PLAYER_SCENARIO) and
        BJIScenario.get(BJIScenario.TYPES.RACE_SOLO) and
        BJIContext.Scenario.Data.Races and
        BJIScenario.isFreeroam() and BJIPerm.canSpawnVehicle() then
        local rawRaces = {}
        for _, race in ipairs(BJIContext.Scenario.Data.Races) do
            if race.enabled then
                table.insert(rawRaces, race)
            end
        end

        local errorMessage = nil
        if #rawRaces == 0 then
            errorMessage = BJILang.get("menu.scenario.soloRace.noRace")
        elseif not ctxt.isOwner or BJIVeh.isUnicycle(ctxt.veh:getID()) then
            errorMessage = BJILang.get("menu.scenario.soloRace.missingOwnVehicle")
        end

        if errorMessage then
            table.insert(scenarioEntry.elems, {
                render = function()
                    LineBuilder()
                        :text(BJILang.get("menu.scenario.soloRace.start"), TEXT_COLORS.DISABLED)
                        :text(string.var("({1})", { errorMessage }), TEXT_COLORS.DISABLED)
                        :build()
                end
            })
        else
            local races = {}
            for _, race in ipairs(rawRaces) do
                local strategies = BJIScenario.get(BJIScenario.TYPES.RACE_SOLO).RESPAWN_STRATEGIES
                local respawnStrategies = {}
                for _, rs in pairs(strategies) do
                    if race.hasStand or not table.includes({ strategies.STAND }, rs) then
                        table.insert(respawnStrategies, rs)
                    end
                end
                table.insert(races, {
                    label = race.name,
                    onClick = function()
                        BJIContext.Scenario.RaceSettings = {
                            multi = false,
                            raceID = race.id,
                            raceName = race.name,
                            loopable = race.loopable,
                            laps = 1,
                            respawnStrategy = BJIScenario.get(BJIScenario.TYPES.RACE_SOLO).RESPAWN_STRATEGIES
                                .LAST_CHECKPOINT,
                            respawnStrategies = respawnStrategies,
                        }
                    end
                })
            end
            table.sort(races, function(a, b)
                return a.label < b.label
            end)
            table.insert(scenarioEntry.elems, {
                label = BJILang.get("menu.scenario.soloRace.start"),
                elems = races
            })
        end
    elseif BJIScenario.is(BJIScenario.TYPES.RACE_SOLO) and
        BJIScenario.get(BJIScenario.TYPES.RACE_SOLO).isRaceStarted() then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.soloRace.stop"),
            onClick = function()
                BJIScenario.switchScenario(BJIScenario.TYPES.FREEROAM, ctxt)
            end,
        })
    end
end

local function menuVehicleDelivery(ctxt, scenarioEntry)
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_PLAYER_SCENARIO) and
        BJIScenario.isFreeroam() and
        BJICache.isFirstLoaded(BJICache.CACHES.DELIVERIES) then
        local errorMessage = nil
        if not BJIContext.Scenario.Data.Deliveries or
            #BJIContext.Scenario.Data.Deliveries < 2 then
            errorMessage = BJILang.get("menu.scenario.vehicleDelivery.noDelivery")
        end

        if errorMessage then
            table.insert(scenarioEntry.elems, {
                render = function()
                    LineBuilder()
                        :text(BJILang.get("menu.scenario.vehicleDelivery.start"), TEXT_COLORS.DISABLED)
                        :text(string.var("({1})", { errorMessage }), TEXT_COLORS.DISABLED)
                        :build()
                end
            })
        else
            table.insert(scenarioEntry.elems, {
                label = BJILang.get("menu.scenario.vehicleDelivery.start"),
                onClick = function()
                    BJIScenario.switchScenario(BJIScenario.TYPES.VEHICLE_DELIVERY, ctxt)
                end,
            })
        end
    elseif BJIScenario.is(BJIScenario.TYPES.VEHICLE_DELIVERY) and
        BJIScenario.get(BJIScenario.TYPES.VEHICLE_DELIVERY) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.vehicleDelivery.stop"),
            onClick = BJIScenario.get(BJIScenario.TYPES.VEHICLE_DELIVERY).onStopDelivery,
        })
    end
end

local function menuPackageDelivery(ctxt, scenarioEntry)
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_PLAYER_SCENARIO) and
        BJIScenario.isFreeroam() and
        BJICache.isFirstLoaded(BJICache.CACHES.DELIVERIES) then
        local errorMessage = nil
        if not BJIContext.Scenario.Data.Deliveries or
            #BJIContext.Scenario.Data.Deliveries < 2 then
            errorMessage = BJILang.get("menu.scenario.packageDelivery.noDelivery")
        elseif not ctxt.isOwner or BJIVeh.isUnicycle(ctxt.veh:getID()) then
            errorMessage = BJILang.get("menu.scenario.packageDelivery.missingOwnVehicle")
        end

        if errorMessage then
            table.insert(scenarioEntry.elems, {
                render = function()
                    LineBuilder()
                        :text(BJILang.get("menu.scenario.packageDelivery.start"), TEXT_COLORS.DISABLED)
                        :text(string.var("({1})", { errorMessage }), TEXT_COLORS.DISABLED)
                        :build()
                end
            })
        else
            table.insert(scenarioEntry.elems, {
                label = BJILang.get("menu.scenario.packageDelivery.start"),
                onClick = function()
                    BJIAsync.delayTask(function()
                        BJIScenario.switchScenario(BJIScenario.TYPES.PACKAGE_DELIVERY, ctxt)
                    end, 0, "BJIPackageDeliveryStart")
                end,
            })
        end
    elseif BJIScenario.is(BJIScenario.TYPES.PACKAGE_DELIVERY) and
        BJIScenario.get(BJIScenario.TYPES.PACKAGE_DELIVERY) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.packageDelivery.stop"),
            onClick = BJIScenario.get(BJIScenario.TYPES.PACKAGE_DELIVERY).onStopDelivery,
        })
    end
end

local function menuDeliveryMulti(ctxt, scenarioEntry)
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_PLAYER_SCENARIO) and
        BJIScenario.isFreeroam() then
        local errorMessage = nil
        if not BJIContext.Scenario.Data.Deliveries or
            #BJIContext.Scenario.Data.Deliveries < 2 then
            errorMessage = BJILang.get("menu.scenario.deliveryMulti.noDelivery")
        elseif not ctxt.isOwner or BJIVeh.isUnicycle(ctxt.veh:getID()) then
            errorMessage = BJILang.get("menu.scenario.deliveryMulti.missingOwnVehicle")
        end

        if errorMessage then
            table.insert(scenarioEntry.elems, {
                render = function()
                    LineBuilder()
                        :text(BJILang.get("menu.scenario.deliveryMulti.join"), TEXT_COLORS.DISABLED)
                        :text(string.var("({1})", { errorMessage }), TEXT_COLORS.DISABLED)
                        :build()
                end
            })
        else
            table.insert(scenarioEntry.elems, {
                label = BJILang.get("menu.scenario.deliveryMulti.join"),
                onClick = function()
                    BJITx.scenario.DeliveryMultiJoin(ctxt.veh:getID(), ctxt.vehPosRot.pos)
                end,
            })
        end
    elseif BJIScenario.is(BJIScenario.TYPES.DELIVERY_MULTI) and
        BJIScenario.get(BJIScenario.TYPES.DELIVERY_MULTI) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.deliveryMulti.leave"),
            onClick = function()
                BJITx.scenario.DeliveryMultiLeave()
            end,
        })
    end
end

-- later update TODO
local function menuTagDuo(ctxt, scenarioEntry)
    if BJIScenario.get(BJIScenario.TYPES.TAG_DUO) and
        BJIScenario.get(BJIScenario.TYPES.TAG_DUO).canChangeTo(ctxt) then
        local lobbies = {}
        table.insert(lobbies, {
            label = "Create a lobby",
            onClick = function()
                BJITx.scenario.TagDuoJoin(nil, ctxt.veh:getID())
            end,
        })
        for i, l in ipairs(BJIScenario.get(BJIScenario.TYPES.TAG_DUO).lobbies) do
            if table.length(l.players) < 2 then
                table.insert(lobbies, {
                    label = string.var("Join {1}'s lobby", { BJIContext.Players[l.host].playerName }),
                    onClick = function()
                        BJITx.scenario.TagDuoJoin(i, ctxt.veh:getID())
                    end,
                })
            end
        end
        table.insert(scenarioEntry.elems, {
            label = "Tag Duo",
            elems = lobbies,
        })
    elseif BJIScenario.get(BJIScenario.TYPES.TAG_DUO) and
        BJIScenario.is(BJIScenario.TYPES.TAG_DUO) then
        table.insert(scenarioEntry.elems, {
            label = "Stop Tag Duo",
            onClick = function()
                BJITx.scenario.TagDuoLeave()
            end,
        })
    end
end

local function menuBusMission(ctxt, scenarioEntry)
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_PLAYER_SCENARIO) and
        BJIScenario.isFreeroam() and
        BJICache.isFirstLoaded(BJICache.CACHES.BUS_LINES) then
        local errorMessage = nil
        if not BJIContext.Scenario.Data.BusLines or
            #BJIContext.Scenario.Data.BusLines == 0 then
            errorMessage = BJILang.get("menu.scenario.busMission.noBusMission")
        end

        if errorMessage then
            table.insert(scenarioEntry.elems, {
                render = function()
                    LineBuilder()
                        :text(BJILang.get("menu.scenario.busMission.start"), TEXT_COLORS.DISABLED)
                        :text(string.var("({1})", { errorMessage }), TEXT_COLORS.DISABLED)
                        :build()
                end
            })
        else
            table.insert(scenarioEntry.elems, {
                label = BJILang.get("menu.scenario.busMission.start"),
                onClick = function()
                    BJIAsync.delayTask(function()
                        BJIScenario.switchScenario(BJIScenario.TYPES.BUS_MISSION, ctxt)
                    end, 0, "BJIBusMissionStart")
                end,
            })
        end
    elseif BJIScenario.is(BJIScenario.TYPES.BUS_MISSION) and
        BJIScenario.get(BJIScenario.TYPES.BUS_MISSION) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.busMission.stop"),
            onClick = BJIScenario.get(BJIScenario.TYPES.BUS_MISSION).onStopBusMission,
        })
    end
end

local function menuSpeedGame(ctxt, scenarioEntry)
    if not BJIScenario.isServerScenarioInProgress() and
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO) then
        local potentialPlayers = BJIPerm.getCountPlayersCanSpawnVehicle()
        local minimumParticipants = BJIScenario.get(BJIScenario.TYPES.SPEED).MINIMUM_PARTICIPANTS
        local errorMessage = nil
        if potentialPlayers < minimumParticipants then
            errorMessage = BJILang.get("menu.scenario.speed.missingPlayers"):var({
                amount = minimumParticipants - potentialPlayers
            })
        end

        if errorMessage then
            table.insert(scenarioEntry.elems, {
                render = function()
                    LineBuilder()
                        :text(BJILang.get("menu.scenario.speed.start"), TEXT_COLORS.DISABLED)
                        :text(string.var("({1})", { errorMessage }), TEXT_COLORS.DISABLED)
                        :build()
                end
            })
        else
            table.insert(scenarioEntry.elems, {
                label = BJILang.get("menu.scenario.speed.start"),
                onClick = function()
                    BJITx.scenario.SpeedStart(false)
                end,
            })
        end
    elseif BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO) and
        BJIScenario.is(BJIScenario.TYPES.SPEED) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.speed.stop"),
            onClick = BJITx.scenario.SpeedStop,
        })
    end
end

local function menuHunter(ctxt, scenarioEntry)
    if not BJIScenario.isServerScenarioInProgress() and
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO) and
        BJIContext.Scenario.Data.Hunter then
        local potentialPlayers = BJIPerm.getCountPlayersCanSpawnVehicle()
        local minimumParticipants = BJIScenario.get(BJIScenario.TYPES.HUNTER).MINIMUM_PARTICIPANTS
        local errorMessage = nil
        if not BJIContext.Scenario.Data.Hunter or
            not BJIContext.Scenario.Data.Hunter.enabled then
            errorMessage = BJILang.get("menu.scenario.hunter.modeDisabled")
        elseif potentialPlayers < minimumParticipants then
            errorMessage = BJILang.get("menu.scenario.hunter.missingPlayers"):var({
                amount = minimumParticipants - potentialPlayers
            })
        end

        if errorMessage then
            table.insert(scenarioEntry.elems, {
                render = function()
                    LineBuilder()
                        :text(BJILang.get("menu.scenario.hunter.start"), TEXT_COLORS.DISABLED)
                        :text(string.var("({1})", { errorMessage }), TEXT_COLORS.DISABLED)
                        :build()
                end
            })
        else
            table.insert(scenarioEntry.elems, {
                label = BJILang.get("menu.scenario.hunter.start"),
                active = BJIContext.Scenario.HunterSettings,
                onClick = function()
                    if BJIContext.Scenario.HunterSettings then
                        BJIContext.Scenario.HunterSettings = nil
                    else
                        local scHunter = BJIScenario.get(BJIScenario.TYPES.HUNTER)
                        BJIContext.Scenario.HunterSettings = {
                            waypoints = scHunter.settings.waypoints,
                            huntedConfig = table.clone(scHunter.settings.huntedConfig),
                            hunterConfigs = table.clone(scHunter.settings.hunterConfigs),
                        }
                    end
                end,
            })
        end
    elseif BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO) and
        BJIScenario.is(BJIScenario.TYPES.HUNTER) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.hunter.stop"),
            onClick = BJITx.scenario.HunterStop,
        })
    end
end

local function menuDerby(ctxt, scenarioEntry)
    if not BJIScenario.isServerScenarioInProgress() and
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO) and
        BJIContext.Scenario.Data.Derby then
        local potentialPlayers = BJIPerm.getCountPlayersCanSpawnVehicle()
        local minimumParticipants = BJIScenario.get(BJIScenario.TYPES.DERBY).MINIMUM_PARTICIPANTS
        local errorMessage = nil
        if #BJIContext.Scenario.Data.Derby == 0 then
            errorMessage = BJILang.get("menu.scenario.derby.noArena")
        elseif potentialPlayers < minimumParticipants then
            errorMessage = BJILang.get("menu.scenario.derby.missingPlayers"):var({
                amount = minimumParticipants - potentialPlayers
            })
        end

        if errorMessage then
            table.insert(scenarioEntry.elems, {
                render = function()
                    LineBuilder()
                        :text(BJILang.get("menu.scenario.derby.start"), TEXT_COLORS.DISABLED)
                        :text(string.var("({1})", { errorMessage }), TEXT_COLORS.DISABLED)
                        :build()
                end
            })
        else
            local arenas = {}
            for i, arena in ipairs(BJIContext.Scenario.Data.Derby) do
                if arena.enabled then
                    table.insert(arenas, {
                        label = string.var("{1} ({2})", {
                            arena.name,
                            BJILang.get("derby.settings.places")
                                :var({ places = #arena.startPositions }),
                        }),
                        onClick = function()
                            BJIContext.Scenario.DerbyEdit = nil
                            local existing = BJIContext.Scenario.DerbySettings
                            if not existing then
                                BJIContext.Scenario.DerbySettings = {
                                    lives = 3,
                                    configs = BJIScenario.get(BJIScenario.TYPES.DERBY).configs or {}
                                }
                                existing = BJIContext.Scenario.DerbySettings
                            end
                            existing.arenaIndex = i
                            existing.arena = arena
                        end
                    })
                end
            end
            table.sort(arenas, function(a, b)
                return a.label < b.label
            end)
            table.insert(scenarioEntry.elems, {
                label = BJILang.get("menu.scenario.derby.start"),
                elems = arenas
            })
        end
    elseif BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO) and
        BJIScenario.is(BJIScenario.TYPES.DERBY) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.derby.stop"),
            onClick = BJITx.scenario.DerbyStop,
        })
    end
end

return function(ctxt)
    local scenarioEntry = {
        label = BJILang.get("menu.scenario.title"),
        elems = {},
    }

    menuSoloRace(ctxt, scenarioEntry)
    menuVehicleDelivery(ctxt, scenarioEntry)
    menuPackageDelivery(ctxt, scenarioEntry)
    menuDeliveryMulti(ctxt, scenarioEntry)
    --menuTagDuo(ctxt, scenarioEntry)
    menuBusMission(ctxt, scenarioEntry)
    menuSpeedGame(ctxt, scenarioEntry)

    -- STOP MULTI RACE
    if BJIScenario.is(BJIScenario.TYPES.RACE_MULTI) and
        (BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO) or
            BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SCENARIO)) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.raceStop"),
            onClick = BJITx.scenario.RaceMultiStop,
        })
    end

    menuHunter(ctxt, scenarioEntry)
    menuDerby(ctxt, scenarioEntry)

    return #scenarioEntry.elems > 0 and scenarioEntry or nil
end
