local te

local function updateTheme()
    LoadTheme(te.data)
end

local function save()
    BJITx.config.bjc("Server.Theme", te.data)
    te.changed = false
end

local function onClose(ctxt)
    if te.changed then
        BJIPopup.createModal(BJILang.get("themeEditor.cancelModal"), {
            {
                label = BJILang.get("common.buttons.cancel"),
            },
            {
                label = BJILang.get("common.buttons.confirm"),
                onClick = function()
                    LoadTheme(BJIContext.BJC.Theme)
                    BJIContext.ThemeEditor = nil
                end
            }
        })
    else
        BJIContext.ThemeEditor = nil
    end
end

local function drawFields()
    AccordionBuilder()
        :label(BJILang.get("themeEditor.Fields.title"))
        :openedBehavior(function()
            for k, v in pairs(te.data.Fields) do
                ColorPicker({
                    id = svar("colorPickerField{1}", { k }),
                    label = BJILang.get(svar("themeEditor.Fields.{1}", { k })),
                    value = RGBA(v[1], v[2], v[3], v[4]),
                    alpha = true,
                    onChange = function(color)
                        te.changed = true
                        te.data.Fields[k] = { color.x, color.y, color.z, color.w }
                        updateTheme()
                    end
                })
            end
        end)
        :build()
end

local function drawTextsPresets()
    AccordionBuilder()
        :label(BJILang.get("themeEditor.Text.title"))
        :openedBehavior(function()
            for k, v in pairs(te.data.Text) do
                ColorPicker({
                    id = svar("colorPickerText{1}", { k }),
                    label = BJILang.get(svar("themeEditor.Text.{1}", { k })),
                    value = RGBA(v[1], v[2], v[3], v[4]),
                    alpha = true,
                    onChange = function(color)
                        te.changed = true
                        te.data.Text[k] = { color.x, color.y, color.z, color.w }
                        updateTheme()
                    end
                })
            end
        end)
        :build()
end

local function drawButtonsPresets()
    AccordionBuilder()
        :label(BJILang.get("themeEditor.Button.title"))
        :openedBehavior(function()
            for k, v in pairs(te.data.Button) do
                AccordionBuilder()
                    :label(BJILang.get(svar("themeEditor.Button.{1}", { k })))
                    :openedBehavior(function()
                        for i, key in ipairs({
                            "baseColor",
                            "hoveredColor",
                            "activeColor",
                        }) do
                            ColorPicker({
                                id = svar("colorPickerButton{1}{2}", { k, key }),
                                label = BJILang.get(svar("themeEditor.Button.{1}", { key })),
                                value = RGBA(v[i][1], v[i][2], v[i][3], v[i][4]),
                                alpha = true,
                                onChange = function(color)
                                    te.changed = true
                                    te.data.Button[k][i] = { color.x, color.y, color.z, color.w }
                                    updateTheme()
                                end
                            })
                        end
                    end)
                    :build()
            end
        end)
        :build()
end

local function drawInputsPresets()
    AccordionBuilder()
        :label(BJILang.get("themeEditor.Input.title"))
        :openedBehavior(function()
            for k, v in pairs(te.data.Input) do
                AccordionBuilder()
                    :label(BJILang.get(svar("themeEditor.Input.{1}", { k })))
                    :openedBehavior(function()
                        for i, key in ipairs({
                            "baseColor",
                            "textColor",
                        }) do
                            if i == 2 then
                                LineBuilder()
                                    :text(BJILang.get("themeEditor.Input.overrideTextColor"))
                                    :btnSwitchYesNo({
                                        id = svar("colorPickerInputTextOverride{1}", { k }),
                                        state = not not v[i],
                                        onClick = function()
                                            te.changed = true
                                            if v[i] then
                                                v[i] = nil
                                            else
                                                v[i] = tdeepcopy(te.data.Fields.TEXT_COLOR)
                                            end
                                            updateTheme()
                                        end
                                    })
                                    :build()
                            end
                            if v[i] then
                                ColorPicker({
                                    id = svar("colorPickerInput{1}{2}", { k, key }),
                                    label = BJILang.get(svar("themeEditor.Input.{1}", { key })),
                                    value = RGBA(v[i][1], v[i][2], v[i][3], v[i][4]),
                                    alpha = true,
                                    onChange = function(color)
                                        te.changed = true
                                        te.data.Input[k][i] = { color.x, color.y, color.z, color.w }
                                        updateTheme()
                                    end
                                })
                            end
                        end
                    end)
                    :build()
            end
        end)
        :build()
end

local function drawBody(ctxt)
    te = BJIContext.ThemeEditor
    if not BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CORE) then
        BJIContext.ThemeEditor = nil
        return
    end

    drawFields()
    drawTextsPresets()
    drawButtonsPresets()
    drawInputsPresets()
end

local function drawFooter(ctxt)
    local line = LineBuilder()
        :btnIcon({
            id = "cancel",
            icon = ICONS.exit_to_app,
            background = BTN_PRESETS.ERROR,
            onClick = onClose,
        })
    if te.changed then
        line:btnIcon({
            id = "reset",
            icon = ICONS.refresh,
            background = BTN_PRESETS.WARNING,
            onClick = function()
                te.data = tdeepcopy(BJIContext.BJC.Server.Theme)
                te.changed = false
                updateTheme()
            end,
        })
            :btnIcon({
                id = "save",
                icon = ICONS.save,
                background = BTN_PRESETS.SUCCESS,
                onClick = save,
            })
    end
    line:build()
end

return {
    body = drawBody,
    footer = drawFooter,
    onClose = onClose,
}
