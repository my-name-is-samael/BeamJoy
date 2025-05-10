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

local function updateCache(ctxt)
    cache = newCache()

    cache.damageThreshold = BJIContext.physics.VehiclePristineThreshold
    cache.canShowDeliveryDamagedWarning = ctxt.vehData and BJIScenario.is(BJIScenario.TYPES.VEHICLE_DELIVERY)
    cache.canShowGlobalDamageWarning = ctxt.vehData and not cache.canShowDeliveryDamagedWarning
    cache.showGPSButton = cache.canShowGlobalDamageWarning and BJIScenario.canRepairAtGarage() and
        BJIContext.Scenario.Data.Garages and #BJIContext.Scenario.Data.Garages > 0

    cache.labels.deliveryDamageWarning = BJILang.get("vehicleDelivery.damagedWarning")
    cache.labels.damageWarning = BJILang.get("garages.damagedWarning")
end

local function draw(ctxt)
    if not ctxt.vehData or not ctxt.vehData.damageState then
        return
    end

    if ctxt.vehData.damageState > cache.damageThreshold then
        if cache.canShowDeliveryDamagedWarning then
            LineBuilder()
                :text(cache.labels.deliveryDamageWarning, TEXT_COLORS.HIGHLIGHT)
                :build()
        elseif cache.canShowGlobalDamageWarning then
            local line = LineBuilder()
                :text(cache.labels.damageWarning)
            if cache.showGPSButton then
                line:btnIcon({
                    id = "setRouteGarage",
                    icon = ICONS.add_location,
                    style = BTN_PRESETS.SUCCESS,
                    onClick = function()
                        local garages = {}
                        for _, garage in ipairs(BJIContext.Scenario.Data.Garages) do
                            local distance = BJIGPS.getRouteLength({
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
                            BJIGPS.prependWaypoint(BJIGPS.KEYS.STATION, garages[1].garage.pos,
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
