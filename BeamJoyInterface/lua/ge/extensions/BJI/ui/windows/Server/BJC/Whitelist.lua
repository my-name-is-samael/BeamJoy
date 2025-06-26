local function drawWhitelistOnlinePlayers(playerNames, labels, cache)
    LineLabel(labels.whitelist.players)
    Indent(1)
    for _, playerName in ipairs(playerNames) do
        local included = table.includes(BJI.Managers.Context.BJC.Whitelist.PlayerNames, playerName)
        LineBuilder():btnIconToggle({
            id = string.var("toggleWhitelist{1}", { playerName }),
            icon = included and BJI.Utils.Icon.ICONS.remove_circle or BJI.Utils.Icon.ICONS.add_circle,
            state = not included,
            coloredIcon = true,
            disabled = cache.disableInputs,
            tooltip = included and labels.whitelist.remove or labels.whitelist.add,
            onClick = function()
                cache.disableInputs = true
                BJI.Tx.moderation.whitelist(playerName)
            end
        }):text(playerName):build()
    end
    Indent(-1)
end

local function drawWhitelistOfflinePlayers(playerNames, labels, cache)
    LineLabel(labels.whitelist.offlinePlayers)
    Indent(1)
    for _, playerName in ipairs(playerNames) do
        LineBuilder():btnIcon({
            id = string.var("removeWhitelist{1}", { playerName }),
            icon = BJI.Utils.Icon.ICONS.remove_circle,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            coloredIcon = true,
            disabled = cache.disableInputs,
            tooltip = labels.whitelist.remove,
            onClick = function()
                cache.disableInputs = true
                BJI.Tx.moderation.whitelist(playerName)
            end
        }):text(playerName):build()
    end
    Indent(-1)
end

return function(ctxt, labels, cache)
    local canToggleWL = BJI.Managers.Perm.hasMinimumGroup(BJI.CONSTANTS.GROUP_NAMES.ADMIN)

    local line = LineBuilder():text(labels.whitelist.state)
    if canToggleWL then
        line:btnIconToggle({
            id = "toggleWhitelist",
            state = BJI.Managers.Context.BJC.Whitelist.Enabled,
            coloredIcon = true,
            disabled = cache.disableInputs,
            onClick = function()
                cache.disableInputs = true
                BJI.Tx.config.bjc("Whitelist.Enabled", not BJI.Managers.Context.BJC.Whitelist.Enabled)
                BJI.Managers.Context.BJC.Whitelist.Enabled = not BJI.Managers.Context.BJC.Whitelist.Enabled
            end
        })
    else
        line:icon({
            icon = BJI.Managers.Context.BJC.Whitelist.Enabled and BJI.Utils.Icon.ICONS.check_circle or BJI.Utils.Icon.ICONS.cancel,
            style = BJI.Managers.Context.BJC.Whitelist.Enabled and BJI.Utils.Style.BTN_PRESETS.SUCCESS or
                BJI.Utils.Style.BTN_PRESETS.ERROR,
            tooltip = BJI.Managers.Context.BJC.Whitelist.Enabled and labels.whitelist.enabled or labels.whitelist.disabled,
            coloredIcon = true,
        })
    end
    line:build()

    drawWhitelistOnlinePlayers(cache.whitelist.online, labels, cache)

    if #cache.whitelist.offline > 0 then
        drawWhitelistOfflinePlayers(cache.whitelist.offline, labels, cache)
    end
    LineLabel(labels.whitelist.addOfflinePlayer)
    local canAdd = #cache.whitelist.addName > 0 and
        not table.includes(BJI.Managers.Context.BJC.Whitelist.PlayerNames, cache.whitelist.addName)
    LineBuilder():inputString({
        id = "addWhitelistName",
        placeholder = labels.whitelist.addOfflinePlayerPlaceholder,
        value = cache.whitelist.addName,
        width = 200,
        onUpdate = function(val)
            cache.whitelist.addName = val
        end
    }):btnIcon({
        id = "addWhitelist",
        icon = BJI.Utils.Icon.ICONS.addListItem,
        style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
        disabled = not canAdd or cache.disableInputs,
        tooltip = labels.whitelist.add,
        onClick = function()
            cache.disableInputs = true
            BJI.Tx.moderation.whitelist(cache.whitelist.addName)
            cache.whitelist.addName = ""
        end
    }):build()
end
