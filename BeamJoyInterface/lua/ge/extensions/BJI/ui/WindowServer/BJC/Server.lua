local function drawServerBroadcasts()
    LineBuilder()
        :text(string.var("{1}:", { BJILang.get("serverConfig.bjc.server.broadcasts.title") }))
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

    local langs = {}
    for _, l in ipairs(BJILang.Langs) do
        table.insert(langs, {
            value = l,
            label = l:upper(),
        })
    end
    table.sort(langs, function(a, b) return a.label < b.label end)
    local iSelected = 0
    for i, l in ipairs(langs) do
        if l.value == BJIContext.BJC.Server.BroadcastsLang then
            iSelected = i
        end
    end
    LineBuilder()
        :text(BJILang.get("serverConfig.bjc.server.broadcasts.lang"))
        :inputCombo({
            id = "serverBroadcastsLang",
            items = langs,
            getLabelFn = function(v)
                return v.label
            end,
            value = langs[iSelected],
            width = 50,
            onChange = function(el)
                BJIContext.BJC.Server.BroadcastsLang = el.value
            end
        })
        :build()
    Indent(2)
    local maxI = #BJIContext.BJC.Server.Broadcasts[BJIContext.BJC.Server.BroadcastsLang]
    local longestLabel = string.var("{1} {2}",
        { BJILang.get("serverConfig.bjc.server.broadcasts.broadcast"), maxI })
    local cols = ColumnsBuilder("serverBroadcasts", { GetColumnTextWidth(longestLabel), -1 })
    for i, broad in ipairs(BJIContext.BJC.Server.Broadcasts[BJIContext.BJC.Server.BroadcastsLang]) do
        cols:addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(string.var("{1} {2}", { BJILang.get("serverConfig.bjc.server.broadcasts.broadcast"), i }))
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
        :btnIcon({
            id = "addServerBroadcastsMessage",
            icon = ICONS.addListItem,
            style = BTN_PRESETS.SUCCESS,
            disabled = lastMessage and #lastMessage == 0,
            onClick = function()
                table.insert(BJIContext.BJC.Server.Broadcasts[BJIContext.BJC.Server.BroadcastsLang], "")
            end
        })
    if iLastMessage > 0 then
        line:btnIcon({
            id = "deleteServerBroadcastsMessage",
            icon = ICONS.delete_forever,
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
        :btnIcon({
            id = "saveServerBroadcasts",
            icon = ICONS.save,
            style = BTN_PRESETS.SUCCESS,
            onClick = function()
                local data = table.clone(BJIContext.BJC.Server.Broadcasts)
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
        :text(string.var("{1}:", { BJILang.get("serverConfig.bjc.server.welcomeMessage.title") }))
        :helpMarker(BJILang.get("serverConfig.bjc.server.welcomeMessage.tooltip"))
        :build()
    Indent(2)
    local labelWidth = 0
    local langs = {}
    for l, msg in pairs(BJIContext.BJC.Server.WelcomeMessage) do
        local w = GetColumnTextWidth(BJILang.get("serverConfig.bjc.server.welcomeMessage.message")
            :var({ lang = l:upper() }))
        if w > labelWidth then
            labelWidth = w
        end
        table.insert(langs, {
            lang = l,
            msg = msg,
        })
    end
    table.sort(langs, function(a, b) return a.lang < b.lang end)
    local cols = ColumnsBuilder("serverWelcomeMessages", { labelWidth, -1 })
    for _, el in pairs(langs) do
        cols:addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(BJILang.get("serverConfig.bjc.server.welcomeMessage.message")
                            :var({ lang = el.lang:upper() }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :inputString({
                            id = "serverWelcomeMessage" .. el.lang,
                            value = el.msg,
                            size = 200,
                            onUpdate = function(val)
                                BJIContext.BJC.Server.WelcomeMessage[el.lang] = val
                            end
                        })
                        :build()
                end
            }
        })
    end
    cols:build()
    LineBuilder()
        :btnIcon({
            id = "saveServerWelcomeMessage",
            icon = ICONS.save,
            style = BTN_PRESETS.SUCCESS,
            onClick = function()
                local data = table.clone(BJIContext.BJC.Server.WelcomeMessage)
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

return function(ctxt)
    if #BJILang.Langs > 1 then
        EmptyLine()
        BJILang.drawSelector({
            label = string.var("{1}:", { BJILang.get("serverConfig.bjc.server.lang") }),
            selected = BJIContext.BJC.Server.Lang,
            onChange = function(newLang)
                BJITx.config.bjc("Server.Lang", newLang)
            end
        })
    else
        LineBuilder()
            :text(string.var("{1}:", { BJILang.get("serverConfig.bjc.server.lang") }))
            :text(BJIContext.BJC.Server.Lang:upper())
            :build()
    end

    LineBuilder()
        :text("Allow Client Mods:")
        :btnIconToggle({
            id = "toggleAllowClientMods",
            state = BJIContext.BJC.Server.AllowClientMods,
            coloredIcon = true,
            onClick = function()
                BJITx.config.bjc("Server.AllowClientMods", not BJIContext.BJC.Server.AllowClientMods)
            end,
        })
        :build()

    LineBuilder()
        :text(string.var("{1}:", { BJILang.get("serverConfig.bjc.server.driftBigBroadcast") }))
        :btnIconToggle({
            id = "driftBigBroadcast",
            state = BJIContext.BJC.Server.DriftBigBroadcast,
            coloredIcon = true,
            onClick = function()
                BJITx.config.bjc("Server.DriftBigBroadcast",
                    not BJIContext.BJC.Server.DriftBigBroadcast)
            end,
        })
        :build()

    drawServerBroadcasts()
    drawServerWelcomeMessages()
end
