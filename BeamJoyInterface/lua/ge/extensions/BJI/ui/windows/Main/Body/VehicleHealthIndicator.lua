local function newCache()
    return {
        damageThreshold = 0,
        canShowDeliveryDamagedWarning = false,
        canShowGlobalDamageWarning = false,
        showGPSButton = false,
        labels = {
            deliveryDamageWarning = "",
            damageWarning = "",
        },
    }
end

local cache = newCache()

---@param ctxt TickContext
local function updateCache(ctxt)
    cache = newCache()

    cache.damageThreshold = BJI.Managers.Context.VehiclePristineThreshold
    cache.canShowGlobalDamageWarning = ctxt.vehData ~= nil
    cache.showGPSButton = cache.canShowGlobalDamageWarning and BJI.Managers.Scenario.canRepairAtGarage() and
        BJI.Managers.Context.Scenario.Data.Garages and #BJI.Managers.Context.Scenario.Data.Garages > 0 and
        (not BJI.Managers.Stations.station or BJI.Managers.Stations.station.isEnergy)

    cache.labels.deliveryDamageWarning = BJI.Managers.Lang.get("vehicleDelivery.damagedWarning")
    cache.labels.damageWarning = BJI.Managers.Lang.get("garages.damagedWarning")
end

local function draw(ctxt)
    if not ctxt.vehData or not ctxt.vehData.damageState then
        return
    end

    if ctxt.vehData.damageState > cache.damageThreshold then
        if cache.canShowGlobalDamageWarning then
            local line = LineBuilder()
                :text(cache.labels.damageWarning)
            if cache.showGPSButton then
                line:btnIcon({
                    id = "setRouteGarage",
                    icon = BJI.Utils.Icon.ICONS.add_location,
                    style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                    tooltip = BJI.Managers.Lang.get("common.buttons.setGPS"),
                    onClick = function()
                        local garages = {}
                        for _, garage in ipairs(BJI.Managers.Context.Scenario.Data.Garages) do
                            local distance = BJI.Managers.GPS.getRouteLength({
                                ctxt.vehPosRot.pos,
                                garage.pos
                            })
                            table.insert(garages, {
                                garage = garage,
                                distance = distance
                            })
                        end
                        if #garages > 0 then
                            table.sort(garages, function(a, b)
                                return a.distance < b.distance
                            end)
                            BJI.Managers.GPS.prependWaypoint(BJI.Managers.GPS.KEYS.STATION, garages[1].garage.pos,
                                garages[1].garage.radius)
                        end
                    end,
                    sound = BTN_NO_SOUND,
                })
            end
            line:build()

            Separator()
        end
    end
end

return {
    updateCache = updateCache,
    draw = draw,
}
