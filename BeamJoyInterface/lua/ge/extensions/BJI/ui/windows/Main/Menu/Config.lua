local M = {
    cache = {
        label = nil,
        ---@type MenuDropdownElement[]
        elems = {},
    },
}

---@param ctxt TickContext
local function menuServer(ctxt)
    if Table({ BJI.Managers.Perm.PERMISSIONS.SET_CONFIG, BJI.Managers.Perm.PERMISSIONS.SET_CORE,
            BJI.Managers.Perm.PERMISSIONS.SET_CEN, BJI.Managers.Perm.PERMISSIONS.SET_MAPS,
            BJI.Managers.Perm.PERMISSIONS.SET_PERMISSIONS, BJI.Managers.Perm.PERMISSIONS.WHITELIST })
        :any(function(p) return BJI.Managers.Perm.hasPermission(p) end) then
        table.insert(M.cache.elems, {
            type = "item",
            label = BJI.Managers.Lang.get("menu.config.server"),
            active = BJI.Windows.Server.show,
            onClick = function()
                BJI.Windows.Server.show = not BJI.Windows.Server.show
            end
        })
    end
end

---@param ctxt TickContext
local function menuEnvironment(ctxt)
    if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SET_ENVIRONMENT) then
        table.insert(M.cache.elems, {
            type = "item",
            label = BJI.Managers.Lang.get("menu.config.environment"),
            active = BJI.Windows.Environment.show,
            onClick = function()
                if BJI.Windows.Environment.show then
                    BJI.Windows.Environment.onClose()
                else
                    BJI.Windows.Environment.open()
                end
            end
        })
    end
end

---@param ctxt TickContext
local function menuTheme(ctxt)
    if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SET_CORE) then
        table.insert(M.cache.elems, {
            type = "item",
            label = BJI.Managers.Lang.get("menu.config.theme"),
            active = BJI.Windows.Theme.show,
            onClick = function()
                if BJI.Windows.Theme.show then
                    BJI.Windows.Theme.onClose()
                else
                    BJI.Windows.Theme.open()
                end
            end
        })
    end
end

---@param ctxt TickContext
local function menuDatabase(ctxt)
    if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.DATABASE_PLAYERS) or
        BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.DATABASE_VEHICLES) then
        table.insert(M.cache.elems, {
            type = "item",
            label = BJI.Managers.Lang.get("menu.config.database"),
            active = BJI.Windows.Database.show,
            onClick = function()
                BJI.Windows.Database.show = not BJI.Windows.Database.show
            end
        })
    end
end

---@param ctxt TickContext
local function menuStopServer(ctxt)
    if BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SET_CORE) then
        table.insert(M.cache.elems, {
            type = "item",
            label = BJI.Managers.Lang.get("menu.config.stop"),
            onClick = function()
                BJI.Managers.Popup.createModal(BJI.Managers.Lang.get("menu.config.stopModal"), {
                    BJI.Managers.Popup.createButton(BJI.Managers.Lang.get("common.buttons.cancel")),
                    BJI.Managers.Popup.createButton(BJI.Managers.Lang.get("common.buttons.confirm"),
                        function()
                            BJI.Tx.config.stop()
                        end),
                })
            end,
        })
    end
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI.Managers.Tick.getContext()
    M.cache = {
        label = BJI.Managers.Lang.get("menu.config.title"),
        elems = {},
    }

    menuServer(ctxt)
    menuEnvironment(ctxt)
    menuTheme(ctxt)
    menuDatabase(ctxt)
    menuStopServer(ctxt)

    MenuDropdownSanitize(M.cache.elems)
end

local listeners = Table()
function M.onLoad()
    updateCache()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        BJI.Managers.Events.EVENTS.WINDOW_VISIBILITY_TOGGLED,
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST
    }, updateCache, "MainMenuConfig"))
end

function M.onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

---@param ctxt TickContext
function M.draw(ctxt)
    if #M.cache.elems > 0 then
        RenderMenuDropdown(M.cache.label, M.cache.elems)
    end
end

return M
