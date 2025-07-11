---@class BJIWindowRacesLeaderboard : BJIWindow
local W = {
    name = "RacesLeaderboard",
    minSize = ImVec2(500, 250),
    maxSize = ImVec2(600, 800),

    show = false,
    data = {
        amountPBs = 0,
        leaderboard = Table(),
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
    W.labels.vSeparator = BJI_Lang.get("common.vSeparator")
    W.labels.amountPBs = BJI_Lang.get("races.leaderboard.amountPBs") .. " :"
    W.labels.columnRace = BJI_Lang.get("races.leaderboard.race")
    W.labels.columnPB = BJI_Lang.get("races.leaderboard.pb")
    W.labels.columnRecord = BJI_Lang.get("races.leaderboard.record")
    W.labels.buttons.removeAllPBs = BJI_Lang.get("races.leaderboard.removeAllPBsButton")
    W.labels.buttons.remove = BJI_Lang.get("common.buttons.remove")
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI_Tick.getContext()

    W.data.amountPBs = 0
    table.forEach(BJI_LocalStorage.get(BJI_LocalStorage.VALUES.RACES_PB) or {},
        ---@param mapPBs table<string, MapRacePBWP[]>
        function(mapPBs)
            W.data.amountPBs = W.data.amountPBs + table.length(mapPBs)
        end)

    W.data.leaderboard = Table(BJI_Context.Scenario.Data.Races):values()
        :filter(function(race)
            return type(race) == "table"
        end):map(function(race)
            local _, pb = BJI_RaceWaypoint.getPB(race.hash)
            return {
                id = race.id,
                name = race.name,
                hash = race.hash,
                color = race.record and race.record.playerName == ctxt.user.playerName and
                    BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT,
                pb = pb and BJI.Utils.UI.RaceDelay(pb) or nil,
                record = race.record and BJI.Utils.UI.RaceDelay(race.record.time) or nil,
                recordTooltip = race.record and string.var("{1} - {2}", { race.record.playerName,
                    BJI_Veh.getModelLabel(race.record.model) }) or nil,
            }
        end):sort(function(a, b)
            if a.name:lower():startswith(b.name:lower()) then
                return false
            elseif b.name:lower():startswith(a.name:lower()) then
                return true
            end
            return a.name:lower() < b.name:lower()
        end)
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.LANG_CHANGED,
        BJI_Events.EVENTS.UI_UPDATE_REQUEST,
    }, function(ctxt)
        updateLabels()
        updateCache(ctxt)
    end, W.name .. "Labels"))

    updateCache()
    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.CACHE_LOADED,
        BJI_Events.EVENTS.RACE_NEW_PB,
        BJI_Events.EVENTS.UI_SCALE_CHANGED,
        BJI_Events.EVENTS.UI_UPDATE_REQUEST,
    }, function(ctxt, data)
        if data._event ~= BJI_Events.EVENTS.CACHE_LOADED or
            data.cache == BJI_Cache.CACHES.RACES then
            updateCache(ctxt)
        end
    end, W.name .. "Cache"))
end

local function onUnload()
    listeners:forEach(BJI_Events.removeListener)
end

local function header()
    if W.data.amountPBs > 0 then
        Text(W.labels.amountPBs)
        SameLine()
        Text(W.data.amountPBs, { color = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT })
        SameLine()
        Text(W.labels.vSeparator)
        SameLine()
        if IconButton("btnRemoveAllPbs", BJI.Utils.Icon.ICONS.delete_forever,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
            BJI_Popup.createModal(
                BJI_Lang.get("races.leaderboard.removeAllPBsModal"), {
                    BJI_Popup.createButton(BJI_Lang.get("common.buttons.cancel")),
                    BJI_Popup.createButton(BJI_Lang.get("common.buttons.confirm"), function()
                        BJI_LocalStorage.set(BJI_LocalStorage.VALUES.RACES_PB, {})
                        BJI_Events.trigger(BJI_Events.EVENTS.RACE_NEW_PB, {})
                    end),
                })
        end
        TooltipText(W.labels.buttons.removeAllPBs)
    end
end

local function body()
    if #W.data.leaderboard > 0 then
        if BeginTable("BJIRacesLeaderboard", {
                { label = W.labels.columnRace .. "##racesleaderboard-label" },
                { label = W.labels.columnPB .. "##racesleaderboard-pb" },
                { label = W.labels.columnRecord .. "##racesleaderboard-record",
                    flags = { TABLE_COLUMNS_FLAGS.NO_RESIZE, TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
            }, { showHeader = true, flags = { TABLE_FLAGS.RESIZABLE } }) then
            W.data.leaderboard:forEach(function(el)
                TableNewRow()
                Text(el.name, { color = el.color })
                TableNextColumn()
                if el.pb then
                    if IconButton("remove-pb-" .. tostring(el.id), BJI.Utils.Icon.ICONS.delete_forever,
                            { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
                        BJI_Popup.createModal(
                            string.var(BJI_Lang.get("races.leaderboard.removePBModal"),
                                { raceName = el.name }), {
                                BJI_Popup.createButton(BJI_Lang.get(
                                    "common.buttons.cancel"
                                )),
                                BJI_Popup.createButton(BJI_Lang.get(
                                    "common.buttons.confirm"
                                ), function()
                                    BJI_RaceWaypoint.setPB(el.hash)
                                    BJI_Events.trigger(
                                        BJI_Events.EVENTS.RACE_NEW_PB, {
                                            raceName = el.name,
                                            raceID = el.id,
                                            raceHash = el.hash,
                                        })
                                end),
                            })
                    end
                    TooltipText(W.labels.buttons.remove)
                    SameLine()
                    Text(el.pb, { color = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT })
                end
                TableNextColumn()
                if el.record then
                    Text(el.record, { color = el.color })
                    TooltipText(el.recordTooltip)
                end
            end)
            EndTable()
        end
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
