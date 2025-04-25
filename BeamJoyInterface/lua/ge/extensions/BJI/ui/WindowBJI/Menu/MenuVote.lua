local function menuMap(ctxt, votesEntry)
    if BJIVote.Map.canStartVote() and
        BJIScenario.isFreeroam() and
        BJIContext.Maps then
        local maps = {}
        local customMapLabel = BJILang.get("menu.vote.mapCustom")
        for mapName, map in pairs(BJIContext.Maps.Data) do
            if map.enabled then
                table.insert(maps, {
                    label = map.custom and svar("{1} ({2})", { map.label, customMapLabel }) or map.label,
                    active = BJIContext.UI.mapName == mapName,
                    onClick = function()
                        if BJIContext.UI.mapName ~= mapName then
                            BJITx.votemap.start(mapName)
                        end
                    end
                })
            end
        end
        table.sort(maps, function(a, b)
            return a.label < b.label
        end)
        table.insert(votesEntry.elems, {
            label = BJILang.get("menu.vote.map"),
            elems = maps
        })
    end
end

local function menuRace(ctxt, votesEntry)
    local function openRaceVote(raceID)
        local race
        for _, r in ipairs(BJIContext.Scenario.Data.Races) do
            if r.id == raceID then
                race = r
                break
            end
        end
        if not race then
            BJIToast.error(BJILang.get("races.edit.invalidRace"))
            return
        end

        local strategies = BJIScenario.get(BJIScenario.TYPES.RACE_MULTI).RESPAWN_STRATEGIES
        local respawnStrategies = {}
        for _, rs in pairs(strategies) do
            if race.hasStand or rs ~= strategies.STAND then
                table.insert(respawnStrategies, rs)
            end
        end

        BJIContext.Scenario.RaceSettings = {
            multi = true,
            raceID = race.id,
            raceName = race.name,
            loopable = race.loopable,
            laps = 1,
            respawnStrategy = BJIScenario.get(BJIScenario.TYPES.RACE_MULTI).RESPAWN_STRATEGIES.LAST_CHECKPOINT,
            respawnStrategies = respawnStrategies,
            vehicle = nil,
            vehicleModel = ctxt.veh and ctxt.veh.jbeam or nil,
            vehicleConfig = BJIVeh.getFullConfig(ctxt.veh and ctxt.veh.partConfig or nil),
            vehicleLabel = nil,
            time = {
                label = nil,
                ToD = nil,
            },
            weather = {
                label = nil,
                keys = nil,
            },
        }
    end
    if BJIVote.Race.canStartVote() then
        local raceErrorMessage = nil
        local minParticipants = BJIScenario.get(BJIScenario.TYPES.RACE_MULTI).MINIMUM_PARTICIPANTS
        local potentialPlayers = BJIPerm.getCountPlayersCanSpawnVehicle()
        local rawRaces = {}
        if BJIContext.Scenario.Data.Races then
            for _, race in ipairs(BJIContext.Scenario.Data.Races) do
                if race.places > 1 then
                    table.insert(rawRaces, race)
                end
            end
        end
        if #rawRaces == 0 then
            raceErrorMessage = BJILang.get("menu.vote.race.noRace")
        elseif potentialPlayers < minParticipants then
            raceErrorMessage = svar(BJILang.get("menu.vote.race.missingPlayers"),
                { amount = minParticipants - potentialPlayers })
        end

        if raceErrorMessage then
            table.insert(votesEntry.elems, {
                render = function()
                    LineBuilder()
                        :text(BJILang.get("menu.vote.race.title"), TEXT_COLORS.DISABLED)
                        :text(svar("({1})", { raceErrorMessage }), TEXT_COLORS.DISABLED)
                        :build()
                end
            })
        else
            local races = {}
            for _, race in ipairs(rawRaces) do
                local disabledSuffix = ""
                if race.enabled == false then
                    disabledSuffix = svar(", {1}", { BJILang.get("common.disabled") })
                end
                table.insert(races, {
                    label = svar("{1} ({2}{3})", {
                        race.name,
                        svar(BJILang.get("races.preparation.places"),
                            { places = race.places }),
                        disabledSuffix,
                    }),
                    onClick = function()
                        openRaceVote(race.id)
                    end
                })
            end
            table.sort(races, function(a, b)
                return a.label < b.label
            end)
            table.insert(votesEntry.elems, {
                label = BJILang.get("menu.vote.race.title"),
                elems = races
            })
        end
    end
end

local function menuSpeed(ctxt, votesEntry)
    if BJIVote.Speed.canStartVote() then
        local potentialPlayers = BJIPerm.getCountPlayersCanSpawnVehicle()
        local minimumParticipants = BJIScenario.get(BJIScenario.TYPES.SPEED).MINIMUM_PARTICIPANTS
        local errorMessage = nil
        if potentialPlayers < minimumParticipants then
            errorMessage = svar(BJILang.get("menu.vote.speed.missingPlayers"), {
                amount = minimumParticipants - potentialPlayers
            })
        end

        if errorMessage then
            table.insert(votesEntry.elems, {
                render = function()
                    LineBuilder()
                        :text(BJILang.get("menu.vote.speed.title"), TEXT_COLORS.DISABLED)
                        :text(svar("({1})", { errorMessage }), TEXT_COLORS.DISABLED)
                        :build()
                end
            })
        else
            table.insert(votesEntry.elems, {
                label = BJILang.get("menu.vote.speed.title"),
                onClick = function()
                    BJITx.scenario.SpeedStart(true)
                end,
            })
        end
    end
end

return function(ctxt)
    local votesEntry = {
        label = BJILang.get("menu.vote.title"),
        elems = {}
    }

    menuMap(ctxt, votesEntry)
    menuRace(ctxt, votesEntry)
    menuSpeed(ctxt, votesEntry)

    return #votesEntry.elems > 0 and votesEntry or nil
end
