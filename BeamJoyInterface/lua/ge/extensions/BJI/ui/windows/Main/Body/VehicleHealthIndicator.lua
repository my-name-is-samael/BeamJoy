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

    cache.damageThreshold = BJI.Managers.Context.VehiclePristineThreshold
    cache.showGPSButton = ctxt.isOwner and
        BJI.Managers.Scenario.canRepairAtGarage() and
        BJI.Managers.Context.Scenario.Data.Garages and
        #BJI.Managers.Context.Scenario.Data.Garages > 0 and
        (not BJI.Managers.Stations.station or BJI.Managers.Stations.station.isEnergy)

    cache.labels.damageWarning = BJI.Managers.Lang.get("garages.damagedWarning")
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
            if IconButton("setRouteGarage", #BJI.Managers.GPS.targets > 0 and
                    BJI.Utils.Icon.ICONS.simobject_bng_waypoint or BJI.Utils.Icon.ICONS.add_location,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, noSound = true }) then
                garages = {}
                for _, garage in ipairs(BJI.Managers.Context.Scenario.Data.Garages) do
                    distance = BJI.Managers.GPS.getRouteLength({
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
                    BJI.Managers.GPS.prependWaypoint({
                        key = BJI.Managers.GPS.KEYS.STATION,
                        pos = garages[1].garage.pos,
                        radius = garages[1].garage.radius
                    })
                end
            end
            TooltipText(BJI.Managers.Lang.get("common.buttons.setGPS"))
        end

        EndTable()
    end
end

return {
    updateCache = updateCache,
    isVisible = isVisible,
    draw = draw,
}
