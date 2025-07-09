local M = {
    cache = {
        label = "",
        ---@type MenuDropdownElement[]
        elems = {},
    },
}

local function menuMap(ctxt)
    if BJI.Managers.Context.Maps then
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

local function menuSpeed(ctxt)
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
                BJI.Tx.vote.ScenarioStart(BJI.Managers.Votes.SCENARIO_TYPES.SPEED, true)
            end,
        })
    end
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI.Managers.Tick.getContext()
    M.cache = {
        label = BJI.Managers.Lang.get("menu.vote.title"),
        elems = {},
    }

    if not BJI.Managers.Tournament.state and
        not BJI.Managers.Votes.Map.started() and
        not BJI.Managers.Votes.Scenario.started() and
        BJI.Managers.Scenario.isFreeroam() then
        if BJI.Managers.Votes.Map.canStartVote() then
            menuMap(ctxt)
        end

        if not BJI.Windows.ScenarioEditor.getState() and
            BJI.Managers.Votes.Scenario.canStartVote() then
            menuSpeed(ctxt)
            if not BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_SERVER_SCENARIO) then
                local common = require("ge/extensions/BJI/ui/windows/Main/Menu/Common")
                common.menuRace(ctxt, M.cache.elems)
                common.menuHunter(ctxt, M.cache.elems)
                common.menuDerby(ctxt, M.cache.elems)
            end
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
        BJI.Managers.Events.EVENTS.VOTE_UPDATED,
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
