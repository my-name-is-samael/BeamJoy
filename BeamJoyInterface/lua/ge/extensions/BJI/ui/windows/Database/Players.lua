local W = {
    labels = {
        loading = "",
        unknown = "",
        yes = "",
        no = "",

        playerName = "",
        group = "",
        lastKickReason = "",
        banned = "",
        tempBanEndsIn = "",
        banReason = "",
        lastBanReason = "",
        muted = "",
        muteReason = "",
        lastMuteReason = "",

        groups = {},
        buttons = {
            refresh = "",
            filterTooltip = "",
            ban = "",
            unban = "",
            mute = "",
        },
    },
    enableFilter = false,
    filter = "",
    cache = {
        ---@type tablelib<string, table> index beammp
        players = Table(),
        ---@type tablelib<integer, {value: string, label: string}> index 1-N
        playersCombo = Table(),
        ---@type string?
        selectedPlayer = nil,
        ---@type tablelib<integer, {value: string, label: string}> index 1-N
        groupsCombo = Table(),
        ---@type string?
        selectedGroup = nil,

        ---@type table<string, any>
        currentPlayer = nil,

        disableInputs = false,
    },
}
--- gc prevention
local nextValue, isBanned

local function updateLabels()
    W.labels.loading = BJI_Lang.get("common.loading")
    W.labels.unknown = BJI_Lang.get("common.unknown")
    W.labels.yes = BJI_Lang.get("common.yes")
    W.labels.no = BJI_Lang.get("common.no")

    W.labels.playerName = BJI_Lang.get("database.players.playerName")
    W.labels.group = BJI_Lang.get("database.players.group")
    W.labels.lastKickReason = BJI_Lang.get("database.players.lastKickReason")
    W.labels.banned = BJI_Lang.get("database.players.banned")
    W.labels.tempBanEndsIn = BJI_Lang.get("database.players.tempBanEndsIn")
    W.labels.banReason = BJI_Lang.get("database.players.banReason")
    W.labels.lastBanReason = BJI_Lang.get("database.players.lastBanReason")
    W.labels.muted = BJI_Lang.get("database.players.muted")
    W.labels.muteReason = BJI_Lang.get("database.players.muteReason")
    W.labels.lastMuteReason = BJI_Lang.get("database.players.lastMuteReason")

    W.labels.groups = Table(BJI_Perm.Groups):map(function(_, gkey)
        return BJI_Lang.get(string.var("groups.{1}", { gkey }), tostring(gkey))
    end)

    W.labels.buttons.refresh = BJI_Lang.get("common.buttons.refresh")
    W.labels.buttons.filterTooltip = BJI_Lang.get("database.players.filterTooltip")
    W.labels.buttons.ban = BJI_Lang.get("moderationBlock.buttons.ban")
    W.labels.buttons.unban = BJI_Lang.get("database.players.unban")
    W.labels.buttons.mute = BJI_Lang.get("moderationBlock.buttons.mute")
end

---@param ctxt TickContext
---@param beammp string
local function updatePlayerView(ctxt, beammp)
    W.cache.selectedPlayer = beammp
    W.cache.selectedGroup = nil
    if W.cache.players[beammp] then
        W.cache.currentPlayer = W.cache.players[beammp]
        W.cache.selectedGroup = W.cache.players[beammp].group
    else
        W.cache.currentPlayer = W.cache.playersCombo[1].value
    end
    if W.cache.currentPlayer then
        W.cache.currentPlayer.inputBanReason = ""
        W.cache.currentPlayer.inputMuteReason = ""
    end
end

local function updateGroupsCombo(ctxt)
    W.cache.groupsCombo = Table(BJI_Perm.Groups)
        :filter(function(g)
            return g.level < ctxt.group.level
        end):map(function(g, gkey)
            return {
                value = gkey,
                label = W.labels.groups[gkey] or gkey,
            }
        end):values():sort(function(a, b)
            if not a.value or not b.value then
                return not a.value
            end
            return BJI_Perm.Groups[a.value].level < BJI_Perm.Groups[b.value].level
        end)
end

---@param ctxt TickContext?
---@param force boolean?
local function updatePlayersCombo(ctxt, force)
    ctxt = ctxt or BJI_Tick.getContext()
    W.cache.playersCombo = W.cache.players:map(function(p, beammp)
        return {
            value = beammp,
            label = string.var("{1} ({2})", { p.playerName, p.lang }),
            playerName = p.playerName,
        }
    end):values():sort(function(a, b)
        return a.label:lower() < b.label:lower()
    end)
    if W.enableFilter and #W.filter > 0 then
        W.cache.playersCombo = W.cache.playersCombo:filter(function(p)
            return p.playerName:lower():find(W.filter:lower())
        end)
    end
    if force and W.cache.selectedPlayer then
        updatePlayerView(ctxt, (W.cache.playersCombo:find(function(pc)
            return pc.value == W.cache.currentPlayer.beammp
        end) or W.cache.playersCombo[1]).value)
    elseif not W.cache.selectedPlayer or not W.cache.playersCombo
        :find(function(option) return option.value == W.cache.selectedPlayer end) then
        updatePlayerView(ctxt, W.cache.playersCombo[1].value)
    end
