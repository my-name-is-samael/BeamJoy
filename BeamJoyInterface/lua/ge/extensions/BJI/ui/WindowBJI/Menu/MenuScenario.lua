return function(ctxt)
    local scenarioEntry = {
        label = BJILang.get("menu.scenario.title"),
        elems = {},
    }

    -- SOLO RACE
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_PLAYER_SCENARIO) and
        BJIScenario.get(BJIScenario.TYPES.RACE_SOLO) and
        BJIScenario.get(BJIScenario.TYPES.RACE_SOLO).canChangeTo(ctxt) then
        local races = {}
        for _, race in ipairs(BJIContext.Scenario.Data.Races) do
            if race.enabled then
                local strategies = BJIScenario.get(BJIScenario.TYPES.RACE_SOLO).RESPAWN_STRATEGIES
                local respawnStrategies = {}
                for _, rs in pairs(strategies) do
                    if race.hasStand or not tincludes({ strategies.STAND }, rs) then
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
        end
        table.sort(races, function(a, b)
            return a.label < b.label
        end)
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.startSoloRace"),
            elems = races
        })
    elseif BJIScenario.is(BJIScenario.TYPES.RACE_SOLO) and
        BJIScenario.get(BJIScenario.TYPES.RACE_SOLO).isRaceStarted() then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.stopSoloRace"),
            onClick = function()
                BJIScenario.switchScenario(BJIScenario.TYPES.FREEROAM, ctxt)
            end,
        })
    end

    -- VEHICLE DELIVERY
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_PLAYER_SCENARIO) and
        BJIScenario.get(BJIScenario.TYPES.VEHICLE_DELIVERY) and
        BJIScenario.get(BJIScenario.TYPES.VEHICLE_DELIVERY).canChangeTo(ctxt) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.startVehicleDelivery"),
            onClick = function()
                BJIScenario.switchScenario(BJIScenario.TYPES.VEHICLE_DELIVERY, ctxt)
            end,
        })
    elseif BJIScenario.is(BJIScenario.TYPES.VEHICLE_DELIVERY) and
        BJIScenario.get(BJIScenario.TYPES.VEHICLE_DELIVERY) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.stopDelivery"),
            onClick = BJIScenario.get(BJIScenario.TYPES.VEHICLE_DELIVERY).onStopDelivery,
        })
    end

    -- PACKAGE DELIVERY
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_PLAYER_SCENARIO) and
        BJIScenario.get(BJIScenario.TYPES.PACKAGE_DELIVERY) and
        BJIScenario.get(BJIScenario.TYPES.PACKAGE_DELIVERY).canChangeTo(ctxt) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.startPackageDelivery"),
            onClick = function()
                BJIAsync.delayTask(function()
                    BJIScenario.switchScenario(BJIScenario.TYPES.PACKAGE_DELIVERY, ctxt)
                end, 0, "BJIPackageDeliveryStart")
            end,
        })
    elseif BJIScenario.is(BJIScenario.TYPES.PACKAGE_DELIVERY) and
        BJIScenario.get(BJIScenario.TYPES.PACKAGE_DELIVERY) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.stopDelivery"),
            onClick = BJIScenario.get(BJIScenario.TYPES.PACKAGE_DELIVERY).onStopDelivery,
        })
    end

    -- DELIVERY MULTI
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_PLAYER_SCENARIO) and
        BJIScenario.get(BJIScenario.TYPES.DELIVERY_MULTI) and
        BJIScenario.get(BJIScenario.TYPES.DELIVERY_MULTI).canChangeTo(ctxt) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.joinDeliveryMulti"),
            onClick = function()
                BJITx.scenario.DeliveryMultiJoin(ctxt.veh:getID(), ctxt.vehPosRot.pos)
            end,
        })
    elseif BJIScenario.is(BJIScenario.TYPES.DELIVERY_MULTI) and
        BJIScenario.get(BJIScenario.TYPES.DELIVERY_MULTI) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.leaveDeliveryMulti"),
            onClick = function()
                BJITx.scenario.DeliveryMultiLeave()
            end,
        })
    end

    -- TAG DUO
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
            if tlength(l.players) < 2 then
                table.insert(lobbies, {
                    label = svar("Join {1}'s lobby", { BJIContext.Players[l.host].playerName }),
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

    -- BUS MISSION
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_PLAYER_SCENARIO) and
        BJIScenario.get(BJIScenario.TYPES.BUS_MISSION) and
        BJIScenario.get(BJIScenario.TYPES.BUS_MISSION).canChangeTo(ctxt) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.startBusMission"),
            onClick = function()
                BJIAsync.delayTask(function()
                    BJIScenario.switchScenario(BJIScenario.TYPES.BUS_MISSION, ctxt)
                end, 0, "BJIBusMissionStart")
            end,
        })
    elseif BJIScenario.is(BJIScenario.TYPES.BUS_MISSION) and
        BJIScenario.get(BJIScenario.TYPES.BUS_MISSION) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.stopBusMission"),
            onClick = BJIScenario.get(BJIScenario.TYPES.BUS_MISSION).onStopBusMission,
        })
    end

    -- SPEED
    if not BJIScenario.isServerScenarioInProgress() and
        tlength(BJIContext.Players) >= 2 and
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.startSpeed"),
            onClick = function()
                BJITx.scenario.SpeedStart(false)
            end,
        })
    elseif BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO) and
        BJIScenario.is(BJIScenario.TYPES.SPEED) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.stopSpeed"),
            onClick = BJITx.scenario.SpeedStop,
        })
    end

    -- STOP MULTI RACE
    if BJIScenario.is(BJIScenario.TYPES.RACE_MULTI) and
        (BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO) or
            BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SCENARIO)) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.raceStop"),
            onClick = BJITx.scenario.RaceMultiStop,
        })
    end

    -- HUNTER
    if not BJIScenario.isServerScenarioInProgress() and
        tlength(BJIContext.Players) >= 3 and
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO) and
        BJIContext.Scenario.Data.Hunter and
        BJIContext.Scenario.Data.Hunter.enabled then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.startHunter"),
            active = BJIContext.Scenario.HunterSettings,
            onClick = function()
                if BJIContext.Scenario.HunterSettings then
                    BJIContext.Scenario.HunterSettings = nil
                else
                    local scHunter = BJIScenario.get(BJIScenario.TYPES.HUNTER)
                    BJIContext.Scenario.HunterSettings = {
                        waypoints = scHunter.settings.waypoints,
                        huntedConfig = tdeepcopy(scHunter.settings.huntedConfig),
                        hunterConfigs = tdeepcopy(scHunter.settings.hunterConfigs),
                    }
                end
            end,
        })
    elseif BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO) and
        BJIScenario.is(BJIScenario.TYPES.HUNTER) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.stopHunter"),
            onClick = BJITx.scenario.HunterStop,
        })
    end

    -- DERBY
    local function openDerbySettings(indexArena)
        BJIContext.Scenario.DerbyEdit = nil
        local arena = BJIContext.Scenario.Data.Derby[indexArena]
        if not arena then
            return
        end

        local existing = BJIContext.Scenario.DerbySettings
        if not existing then
            BJIContext.Scenario.DerbySettings = {
                lives = 3,
                configs = BJIScenario.get(BJIScenario.TYPES.DERBY).configs or {}
            }
            existing = BJIContext.Scenario.DerbySettings
        end
        existing.arenaIndex = indexArena
        existing.arena = arena
    end
    if not BJIScenario.isServerScenarioInProgress() and
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO) and
        tlength(BJIContext.Players) >= 3 and
        #BJIContext.Scenario.Data.Derby > 0 then
        local arenas = {}
        for i, arena in ipairs(BJIContext.Scenario.Data.Derby) do
            if arena.enabled then
                table.insert(arenas, {
                    label = svar("{1} ({2})", {
                        arena.name,
                        svar(BJILang.get("derby.settings.places"),
                            { places = #arena.startPositions }),
                    }),
                    onClick = function()
                        openDerbySettings(i)
                    end
                })
            end
        end
        table.sort(arenas, function(a, b)
            return a.label < b.label
        end)
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.startDerby"),
            elems = arenas
        })
    elseif BJIPerm.hasPermission(BJIPerm.PERMISSIONS.START_SERVER_SCENARIO) and
        BJIScenario.is(BJIScenario.TYPES.DERBY) then
        table.insert(scenarioEntry.elems, {
            label = BJILang.get("menu.scenario.stopDerby"),
            onClick = BJITx.scenario.DerbyStop,
        })
    end

    return #scenarioEntry.elems > 0 and scenarioEntry or nil
end
