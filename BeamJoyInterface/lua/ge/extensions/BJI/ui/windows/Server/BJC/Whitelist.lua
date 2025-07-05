--- gc prevention
local nextValue, included

---@param playerNames tablelib<integer, string> index 1-N
---@param labels table
---@param cache table
local function drawWhitelistOnlinePlayers(playerNames, labels, cache)
    Text(labels.whitelist.players)
    SameLine()
    if Button("addAllConnectedPlayers", labels.whitelist.addAllConnectedPlayers,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
        playerNames:forEach(function(playerName)
            if not table.includes(BJI.Managers.Context.BJC.Whitelist.PlayerNames, playerName) then
                BJI.Tx.moderation.whitelist(playerName)
            end
        end)
    end
    Indent()
    playerNames:forEach(function(playerName)
        included = table.includes(BJI.Managers.Context.BJC.Whitelist.PlayerNames, playerName)
        if IconButton("toggleWhitelist" .. playerName, included and BJI.Utils.Icon.ICONS.remove_circle or
                BJI.Utils.Icon.ICONS.add_circle, { btnStyle = included and BJI.Utils.Style.BTN_PRESETS.ERROR or
                    BJI.Utils.Style.BTN_PRESETS.SUCCESS, bgLess = true, disabled = cache.disableInputs }) then
            cache.disableInputs = true
            BJI.Tx.moderation.whitelist(playerName)
        end
        TooltipText(included and labels.buttons.remove or labels.buttons.add)
        SameLine()
        Text(playerName)
    end)
    Unindent()
end

---@param playerNames tablelib<integer, string> index 1-N
---@param labels table
---@param cache table
local function drawWhitelistOfflinePlayers(playerNames, labels, cache)
    Text(labels.whitelist.offlinePlayers)
    Indent()
    playerNames:forEach(function(playerName)
        if IconButton("toggleWhitelist" .. playerName, BJI.Utils.Icon.ICONS.remove_circle,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, bgLess = true,
                    disabled = cache.disableInputs }) then
            cache.disableInputs = true
            BJI.Tx.moderation.whitelist(playerName)
        end
        TooltipText(labels.buttons.remove)
        SameLine()
        Text(playerName)
    end)
    Unindent()
end

return function(ctxt, labels, cache)
    Text(labels.whitelist.state)
    SameLine()
    if cache.whitelist.canToggleState then
        if IconButton("toggleWhitelist", BJI.Managers.Context.BJC.Whitelist.Enabled and BJI.Utils.Icon.ICONS.check_circle or
                BJI.Utils.Icon.ICONS.cancel, { bgLess = true, btnStyle = BJI.Managers.Context.BJC.Whitelist.Enabled and
                    BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = cache.disableInputs }) then
            cache.disableInputs = true
            BJI.Tx.config.bjc("Whitelist.Enabled", not BJI.Managers.Context.BJC.Whitelist.Enabled)
            BJI.Managers.Context.BJC.Whitelist.Enabled = not BJI.Managers.Context.BJC.Whitelist.Enabled
        end
    else
        Icon(BJI.Managers.Context.BJC.Whitelist.Enabled and BJI.Utils.Icon.ICONS.check_circle or
            BJI.Utils.Icon.ICONS.cancel, {
                color = BJI.Managers.Context.BJC.Whitelist.Enabled and
                    BJI.Utils.Style.TEXT_COLORS.SUCCESS or BJI.Utils.Style.TEXT_COLORS.ERROR
            })
        TooltipText(BJI.Managers.Context.BJC.Whitelist.Enabled and labels.whitelist.enabled or
            labels.whitelist.disabled)
    end

    drawWhitelistOnlinePlayers(cache.whitelist.online, labels, cache)

    if #cache.whitelist.offline > 0 then
        drawWhitelistOfflinePlayers(cache.whitelist.offline, labels, cache)
    end
    Text(labels.whitelist.addOfflinePlayer)
    SameLine()
    local canAdd = #cache.whitelist.addName > 0 and
        not table.includes(BJI.Managers.Context.BJC.Whitelist.PlayerNames, cache.whitelist.addName)
    if IconButton("addWhitelist", BJI.Utils.Icon.ICONS.add, {
            disabled = not canAdd or cache.disableInputs, btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
        cache.disableInputs = true
        BJI.Tx.moderation.whitelist(cache.whitelist.addName)
        cache.whitelist.addName = ""
    end
    TooltipText(labels.buttons.add)
    SameLine()
    nextValue = InputText("addWhitelistName", cache.whitelist.addName)
    if nextValue then cache.whitelist.addName = nextValue end
    TooltipText(labels.whitelist.addOfflinePlayerPlaceholder)
end