end

---@param players table[]
---@param force boolean?
local function updateCache(players, force)
    local ctxt = BJI_Tick.getContext()

    W.cache.disableInputs = false

    W.cache.players = Table(players)
        :map(function(p)
            local pGroup = BJI_Perm.Groups[p.group]
            local pLevel = pGroup and pGroup.level or 0
            return table.assign(p, {
                readOnly = p.playerName == ctxt.user.playerName or pLevel >= ctxt.group.level,
            })
        end):reduce(function(res, p)
            res[p.beammp] = p
            return res
        end, Table())

    updatePlayersCombo(ctxt, force)

    updateGroupsCombo(ctxt)
end

local function requestPlayersDatabase(force)
    BJI_Tx_database.playersGet(function(players)
        if players then
            updateCache(players, force)
        end
    end)
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.LANG_CHANGED, updateLabels, W.name))

    requestPlayersDatabase()
    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.DATABASE_PLAYERS_UPDATED,
    }, requestPlayersDatabase, W.name))

    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.PERMISSION_CHANGED, function()
        requestPlayersDatabase(true)
    end, W.name))
end

local function onUnload()
    listeners:forEach(BJI_Events.removeListener)
    W.cache.players = Table()
    W.cache.playersCombo = Table()
    W.cache.selectedPlayer = nil
end

