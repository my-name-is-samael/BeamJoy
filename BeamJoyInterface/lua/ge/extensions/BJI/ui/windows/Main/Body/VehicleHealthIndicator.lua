local function newCache()
    return {
        damageThreshold = 0,
        canShowDeliveryDamagedWarning = false,
        showGPSButton = false,
        labels = {
            damageWarning = "",
        },
    }
end
-- gc prevention
local damages, garages, distance

local cache = newCache()

---@param ctxt TickContext
local function updateCache(ctxt)
    cache = newCache()

    cache.damageThreshold = BJI_Context.VehiclePristineThreshold
    cache.showGPSButton = ctxt.isOwner and
        BJI_Scenario.canRepairAtGarage() and
        BJI_Stations.Data.Garages and
        #BJI_Stations.Data.Garages > 0 and
        (not BJI_Stations.station or BJI_Stations.station.isEnergy)

    cache.labels.damageWarning = BJI_Lang.get("garages.damagedWarning")
end

---@param ctxt TickContext
---@return boolean
local function isVisible(ctxt)
    damages = ctxt.isOwner and tonumber(ctxt.veh.veh.damageState) or nil
    return damages ~= nil and damages > cache.damageThreshold
end

---@param ctxt TickContext
local function draw(ctxt)
    if BeginTable("BJIMainVehicleHelthIndicator", {
            { label = "##main-health-indicator-indicator", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
            { label = "##main-health-indicator-button" },
        }) then
        TableNewRow()
        Text(cache.labels.damageWarning)
        TableNextColumn()
        if cache.showGPSButton then
            if IconButton("setRouteGarage", #BJI_GPS.targets > 0 and
                    BJI.Utils.Icon.ICONS.simobject_bng_waypoint or BJI.Utils.Icon.ICONS.add_location,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, noSound = true }) then
                garages = {}
                for _, garage in ipairs(BJI_Stations.Data.Garages) do
                    distance = BJI_GPS.getRouteLength({
                        ctxt.veh.position,
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
                    BJI_GPS.prependWaypoint({
                        key = BJI_GPS.KEYS.STATION,
                        pos = garages[1].garage.pos,
                        radius = garages[1].garage.radius
                    })
                end
            end
            TooltipText(BJI_Lang.get("common.buttons.setGPS"))
        end

        EndTable()
    end
end

return {
    updateCache = updateCache,
    isVisible = isVisible,
    draw = draw,
}
