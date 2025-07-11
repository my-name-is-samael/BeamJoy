local C = {}

---@param ctxt TickContext
---@param elems table
local function menuRace(ctxt, elems)
    if BJI_Context.Scenario.Data.Races then
        local errorMessage = nil
        local minParticipants = (BJI_Scenario.get(BJI_Scenario.TYPES.RACE_MULTI) or {})
            .MINIMUM_PARTICIPANTS
        local potentialPlayers = BJI_Perm.getCountPlayersCanSpawnVehicle()
        local rawRaces = Table(BJI_Context.Scenario.Data.Races)
            :filter(function(race) return race.enabled and race.places > 1 end)

        if #rawRaces == 0 then
            errorMessage = BJI_Lang.get("menu.scenario.race.noRace")
        elseif potentialPlayers < minParticipants then
            errorMessage = BJI_Lang.get("errors.missingPlayers")
                :var({ amount = minParticipants - potentialPlayers })
        end

        if errorMessage then
            table.insert(elems, {
                type = "custom",
                render = function()
                    Text(BJI_Lang.get("menu.scenario.race.title"), { color = BJI.Utils.Style.TEXT_COLORS.DISABLED })
                    TooltipText(errorMessage)
                end
            })
        else
            local respawnStrategies = Table(BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES)
                :sort(function(a, b) return a.order < b.order end)
                :map(function(el) return el.key end)
            local disabledSuffix = string.var(", {1}", { BJI_Lang.get("common.disabled") })
            if #rawRaces <= BJI_Win_Selection.LIMIT_ELEMS_THRESHOLD then
                -- sub elems
                table.insert(elems, {
                    type = "menu",
                    label = BJI_Lang.get("menu.scenario.race.title"),
                    elems = rawRaces:map(function(race)
                        return {
                            type = "item",
                            label = string.var("{1} ({2}{3})", {
                                race.name,
                                BJI_Lang.get("races.preparation.places")
                                    :var({ places = race.places }),
                                race.enabled and "" or disabledSuffix,
                            }),
                            onClick = function()
                                BJI_Win_RaceSettings.open({
                                    multi = true,
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
                table.insert(elems, {
                    type = "item",
                    label = BJI_Lang.get("menu.scenario.race.title"),
                    onClick = function()
                        BJI_Win_Selection.open("menu.scenario.race.title", rawRaces
                            :map(function(race)
                                return {
                                    label = string.var("{1} ({2}{3})", {
                                        race.name,
                                        BJI_Lang.get("races.preparation.places")
                                            :var({ places = race.places }),
                                        race.enabled and "" or disabledSuffix,
                                    }),
                                    value = race.id
                                }
                            end):sort(function(a, b) return a.label < b.label end) or Table(), nil,
                            function(raceID)
                                rawRaces:find(function(r) return r.id == raceID end,
                                    function(race)
                                        BJI_Win_RaceSettings.open({
                                            multi = true,
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
                            end, { BJI_Perm.PERMISSIONS.VOTE_SERVER_SCENARIO })
                    end,
                })
            end
        end
    end
end

---@param ctxt TickContext
---@param elems table
local function menuHunter(ctxt, elems)
    if BJI_Context.Scenario.Data.HunterInfected then
        local potentialPlayers = BJI_Perm.getCountPlayersCanSpawnVehicle()
        local minimumParticipants = BJI_Scenario.get(BJI_Scenario.TYPES.HUNTER).MINIMUM_PARTICIPANTS
        local errorMessage = nil
        if not BJI_Context.Scenario.Data.HunterInfected or
            not BJI_Context.Scenario.Data.HunterInfected.enabledHunter then
            errorMessage = BJI_Lang.get("menu.scenario.hunter.modeDisabled")
        elseif potentialPlayers < minimumParticipants then
            errorMessage = BJI_Lang.get("errors.missingPlayers"):var({
                amount = minimumParticipants - potentialPlayers
            })
        end

        if errorMessage then
            table.insert(elems, {
                type = "custom",
                render = function()
                    Text(BJI_Lang.get("menu.scenario.hunter.start"),
                        { color = BJI.Utils.Style.TEXT_COLORS.DISABLED })
                    TooltipText(errorMessage)
                end
            })
        else
            table.insert(elems, {
                type = "item",
                label = BJI_Lang.get("menu.scenario.hunter.start"),
                active = BJI_Win_HunterSettings.show,
                onClick = function()
                    if BJI_Win_HunterSettings.show then
                        BJI_Win_HunterSettings.onClose()
                    else
                        BJI_Win_HunterSettings.open()
                    end
                end,
            })
        end
    end
end

---@param ctxt TickContext
---@param elems table
local function menuInfected(ctxt, elems)
    if BJI_Context.Scenario.Data.HunterInfected then
        local potentialPlayers = BJI_Perm.getCountPlayersCanSpawnVehicle()
        local minimumParticipants = BJI_Scenario.get(BJI_Scenario.TYPES.INFECTED).MINIMUM_PARTICIPANTS
        local errorMessage = nil
        if not BJI_Context.Scenario.Data.HunterInfected or
            not BJI_Context.Scenario.Data.HunterInfected.enabledInfected then
            errorMessage = BJI_Lang.get("menu.scenario.infected.modeDisabled")
        elseif potentialPlayers < minimumParticipants then
            errorMessage = BJI_Lang.get("errors.missingPlayers"):var({
                amount = minimumParticipants - potentialPlayers
            })
        end

        if errorMessage then
            table.insert(elems, {
                type = "custom",
                render = function()
                    Text(BJI_Lang.get("menu.scenario.infected.start"),
                        { color = BJI.Utils.Style.TEXT_COLORS.DISABLED })
                    TooltipText(errorMessage)
                end
            })
        else
            table.insert(elems, {
                type = "item",
                label = BJI_Lang.get("menu.scenario.infected.start"),
                active = BJI_Win_InfectedSettings.show,
                onClick = function()
                    if BJI_Win_InfectedSettings.show then
                        BJI_Win_InfectedSettings.onClose()
                    else
                        BJI_Win_InfectedSettings.open()
                    end
                end,
            })
        end
    end
end

---@param ctxt TickContext
---@param elems table
local function menuDerby(ctxt, elems)
    if BJI_Context.Scenario.Data.Derby then
        local rawArenas = Table(BJI_Context.Scenario.Data.Derby)
            :filter(function(arena) return arena.enabled end)

        local potentialPlayers = BJI_Perm.getCountPlayersCanSpawnVehicle()
        local minimumParticipants = BJI_Scenario.get(BJI_Scenario.TYPES.DERBY).MINIMUM_PARTICIPANTS
        local errorMessage = nil
        if #rawArenas == 0 then
            errorMessage = BJI_Lang.get("menu.scenario.derby.noArena")
        elseif potentialPlayers < minimumParticipants then
            errorMessage = BJI_Lang.get("errors.missingPlayers"):var({
                amount = minimumParticipants - potentialPlayers
            })
        end

        if errorMessage then
            table.insert(elems, {
                type = "custom",
                render = function()
                    Text(BJI_Lang.get("menu.scenario.derby.start"),
                        { color = BJI.Utils.Style.TEXT_COLORS.DISABLED })
                    TooltipText(errorMessage)
                end
            })
        else
            if #rawArenas <= BJI_Win_Selection.LIMIT_ELEMS_THRESHOLD then
                -- sub elems
                table.insert(elems, {
                    type = "menu",
                    label = BJI_Lang.get("menu.scenario.derby.start"),
                    elems = rawArenas:map(function(arena, iArena)
                        return {
                            type = "item",
                            label = string.var("{1} ({2})", { arena.name,
                                BJI_Lang.get("derby.settings.places")
                                    :var({ places = #arena.startPositions })
                            }),
                            onClick = function()
                                BJI_Win_DerbySettings.open(iArena)
                            end
                        }
                    end):sort(function(a, b)
                        return a.label < b.label
                    end)
                })
            else
                -- selection window
                table.insert(elems, {
                    type = "item",
                    label = BJI_Lang.get("menu.scenario.derby.start"),
                    onClick = function()
                        BJI_Win_Selection.open("menu.scenario.derby.start", rawArenas:map(function(arena, iArena)
                            return {
                                label = string.var("{1} ({2})", { arena.name,
                                    BJI_Lang.get("derby.settings.places")
                                        :var({ places = #arena.startPositions })
                                }),
                                value = iArena,
                            }
                        end), nil, function(iArena)
                            BJI_Win_DerbySettings.open(iArena)
                        end, { BJI_Perm.PERMISSIONS.START_SERVER_SCENARIO })
                    end,
                })
            end
        end
    end
end

C.menuRace = menuRace
C.menuHunter = menuHunter
C.menuInfected = menuInfected
C.menuDerby = menuDerby

return C