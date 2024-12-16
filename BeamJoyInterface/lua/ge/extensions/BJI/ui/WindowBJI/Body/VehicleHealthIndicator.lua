local function drawHealth(ctxt)
    local veh = ctxt.vehData

    if not ctxt.vehData or not ctxt.vehData.damageState then
        return
    end

    local damageThreshold = BJIContext.physics.VehiclePristineThreshold

    if BJIScenario.is(BJIScenario.TYPES.VEHICLE_DELIVERY) then
        if ctxt.vehData.damageState > damageThreshold then
            LineBuilder()
                :text(BJILang.get("vehicleDelivery.damagedWarning"), TEXT_COLORS.HIGHLIGHT)
                :build()
        end
    else
        if ctxt.vehData.damageState > damageThreshold then
            local line = LineBuilder()
                :text(BJILang.get("garages.damagedWarning"))
            if BJIScenario.canRepairAtGarage() then
                if BJIContext.Scenario.Data.Garages and #BJIContext.Scenario.Data.Garages > 0 then
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
                    })
                end
            end
            line:build()

            Separator()
        end
    end
end
return drawHealth
