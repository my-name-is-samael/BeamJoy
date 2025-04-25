return function(ctxt)
    local configEntry = {
        label = BJILang.get("menu.config.title"),
        elems = {},
    }

    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CONFIG) or
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CORE) or
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CEN) or
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_MAPS) or
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_PERMISSIONS) then
        table.insert(configEntry.elems, {
            label = BJILang.get("menu.config.server"),
            active = BJIContext.ServerEditorOpen,
            onClick = function()
                BJIContext.ServerEditorOpen = not BJIContext.ServerEditorOpen
            end
        })
    end

    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_ENVIRONMENT) then
        table.insert(configEntry.elems, {
            label = BJILang.get("menu.config.environment"),
            active = BJIContext.EnvironmentEditorOpen,
            onClick = function()
                BJIContext.EnvironmentEditorOpen = not BJIContext.EnvironmentEditorOpen
            end
        })
    end

    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CORE) then
        table.insert(configEntry.elems, {
            label = BJILang.get("menu.config.theme"),
            active = BJIContext.ThemeEditor,
            onClick = function()
                if BJIContext.ThemeEditor then
                    if BJIContext.ThemeEditor.changed then
                        BJIPopup.createModal(BJILang.get("themeEditor.cancelModal"), {
                            {
                                label = BJILang.get("common.buttons.cancel"),
                            },
                            {
                                label = BJILang.get("common.buttons.confirm"),
                                onClick = function()
                                    LoadTheme(BJIContext.BJC.Server.Theme)
                                    BJIContext.ThemeEditor = nil
                                end
                            }
                        })
                    else
                        BJIContext.ThemeEditor = nil
                    end
                else
                    BJIContext.ThemeEditor = {
                        data = tdeepcopy(BJIContext.BJC.Server.Theme),
                    }
                end
            end
        })
    end

    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.DATABASE_PLAYERS) or
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.DATABASE_VEHICLES) then
        table.insert(configEntry.elems, {
            label = BJILang.get("menu.config.database"),
            active = BJIContext.DatabaseEditorOpen,
            onClick = function()
                BJIContext.DatabaseEditorOpen = not BJIContext.DatabaseEditorOpen
            end
        })
    end

    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CORE) then
        table.insert(configEntry.elems, {
            label = BJILang.get("menu.config.stop"),
            onClick = function()
                BJIPopup.createModal(BJILang.get("menu.config.stopModal"), {
                    {
                        label = BJILang.get("common.buttons.cancel"),
                    },
                    {
                        label = BJILang.get("common.buttons.confirm"),
                        onClick = BJITx.config.stop,
                    }
                })
            end,
        })
    end

    return #configEntry.elems > 0 and configEntry or nil
end