---@param ctxt TickContext
local function header(ctxt)
    if W.cache.players:length() == 0 then
        Text(W.labels.loading)
        return
    end

    if BeginTable("BJIDatabasePlayersHeader", {
            { label = "##databaseplayersheader-filter", flags = { W.enableFilter and TABLE_COLUMNS_FLAGS.WIDTH_STRETCH or nil } },
            { label = "##databaseplayersheader-combo",  flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        TableNewRow()
        if IconButton("databasePlayersRefresh", BJI.Utils.Icon.ICONS.refresh,
                { disabled = W.cache.disableInputs }) then
            requestPlayersDatabase()
        end
        TooltipText(W.labels.buttons.refresh)
        SameLine()
        if IconButton("databasePlayersFilterToggle", BJI.Utils.Icon.ICONS.ab_filter_default,
                { disabled = W.cache.disableInputs, btnStyle = W.enableFilter and
                    BJI.Utils.Style.BTN_PRESETS.ERROR or BJI.Utils.Style.BTN_PRESETS.INFO }) then
            if W.enableFilter and #W.filter > 0 then
                W.filter = ""
            else
                W.enableFilter = not W.enableFilter
            end
            updatePlayersCombo(ctxt)
        end
        TooltipText(W.labels.buttons.filterTooltip)
        if W.enableFilter then
            SameLine()
            nextValue = InputText("databasePlayersFilter", W.filter,
                { disabled = W.cache.disableInputs })
            TooltipText(W.labels.buttons.filterTooltip)
            if nextValue then
                W.filter = nextValue
                updatePlayersCombo(ctxt)
            end
        end
        TableNextColumn()
        nextValue = Combo("databasePlayers", W.cache.selectedPlayer, W.cache.playersCombo,
            { width = -1, disabled = W.cache.disableInputs })
        if nextValue then
            updatePlayerView(ctxt, nextValue)
        end

        EndTable()
    end
end

---@param ctxt TickContext
local function body(ctxt)
    if not W.cache.currentPlayer then
        Text(W.labels.unknown)
        return
    end

    if BeginTable("BJIDatabasePlayersDetail", {
            { label = "##databaseplayersdetail-labels" },
            { label = "##databaseplayersdetail-values", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        TableNewRow()
        Text(W.labels.playerName)
        TableNextColumn()
        Text(string.format("%s - %s (%s)",
            W.cache.currentPlayer.beammp,
            W.cache.currentPlayer.playerName,
            W.cache.currentPlayer.lang))

        TableNewRow()
        Text(W.labels.group)
        TableNextColumn()
        if W.cache.currentPlayer.readOnly then
            Text(W.labels.groups[W.cache.currentPlayer.group])
        else
            nextValue = Combo("databasePlayerGroup", W.cache.selectedGroup,
                W.cache.groupsCombo, { disabled = W.cache.disableInputs })
            if nextValue then
                W.cache.disableInputs = true
                W.cache.selectedGroup = nextValue
                BJI_Tx_moderation.setGroup(W.cache.currentPlayer.playerName, W.cache.selectedGroup)
            end
        end

        if W.cache.currentPlayer.kickReason and #W.cache.currentPlayer.kickReason > 0 then
            TableNewRow()
            Text(W.labels.lastKickReason)
            TableNextColumn()
            Text(W.cache.currentPlayer.kickReason)
        end

        TableNewRow()
        Text(W.labels.banned)
        TableNextColumn()
        if W.cache.currentPlayer.readOnly then
            Text(W.cache.currentPlayer.banned and W.labels.yes or W.labels.no)
        else
            isBanned = W.cache.currentPlayer.banned == true or W.cache.currentPlayer.tempBanUntil ~= nil
            if IconButton("databasePlayerBanned", BJI.Utils.Icon.ICONS.gavel, { disabled = W.cache.disableInputs,
                    btnStyle = isBanned and BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR }) then
                W.cache.disableInputs = true
                if isBanned then
                    BJI_Tx_moderation.unban(W.cache.currentPlayer.playerName)
                else
                    BJI_Tx_moderation.ban(W.cache.currentPlayer.playerName, W.cache.currentPlayer.inputBanReason)
                end
            end
            TooltipText(isBanned and W.labels.buttons.unban or W.labels.buttons.ban)
        end
        if W.cache.currentPlayer.tempBanUntil then
            SameLine()
            Text(W.labels.tempBanEndsIn:var({
                secs = BJI.Utils.UI.PrettyDelay(
                    BJI_Tick.applyTimeOffset(W.cache.currentPlayer.tempBanUntil) -
                    math.floor(ctxt.now / 1000)
                )
            }))
        end

        if W.cache.currentPlayer.readOnly or W.cache.currentPlayer.banned or
            W.cache.currentPlayer.tempBanUntil then
            if W.cache.currentPlayer.banReason and
                #W.cache.currentPlayer.banReason > 0 then
                TableNewRow()
                Text(W.cache.currentPlayer.muted and W.labels.banReason or W.labels.lastBanReason)
                TableNextColumn()
                Text(W.cache.currentPlayer.banReason)
            end
        else
            TableNewRow()
            Text(W.labels.banReason)
            TableNextColumn()
            nextValue = InputText("databasePlayerBanReason", W.cache.currentPlayer.inputBanReason,
                { disabled = W.cache.disableInputs })
            if nextValue then W.cache.currentPlayer.inputBanReason = nextValue end
            if W.cache.currentPlayer.banReason and
                #W.cache.currentPlayer.banReason > 0 then
                TableNewRow()
                Text(W.labels.lastBanReason)
                TableNextColumn()
                Text(W.cache.currentPlayer.banReason)
            end
        end

        TableNewRow()
        Text(W.labels.muted)
        TableNextColumn()
        if W.cache.currentPlayer.readOnly then
            Text(W.cache.currentPlayer.muted and W.labels.yes or W.labels.no)
        else
            if IconButton("databasePlayerMuted", BJI.Utils.Icon.ICONS.mic_off,
                    { disabled = W.cache.disableInputs, btnStyle = W.cache.currentPlayer.muted == true and
                        BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR }) then
                W.cache.disableInputs = true
                BJI_Tx_moderation.mute(W.cache.currentPlayer.playerName, W.cache.currentPlayer
                    .inputMuteReason)
            end
            TooltipText(W.labels.buttons.mute)
        end

        if W.cache.currentPlayer.readOnly or W.cache.currentPlayer.muted then
            if W.cache.currentPlayer.muteReason and
                #W.cache.currentPlayer.muteReason > 0 then
                TableNewRow()
                Text(W.cache.currentPlayer.muted and W.labels.muteReason or W.labels.lastMuteReason)
                TableNextColumn()
                Text(W.cache.currentPlayer.muteReason)
            end
        else
            TableNewRow()
            Text(W.labels.muteReason)
            TableNextColumn()
            nextValue = InputText("databasePlayerMuteReason", W.cache.currentPlayer.inputMuteReason,
                { disabled = W.cache.disableInputs })
            if nextValue then W.cache.currentPlayer.inputMuteReason = nextValue end
            if W.cache.currentPlayer.muteReason and
                #W.cache.currentPlayer.muteReason > 0 then
                TableNewRow()
                Text(W.labels.lastMuteReason)
                TableNextColumn()
                Text(W.cache.currentPlayer.muteReason)
            end
        end

        EndTable()
    end
end

W.onLoad = onLoad
W.onUnload = onUnload
W.header = header
W.body = body

return W
