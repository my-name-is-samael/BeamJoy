local function drawServerBroadcasts()
    LineBuilder()
        :text(svar("{1}:", { BJILang.get("serverConfig.bjc.server.broadcasts.title") }))
        :helpMarker(BJILang.get("serverConfig.bjc.server.broadcasts.tooltip"))
        :build()
    Indent(2)
    LineBuilder()
        :text(BJILang.get("serverConfig.bjc.server.broadcasts.delay"))
        :inputNumeric({
            id = "serverBroadcastsDelay",
            type = "int",
            value = BJIContext.BJC.Server.Broadcasts.delay,
            min = 30,
            step = 1,
            stepFast = 5,
            width = 120,
            onUpdate = function(val)
                BJIContext.BJC.Server.Broadcasts.delay = val
            end
        })
        :text(PrettyDelay(BJIContext.BJC.Server.Broadcasts.delay))
        :build()

    LineBuilder()
        :text(BJILang.get("serverConfig.bjc.server.broadcasts.lang"))
        :inputCombo({
            id = "serverBroadcastsLang",
            items = BJILang.Langs,
            value = BJIContext.BJC.Server.BroadcastsLang,
            width = 50,
            onChange = function(val)
                BJIContext.BJC.Server.BroadcastsLang = val
            end
        })
        :build()
    Indent(2)
    local maxI = #BJIContext.BJC.Server.Broadcasts[BJIContext.BJC.Server.BroadcastsLang]
    local longestLabel = svar("{1} {2}",
        { BJILang.get("serverConfig.bjc.server.broadcasts.broadcast"), maxI })
    local cols = ColumnsBuilder("serverBroadcasts", { GetColumnTextWidth(longestLabel), -1 })
    for i, broad in ipairs(BJIContext.BJC.Server.Broadcasts[BJIContext.BJC.Server.BroadcastsLang]) do
        cols:addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1} {2}", { BJILang.get("serverConfig.bjc.server.broadcasts.broadcast"), i }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :inputString({
                            id = "serverBroadcastsMessage" .. i,
                            value = broad,
                            size = 200,
                            onUpdate = function(val)
                                BJIContext.BJC.Server.Broadcasts[BJIContext.BJC.Server.BroadcastsLang][i] = val
                            end
                        })
                        :build()
                end
            }
        })
    end
    cols:build()
    local iLastMessage = #BJIContext.BJC.Server.Broadcasts[BJIContext.BJC.Server.BroadcastsLang]
    local lastMessage = BJIContext.BJC.Server.Broadcasts[BJIContext.BJC.Server.BroadcastsLang][iLastMessage]
    local line = LineBuilder()
        :btn({
            id = "addServerBroadcastsMessage",
            label = BJILang.get("common.buttons.add"),
            style = BTN_PRESETS.SUCCESS,
            disabled = lastMessage and #lastMessage == 0,
            onClick = function()
                table.insert(BJIContext.BJC.Server.Broadcasts[BJIContext.BJC.Server.BroadcastsLang], "")
            end
        })
    if iLastMessage > 0 then
        line:btn({
            id = "deleteServerBroadcastsMessage",
            label = BJILang.get("common.buttons.delete"),
            style = BTN_PRESETS.ERROR,
            onClick = function()
                table.remove(BJIContext.BJC.Server.Broadcasts[BJIContext.BJC.Server.BroadcastsLang],
                    iLastMessage)
            end
        })
    end
    line:build()
    Indent(-2)

    LineBuilder()
        :btn({
            id = "saveServerBroadcasts",
            label = BJILang.get("common.buttons.save"),
            style = BTN_PRESETS.SUCCESS,
            onClick = function()
                local data = tdeepcopy(BJIContext.BJC.Server.Broadcasts)
                -- remove empty messages
                for k, langBroads in pairs(data) do
                    if k ~= "delay" then
                        for i, broad in ipairs(langBroads) do
                            if #broad == 0 then
                                table.remove(langBroads, i)
                            end
                        end
                    end
                end
                BJITx.config.bjc("Server.Broadcasts", data)
            end
        })
    Indent(-2)
end

local function drawServerWelcomeMessages()
    LineBuilder()
        :text(svar("{1}:", { BJILang.get("serverConfig.bjc.server.welcomeMessage.title") }))
        :helpMarker(BJILang.get("serverConfig.bjc.server.welcomeMessage.tooltip"))
        :build()
    Indent(2)
    local labelWidth = 0
    for lang in pairs(BJIContext.BJC.Server.WelcomeMessage) do
        local w = GetColumnTextWidth(svar(BJILang.get("serverConfig.bjc.server.welcomeMessage.message"),
            { lang = lang }))
        if w > labelWidth then
            labelWidth = w
        end
    end
    local cols = ColumnsBuilder("serverWelcomeMessages", { labelWidth, -1 })
    for lang, message in pairs(BJIContext.BJC.Server.WelcomeMessage) do
        cols:addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar(BJILang.get("serverConfig.bjc.server.welcomeMessage.message"),
                            { lang = lang }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :inputString({
                            id = "serverWelcomeMessage" .. lang,
                            value = message,
                            size = 200,
                            onUpdate = function(val)
                                BJIContext.BJC.Server.WelcomeMessage[lang] = val
                            end
                        })
                        :build()
                end
            }
        })
    end
    cols:build()
    LineBuilder()
        :btn({
            id = "saveServerWelcomeMessage",
            label = BJILang.get("common.buttons.save"),
            style = BTN_PRESETS.SUCCESS,
            onClick = function()
                local data = tdeepcopy(BJIContext.BJC.Server.WelcomeMessage)
                for lang, msg in pairs(data) do
                    if #msg == 0 then
                        data[lang] = nil
                    end
                end
                BJITx.config.bjc("Server.WelcomeMessage", data)
            end
        })
        :build()
    Indent(-2)
end

return function (ctxt)
    if #BJILang.Langs > 1 then
        BJILang.drawSelector({
            label = svar("{1}:", { BJILang.get("serverConfig.bjc.server.lang") }),
            selected = BJIContext.BJC.Server.Lang,
            onChange = function(newLang)
                BJITx.config.bjc("Server.Lang", newLang)
            end
        })
    else
        LineBuilder()
            :text(svar("{1}:", { BJILang.get("serverConfig.bjc.server.lang") }))
            :text(BJIContext.BJC.Server.Lang:upper())
            :build()
    end

    LineBuilder()
        :text("Allow Client Mods:")
        :btnSwitchYesNo({
            id = "toggleAllowClientMods",
            state = BJIContext.BJC.Server.AllowClientMods,
            onClick = function()
                BJITx.config.bjc("Server.AllowClientMods", not BJIContext.BJC.Server.AllowClientMods)
            end,
        })
        :build()

    LineBuilder()
        :text(svar("{1}:", { BJILang.get("serverConfig.bjc.server.driftBigBroadcast") }))
        :btnSwitchEnabledDisabled({
            id = "driftBigBroadcast",
            state = BJIContext.BJC.Server.DriftBigBroadcast,
            onClick = function()
                BJITx.config.bjc("Server.DriftBigBroadcast",
                    not BJIContext.BJC.Server.DriftBigBroadcast)
            end,
        })
        :build()

    drawServerBroadcasts()
    drawServerWelcomeMessages()
end