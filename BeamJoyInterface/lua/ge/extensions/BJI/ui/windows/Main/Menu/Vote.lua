local M = {
    cache = {
        label = "",
        ---@type MenuDropdownElement[]
        elems = {},
    },
}

local function menuMap(ctxt)
    if BJI.Managers.Votes.Map.canStartVote() then
        local rawMaps = Table(BJI.Managers.Context.Maps):filter(function(m)
            return m.enabled
        end)
        if table.length(rawMaps) > 1 then
            local maps = {}
            local customMapLabel = BJI.Managers.Lang.get("menu.vote.map.custom")
            if table.length(rawMaps) - 1 <= BJI.Windows.Selection.LIMIT_ELEMS_THRESHOLD then
                -- sub menu
                maps = rawMaps:map(function(map, mapName)
                    return {
                        type = "item",
                        label = map.custom and string.var("{1} ({2})", { map.label, customMapLabel }) or map.label,
                        active = BJI.Managers.Context.UI.mapName == tostring(mapName),
                        disabled = BJI.Managers.Context.UI.mapName == tostring(mapName),
                        onClick = function()
                            BJI.Tx.vote.MapStart(tostring(mapName))
                        end
                    }
                end):sort(function(a, b)
                    return a.label:lower() < b.label:lower()
                end)
                table.insert(M.cache.elems, {
                    type = "menu",
                    label = BJI.Managers.Lang.get("menu.vote.map.title"),
                    elems = maps
                })
            else
                -- selection window
                table.insert(M.cache.elems, {
                    type = "item",
                    label = BJI.Managers.Lang.get("menu.vote.map.title"),
                    onClick = function()
                        BJI.Windows.Selection.open("menu.vote.map.title", rawMaps
                            :filter(function(_, mapName) return BJI.Managers.Context.UI.mapName ~= mapName end)
                            :map(function(map, mapName)
                                return {
                                    label = map.custom and string.var("{1} ({2})", { map.label, customMapLabel }) or
                                        map.label,
                                    value = mapName
                                }
                            end):sort(function(a, b)
                                return a.label < b.label
                            end) or Table(), function(mapName, onClose)
                                SameLine()
                                if IconButton("voteMapValid", BJI.Utils.Icon.ICONS.event_available,
                                        { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
                                    BJI.Tx.vote.MapStart(mapName)
                                    onClose()
                                end
                                TooltipText(BJI.Managers.Lang.get("common.buttons.vote"))
                            end, nil, { BJI.Managers.Perm.PERMISSIONS.VOTE_MAP })
                    end,
                })
            end
        end
    end
end

local function menuRace(ctxt)
    if BJI.Managers.Votes.Race.canStartVote() then
        local errorMessage = nil
        local minParticipants = (BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.RACE_MULTI) or {})
            .MINIMUM_PARTICIPANTS
        local potentialPlayers = BJI.Managers.Perm.getCountPlayersCanSpawnVehicle()
        local rawRaces = Table(BJI.Managers.Context.Scenario.Data.Races)
            :filter(function(race) return race.enabled and race.places > 1 end)

        if #rawRaces == 0 then
            errorMessage = BJI.Managers.Lang.get("menu.vote.race.noRace")
        elseif potentialPlayers < minParticipants then
            errorMessage = BJI.Managers.Lang.get("errors.missingPlayers")
                :var({ amount = minParticipants - potentialPlayers })
        end

        if errorMessage then
            table.insert(M.cache.elems, {
                type = "custom",
                render = function()
                    Text(BJI.Managers.Lang.get("menu.vote.race.title"), { color = BJI.Utils.Style.TEXT_COLORS.DISABLED })
                    TooltipText(errorMessage)
                end
            })
        else
            local respawnStrategies = Table(BJI.CONSTANTS.RACES_RESPAWN_STRATEGIES)
                :sort(function(a, b) return a.order < b.order end)
                :map(function(el) return el.key end)
            local disabledSuffix = string.var(", {1}", { BJI.Managers.Lang.get("common.disabled") })
            if #rawRaces <= BJI.Windows.Selection.LIMIT_ELEMS_THRESHOLD then
                -- sub elems
                table.insert(M.cache.elems, {
                    type = "menu",
                    label = BJI.Managers.Lang.get("menu.vote.race.title"),
                    elems = rawRaces:map(function(race)
                        return {
                            type = "item",
                            label = string.var("{1} ({2}{3})", {
                                race.name,
                                BJI.Managers.Lang.get("races.preparation.places")
                                    :var({ places = race.places }),
                                race.enabled and "" or disabledSuffix,
                            }),
                            onClick = function()
                                BJI.Windows.RaceSettings.open({
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
                table.insert(M.cache.elems, {
                    type = "item",
                    label = BJI.Managers.Lang.get("menu.vote.race.title"),
                    onClick = function()
                        BJI.Windows.Selection.open("menu.vote.race.title", rawRaces
                            :map(function(race)
                                return {
                                    label = string.var("{1} ({2}{3})", {
                                        race.name,
                                        BJI.Managers.Lang.get("races.preparation.places")
                                            :var({ places = race.places }),
                                        race.enabled and "" or disabledSuffix,
                                    }),
                                    value = race.id
                                }
                            end):sort(function(a, b) return a.label < b.label end) or Table(), nil,
                            function(raceID)
                                rawRaces:find(function(r) return r.id == raceID end,
                                    function(race)
                                        BJI.Windows.RaceSettings.open({
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
                            end, { BJI.Managers.Perm.PERMISSIONS.VOTE_SERVER_SCENARIO })
                    end,
                })
            end
        end
    end
end

local function menuSpeed(ctxt)
    if BJI.Managers.Votes.Speed.canStartVote() then
        local potentialPlayers = BJI.Managers.Perm.getCountPlayersCanSpawnVehicle()
        local minimumParticipants = (BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.SPEED) or {})
            .MINIMUM_PARTICIPANTS or 0
        local errorMessage = nil
        if potentialPlayers < minimumParticipants then
            errorMessage = BJI.Managers.Lang.get("errors.missingPlayers"):var({
                amount = minimumParticipants - potentialPlayers
            })
        end

        if errorMessage then
            table.insert(M.cache.elems, {
                type = "custom",
                render = function()
                    Text(BJI.Managers.Lang.get("menu.vote.speed.title"), { color = BJI.Utils.Style.TEXT_COLORS.DISABLED })
                    TooltipText(errorMessage)
                end
            })
        else
            table.insert(M.cache.elems, {
                type = "item",
                label = BJI.Managers.Lang.get("menu.vote.speed.title"),
                onClick = function()
                    BJI.Tx.vote.SpeedStart(true)
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

    if not BJI.Managers.Tournament.state then
        menuMap(ctxt)

        if not BJI.Windows.ScenarioEditor.getState() then
            menuRace(ctxt)
            menuSpeed(ctxt)
        end
    end

    MenuDropdownSanitize(M.cache.elems)
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
        BJI.Managers.Events.EVENTS.TOURNAMENT_UPDATED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST
    }, updateCache, "MainMenuVote"))

    ---@param data {cache: string}
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.CACHE_LOADED, function(ctxt, data)
        if table.includes({
                BJI.Managers.Cache.CACHES.VOTE,
                BJI.Managers.Cache.CACHES.PLAYERS,
                BJI.Managers.Cache.CACHES.RACE,
                BJI.Managers.Cache.CACHES.RACES,
                BJI.Managers.Cache.CACHES.SPEED,
                BJI.Managers.Cache.CACHES.MAP,
                BJI.Managers.Cache.CACHES.MAPS,
            }, data.cache) then
            updateCache(ctxt)
        end
    end, "MainMenuVote"))
end

function M.onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

---@param ctxt TickContext
function M.draw(ctxt)
    if #M.cache.elems > 0 then
        RenderMenuDropdown(M.cache.label, M.cache.elems)
    end
end

return M
