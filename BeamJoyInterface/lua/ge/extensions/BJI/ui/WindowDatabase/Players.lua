local currentBeamID

local function draw()
    local options = {}
    local selected
    for beamID, playerData in pairs(BJIContext.Database.Players) do
        table.insert(options, {
            value = beamID,
            label = svar("{1} ({2})", { playerData.playerName, playerData.lang }),
        })
        if currentBeamID == beamID then
            selected = options[#options]
        end
    end
    table.sort(options, function(a, b)
        return a.label:lower() < b.label:lower()
    end)
    if not currentBeamID then
        currentBeamID = options[1].value
        selected = options[1]
    end

    LineBuilder()
        :btnIcon({
            id = "databasePlayersRefresh",
            icon = ICONS.refresh,
            background = BTN_PRESETS.INFO,
            onClick = function()
                BJICache.invalidate(BJICache.CACHES.DATABASE_PLAYERS)
            end
        })
        :inputCombo({
            id = "databasePlayerFilter",
            items = options,
            getLabelFn = function(item)
                return item.label
            end,
            value = selected,
            onChange = function(item)
                currentBeamID = item.value
            end,
        })
        :build()

    local playerData = BJIContext.Database.Players[currentBeamID]
    if playerData then
        local selfGroup = BJIPerm.Groups[BJIContext.User.group]
        local playerGroup
        for name, g in pairs(BJIPerm.Groups) do
            if name == playerData.group then
                playerGroup = g
            end
        end
        local readOnly = selfGroup.level <= playerGroup.level

        local groups = {}
        local selectedGroup
        for groupName, group in pairs(BJIPerm.Groups) do
            if not tincludes({ "_new", "_newLevel" }, groupName, true) and
                group.level < selfGroup.level then
                table.insert(groups, {
                    value = group.level,
                    name = groupName,
                    label = BJILang.get(svar("groups.{1}", { groupName }), groupName),
                })
                if groupName == playerData.group then
                    selectedGroup = groups[#groups]
                end
            end
        end
        table.sort(groups, function(a, b)
            return a.value < b.value
        end)

        local labelWidth = 0
        for _, key in ipairs({
            "database.players.playerName",
            "database.players.group",
            "database.players.banned",
            "database.players.banReason",
            "database.players.muted",
            "database.players.muteReason",
        }) do
            local label = BJILang.get(key)
            local w = GetColumnTextWidth(label .. "  ")
            if w > labelWidth then
                labelWidth = w
            end
        end

        ColumnsBuilder(svar("databasePlayer-{1}", { playerData.playerName }), { labelWidth, -1, GetBtnIconSize() })
            :addRow({
                cells = {
                    function()
                        LineBuilder()
                            :text(BJILang.get("database.players.playerName"))
                            :build()
                    end,
                    function()
                        LineBuilder()
                            :text(svar("{1} - {2} ({3})",
                                { playerData.beammp, playerData.playerName, playerData.lang }))
                            :build()
                    end,
                }
            })
            :addRow({
                cells = {
                    function()
                        LineBuilder()
                            :text(BJILang.get("database.players.group"))
                            :build()
                    end,
                    function()
                        if readOnly then
                            LineBuilder()
                                :text(BJILang.get(svar("groups.{1}",
                                    { playerData.group }), playerData.group))
                                :build()
                        else
                            LineBuilder()
                                :inputCombo({
                                    id = "databasePlayerGroup",
                                    items = groups,
                                    getLabelFn = function(item)
                                        return item.label
                                    end,
                                    value = selectedGroup,
                                    onChange = function(item)
                                        BJITx.moderation.setGroup(playerData.playerName, item.name)
                                        playerData.group = item.name
                                    end
                                })
                                :build()
                        end
                    end,
                }
            })
            :addRow({
                cells = {
                    function()
                        LineBuilder()
                            :text(BJILang.get("database.players.banned"))
                            :build()
                    end,
                    function()
                        local line = LineBuilder()
                        if readOnly then
                            line:text(playerData.muted and
                                BJILang.get("common.yes") or BJILang.get("common.no"))
                        else
                            line:btnIconSwitch({
                                id = "databasePlayerBanned",
                                iconEnabled = ICONS.gavel,
                                state = playerData.banned == true or playerData.tempBanUntil ~= nil,
                                onClick = function()
                                    if playerData.banned or playerData.tempBanUntil then
                                        BJITx.moderation.unban(playerData.playerName)
                                    else
                                        BJITx.moderation.ban(playerData.playerName)
                                    end
                                end,
                            })
                        end
                        if playerData.tempBanUntil then
                            line:text(svar(BJILang.get("database.players.tempBanEndsIn"),
                                {
                                    secs = playerData.tempBanUntil -
                                        PrettyDelay(BJITick.applyTimeOffset(GetCurrentTime()))
                                }))
                        end
                        line:build()
                    end,
                }
            })
            :addRow({
                cells = {
                    function()
                        LineBuilder()
                            :text(BJILang.get("database.players.banReason"))
                            :build()
                    end,
                    function()
                        local line = LineBuilder()
                        if playerData.banned or playerData.tempBanUntil or readOnly then
                            line:text(playerData.banReason or "/")
                        else
                            line:inputString({
                                id = "databasePlayerBanReason",
                                value = playerData.banReason or "",
                                onUpdate = function(reason)
                                    playerData.banReason = reason
                                end,
                            })
                        end
                        line:build()
                    end,
                    function()
                        if not playerData.banned and not playerData.tempBanUntil and not readOnly then
                            LineBuilder()
                                :btnIcon({
                                    id = "databasePlayerBan",
                                    icon = ICONS.gavel,
                                    background = BTN_PRESETS.ERROR,
                                    onClick = function()
                                        BJITx.moderation.ban(playerData.playerName, playerData.banReason)
                                    end
                                })
                                :build()
                        end
                    end,
                }
            })
            :addRow({
                cells = {
                    function()
                        LineBuilder()
                            :text(BJILang.get("database.players.muted"))
                            :build()
                    end,
                    function()
                        if readOnly then
                            LineBuilder()
                                :text(playerData.muted and
                                    BJILang.get("common.yes") or BJILang.get("common.no"))
                                :build()
                        else
                            LineBuilder()
                                :btnIconSwitch({
                                    id = "databasePlayerMuted",
                                    iconEnabled = ICONS.mic_off,
                                    state = playerData.muted == true,
                                    onClick = function()
                                        BJITx.moderation.mute(playerData.playerName)
                                    end
                                })
                                :build()
                        end
                    end,
                }
            })
            :addRow({
                cells = {
                    function()
                        LineBuilder()
                            :text(BJILang.get("database.players.muteReason"))
                            :build()
                    end,
                    function()
                        local line = LineBuilder()
                        if playerData.muted or readOnly then
                            line:text(playerData.muteReason or "/")
                        else
                            line:inputString({
                                id = "databasePlayerMuteReason",
                                value = playerData.muteReason or "",
                                onUpdate = function(reason)
                                    playerData.muteReason = reason
                                end,
                            })
                        end
                        line:build()
                    end,
                    function()
                        if not playerData.muted and not readOnly then
                            LineBuilder()
                                :btnIcon({
                                    id = "databasePlayerMute",
                                    icon = ICONS.mic_off,
                                    background = BTN_PRESETS.ERROR,
                                    onClick = function()
                                        BJITx.moderation.mute(playerData.playerName, playerData.muteReason)
                                        playerData.muted = true
                                    end
                                })
                                :build()
                        end
                    end,
                }
            })
            :build()
    end
end

return draw
