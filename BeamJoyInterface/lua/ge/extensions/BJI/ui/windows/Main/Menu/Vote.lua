local M = {
    cache = {
        label = "",
        elems = {},
    },
}

local function menuMap(ctxt)
    if BJI.Managers.Votes.Map.canStartVote() then
        local maps = {}
        local customMapLabel = BJI.Managers.Lang.get("menu.vote.map.custom")
        for mapName, map in pairs(BJI.Managers.Context.Maps) do
            if map.enabled then
                table.insert(maps, {
                    label = map.custom and string.var("{1} ({2})", { map.label, customMapLabel }) or map.label,
                    active = BJI.Managers.Context.UI.mapName == mapName,
                    onClick = function()
                        if BJI.Managers.Context.UI.mapName ~= mapName then
                            BJI.Tx.votemap.start(mapName)
                        end
                    end
                })
            end
        end
        table.sort(maps, function(a, b)
            return a.label < b.label
        end)
        table.insert(M.cache.elems, {
            label = BJI.Managers.Lang.get("menu.vote.map.title"),
            elems = maps
        })
    end
end

local function menuRace(ctxt)
    local function openRaceVote(raceID)
        local race
        for _, r in ipairs(BJI.Managers.Context.Scenario.Data.Races) do
            if r.id == raceID then
                race = r
                break
            end
        end
        if not race then
            BJI.Managers.Toast.error(BJI.Managers.Lang.get("races.edit.invalidRace"))
            return
        end

        local respawnStrategies = table.filter(BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES, function(rs)
                return race.hasStand or rs.key ~= BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.STAND.key
            end)
            :sort(function(a, b) return a.order < b.order end)
            :map(function(el) return el.key end)

        BJI.Windows.RaceSettings.open({
            multi = true,
            raceID = race.id,
            raceName = race.name,
            loopable = race.loopable,
            laps = 1,
            defaultRespawnStrategy = BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES.LAST_CHECKPOINT.key,
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
    if BJI.Managers.Votes.Race.canStartVote() then
        local raceErrorMessage = nil
        local minParticipants = (BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.RACE_MULTI) or {})
        .MINIMUM_PARTICIPANTS
        local potentialPlayers = BJI.Managers.Perm.getCountPlayersCanSpawnVehicle()
        local rawRaces = {}
        if BJI.Managers.Context.Scenario.Data.Races then
            for _, race in ipairs(BJI.Managers.Context.Scenario.Data.Races) do
                if race.places > 1 then
                    table.insert(rawRaces, race)
                end
            end
        end
        if #rawRaces == 0 then
            raceErrorMessage = BJI.Managers.Lang.get("menu.vote.race.noRace")
        elseif potentialPlayers < minParticipants then
            raceErrorMessage = BJI.Managers.Lang.get("menu.vote.race.missingPlayers")
                :var({ amount = minParticipants - potentialPlayers })
        end

        if raceErrorMessage then
            table.insert(M.cache.elems, {
                render = function()
                    LineBuilder()
                        :text(BJI.Managers.Lang.get("menu.vote.race.title"), BJI.Utils.Style.TEXT_COLORS.DISABLED)
                        :text(string.var("({1})", { raceErrorMessage }), BJI.Utils.Style.TEXT_COLORS.DISABLED)
                        :build()
                end
            })
        else
            local races = {}
            for _, race in ipairs(rawRaces) do
                local disabledSuffix = ""
                if race.enabled == false then
                    disabledSuffix = string.var(", {1}", { BJI.Managers.Lang.get("common.disabled") })
                end
                table.insert(races, {
                    label = string.var("{1} ({2}{3})", {
                        race.name,
                        BJI.Managers.Lang.get("races.preparation.places")
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
                label = BJI.Managers.Lang.get("menu.vote.race.title"),
                elems = races
            })
        end
    end
end

local function menuSpeed(ctxt)
    if BJI.Managers.Votes.Speed.canStartVote() then
        local potentialPlayers = BJI.Managers.Perm.getCountPlayersCanSpawnVehicle()
        local minimumParticipants = (BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.SPEED) or {})
        .MINIMUM_PARTICIPANTS
        local errorMessage = nil
        if potentialPlayers < minimumParticipants then
            errorMessage = BJI.Managers.Lang.get("menu.vote.speed.missingPlayers"):var({
                amount = minimumParticipants - potentialPlayers
            })
        end

        if errorMessage then
            table.insert(M.cache.elems, {
                render = function()
                    LineBuilder()
                        :text(BJI.Managers.Lang.get("menu.vote.speed.title"), BJI.Utils.Style.TEXT_COLORS.DISABLED)
                        :text(string.var("({1})", { errorMessage }), BJI.Utils.Style.TEXT_COLORS.DISABLED)
                        :build()
                end
            })
        else
            table.insert(M.cache.elems, {
                label = BJI.Managers.Lang.get("menu.vote.speed.title"),
                onClick = function()
                    BJI.Tx.scenario.SpeedStart(true)
                end,
            })
        end
    end
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI.Managers.Tick.getContext()
    M.cache = {
        label = BJI.Managers.Lang.get("menu.vote.title"),
        elems = {},
    }

    menuMap(ctxt)

    if not BJI.Windows.ScenarioEditor.getState() then
        menuRace(ctxt)
        menuSpeed(ctxt)
    end
end

local listeners = Table()
function M.onLoad()
    updateCache()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.SCENARIO_CHANGED,
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.SCENARIO_UPDATED,
        BJI.Managers.Events.EVENTS.SCENARIO_EDITOR_UPDATED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST
    }, updateCache))

    ---@param data {cache: string}
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.CACHE_LOADED, function(ctxt, data)
        if table.includes({
                BJI.Managers.Cache.CACHES.VOTE,
                BJI.Managers.Cache.CACHES.PLAYERS,
                BJI.Managers.Cache.CACHES.RACE,
                BJI.Managers.Cache.CACHES.RACES,
                BJI.Managers.Cache.CACHES.SPEED,
                BJI.Managers.Cache.CACHES.MAP,
            }, data.cache) then
            updateCache(ctxt)
        end
    end))
end

function M.onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

return M
