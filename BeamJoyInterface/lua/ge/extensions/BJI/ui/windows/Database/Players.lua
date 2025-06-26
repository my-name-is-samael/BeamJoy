local W = {
    labels = {
        loading = "",
        unknown = "",
        yes = "",
        no = "",

        playerName = "",
        group = "",
        banned = "",
        tempBanEndsIn = "",
        banReason = "",
        muted = "",
        muteReason = "",

        groups = {},
        buttons = {
            refresh = "",
            mute = "",
        },
    },
    cache = {
        ---@type tablelib<integer, table>
        players = Table(),
        ---@type tablelib<integer, {value: string, label: string}>
        playersCombo = Table(),
        ---@type {value: string, label: string}?
        selectedPlayer = nil,
        ---@type tablelib<integer, {value: string, label: string}>
        groupsCombo = Table(),
        ---@type {value: string, label: string}?
        selectedGroup = nil,

        ---@type table<string, any>
        currentPlayer = nil,

        disableInputs = false,
    },
    labelsWidth = 0,
}

local function updateLabels()
    W.labels.loading = BJI.Managers.Lang.get("common.loading")
    W.labels.unknown = BJI.Managers.Lang.get("common.unknown")
    W.labels.yes = BJI.Managers.Lang.get("common.yes")
    W.labels.no = BJI.Managers.Lang.get("common.no")

    W.labels.playerName = BJI.Managers.Lang.get("database.players.playerName")
    W.labels.group = BJI.Managers.Lang.get("database.players.group")
    W.labels.banned = BJI.Managers.Lang.get("database.players.banned")
    W.labels.tempBanEndsIn = BJI.Managers.Lang.get("database.players.tempBanEndsIn")
    W.labels.banReason = BJI.Managers.Lang.get("database.players.banReason")
    W.labels.muted = BJI.Managers.Lang.get("database.players.muted")
    W.labels.muteReason = BJI.Managers.Lang.get("database.players.muteReason")

    W.labels.groups = Table(BJI.Managers.Perm.Groups):map(function(_, gkey)
        return BJI.Managers.Lang.get(string.var("groups.{1}", { gkey }), tostring(gkey))
    end)

    W.labels.buttons.refresh = BJI.Managers.Lang.get("common.buttons.refresh")
    W.labels.buttons.mute = BJI.Managers.Lang.get("moderationBlock.buttons.mute")
end

local function updateWidths()
    W.labelsWidth = Table({
        W.labels.playerName,
        W.labels.group,
        W.labels.banned,
        W.labels.banReason,
        W.labels.muted,
        W.labels.muteReason,
    }):reduce(function(acc, l)
        local w = BJI.Utils.UI.GetColumnTextWidth(l)
        return w > acc and w or acc
    end, 0)
end

local function updatePlayerView(beammp)
    W.cache.selectedGroup = nil
    if not W.cache.players:find(function(p) return p.beammp == beammp end, function(p)
            W.cache.currentPlayer = p
            W.cache.selectedGroup = p.group
        end) then
        W.cache.currentPlayer = W.cache.players[1]
    end
end

---@param players table[]
local function updateCache(players, force)
    LogWarn("cache")
    local ctxt = BJI.Managers.Tick.getContext()

    W.cache.disableInputs = false

    W.cache.players = Table(players)
        :map(function(p)
            local pGroup = BJI.Managers.Perm.Groups[p.group]
            local pLevel = pGroup and pGroup.level or 0
            return table.assign(p, {
                readOnly = p.playerName == ctxt.user.playerName or pLevel >= ctxt.group.level,
            })
        end)

    W.cache.groupsCombo = Table(BJI.Managers.Perm.Groups)
        :filter(function(g)
            return g.level < ctxt.group.level
        end):keys()

    W.cache.playersCombo = W.cache.players:map(function(p)
        return {
            value = p.beammp,
            label = string.var("{1} ({2})", { p.playerName, p.lang }),
        }
    end):sort(function(a, b)
        return a.label:lower() < b.label:lower()
    end)
    if force and W.cache.selectedPlayer then
        W.cache.selectedPlayer = W.cache.playersCombo:find(function(pc) return pc.value == W.cache.currentPlayer.beammp end) or
            W.cache.playersCombo[1]
        updatePlayerView(W.cache.selectedPlayer.value)
    elseif not W.cache.selectedPlayer or not W.cache.playersCombo
        :find(function(pc) return pc.value == W.cache.selectedPlayer.value end) then
        W.cache.selectedPlayer = W.cache.playersCombo[1]
        updatePlayerView(W.cache.selectedPlayer.value)
    end
end

local function requestPlayersDatabase(force)
    BJI.Tx.database.playersGet(function(players)
        LogWarn("data received")
        if players then
            LogWarn("data valid")
            updateCache(players, force)
        end
    end)
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, function()
        updateLabels()
        updateWidths()
    end, W.name))

    updateWidths()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED,
    }, updateWidths, W.name))

    requestPlayersDatabase()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.DATABASE_PLAYERS_UPDATED,
    }, requestPlayersDatabase, W.name))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
    W.cache.players = Table()
    W.cache.playersCombo = Table()
    W.cache.selectedPlayer = nil
end

