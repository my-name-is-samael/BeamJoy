local M = {
    cache = {
        label = nil,
        ---@type MenuDropdownElement[]
        elems = {},
    },
}

---@param ctxt TickContext
local function menuServer(ctxt)
    if Table({ BJI_Perm.PERMISSIONS.SET_CONFIG, BJI_Perm.PERMISSIONS.SET_CORE,
            BJI_Perm.PERMISSIONS.SET_CEN, BJI_Perm.PERMISSIONS.SET_MAPS,
            BJI_Perm.PERMISSIONS.SET_PERMISSIONS, BJI_Perm.PERMISSIONS.WHITELIST })
        :any(function(p) return BJI_Perm.hasPermission(p) end) then
        table.insert(M.cache.elems, {
            type = "item",
            label = BJI_Lang.get("menu.config.server"),
            active = BJI_Win_Server.show,
            onClick = function()
                BJI_Win_Server.show = not BJI_Win_Server.show
            end
        })
    end
end

---@param ctxt TickContext
local function menuEnvironment(ctxt)
    if BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SET_ENVIRONMENT) then
        table.insert(M.cache.elems, {
            type = "item",
            label = BJI_Lang.get("menu.config.environment"),
            active = BJI_Win_Environment.show,
            onClick = function()
                if BJI_Win_Environment.show then
                    BJI_Win_Environment.onClose()
                else
                    BJI_Win_Environment.open()
                end
            end
        })
    end
end

---@param ctxt TickContext
local function menuTheme(ctxt)
    if BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SET_CORE) then
        table.insert(M.cache.elems, {
            type = "item",
            label = BJI_Lang.get("menu.config.theme"),
            active = BJI_Win_Theme.show,
            onClick = function()
                if BJI_Win_Theme.show then
                    BJI_Win_Theme.onClose()
                else
                    BJI_Win_Theme.open()
                end
            end
        })
    end
end

---@param ctxt TickContext
local function menuDatabase(ctxt)
    if BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.DATABASE_PLAYERS) or
        BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.DATABASE_VEHICLES) then
        table.insert(M.cache.elems, {
            type = "item",
            label = BJI_Lang.get("menu.config.database"),
            active = BJI_Win_Database.show,
            onClick = function()
                BJI_Win_Database.show = not BJI_Win_Database.show
            end
        })
    end
end

---@param ctxt TickContext
local function menuStopServer(ctxt)
    if BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SET_CORE) then
        table.insert(M.cache.elems, {
            type = "item",
            label = BJI_Lang.get("menu.config.stop"),
            onClick = function()
                BJI_Popup.createModal(BJI_Lang.get("menu.config.stopModal"), {
                    BJI_Popup.createButton(BJI_Lang.get("common.buttons.cancel")),
                    BJI_Popup.createButton(BJI_Lang.get("common.buttons.confirm"),
                        function()
                            BJI_Tx_config.stop()
                        end),
                })
            end,
        })
    end
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI_Tick.getContext()
    M.cache = {
        label = BJI_Lang.get("menu.config.title"),
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
    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.PERMISSION_CHANGED,
        BJI_Events.EVENTS.WINDOW_VISIBILITY_TOGGLED,
        BJI_Events.EVENTS.LANG_CHANGED,
        BJI_Events.EVENTS.UI_UPDATE_REQUEST
    }, updateCache, "MainMenuConfig"))
end

function M.onUnload()
    listeners:forEach(BJI_Events.removeListener)
end

---@param ctxt TickContext
function M.draw(ctxt)
    if #M.cache.elems > 0 then
        RenderMenuDropdown(M.cache.label, M.cache.elems)
    end
end

return M
