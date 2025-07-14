---@class BJIStation
---@field name string
---@field pos vec3
---@field radius number
---@field types string[]?
---@field isEnergy boolean

---@class BJIManagerStations : BJIManager
local M = {
    _name = "Stations",

    Data = {
        ---@type {name: string, pos: vec3, radius: number, types: string[]}[]
        EnergyStations = {},
        ---@type {name: string, pos: vec3, radius: number}[]
        Garages = {},
    },

    markersIDs = Table(),

    renderStationDistance = 50,
    COLORS = {
        GARAGE = BJI.Utils.ShapeDrawer.Color(1, .4, 0, .05),
        ENERGY = BJI.Utils.ShapeDrawer.Color(.2, 1, .2, .05),
        TEXT = BJI.Utils.ShapeDrawer.Color(1, 1, 1, .5),
        BG = BJI.Utils.ShapeDrawer.Color(0, 0, 0, .3),
    },

    ---@type BJIStation?
    station = nil,

    refuelBaseTime = 5,

    stationProcess = false,
}

local function updateMarkers()
    local function getID(prefix, name, i)
        return string.format("%s_%s_%d", prefix, name:gsub(" ", "_"), i)
    end
    local status
    M.markersIDs:forEach(BJI_InteractiveMarker.deleteMarker)
    M.markersIDs:clear()
    Table(M.Data.Garages):forEach(function(g, i)
        local id = getID("garage", g.name, i)
        status = pcall(BJI_InteractiveMarker.upsertMarker, id, BJI_InteractiveMarker.TYPES.GARAGE.icon,
            g.pos, g.radius, {
                color = BJI_InteractiveMarker.TYPES.GARAGE.color,
                visibleFreeCam = true,
                visibleAnyVeh = true,
                condition = function(ctxt)
                    return not BJI_Win_ScenarioEditor.is(BJI_Win_ScenarioEditor.TYPES.GARAGES) and
                        ctxt.veh and (
                            BJI_Scenario.canRepairAtGarage() or (
                                BJI_Scenario.canRefuelAtStation() and
                                ctxt.vehData and table.any(ctxt.vehData.tanks, function(t)
                                    return t.energyType == BJI_Veh.FUEL_TYPES.N2O
                                end)
                            )
                        )
                end,
                onEnter = function(ctxt)
                    if ctxt.isOwner then
                        M.station = table.assign({ isEnergy = false }, g)
                    end
                end,
                onLeave = function(ctxt)
                    M.station = nil
                end,
            }, {
                {
                    condition = function(ctxt)
                        return ctxt.isOwner and not M.stationProcess and
                            BJI_Scenario.canRepairAtGarage()
                    end,
                    icon = BJI_InteractiveMarker.TYPES.GARAGE.icon,
                    type = BJI_Lang.get("interactiveMarkers.garage.type"),
                    label = g.name,
                    buttonLabel = BJI_Lang.get("interactiveMarkers.garage.buttonRepair"),
                    callback = function(ctxt)
                        if tonumber(ctxt.veh.veh.damageState) >= 1 then
                            M.tryRepair(ctxt)
                        else
                            BJI_Toast.info(BJI_Lang.get("interactiveMarkers.garage.alreadyRepaired"))
                        end
                    end
                },
                {
                    condition = function(ctxt)
                        return ctxt.vehData and not M.stationProcess and
                            BJI_Scenario.canRefuelAtStation() and
                            table.any(ctxt.vehData.tanks, function(t)
                                return t.energyType == BJI_Veh.FUEL_TYPES.N2O
                            end) or false
                    end,
                    icon = BJI_InteractiveMarker.TYPES.ENERGY_STATION.icon,
                    type = BJI_Lang.get("interactiveMarkers.garage.type"),
                    label = g.name,
                    buttonLabel = BJI_Lang.get("interactiveMarkers.garage.refuelNOS"),
                    callback = function(ctxt)
                        local energy, total = 0, 0
                        local countTanks = table.reduce(ctxt.vehData.tanks, function(res, t)
                            if t.energyType == BJI_Veh.FUEL_TYPES.N2O then
                                energy = energy + t.currentEnergy
                                total = total + t.maxEnergy
                                res = res + 1
                            end
                            return res
                        end, 0)
                        if countTanks > 0 and energy / total < .95 then
                            M.tryRefuel(ctxt, { BJI_Veh.FUEL_TYPES.N2O }, 100, countTanks * M.refuelBaseTime)
                        else
                            BJI_Toast.info(BJI_Lang.get("interactiveMarkers.garage.alreadyFull"))
                        end
                    end
                },
            })
        if status then
            M.markersIDs:insert(id)
        else
            BJI_InteractiveMarker.deleteMarker(id)
        end
    end)

    Table(M.Data.EnergyStations):forEach(function(es, i)
        local id = getID("energyStation", es.name, i)
        local isElectric = #es.types == 1 and es.types[1] == BJI_Veh.FUEL_TYPES.ELECTRIC
        status = pcall(BJI_InteractiveMarker.upsertMarker, id, BJI_InteractiveMarker.TYPES.ENERGY_STATION.icon,
            es.pos, es.radius, {
                color = BJI_InteractiveMarker.TYPES.ENERGY_STATION.color,
                visibleFreeCam = true,
                visibleAnyVeh = true,
                condition = function(ctxt)
                    return not BJI_Win_ScenarioEditor.is(BJI_Win_ScenarioEditor.TYPES.STATIONS) and
                        BJI_Scenario.canRefuelAtStation() and ctxt.vehData and
                        Table(ctxt.vehData.tanks):any(function(t)
                            return table.includes(es.types, t.energyType)
                        end)
                end,
                onEnter = function(ctxt)
                    if ctxt.isOwner then
                        M.station = table.assign({ isEnergy = true }, es)
                    end
                end,
                onLeave = function()
                    M.station = nil
                end,
            }, {
                {
                    condition = function(ctxt)
                        return ctxt.vehData and not M.stationProcess and
                            table.any(ctxt.vehData.tanks, function(t)
                                return table.includes(es.types, t.energyType)
                            end) or false
                    end,
                    icon = BJI_InteractiveMarker.TYPES.ENERGY_STATION.icon,
                    type = BJI_Lang.get(isElectric and
                        "interactiveMarkers.electricStation.type" or
                        "interactiveMarkers.gasStation.type"),
                    label = es.name,
                    buttonLabel = BJI_Lang.get(isElectric and
                        "interactiveMarkers.electricStation.button" or
                        "interactiveMarkers.gasStation.button"),
                    callback = function(ctxt)
                        local tanks = table.reduce(ctxt.vehData.tanks, function(res, t)
                            if t.currentEnergy / t.maxEnergy < .95 then
                                table.insert(res, t)
                            end
                            return res
                        end, {})
                        if #tanks > 0 then
                            M.tryRefuel(ctxt, table.map(tanks, function(t) return t.energyType end)
                                :values(), 100, #tanks * M.refuelBaseTime)
                        else
                            BJI_Toast.info(BJI_Lang.get(isElectric and
                                "interactiveMarkers.electricStation.alreadyFull" or
                                "interactiveMarkers.gasStation.alreadyFull"))
                        end
                    end
                }
            })
        if status then
            M.markersIDs:insert(id)
        else
            BJI_InteractiveMarker.deleteMarker(id)
        end
    end)
end

local function initCacheHandlers()
    local _
    BJI_Cache.addRxHandler(BJI_Cache.CACHES.STATIONS, function(cacheData)
        M.Data.EnergyStations = table.map(cacheData.EnergyStations, function(es)
            _, es.pos = pcall(vec3, es.pos.x, es.pos.y, es.pos.z)
            return _ and es or nil
        end)
        M.Data.Garages = table.map(cacheData.Garages, function(g)
            _, g.pos = pcall(vec3, g.pos.x, g.pos.y, g.pos.z)
            return _ and g or nil
        end)

        updateMarkers()
    end)
end

---@param ctxt TickContext
---@return string[]
local function getRestrictions(ctxt)
    if M.stationProcess then
        return Table():addAll(BJI_Restrictions.RESETS.ALL, true)
            :addAll(BJI_Restrictions.OTHER.VEHICLE_SWITCH, true)
            :addAll(BJI_Restrictions.OTHER.CAMERA_CHANGE, true)
            :addAll(BJI_Restrictions.OTHER.FREE_CAM, true)
            :addAll(BJI_Restrictions.OTHER.BIG_MAP, true)
            :addAll(BJI_Restrictions.OTHER.PHOTO_MODE, true)
    end
    return {}
end

---@param ctxt TickContext
---@param id string
---@param durationSec integer
---@param beginCallback fun()?
---@param endCallback fun(ctxt: TickContext)?
local function commonStationProcess(ctxt, id, durationSec, beginCallback, endCallback)
    if not ctxt.veh or not ctxt.veh.isLocal then return end
    beginCallback = beginCallback or function() end
    endCallback = endCallback or function() end

    BJI_Veh.stopVehicle(ctxt.veh)
    M.stationProcess = true
    BJI_Restrictions.update()
    BJI_Events.trigger(BJI_Events.EVENTS.RESTRICTIONS_UPDATE)
    local previousCam = {
        name = ctxt.camera,
        posrot = ctxt.camera == BJI_Cam.CAMERAS.FREE and BJI_Cam.getPositionRotation() or nil
    }
    BJI_Cam.setCamera(BJI_Cam.CAMERAS.EXTERNAL)
    ctxt.vehData.freezeStation = true
    BJI_Veh.freeze(true, ctxt.veh.gameVehicleID)
    ctxt.vehData.engineStation = false
    BJI_Veh.engine(false, ctxt.veh.gameVehicleID)
    beginCallback()

    local timeout = GetCurrentTimeMillis() + durationSec * 1000 + 10 -- 10 ms to allow first flash to print
    BJI_Message.flashCountdown(id, timeout, false, nil, durationSec)
    BJI_Async.task(function(ctxt2)
        return not ctxt2.veh or ctxt2.now >= timeout
    end, function(ctxt2)
        if ctxt2.veh then
            ctxt.vehData.freezeStation = false
            if not ctxt.vehData.freeze then
                BJI_Veh.freeze(false, ctxt.vehData.gameVehID)
            end
            ctxt.vehData.engineStation = true
            if ctxt.vehData.engine then
                BJI_Veh.engine(true, ctxt.vehData.gameVehID)
            end
        else
            BJI_Message.cancelFlash(id)
        end
        if previousCam.name == BJI_Cam.CAMERAS.FREE then
            BJI_Cam.setCamera(previousCam.name)
            BJI_Cam.setPositionRotation(previousCam.posrot.pos, previousCam.posrot.rot)
        elseif ctxt2.veh then
            BJI_Cam.setCamera(previousCam.name)
        end
        endCallback(ctxt2)
        M.stationProcess = false
        BJI_Restrictions.update()
    end, id .. "-ended")
end

---@param ctxt TickContext
local function tryRefuel(ctxt, energyTypes, fillPercent, fillDuration)
    if not ctxt.isOwner or not ctxt.vehData or not ctxt.vehData.tanks then return end
    if not energyTypes or #energyTypes == 0 then return end

    -- no values = emergency refill
    fillDuration = fillDuration or BJI_Context.BJC.Freeroam.EmergencyRefuelDuration
    fillPercent = fillPercent or math.round(BJI_Context.BJC.Freeroam.EmergencyRefuelPercent / 100, 2)


    local tanksToRefuel = {}
    for tankName, tank in pairs(ctxt.vehData.tanks) do
        if table.includes(energyTypes, tank.energyType) then
            tanksToRefuel[tankName] = tank
        end
    end
    if table.length(tanksToRefuel) == 0 then return end

    commonStationProcess(ctxt, "BJIRefill", fillDuration, nil, function(ctxt2)
        if ctxt2.veh then
            for tankName, t in pairs(tanksToRefuel) do
                local targetEnergy = math.round(t.maxEnergy * fillPercent)
                BJI_Veh.setFuel(tankName, targetEnergy)
            end

            local completedKey = table.length(tanksToRefuel) > 1 and "energyStations.flashTanksFilled" or
                "energyStations.flashTankFilled"
            if #energyTypes == 1 and energyTypes[1] == BJI.CONSTANTS.ENERGY_STATION_TYPES.ELECTRIC then
                completedKey = "energyStations.flashBatteryFilled"
            end
            BJI_Message.flash("BJIRefillDone", BJI_Lang.get(completedKey), 3, false)
        end
    end)
end

---@param ctxt TickContext
local function tryRepair(ctxt)
    commonStationProcess(ctxt, "BJIStationRepair", 5, function()
        BJI_Reputation.onGarageRepair()
        BJI_Scenario.onGarageRepair()
    end, function(ctxt2)
        if ctxt2.veh then
            BJI_Veh.setPositionRotation(ctxt2.veh.position, nil, {
                safe = false
            })
            BJI_Veh.postResetPreserveEnergy(ctxt2.veh.gameVehicleID)
            BJI_Sound.play(BJI_Sound.SOUNDS.REPAIR)

            BJI_Message.flash("BJIStationRepairDone", BJI_Lang.get("garages.flashVehicleRepaired"), 3, false)
        end
    end)
end

M.getRestrictions = getRestrictions

M.tryRefuel = tryRefuel
M.tryRepair = tryRepair

M.onLoad = function()
    initCacheHandlers()

    BJI_Events.addListener(BJI_Events.EVENTS.LANG_CHANGED, updateMarkers, M._name)
end

return M
