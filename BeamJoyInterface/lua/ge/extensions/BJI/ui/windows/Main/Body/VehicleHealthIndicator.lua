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
    damages = (ctxt.isOwner and BJI_Veh.getVehicleObject(ctxt.veh.gameVehicleID)) and
        tonumber(ctxt.veh.veh.damageState) or nil
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
                BJI_Stations.setGPS()
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
