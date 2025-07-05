local M = {
    cache = {
        label = nil,
        ---@type MenuDropdownElement[]
        elems = {},
    },
}

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI.Managers.Tick.getContext()
    M.cache = {
        label = BJI.Managers.Lang.get("menu.me.title"),
        elems = {},
    }

    -- SETTINGS
    table.insert(M.cache.elems, {
        type = "item",
        label = BJI.Managers.Lang.get("menu.me.settings"),
        active = BJI.Windows.UserSettings.show,
        onClick = function()
            BJI.Windows.UserSettings.show = not BJI.Windows.UserSettings.show
        end
    })

    -- VEHICLE SELECTOR
    if not BJI.Managers.Restrictions.getState(BJI.Managers.Restrictions._SCENARIO_DRIVEN.VEHICLE_SELECTOR) then
        table.insert(M.cache.elems, {
            type = "item",
            label = BJI.Managers.Lang.get("menu.me.vehicleSelector"),
            active = BJI.Windows.VehSelector.show,
            onClick = function()
                if BJI.Windows.VehSelector.show then
                    BJI.Windows.VehSelector.tryClose()
                else
                    BJI.Windows.VehSelector.open(true)
                end
            end
        })
    end

    -- CLEAR GPS
    if BJI.Managers.GPS.isClearable() then
        table.insert(M.cache.elems, {
            type = "item",
            label = BJI.Managers.Lang.get("menu.me.clearGPS"),
            onClick = BJI.Managers.GPS.clear,
        })
    end
end

local listeners = Table()
function M.onLoad()
    updateCache()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.SCENARIO_CHANGED,
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.WINDOW_VISIBILITY_TOGGLED,
        BJI.Managers.Events.EVENTS.GPS_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST
    }, updateCache, "MainMenuMe"))
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
