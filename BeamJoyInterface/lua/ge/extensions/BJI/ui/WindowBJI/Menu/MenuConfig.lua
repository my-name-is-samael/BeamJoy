local M = {
    cache = {
        label = nil,
        elems = {},
    },
}

local function menuServer(ctxt)
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CONFIG) or
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CORE) or
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CEN) or
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_MAPS) or
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_PERMISSIONS) then
        table.insert(M.cache.elems, {
            label = BJILang.get("menu.config.server"),
            active = BJIContext.ServerEditorOpen,
            onClick = function()
                BJIContext.ServerEditorOpen = not BJIContext.ServerEditorOpen
            end
        })
    end
end

local function menuEnvironment(ctxt)
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_ENVIRONMENT) then
        table.insert(M.cache.elems, {
            label = BJILang.get("menu.config.environment"),
            active = BJIContext.EnvironmentEditorOpen,
            onClick = function()
                BJIContext.EnvironmentEditorOpen = not BJIContext.EnvironmentEditorOpen
            end
        })
    end
end

local function menuTheme(ctxt)
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CORE) then
        table.insert(M.cache.elems, {
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
                        data = table.clone(BJIContext.BJC.Server.Theme),
                    }
                end
            end
        })
    end
end

local function menuDatabase(ctxt)
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.DATABASE_PLAYERS) or
        BJIPerm.hasPermission(BJIPerm.PERMISSIONS.DATABASE_VEHICLES) then
        table.insert(M.cache.elems, {
            label = BJILang.get("menu.config.database"),
            active = BJIContext.DatabaseEditorOpen,
            onClick = function()
                BJIContext.DatabaseEditorOpen = not BJIContext.DatabaseEditorOpen
            end
        })
    end
end

local function menuStopServer(ctxt)
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CORE) then
        table.insert(M.cache.elems, {
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
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJITick.getContext()
    M.cache = {
        label = BJILang.get("menu.config.title"),
        elems = {},
    }

    menuServer(ctxt)
    menuEnvironment(ctxt)
    menuTheme(ctxt)
    menuDatabase(ctxt)
    menuStopServer(ctxt)
end

local listeners = Table()
function M.onLoad()
    updateCache()
    listeners:insert(BJIEvents.addListener({
        BJIEvents.EVENTS.PERMISSION_CHANGED,
        BJIEvents.EVENTS.WINDOW_VISIBILITY_TOGGLED,
        BJIEvents.EVENTS.LANG_CHANGED,
        BJIEvents.EVENTS.UI_UPDATE_REQUEST
    }, updateCache))
end

function M.onUnload()
    listeners:forEach(BJIEvents.removeListener)
end

return M
