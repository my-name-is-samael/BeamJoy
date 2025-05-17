---@class BJIWindowRacesLeaderboard : BJIWindow
local W = {
    name = "RacesLeaderboard",
    w = 530,
    h = 320,

    show = false,
    data = {
        hasPBs = false,
        PBsWidth = 0,
        namesWidth = 0,
        amountPBs = 0,
        leaderboardCols = {},
    },

    labels = {
        vSeparator = "",
        amountPBs = "",
        removeAllPBsButton = "",
        pb = "",
    }
}

local function onClose()
    W.show = false
end

local function updateLabels()
    W.labels.vSeparator = BJI.Managers.Lang.get("common.vSeparator")
    W.labels.amountPBs = string.var("{1} :", { BJI.Managers.Lang.get("races.leaderboard.amountPBs") })
    W.labels.removeAllPBsButton = BJI.Managers.Lang.get("races.leaderboard.removeAllPBsButton")
    W.labels.pb = string.var("{1} :", { BJI.Managers.Lang.get("races.leaderboard.pb") })
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI.Managers.Tick.getContext()

    W.data.hasPBs = false
    W.data.amountPBs = 0
    table.forEach(BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.VALUES.RACES_PB) or {},
        ---@param mapPBs table<string, MapRacePBWP[]>
        function(mapPBs)
            W.data.amountPBs = W.data.amountPBs + table.length(mapPBs)
        end)

    W.data.PBsWidth = BJI.Utils.Common.GetColumnTextWidth(W.labels.pb .. "   " .. HELPMARKER_TEXT) + GetIconSize()
    W.data.namesWidth = 0
    W.data.leaderboardCols = Table(BJI.Managers.Context.Scenario.Data.Races):clone()
        :filter(function(map)
            return type(map) == "table"
        end)
        :map(function(race)
            local res = {
                id = race.id,
                name = race.name,
                hash = race.hash,
                record = race.record and table.clone(race.record) or nil,
            }
            if race.record then
                local pb = BJI.Managers.RaceWaypoint.getPB(race.hash)
                if pb then
                    W.data.hasPBs = true
                    res.pb = pb
                end
            end
            return res
        end)
        :map(function(race)
            local w = BJI.Utils.Common.GetColumnTextWidth(race.name)
            if w > W.data.namesWidth then
                W.data.namesWidth = w
            end
            local cells = {
                function()
                    LineBuilder()
                        :text(race.name,
                            (race.record and race.record.playerName == ctxt.user.playerName) and
                            BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or
                            BJI.Utils.Style.TEXT_COLORS.DEFAULT)
                        :build()
                end
            }
            if W.data.hasPBs then
                table.insert(cells, function()
                    if not race.record then
                        return
                    end
                    local pb, pbTime = BJI.Managers.RaceWaypoint.getPB(race.hash)
                    if pb then
                        LineBuilder()
                            :text(W.labels.pb)
                            :helpMarker(BJI.Utils.Common.RaceDelay(pbTime or 0))
                            :btnIcon({
                                id = string.var("removePb-{1}", { race.id }),
                                icon = ICONS.delete_forever,
                                style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                                onClick = function()
                                    BJI.Managers.Popup.createModal(
                                        string.var(BJI.Managers.Lang.get("races.leaderboard.removePBModal"),
                                            { raceName = race.name }), {
                                            {
                                                label = BJI.Managers.Lang.get("common.buttons.cancel"),
                                            },
                                            {
                                                label = BJI.Managers.Lang.get("common.buttons.confirm"),
                                                onClick = function()
                                                    BJI.Managers.RaceWaypoint.setPB(race.hash)
                                                    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.RACE_NEW_PB, {
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
                if race.record then
                    LineLabel(string.var("{time} - {playerName} - {model}", {
                            time = BJI.Utils.Common.RaceDelay(race.record.time),
                            playerName = race.record.playerName,
                            model = BJI.Managers.Veh.getModelLabel(race.record.model)
                        }),
                        race.record.playerName == ctxt.user.playerName and
                        BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or
                        BJI.Utils.Style.TEXT_COLORS.DEFAULT)
                else
                    LineLabel("/")
                end
            end)
            return {
                cells = cells,
                name = race.name,
            }
        end):values()
        :sort(function(a, b)
            if a.name:find(b.name) then
                return false
            elseif b.name:find(a.name) then
                return true
            end
            return a.name < b.name
        end)
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, function(ctxt)
        updateLabels()
        updateCache(ctxt)
    end))

    updateCache()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.CACHE_LOADED,
        BJI.Managers.Events.EVENTS.RACE_NEW_PB,
        BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, function(ctxt, data)
        if data._event ~= BJI.Managers.Events.EVENTS.CACHE_LOADED or
            data.cache == BJI.Managers.Cache.CACHES.RACES then
            updateCache(ctxt)
        end
    end))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

local function header()
    if W.data.amountPBs > 0 then
        LineBuilder()
            :text(W.labels.amountPBs)
            :text(W.data.amountPBs, BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT)
            :text(W.labels.vSeparator)
            :btn({
                id = "btnRemoveAllPbs",
                label = W.labels.removeAllPBsButton,
                style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                onClick = function()
                    BJI.Managers.Popup.createModal(
                        BJI.Managers.Lang.get("races.leaderboard.removeAllPBsModal"), {
                            {
                                label = BJI.Managers.Lang.get("common.buttons.cancel"),
                            },
                            {
                                label = BJI.Managers.Lang.get("common.buttons.confirm"),
                                onClick = function()
                                    BJI.Managers.LocalStorage.set(BJI.Managers.LocalStorage.VALUES.RACES_PB, {})
                                    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.RACE_NEW_PB, {})
                                end
                            }
                        })
                end,
            })
    end
end

local function body()
    local widths = { W.data.namesWidth, -1 }
    if W.data.hasPBs then
        widths = { W.data.namesWidth, W.data.PBsWidth, -1 }
    end
    local cols = ColumnsBuilder("BJIRacesLeaderboard", widths)
    table.forEach(W.data.leaderboardCols, function(el)
        cols:addRow(el)
    end)
    cols:build()
end

W.onLoad = onLoad
W.onUnload = onUnload

W.header = header
W.body = body
W.onClose = onClose
W.getState = function()
    return W.show
end

return W
