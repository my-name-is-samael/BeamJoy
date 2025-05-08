local M = {
    cache = {
        label = nil,
        elems = {},
    },
}

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJITick.getContext()
    M.cache = {
        label = BJILang.get("menu.me.title"),
        elems = {},
    }

    -- SETTINGS
    table.insert(M.cache.elems, {
        label = BJILang.get("menu.me.settings"),
        active = BJIUserSettingsWindow.show,
        onClick = function()
            BJIUserSettingsWindow.show = not BJIUserSettingsWindow.show
        end
    })

    -- VEHICLE SELECTOR
    if BJIPerm.canSpawnVehicle() and
        BJIScenario.canSelectVehicle() then
        table.insert(M.cache.elems, {
            label = BJILang.get("menu.me.vehicleSelector"),
            active = BJIVehSelector.state,
            onClick = function()
                if BJIVehSelector.state then
                    BJIVehSelector.tryClose()
                else
                    local models = BJIScenario.getModelList()
                    if table.length(models) > 0 then
                        BJIVehSelector.open(models, true)
                    end
                end
            end
        })

        -- CLEAR GPS
        if BJIGPS.isClearable() then
            table.insert(M.cache.elems, {
                label = BJILang.get("menu.me.clearGPS"),
                onClick = BJIGPS.clear,
            })
        end
    end
end

local listeners = Table()
function M.onLoad()
    updateCache()
    listeners:insert(BJIEvents.addListener({
        BJIEvents.EVENTS.SCENARIO_CHANGED,
        BJIEvents.EVENTS.PERMISSION_CHANGED,
        BJIEvents.EVENTS.LANG_CHANGED,
        BJIEvents.EVENTS.WINDOW_VISIBILITY_TOGGLED,
        BJIEvents.EVENTS.GPS_CHANGED,
        BJIEvents.EVENTS.UI_UPDATE_REQUEST
    }, updateCache))
end

function M.onUnload()
    listeners:forEach(BJIEvents.removeListener)
end

return M