---@param ctxt TickContext
local function header(ctxt)
    if W.cache.players:length() == 0 then
        LineLabel(W.labels.loading)
        return
    end

    LineBuilder()
        :btnIcon({
            id = "databasePlayersRefresh",
            icon = BJI.Utils.Icon.ICONS.refresh,
            style = BJI.Utils.Style.BTN_PRESETS.INFO,
            disabled = W.cache.disableInputs,
            tooltip = W.labels.buttons.refresh,
            onClick = requestPlayersDatabase,
        })
        :inputCombo({
            id = "databasePlayerFilter",
            items = W.cache.playersCombo,
            getLabelFn = function(item)
                return item.label
            end,
            value = W.cache.selectedPlayer,
            disabled = W.cache.disableInputs,
            onChange = function(item)
                W.cache.selectedPlayer = item
                updatePlayerView(item.value)
            end,
        })
        :build()
end

---@param ctxt TickContext
local function body(ctxt)
    if not W.cache.currentPlayer then
        LineLabel(W.labels.unknown)
        return
    end

    ColumnsBuilder("databasePlayerDetail", { W.labelsWidth, -1 }):addRow({
        cells = {
            function() LineLabel(W.labels.playerName) end,
            function()
                LineLabel(string.var("{1} - {2} ({3})",
                    { W.cache.currentPlayer.beammp, W.cache.currentPlayer.playerName, W.cache.currentPlayer.lang }))
            end,
        }
    }):addRow({
        cells = {
            function() LineLabel(W.labels.group) end,
            function()
                if W.cache.currentPlayer.readOnly then
                    LineLabel(W.labels.groups[W.cache.currentPlayer.group])
                else
                    LineBuilder()
                        :inputCombo({
                            id = "databasePlayerGroup",
                            items = W.cache.groupsCombo,
                            getLabelFn = function(groupKey)
                                return W.labels.groups[groupKey]
                            end,
                            value = W.cache.selectedGroup,
                            disabled = W.cache.disableInputs,
                            onChange = function(item)
                                W.cache.disableInputs = true
                                W.cache.selectedGroup = item
                                BJI.Tx.moderation.setGroup(W.cache.currentPlayer.playerName, item)
                            end
                        })
                        :build()
                end
            end,
        }
    }):addRow({
        cells = {
            function() LineLabel(W.labels.banned) end,
            function()
                local line = LineBuilder()
                if W.cache.currentPlayer.readOnly then
                    line:text(W.cache.currentPlayer.muted and W.labels.yes or W.labels.no)
                else
                    line:btnIconToggle({
                        id = "databasePlayerBanned",
                        icon = BJI.Utils.Icon.ICONS.gavel,
                        state = W.cache.currentPlayer.banned == true or W.cache.currentPlayer.tempBanUntil ~= nil,
                        disabled = W.cache.disableInputs,
                        onClick = function()
                            W.cache.disableInputs = true
                            if W.cache.currentPlayer.banned or W.cache.currentPlayer.tempBanUntil then
                                BJI.Tx.moderation.unban(W.cache.currentPlayer.playerName)
                            else
                                BJI.Tx.moderation.ban(W.cache.currentPlayer.playerName, W.cache.currentPlayer.banReason)
                            end
                        end,
                    })
                end
                if W.cache.currentPlayer.tempBanUntil then
                    line:text(W.labels.tempBanEndsIn:var({
                        secs = BJI.Utils.UI.PrettyDelay(
                            W.cache.currentPlayer.tempBanUntil -
                            BJI.Managers.Tick.applyTimeOffset(math.floor(ctxt.now / 1000))
                        )
                    }))
                end
                line:build()
            end,
        }
    }):addRow({
        cells = {
            function()
                LineLabel(W.labels.banReason)
            end,
            function()
                if W.cache.currentPlayer.banned or
                    W.cache.currentPlayer.tempBanUntil or
                    W.cache.currentPlayer.readOnly then
                    LineLabel(W.cache.currentPlayer.banReason or "/")
                else
                    LineBuilder():inputString({
                        id = "databasePlayerBanReason",
                        value = W.cache.currentPlayer.banReason or "",
                        disabled = W.cache.disableInputs,
                        onUpdate = function(reason)
                            W.cache.currentPlayer.banReason = reason
                        end,
                    }):build()
                end
            end,
        }
    }):addRow({
        cells = {
            function() LineLabel(W.labels.muted) end,
            function()
                if W.cache.currentPlayer.readOnly then
                    LineLabel(W.cache.currentPlayer.muted and W.labels.yes or W.labels.no)
                else
                    LineBuilder()
                        :btnIconToggle({
                            id = "databasePlayerMuted",
                            icon = BJI.Utils.Icon.ICONS.mic_off,
                            state = W.cache.currentPlayer.muted == true,
                            disabled = W.cache.disableInputs,
                            tooltip = W.labels.buttons.mute,
                            onClick = function()
                                W.cache.disableInputs = true
                                BJI.Tx.moderation.mute(W.cache.currentPlayer.playerName, W.cache.currentPlayer.muteReason)
                            end
                        })
                        :build()
                end
            end,
        }
    }):addRow({
        cells = {
            function() LineLabel(W.labels.muteReason) end,
            function()
                if W.cache.currentPlayer.muted or
                    W.cache.currentPlayer.readOnly then
                    LineLabel(W.cache.currentPlayer.muteReason or "/")
                else
                    LineBuilder():inputString({
                        id = "databasePlayerMuteReason",
                        value = W.cache.currentPlayer.muteReason or "",
                        disabled = W.cache.disableInputs,
                        onUpdate = function(reason)
                            W.cache.currentPlayer.muteReason = reason
                        end,
                    }):build()
                end
            end,
        }
    }):build()
end

W.onLoad = onLoad
W.onUnload = onUnload
W.header = header
W.body = body

return W
