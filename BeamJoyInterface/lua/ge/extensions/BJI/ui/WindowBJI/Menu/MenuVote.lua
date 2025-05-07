local M = {
    cache = {
        label = "",
        elems = {},
    },
}

local function menuMap(ctxt)
    if BJIVote.Map.canStartVote() then
        local maps = {}
        local customMapLabel = BJILang.get("menu.vote.map.custom")
        for mapName, map in pairs(BJIContext.Maps.Data) do
            if map.enabled then
                table.insert(maps, {
                    label = map.custom and string.var("{1} ({2})", { map.label, customMapLabel }) or map.label,
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
        table.insert(M.cache.elems, {
            label = BJILang.get("menu.vote.map.title"),
            elems = maps
        })
    end
end

local function menuRace(ctxt)
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

        local respawnStrategies = table.filter(BJI_RACES_RESPAWN_STRATEGIES, function(rs)
                return race.hasStand or rs.key ~= BJI_RACES_RESPAWN_STRATEGIES.STAND.key
            end)
            :sort(function(a, b) return a.order < b.order end)
            :map(function(el) return el.key end)

        BJIRaceSettingsWindow.open({
            multi = true,
            raceID = race.id,
            raceName = race.name,
            loopable = race.loopable,
            laps = 1,
            defaultRespawnStrategy = BJI_RACES_RESPAWN_STRATEGIES.LAST_CHECKPOINT.key,
            respawnStrategies = respawnStrategies,
            vehicleMode = nil,
            time = {
                label = nil,
                ToD = nil,
            },
            weather = {
                label = nil,
                keys = nil,
            },
        })
    end
    if BJIVote.Race.canStartVote() then
        local raceErrorMessage = nil
        local minParticipants = (BJIScenario.get(BJIScenario.TYPES.RACE_MULTI) or {}).MINIMUM_PARTICIPANTS
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
            raceErrorMessage = BJILang.get("menu.vote.race.missingPlayers")
                :var({ amount = minParticipants - potentialPlayers })
        end

        if raceErrorMessage then
            table.insert(M.cache.elems, {
                render = function()
                    LineBuilder()
                        :text(BJILang.get("menu.vote.race.title"), TEXT_COLORS.DISABLED)
                        :text(string.var("({1})", { raceErrorMessage }), TEXT_COLORS.DISABLED)
                        :build()
                end
            })
        else
            local races = {}
            for _, race in ipairs(rawRaces) do
                local disabledSuffix = ""
                if race.enabled == false then
                    disabledSuffix = string.var(", {1}", { BJILang.get("common.disabled") })
                end
                table.insert(races, {
                    label = string.var("{1} ({2}{3})", {
                        race.name,
                        BJILang.get("races.preparation.places")
                            :var({ places = race.places }),
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
            table.insert(M.cache.elems, {
                label = BJILang.get("menu.vote.race.title"),
                elems = races
            })
        end
    end
end

local function menuSpeed(ctxt)
    if BJIVote.Speed.canStartVote() then
        local potentialPlayers = BJIPerm.getCountPlayersCanSpawnVehicle()
        local minimumParticipants = (BJIScenario.get(BJIScenario.TYPES.SPEED) or {}).MINIMUM_PARTICIPANTS
        local errorMessage = nil
        if potentialPlayers < minimumParticipants then
            errorMessage = BJILang.get("menu.vote.speed.missingPlayers"):var({
                amount = minimumParticipants - potentialPlayers
            })
        end

        if errorMessage then
            table.insert(M.cache.elems, {
                render = function()
                    LineBuilder()
                        :text(BJILang.get("menu.vote.speed.title"), TEXT_COLORS.DISABLED)
                        :text(string.var("({1})", { errorMessage }), TEXT_COLORS.DISABLED)
                        :build()
                end
            })
        else
            table.insert(M.cache.elems, {
                label = BJILang.get("menu.vote.speed.title"),
                onClick = function()
                    BJITx.scenario.SpeedStart(true)
                end,
            })
        end
    end
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJITick.getContext()
    M.cache = {
        label = BJILang.get("menu.vote.title"),
        elems = {},
    }

    menuMap(ctxt)
    menuRace(ctxt)
    menuSpeed(ctxt)
end

local listeners = {}
function M.onLoad()
    updateCache()
    table.insert(listeners, BJIEvents.addListener({
        BJIEvents.EVENTS.SCENARIO_CHANGED,
        BJIEvents.EVENTS.PERMISSION_CHANGED,
        BJIEvents.EVENTS.LANG_CHANGED,
        BJIEvents.EVENTS.SCENARIO_UPDATED,
        BJIEvents.EVENTS.UI_UPDATE_REQUEST
    }, updateCache))

    ---@param data {cache: string}
    table.insert(listeners, BJIEvents.addListener(BJIEvents.EVENTS.CACHE_LOADED, function(ctxt, data)
        if table.includes({
                BJICache.CACHES.VOTE,
                BJICache.CACHES.PLAYERS,
                BJICache.CACHES.RACE,
                BJICache.CACHES.RACES,
                BJICache.CACHES.SPEED,
                BJICache.CACHES.MAP,
            }, data.cache) then
            updateCache(ctxt)
        end
    end))
end

function M.onUnload()
    for _, id in ipairs(listeners) do
        BJIEvents.removeListener(id)
    end
end

return M
