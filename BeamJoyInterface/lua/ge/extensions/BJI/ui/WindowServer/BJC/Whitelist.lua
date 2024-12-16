local function drawWhitelistOnlinePlayers(playerNames)
    LineBuilder()
        :text(svar("{1}:", { BJILang.get("serverConfig.bjc.whitelist.players") }))
        :build()
    Indent(1)
    for _, playerName in ipairs(playerNames) do
        local included = tincludes(BJIContext.BJC.Whitelist.PlayerNames, playerName)
        LineBuilder()
            :btnIconToggle({
                id = svar("toggleWhitelist{1}", { playerName }),
                icon = included and ICONS.remove_circle or ICONS.add_circle,
                state = not included,
                coloredIcon = true,
                onClick = function()
                    BJITx.moderation.whitelist(playerName)
                    if included then
                        local pos = tpos(BJIContext.BJC.Whitelist.PlayerNames, playerName)
                        table.remove(BJIContext.BJC.Whitelist.PlayerNames, pos)
                    else
                        table.insert(BJIContext.BJC.Whitelist.PlayerNames, playerName)
                    end
                end
            })
            :text(playerName)
            :build()
    end
    Indent(-1)
end

local function drawWhitelistOfflinePlayers(playerNames)
    LineBuilder()
        :text(svar("{1}:", { BJILang.get("serverConfig.bjc.whitelist.offlinePlayers") }))
        :build()
    Indent(1)
    for _, playerName in ipairs(playerNames) do
        LineBuilder()
            :btnIcon({
                id = svar("removeWhitelist{1}", { playerName }),
                icon = ICONS.remove_circle,
                style = BTN_PRESETS.ERROR,
                coloredIcon = true,
                onClick = function()
                    BJITx.moderation.whitelist(playerName)
                    local pos = tpos(BJIContext.BJC.Whitelist.PlayerNames, playerName)
                    table.remove(BJIContext.BJC.Whitelist.PlayerNames, pos)
                end
            })
            :text(playerName)
            :build()
    end
    Indent(-1)
end

return function(ctxt)
    local canToggleWL = BJIPerm.hasMinimumGroup(BJI_GROUP_NAMES.ADMIN)

    local connectedPlayerNames = {}
    for _, player in pairs(BJIContext.Players) do
        if not player.guest then
            table.insert(connectedPlayerNames, player.playerName)
        end
    end

    local line = LineBuilder()
        :text(svar("{1}:", { BJILang.get("common.state") }))
    if canToggleWL then
        line:btnIconToggle({
            id = "toggleWhitelist",
            state = BJIContext.BJC.Whitelist.Enabled,
            coloredIcon = true,
            onClick = function()
                BJITx.config.bjc("Whitelist.Enabled", not BJIContext.BJC.Whitelist.Enabled)
                BJIContext.BJC.Whitelist.Enabled = not BJIContext.BJC.Whitelist.Enabled
            end
        })
    else
        line:icon({
            icon = BJIContext.BJC.Whitelist.Enabled and ICONS.check_circle or ICONS.cancel,
            style = BJIContext.BJC.Whitelist.Enabled and BTN_PRESETS.SUCCESS or BTN_PRESETS.ERROR,
            coloredIcon = true,
        })
    end
    line:build()

    drawWhitelistOnlinePlayers(connectedPlayerNames)

    local offlinePlayers = {}
    for _, playerName in ipairs(BJIContext.BJC.Whitelist.PlayerNames) do
        if not tincludes(connectedPlayerNames, playerName) then
            table.insert(offlinePlayers, playerName)
        end
    end
    if #offlinePlayers > 0 then
        drawWhitelistOfflinePlayers(offlinePlayers)
    end
    LineBuilder()
        :text(svar("{1}:", { BJILang.get("serverConfig.bjc.whitelist.addOfflinePlayer") }))
        :build()
    local canAdd = BJIContext.BJC.Whitelist.PlayerName ~= "" and
        not tincludes(BJIContext.BJC.Whitelist.PlayerNames, BJIContext.BJC.Whitelist.PlayerName)
    LineBuilder()
        :inputString({
            id = "addWhitelistName",
            placeholder = BJILang.get("serverConfig.bjc.whitelist.addOfflinePlayerPlaceholder"),
            value = BJIContext.BJC.Whitelist.PlayerName,
            size = BJIContext.BJC.Whitelist.PlayerName._size,
            width = 200,
            onUpdate = function(val)
                BJIContext.BJC.Whitelist.PlayerName = val
            end
        })
        :btnIcon({
            id = "addWhitelist",
            icon = ICONS.addListItem,
            style = BTN_PRESETS.SUCCESS,
            disabled = not canAdd,
            onClick = function()
                BJITx.moderation.whitelist(BJIContext.BJC.Whitelist.PlayerName)
                BJIContext.BJC.Whitelist.PlayerName = ""
            end
        })
        :build()
end
