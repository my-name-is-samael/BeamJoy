local function drawServerBroadcasts(labels, cache)
    LineBuilder()
        :text(labels.server.broadcasts.title)
        :helpMarker(labels.server.broadcasts.tooltip)
        :build()
    Indent(2)
    LineBuilder()
        :text(labels.server.broadcasts.delay)
        :inputNumeric({
            id = "serverBroadcastsDelay",
            type = "int",
            value = BJI.Managers.Context.BJC.Server.Broadcasts.delay,
            min = 30,
            step = 1,
            stepFast = 5,
            width = 120,
            onUpdate = function(val)
                BJI.Managers.Context.BJC.Server.Broadcasts.delay = val
            end
        })
        :text(BJI.Utils.Common.PrettyDelay(BJI.Managers.Context.BJC.Server.Broadcasts.delay))
        :build()

    LineBuilder()
        :text(labels.server.broadcasts.lang)
        :inputCombo({
            id = "serverBroadcastsLang",
            items = cache.server.broadcasts.langs,
            getLabelFn = function(v)
                return v.label
            end,
            value = cache.server.broadcasts.selectedLang,
            width = 50,
            onChange = function(el)
                cache.server.broadcasts.selectedLang = el
            end
        })
        :build()
    Indent(2)
    local maxI = #BJI.Managers.Context.BJC.Server.Broadcasts[cache.server.broadcasts.selectedLang.value]
    local longestLabel = string.var("{1} {2}", { labels.server.broadcasts.broadcast, maxI })
    local cols = ColumnsBuilder("serverBroadcasts", { BJI.Utils.Common.GetColumnTextWidth(longestLabel), -1 })
    for i, broad in ipairs(BJI.Managers.Context.BJC.Server.Broadcasts[cache.server.broadcasts.selectedLang.value]) do
        cols:addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(string.var("{1} {2}", { labels.server.broadcasts.broadcast, i }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :inputString({
                            id = "serverBroadcastsMessage" .. i,
                            value = broad,
                            size = 200,
                            onUpdate = function(val)
                                BJI.Managers.Context.BJC.Server.Broadcasts[cache.server.broadcasts.selectedLang.value][i] =
                                    val
                            end
                        })
                        :build()
                end
            }
        })
    end
    cols:build()
    local iLastMessage = #BJI.Managers.Context.BJC.Server.Broadcasts[cache.server.broadcasts.selectedLang.value]
    local lastMessage = BJI.Managers.Context.BJC.Server.Broadcasts[cache.server.broadcasts.selectedLang.value]
        [iLastMessage]
    local line = LineBuilder()
        :btnIcon({
            id = "addServerBroadcastsMessage",
            icon = ICONS.addListItem,
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            disabled = lastMessage and #lastMessage == 0,
            onClick = function()
                table.insert(BJI.Managers.Context.BJC.Server.Broadcasts[cache.server.broadcasts.selectedLang.value],
                    "")
            end
        })
    if iLastMessage > 0 then
        line:btnIcon({
            id = "deleteServerBroadcastsMessage",
            icon = ICONS.delete_forever,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            onClick = function()
                table.remove(BJI.Managers.Context.BJC.Server.Broadcasts[cache.server.broadcasts.selectedLang.value],
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
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            disabled = cache.disableInputs,
            onClick = function()
                cache.disableInputs = true
                local data = table.clone(BJI.Managers.Context.BJC.Server.Broadcasts)
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
                BJI.Tx.config.bjc("Server.Broadcasts", data)
            end
        })
    Indent(-2)
end

local function drawServerWelcomeMessages(labels, cache)
    LineBuilder()
        :text(labels.server.welcomeMessage.title)
        :helpMarker(labels.server.welcomeMessage.tooltip)
        :build()
    Indent(2)
    Table(BJI.Managers.Context.BJC.Server.WelcomeMessage)
        :map(function(msg, l)
            return {
                lang = l,
                msg = msg
            }
        end):sort(function(a, b) return a.lang < b.lang end)
        :reduce(function(cols, el)
            return cols:addRow({
                cells = {
                    function() LineLabel(labels.server.welcomeMessage.message:var({ lang = el.lang:upper() })) end,
                    function()
                        LineBuilder()
                            :inputString({
                                id = "serverWelcomeMessage" .. el.lang,
                                value = el.msg,
                                size = 200,
                                onUpdate = function(val)
                                    BJI.Managers.Context.BJC.Server.WelcomeMessage[el.lang] = val
                                end
                            })
                            :build()
                    end
                }
            })
        end, ColumnsBuilder("serverWelcomeMessages", { cache.server.welcomeMessage.langsWidth, -1 }))
        :build()
    LineBuilder()
        :btnIcon({
            id = "saveServerWelcomeMessage",
            icon = ICONS.save,
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            disabled = cache.disableInputs,
            onClick = function()
                cache.disableInputs = true
                local data = table.clone(BJI.Managers.Context.BJC.Server.WelcomeMessage)
                for lang, msg in pairs(data) do
                    if #msg == 0 then
                        data[lang] = nil
                    end
                end
                BJI.Tx.config.bjc("Server.WelcomeMessage", data)
            end
        })
        :build()
    Indent(-2)
end

return function(ctxt, labels, cache)
    if #BJI.Managers.Lang.Langs > 1 then
        EmptyLine()
        BJI.Managers.Lang.drawSelector({
            label = labels.server.lang,
            selected = BJI.Managers.Context.BJC.Server.Lang,
            onChange = function(newLang)
                BJI.Tx.config.bjc("Server.Lang", newLang)
            end
        })
    else
        LineBuilder()
            :text(labels.server.lang)
            :text(BJI.Managers.Context.BJC.Server.Lang:upper())
            :build()
    end

    LineBuilder()
        :text(labels.server.allowMods)
        :btnIconToggle({
            id = "toggleAllowClientMods",
            state = BJI.Managers.Context.BJC.Server.AllowClientMods,
            coloredIcon = true,
            disabled = cache.disableInputs,
            onClick = function()
                cache.disableInputs = true
                BJI.Tx.config.bjc("Server.AllowClientMods", not BJI.Managers.Context.BJC.Server.AllowClientMods)
            end,
        })
        :build()

    LineBuilder()
        :text(labels.server.driftBigBroadcast)
        :btnIconToggle({
            id = "driftBigBroadcast",
            state = BJI.Managers.Context.BJC.Server.DriftBigBroadcast,
            coloredIcon = true,
            disabled = cache.disableInputs,
            onClick = function()
                cache.disableInputs = true
                BJI.Tx.config.bjc("Server.DriftBigBroadcast",
                    not BJI.Managers.Context.BJC.Server.DriftBigBroadcast)
            end,
        })
        :build()

    drawServerBroadcasts(labels, cache)
    drawServerWelcomeMessages(labels, cache)
end
