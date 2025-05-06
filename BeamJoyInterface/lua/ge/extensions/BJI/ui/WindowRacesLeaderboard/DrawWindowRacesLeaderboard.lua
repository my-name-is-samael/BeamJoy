local M = {
    show = false,
}

local cache = {
    hasPBs = false,
    PBsWidth = 0,
    namesWidth = 0,
    amountPBs = 0,
    leaderboardCols = {},

    labels = {
        vSeparator = "",
        amountPBs = "",
        removeAllPBsButton = "",
        pb = "",
    }
}
M.cache = cache

local function onClose()
    M.show = false
end

local function updateLabels()
    cache.labels.vSeparator = BJILang.get("common.vSeparator")
    cache.labels.amountPBs = string.var("{1} :", { BJILang.get("races.leaderboard.amountPBs") })
    cache.labels.removeAllPBsButton = BJILang.get("races.leaderboard.removeAllPBsButton")
    cache.labels.pb = string.var("{1} :", { BJILang.get("races.leaderboard.pb") })
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJITick.getContext()

    cache.hasPBs = false
    cache.amountPBs = 0
    table.forEach(BJILocalStorage.get(BJILocalStorage.VALUES.RACES_PB)[GetMapName() or BJIContext.UI.mapName] or {},
        ---@param mapPBs table<string, MapRacePBWP[]>
        function(mapPBs)
            cache.amountPBs = cache.amountPBs + table.length(mapPBs)
        end)

    cache.PBsWidth = GetColumnTextWidth(cache.labels.pb .. "   " .. HELPMARKER_TEXT) + GetIconSize()
    cache.namesWidth = 0
    cache.leaderboardCols = table.filter(table.clone(BJIContext.Scenario.Data.Races), function(race)
            return race.record
        end)
        :map(function(race)
            local res = {
                id = race.id,
                name = race.name,
                hash = race.hash,
                record = table.clone(race.record),
            }
            local pb = BJIRaceWaypoint.getPB(race.hash)
            if pb then
                cache.hasPBs = true
                res.pb = pb
            end
            return res
        end)
        :map(function(race)
            local w = GetColumnTextWidth(race.name)
            if w > cache.namesWidth then
                cache.namesWidth = w
            end
            local cells = {
                function()
                    LineBuilder()
                        :text(race.name,
                            race.record.playerName == ctxt.user.playerName and
                            TEXT_COLORS.HIGHLIGHT or
                            TEXT_COLORS.DEFAULT)
                        :build()
                end
            }
            if cache.hasPBs then
                table.insert(cells, function()
                    local pb, pbTime = BJIRaceWaypoint.getPB(race.hash)
                    if pb then
                        LineBuilder()
                            :text(cache.labels.pb)
                            :helpMarker(RaceDelay(pbTime))
                            :btnIcon({
                                id = string.var("removePb-{1}", { race.id }),
                                icon = ICONS.delete_forever,
                                style = BTN_PRESETS.ERROR,
                                onClick = function()
                                    BJIPopup.createModal(
                                        string.var(BJILang.get("races.leaderboard.removePBModal"), { raceName = race.name }), {
                                            {
                                                label = BJILang.get("common.buttons.cancel"),
                                            },
                                            {
                                                label = BJILang.get("common.buttons.confirm"),
                                                onClick = function()
                                                    BJIRaceWaypoint.setPB(race.hash)
                                                    BJIEvents.trigger(BJIEvents.EVENTS.RACE_NEW_PB, {
                                                        raceName = race.name,
                                                        raceID = race.id,
                                                        raceHash = race.hash,
                                                    })
                                                end
                                            }
                                        })
                                end,
                            })
                            :build()
                    end
                end)
            end
            table.insert(cells, function()
                LineBuilder()
                    :text(string.var("{time} - {playerName} - {model}", {
                            time = RaceDelay(race.record.time),
                            playerName = race.record.playerName,
                            model = BJIVeh.getModelLabel(race.record.model)
                        }),
                        race.record.playerName == ctxt.user.playerName and
                        TEXT_COLORS.HIGHLIGHT or
                        TEXT_COLORS.DEFAULT)
                    :build()
            end)
            return {
                cells = cells,
                name = race.name,
            }
        end):values()

    table.sort(cache.leaderboardCols, function(a, b)
        if a.name:find(b.name) then
            return false
        elseif b.name:find(a.name) then
            return true
        end
        return a.name < b.name
    end)
end

local listeners = {}
local function onLoad()
    updateLabels()
    table.insert(listeners, BJIEvents.addListener({
        BJIEvents.EVENTS.LANG_CHANGED,
        BJIEvents.EVENTS.UI_UPDATE_REQUEST,
    }, function(ctxt)
        updateLabels()
        updateCache(ctxt)
    end))

    updateCache()
    table.insert(listeners, BJIEvents.addListener({
        BJIEvents.EVENTS.CACHE_LOADED,
        BJIEvents.EVENTS.RACE_NEW_PB,
        BJIEvents.EVENTS.UI_SCALE_CHANGED,
        BJIEvents.EVENTS.UI_UPDATE_REQUEST,
    }, function(ctxt, data)
        if data._event ~= BJIEvents.EVENTS.CACHE_LOADED or
            data.cache == BJICache.CACHES.RACES then
            updateCache(ctxt)
        end
    end))
end

local function onUnload()
    table.forEach(listeners, BJIEvents.removeListener)
end

local function header()
    if cache.amountPBs > 0 then
        LineBuilder()
            :text(cache.labels.amountPBs)
            :text(cache.amountPBs, TEXT_COLORS.HIGHLIGHT)
            :text(cache.labels.vSeparator)
            :btn({
                id = "btnRemoveAllPbs",
                label = cache.labels.removeAllPBsButton,
                style = BTN_PRESETS.ERROR,
                onClick = function()
                    BJIPopup.createModal(
                        BJILang.get("races.leaderboard.removeAllPBsModal"), {
                            {
                                label = BJILang.get("common.buttons.cancel"),
                            },
                            {
                                label = BJILang.get("common.buttons.confirm"),
                                onClick = function()
                                    BJILocalStorage.set(BJILocalStorage.VALUES.RACES_PB, {})
                                    BJIEvents.trigger(BJIEvents.EVENTS.RACE_NEW_PB, {})
                                end
                            }
                        })
                end,
            })
    end
end

local function body()
    local widths = { cache.namesWidth, -1 }
    if cache.hasPBs then
        widths = { cache.namesWidth, cache.PBsWidth, -1 }
    end
    local cols = ColumnsBuilder("BJIRacesLeaderboard", widths)
    table.forEach(cache.leaderboardCols, function(el)
        cols:addRow(el)
    end)
    cols:build()
end

M.onLoad = onLoad
M.onUnload = onUnload

M.header = header
M.body = body
M.onClose = onClose

return M
