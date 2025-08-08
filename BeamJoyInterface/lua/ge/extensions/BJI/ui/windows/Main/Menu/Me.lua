local M = {
    cache = {
        label = nil,
        ---@type MenuDropdownElement[]
        elems = {},
    },
}

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI_Tick.getContext()
    M.cache = {
        label = BJI_Lang.get("menu.me.title"),
        elems = {},
    }

    -- SETTINGS
    table.insert(M.cache.elems, {
        type = "item",
        label = BJI_Lang.get("menu.me.settings"),
        active = BJI_Win_UserSettings.show,
        onClick = function()
            BJI_Win_UserSettings.show = not BJI_Win_UserSettings.show
        end
    })

    -- VEHICLE SELECTOR
    if not BJI_Restrictions.getState(BJI_Restrictions._SCENARIO_DRIVEN.VEHICLE_SELECTOR) then
        table.insert(M.cache.elems, {
            type = "item",
            label = BJI_Lang.get("menu.me.vehicleSelector"),
            active = BJI_Win_VehSelector.show,
            onClick = function()
                if BJI_Win_VehSelector.show then
                    BJI_Win_VehSelector.tryClose()
                else
                    BJI_Win_VehSelector.open(true)
                end
            end
        })
    end

    -- CLEAR GPS
    if BJI_GPS.isClearable() then
        table.insert(M.cache.elems, {
            type = "item",
            label = BJI_Lang.get("menu.me.clearGPS"),
            onClick = BJI_GPS.clear,
        })
    end
end

local listeners = Table()
function M.onLoad()
    updateCache()
    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.SCENARIO_CHANGED,
        BJI_Events.EVENTS.PERMISSION_CHANGED,
        BJI_Events.EVENTS.LANG_CHANGED,
        BJI_Events.EVENTS.WINDOW_VISIBILITY_TOGGLED,
        BJI_Events.EVENTS.GPS_CHANGED,
        BJI_Events.EVENTS.UI_UPDATE_REQUEST
    }, updateCache, "MainMenuMe"))
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
