local M = {
    cache = {
        label = "",
        ---@type MenuDropdownElement[]
        elems = {},
    },
}

local function menuMap(ctxt)
    if BJI_Context.Maps then
        local rawMaps = Table(BJI_Context.Maps):filter(function(m)
            return m.enabled
        end)
        if table.length(rawMaps) > 1 then
            local maps = {}
            local customMapLabel = BJI_Lang.get("menu.vote.map.custom")
            if table.length(rawMaps) - 1 <= BJI_Win_Selection.LIMIT_ELEMS_THRESHOLD then
                -- sub menu
                maps = rawMaps:map(function(map, mapName)
                    return {
                        type = "item",
                        label = map.custom and string.var("{1} ({2})", { map.label, customMapLabel }) or map.label,
                        active = BJI_Context.UI.mapName == tostring(mapName),
                        disabled = BJI_Context.UI.mapName == tostring(mapName),
                        onClick = function()
                            BJI_Tx_vote.MapStart(tostring(mapName))
                        end
                    }
                end):sort(function(a, b)
                    return a.label:lower() < b.label:lower()
                end)
                table.insert(M.cache.elems, {
                    type = "menu",
                    label = BJI_Lang.get("menu.vote.map.title"),
                    elems = maps
                })
            else
                -- selection window
                table.insert(M.cache.elems, {
                    type = "item",
                    label = BJI_Lang.get("menu.vote.map.title"),
                    onClick = function()
                        BJI_Win_Selection.open("menu.vote.map.title", rawMaps
                            :filter(function(_, mapName) return BJI_Context.UI.mapName ~= mapName end)
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
                                    BJI_Tx_vote.MapStart(mapName)
                                    onClose()
                                end
                                TooltipText(BJI_Lang.get("common.buttons.vote"))
                            end, nil, { BJI_Perm.PERMISSIONS.VOTE_MAP })
                    end,
                })
            end
        end
    end
end

local function menuSpeed(ctxt)
    local potentialPlayers = BJI_Perm.getCountPlayersCanSpawnVehicle()
    local minimumParticipants = (BJI_Scenario.get(BJI_Scenario.TYPES.SPEED) or {})
        .MINIMUM_PARTICIPANTS or 0
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
                Text(BJI_Lang.get("menu.vote.speed.title"), { color = BJI.Utils.Style.TEXT_COLORS.DISABLED })
                TooltipText(errorMessage)
            end
        })
    else
        table.insert(M.cache.elems, {
            type = "item",
            label = BJI_Lang.get("menu.vote.speed.title"),
            onClick = function()
                BJI_Tx_vote.ScenarioStart(BJI_Votes.SCENARIO_TYPES.SPEED, true)
            end,
        })
    end
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI_Tick.getContext()
    M.cache = {
        label = BJI_Lang.get("menu.vote.title"),
        elems = {},
    }

    if not BJI_Tournament.state and
        not BJI_Votes.Map.started() and
        not BJI_Votes.Scenario.started() and
        BJI_Scenario.isFreeroam() then
        if BJI_Votes.Map.canStartVote() then
            menuMap(ctxt)
        end

        if not BJI_Win_ScenarioEditor.getState() and
            BJI_Votes.Scenario.canStartVote() then
            menuSpeed(ctxt)
            if not BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.START_SERVER_SCENARIO) then
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
    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.SCENARIO_CHANGED,
        BJI_Events.EVENTS.PERMISSION_CHANGED,
        BJI_Events.EVENTS.LANG_CHANGED,
        BJI_Events.EVENTS.SCENARIO_UPDATED,
        BJI_Events.EVENTS.SCENARIO_EDITOR_UPDATED,
        BJI_Events.EVENTS.TOURNAMENT_UPDATED,
        BJI_Events.EVENTS.VOTE_UPDATED,
        BJI_Events.EVENTS.UI_UPDATE_REQUEST
    }, updateCache, "MainMenuVote"))

    ---@param data {cache: string}
    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.CACHE_LOADED, function(ctxt, data)
        if table.includes({
                BJI_Cache.CACHES.VOTE,
                BJI_Cache.CACHES.PLAYERS,
                BJI_Cache.CACHES.RACE,
                BJI_Cache.CACHES.RACES,
                BJI_Cache.CACHES.SPEED,
                BJI_Cache.CACHES.MAP,
                BJI_Cache.CACHES.MAPS,
            }, data.cache) then
            updateCache(ctxt)
        end
    end, "MainMenuVote"))
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
