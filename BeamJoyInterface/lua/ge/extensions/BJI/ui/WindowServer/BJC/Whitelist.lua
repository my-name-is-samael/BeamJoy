local function drawWhitelistOnlinePlayers(playerNames)
    LineBuilder()
        :text(svar("{1}:", { BJILang.get("serverConfig.bjc.whitelist.players") }))
        :build()
    Indent(1)
    local nameWidth = 0
    for _, playerName in ipairs(playerNames) do
        local w = GetColumnTextWidth(playerName)
        if w > nameWidth then
            nameWidth = w
        end
    end
    local cols = ColumnsBuilder("whitelistOnlinePlayers", { nameWidth, -1 })
    for _, playerName in ipairs(playerNames) do
        cols:addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(playerName)
                        :build()
                end,
                function()
                    LineBuilder()
                        :btnSwitch({
                            id = svar("toggleWhitelist{1}", { playerName }),
                            labelOn = BJILang.get("common.buttons.add"),
                            labelOff = BJILang.get("common.buttons.remove"),
                            state = not tincludes(BJIContext.BJC.Whitelist.PlayerNames, playerName),
                            onClick = function()
                                BJITx.moderation.whitelist(playerName)
                            end
                        })
                        :build()
                end
            }
        })
    end
    cols:build()
    Indent(-1)
end

local function drawWhitelistOfflinePlayers(playerNames)
    LineBuilder()
        :text(svar("{1}:", { BJILang.get("serverConfig.bjc.whitelist.offlinePlayers") }))
        :build()
    Indent(1)
    local nameWidth = 0
    for _, playerName in ipairs(playerNames) do
        local w = GetColumnTextWidth(playerName)
        if w > nameWidth then
            nameWidth = w
        end
    end
    local cols = ColumnsBuilder("whitelistOfflinePlayers", { nameWidth, -1 })
    for _, playerName in ipairs(playerNames) do
        cols:addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(playerName)
                        :build()
                end,
                function()
                    LineBuilder()
                        :btn({
                            id = svar("removeWhitelist{1}", { playerName }),
                            label = BJILang.get("common.buttons.remove"),
                            style = BTN_PRESETS.ERROR,
                            onClick = function()
                                BJITx.moderation.whitelist(playerName)
                            end
                        })
                        :build()
                end
            }
        })
    end
    cols:build()
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
        line:btnSwitchEnabledDisabled({
            id = "toggleWhitelist",
            state = BJIContext.BJC.Whitelist.Enabled,
            onClick = function()
                BJITx.config.bjc("Whitelist.Enabled", not BJIContext.BJC.Whitelist.Enabled)
            end
        })
    else
        local label = BJILang.get("common.disabled")
        if BJIContext.BJC.Whitelist.Enabled then
            label = BJILang.get("common.enabled")
        end
        line:text(label)
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
        :btn({
            id = "addWhitelist",
            label = BJILang.get("common.buttons.add"),
            style = BTN_PRESETS.SUCCESS,
            disabled = not canAdd,
            onClick = function()
                BJITx.moderation.whitelist(BJIContext.BJC.Whitelist.PlayerName)
                BJIContext.BJC.Whitelist.PlayerName = ""
            end
        })
        :build()
end
