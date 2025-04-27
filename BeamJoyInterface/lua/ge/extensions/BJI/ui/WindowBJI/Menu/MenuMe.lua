return function(ctxt)
    local meEntry = {
        label = BJILang.get("menu.me.title"),
        elems = {},
    }

    -- SETTINGS
    table.insert(meEntry.elems, {
        label = BJILang.get("menu.me.settings"),
        active = BJIContext.UserSettings.open,
        onClick = function()
            BJIContext.UserSettings.open = not BJIContext.UserSettings.open
        end
    })

    -- VEHICLE SELECTOR
    if BJIPerm.canSpawnVehicle() and
        BJIScenario.canSelectVehicle() then
        table.insert(meEntry.elems, {
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
            table.insert(meEntry.elems, {
                label = BJILang.get("menu.me.clearGPS"),
                onClick = BJIGPS.clear,
            })
        end
    end

    return #meEntry.elems > 0 and meEntry or nil
end
