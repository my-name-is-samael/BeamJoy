---@class BJIWindowRacesLeaderboard : BJIWindow
local W = {
    name = "RacesLeaderboard",
    w = 530,
    h = 320,

    show = false,
    data = {
        amountPBs = 0,
        ---@type ColumnsBuilder?
        leaderboardCols = nil,
    },

    labels = {
        vSeparator = "",
        amountPBs = "",
        columnRace = "",
        columnPB = "",
        columnRecord = "",
        buttons = {
            removeAllPBs = "",
            remove = "",
        },
    }
}

local function onClose()
    W.show = false
end

local function updateLabels()
    W.labels.vSeparator = BJI.Managers.Lang.get("common.vSeparator")
    W.labels.amountPBs = BJI.Managers.Lang.get("races.leaderboard.amountPBs") .. " :"
    W.labels.columnRace = BJI.Managers.Lang.get("races.leaderboard.race")
    W.labels.columnPB = BJI.Managers.Lang.get("races.leaderboard.pb")
    W.labels.columnRecord = BJI.Managers.Lang.get("races.leaderboard.record")
    W.labels.buttons.removeAllPBs = BJI.Managers.Lang.get("races.leaderboard.removeAllPBsButton")
    W.labels.buttons.remove = BJI.Managers.Lang.get("common.buttons.remove")
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI.Managers.Tick.getContext()

    W.data.amountPBs = 0
    table.forEach(BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.VALUES.RACES_PB) or {},
        ---@param mapPBs table<string, MapRacePBWP[]>
        function(mapPBs)
            W.data.amountPBs = W.data.amountPBs + table.length(mapPBs)
        end)

    W.data.leaderboardCols = ColumnsBuilder("BJIRacesLeaderboard", {})
    if table.length(BJI.Managers.Context.Scenario.Data.Races) > 0 then
        local namesWidth = BJI.Utils.Common.GetColumnTextWidth(W.labels.columnRace)
        local PBsWidth = BJI.Utils.Common.GetColumnTextWidth(W.labels.columnPB)
        local cols = Table(BJI.Managers.Context.Scenario.Data.Races):filter(function(race)
                return type(race) == "table"
            end):map(function(race)
                local _, pb = BJI.Managers.RaceWaypoint.getPB(race.hash)
                local res = {
                    id = race.id,
                    name = race.name,
                    hash = race.hash,
                    pb = pb,
                    record = race.record and table.clone(race.record) or nil,
                }
                return res
            end):map(function(race)
                local w = BJI.Utils.Common.GetColumnTextWidth(race.name)
                if w > namesWidth then
                    namesWidth = w
                end

                local pbLabel = ""
                if race.pb then
                    pbLabel = BJI.Utils.Common.RaceDelay(race.pb or 0)
                    w = BJI.Utils.Common.GetColumnTextWidth(pbLabel)
                    if w + GetBtnIconSize() > PBsWidth then
                        PBsWidth = w + GetBtnIconSize()
                    end
                end

                local hasRecord = race.record and race.record.playerName == ctxt.user.playerName
                local recordLabel = race.record and BJI.Utils.Common.RaceDelay(race.record.time) or ""
                return {
                    name = race.name,
                    cells = {
                        function()
                            LineLabel(race.name, hasRecord and
                                BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT)
                        end,
                        race.pb and function()
                            LineBuilder():btnIcon({
                                id = string.var("removePb-{1}", { race.id }),
                                icon = ICONS.delete_forever,
                                style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                                tooltip = W.labels.buttons.remove,
                                onClick = function()
                                    BJI.Managers.Popup.createModal(
                                        string.var(BJI.Managers.Lang.get("races.leaderboard.removePBModal"),
                                            { raceName = race.name }), {
                                            BJI.Managers.Popup.createButton(BJI.Managers.Lang.get(
                                                "common.buttons.cancel"
                                            )),
                                            BJI.Managers.Popup.createButton(BJI.Managers.Lang.get(
                                                "common.buttons.confirm"
                                            ), function()
                                                BJI.Managers.RaceWaypoint.setPB(race.hash)
                                                BJI.Managers.Events.trigger(
                                                    BJI.Managers.Events.EVENTS.RACE_NEW_PB, {
                                                        raceName = race.name,
                                                        raceID = race.id,
                                                        raceHash = race.hash,
                                                    })
                                            end),
                                        })
                                end,
                            }):text(pbLabel, BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT):build()
                        end,
                        race.record and function()
                            LineLabel(recordLabel, hasRecord and
                                BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT,
                                false,
                                race.record and string.var("{1} - {2}", { race.record.playerName,
                                    BJI.Managers.Veh.getModelLabel(race.record.model) }) or nil
                            )
                        end
                    },
                }
            end):values()
            :sort(function(a, b)
                if a.name:startswith(b.name) then
                    return false
                elseif b.name:startswith(a.name) then
                    return true
                end
                return a.name < b.name
            end)

        W.data.leaderboardCols = ColumnsBuilder("BJIRacesLeaderboard", { -1, -1, -1 }, true)
            :addRow({
                cells = {
                    function() LineLabel(W.labels.columnRace) end,
                    function() LineLabel(W.labels.columnPB) end,
                    function() LineLabel(W.labels.columnRecord) end,
                }
            }):addSeparator()
        Table(cols):forEach(function(col)
            W.data.leaderboardCols:addRow(col)
        end)
    end
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
    end, W.name .. "Labels"))

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
    end, W.name .. "Cache"))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

local function header()
    if W.data.amountPBs > 0 then
        LineBuilder():text(W.labels.amountPBs)
            :text(W.data.amountPBs, BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT)
            :text(W.labels.vSeparator)
            :btnIcon({
                id = "btnRemoveAllPbs",
                icon = ICONS.delete_forever,
                tooltip = W.labels.buttons.removeAllPBs,
                style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                onClick = function()
                    BJI.Managers.Popup.createModal(
                        BJI.Managers.Lang.get("races.leaderboard.removeAllPBsModal"), {
                            BJI.Managers.Popup.createButton(BJI.Managers.Lang.get("common.buttons.cancel")),
                            BJI.Managers.Popup.createButton(BJI.Managers.Lang.get("common.buttons.confirm"), function()
                                BJI.Managers.LocalStorage.set(BJI.Managers.LocalStorage.VALUES.RACES_PB, {})
                                BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.RACE_NEW_PB, {})
                            end),
                        })
                end,
            }):build()
    end
end

local function body()
    if W.data.leaderboardCols then
        W.data.leaderboardCols:build()
    end
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
