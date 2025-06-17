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
    local damages = ctxt.isOwner and tonumber(ctxt.veh.damageState) or nil
    return damages ~= nil and damages > cache.damageThreshold
end

---@param ctxt TickContext
local function draw(ctxt)
    if not isVisible(ctxt) then
        return
    end

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
                    BJI.Managers.GPS.prependWaypoint({
                        key = BJI.Managers.GPS.KEYS.STATION,
                        pos = garages[1].garage.pos,
                        radius = garages[1].garage.radius
                    })
                end
            end,
            sound = BTN_NO_SOUND,
        })
    end
    line:build()
end

return {
    updateCache = updateCache,
    isVisible = isVisible,
    draw = draw,
}
