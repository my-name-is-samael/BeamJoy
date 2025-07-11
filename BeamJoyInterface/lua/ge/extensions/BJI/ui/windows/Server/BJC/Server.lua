--- gc prevention
local nextValue, iLastMessage, lastMessage

local function drawServerBroadcasts(labels, cache)
    Text(labels.server.broadcasts.title)
    TooltipText(labels.server.broadcasts.tooltip)
    Indent(); Indent()
    if BeginTable("BJIServerBJCServerBroadcasts1", {
            { label = "##bjiserverbjcserverbroadcasts1-labels" },
            { label = "##bjiserverbjcserverbroadcasts1-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        TableNewRow()
        Text(labels.server.broadcasts.delay)
        TableNextColumn()
        nextValue = SliderIntPrecision("serverBroadcastsDelay", BJI_Context.BJC.Server.Broadcasts.delay, 30,
            3600, {
                step = 1,
                stepFast = 5,
                formatRender = tostring(BJI_Context.BJC.Server.Broadcasts.delay) .. " - " ..
                    cache.server.broadcasts.prettyBrodcastsDelay
            })
        if nextValue then
            BJI_Context.BJC.Server.Broadcasts.delay = nextValue
            cache.server.broadcasts.prettyBrodcastsDelay = BJI.Utils.UI.PrettyDelay(BJI_Context.BJC.Server
                .Broadcasts.delay)
        end

        TableNewRow()
        Text(labels.server.broadcasts.lang)
        TableNextColumn()
        nextValue = Combo("serverBroadcastsLang", cache.server.broadcasts.selectedLang, cache.server.broadcasts.langs,
            { width = 100 })
        if nextValue then cache.server.broadcasts.selectedLang = nextValue end

        EndTable()
    end

    Indent(); Indent()
    if BeginTable("BJIServerBJCServerBroadcasts2", {
            { label = "##bjiserverbjcserverbroadcasts2-labels" },
            { label = "##bjiserverbjcserverbroadcasts2-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        table.forEach(BJI_Context.BJC.Server.Broadcasts[cache.server.broadcasts.selectedLang],
            function(broad, i)
                TableNewRow()
                Text(labels.server.broadcasts.broadcast .. " " .. tostring(i))
                TableNextColumn()
                if IconButton("deleteServerBroadcastsMessage", BJI.Utils.Icon.ICONS.delete_forever,
                        { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
                    table.remove(BJI_Context.BJC.Server.Broadcasts[cache.server.broadcasts.selectedLang], i)
                    cache.server.broadcasts.langs:find(
                        function(el) return el.value == cache.server.broadcasts.selectedLang end,
                        function(el)
                            el.label = string.format("%s (%d)", el.value:upper(),
                                #BJI_Context.BJC.Server.Broadcasts[el.value])
                        end)
                end
                TooltipText(labels.buttons.remove)
                SameLine()
                nextValue = InputText("serverBroadcastsMessage" .. i, broad, { size = 200 })
                if nextValue then
                    BJI_Context.BJC.Server.Broadcasts[cache.server.broadcasts.selectedLang][i] = nextValue
                end
            end)

        EndTable()
    end

    iLastMessage = #BJI_Context.BJC.Server.Broadcasts[cache.server.broadcasts.selectedLang]
    lastMessage = BJI_Context.BJC.Server.Broadcasts[cache.server.broadcasts.selectedLang][iLastMessage]
    if IconButton("addServerBroadcastsMessage", BJI.Utils.Icon.ICONS.addListItem,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = lastMessage and #lastMessage == 0 }) then
        table.insert(BJI_Context.BJC.Server.Broadcasts[cache.server.broadcasts.selectedLang], "")
        cache.server.broadcasts.langs:find(function(el) return el.value == cache.server.broadcasts.selectedLang end,
            function(el)
                el.label = string.format("%s (%d)", el.value:upper(),
                    #BJI_Context.BJC.Server.Broadcasts[el.value])
            end)
    end
    TooltipText(labels.buttons.add)
    Unindent(); Unindent()

    if IconButton("saveServerBroadcasts", BJI.Utils.Icon.ICONS.save,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = cache.disableInputs }) then
        cache.disableInputs = true
        local data = table.clone(BJI_Context.BJC.Server.Broadcasts)
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
        BJI_Tx_config.bjc("Server.Broadcasts", data)
    end
    TooltipText(labels.buttons.save)
    Unindent(); Unindent()
end

local function drawServerWelcomeMessages(labels, cache)
    Text(labels.server.welcomeMessage.title)
    TooltipText(labels.server.welcomeMessage.tooltip)
    Indent(); Indent()
    if BeginTable("BJIServerBJCServerWelcomeMessages", {
            { label = "##bjiserverbjcserverwelcomemessages-labels" },
            { label = "##bjiserverbjcserverwelcomemessages-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        Table(BJI_Context.BJC.Server.WelcomeMessage):forEach(function(msg, lang)
            TableNewRow()
            Text(labels.server.welcomeMessage.message:var({ lang = tostring(lang):upper() }))
            TableNextColumn()
            nextValue = InputText("serverWelcomeMessage" .. lang, msg, { size = 200 })
            if nextValue then BJI_Context.BJC.Server.WelcomeMessage[lang] = nextValue end
        end)

        EndTable()
    end
    if IconButton("saveServerWelcomeMessage", BJI.Utils.Icon.ICONS.save,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = cache.disableInputs }) then
        cache.disableInputs = true
        local data = table.clone(BJI_Context.BJC.Server.WelcomeMessage)
        for lang, msg in pairs(data) do
            if #msg == 0 then
                data[lang] = nil
            end
        end
        BJI_Tx_config.bjc("Server.WelcomeMessage", data)
    end
    TooltipText(labels.buttons.save)
    Unindent(); Unindent()
end

return function(ctxt, labels, cache)
    if #BJI_Lang.Langs > 1 then
        BJI_Lang.drawSelector({
            id = "serverLang",
            label = labels.server.lang,
            selected = BJI_Context.BJC.Server.Lang,
            onChange = function(newLang)
                BJI_Tx_config.bjc("Server.Lang", newLang)
            end
        })

        BJI_Lang.drawSelector({
            id = "discordChatHookLang",
            label = labels.server.discordChatHookLang,
            tooltip = labels.server.discordChatHookLangTooltip,
            selected = BJI_Context.BJC.Server.DiscordChatHookLang,
            onChange = function(newLang)
                BJI_Tx_config.bjc("Server.DiscordChatHookLang", newLang)
            end
        })
    else
        Text(labels.server.lang)
        SameLine()
        Text(BJI_Context.BJC.Server.Lang:upper())

        Text(labels.server.discordChatHookLang)
        TooltipText(labels.server.discordChatHookLangTooltip)
        SameLine()
        Text(BJI_Context.BJC.Server.DiscordChatHookLang:upper())
        TooltipText(labels.server.discordChatHookLangTooltip)
    end

    Text(labels.server.allowMods)
    SameLine()
    if IconButton("toggleAllowClientMods", BJI_Context.BJC.Server.AllowClientMods and
            BJI.Utils.Icon.ICONS.check_circle or BJI.Utils.Icon.ICONS.cancel,
            { bgLess = true, btnStyle = BJI_Context.BJC.Server.AllowClientMods and
                BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR,
                disabled = cache.disableInputs }) then
        cache.disableInputs = true
        BJI_Tx_config.bjc("Server.AllowClientMods", not BJI_Context.BJC.Server.AllowClientMods)
    end

    Text(labels.server.driftBigBroadcast)
    SameLine()
    if IconButton("toggleDriftBigBroadcast", BJI_Context.BJC.Server.DriftBigBroadcast and
            BJI.Utils.Icon.ICONS.check_circle or BJI.Utils.Icon.ICONS.cancel,
            { bgLess = true, btnStyle = BJI_Context.BJC.Server.DriftBigBroadcast and
                BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR,
                disabled = cache.disableInputs }) then
        cache.disableInputs = true
        BJI_Tx_config.bjc("Server.DriftBigBroadcast", not BJI_Context.BJC.Server.DriftBigBroadcast)
    end

    drawServerBroadcasts(labels, cache)
    drawServerWelcomeMessages(labels, cache)
end
