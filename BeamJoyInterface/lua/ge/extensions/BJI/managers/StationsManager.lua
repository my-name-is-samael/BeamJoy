---@class BJIStation
---@field name string
---@field pos vec3
---@field radius number
---@field types string[]?
---@field isEnergy boolean

---@class BJIManagerStations : BJIManager
local M = {
    _name = "Stations",

    renderStationDistance = 50,
    COLORS = {
        GARAGE = BJI.Utils.ShapeDrawer.Color(1, .4, 0, .05),
        ENERGY = BJI.Utils.ShapeDrawer.Color(.2, 1, .2, .05),
        TEXT = BJI.Utils.ShapeDrawer.Color(1, 1, 1, .5),
        BG = BJI.Utils.ShapeDrawer.Color(0, 0, 0, .3),
    },

    ---@type BJIStation?
    station = nil,

    -- detection thread data
    detectionStations = {},
    detectionProcess = nil,
    detectionLimit = 20, -- amount of detection by frame

    stationProcess = false,
}

---@param ctxt TickContext
local function getVehEnergyTypes(ctxt)
    if not ctxt.vehData or not ctxt.vehData.tanks then
        return {}
    end

    local energyTypes = {}
    for _, tank in pairs(ctxt.vehData.tanks) do
        if not table.includes(energyTypes, tank.energyType) then
            table.insert(energyTypes, tank.energyType)
        end
    end
    return energyTypes
end

---@param ctxt TickContext
local function detectChunk(ctxt)
    if not ctxt.veh then
        return
    end

    local energyTypes = getVehEnergyTypes(ctxt)
    if #energyTypes == 0 then
        return
    end

    if not M.detectionProcess or M.detectionProcess > #M.detectionStations then
        M.detectionProcess = 0
    end

    local target = math.min(M.detectionProcess + M.detectionLimit, #M.detectionStations)

    for i = M.detectionProcess, target do
        local s = M.detectionStations[i]
        if s and ctxt.veh.position:distance(s.pos) <= s.radius then
            if not s.isEnergy then
                M.station = s
                M.detectionProcess = nil
                BJI_Events.trigger(BJI_Events.EVENTS.STATION_PROXIMITY_CHANGED)
                return
            end
            for _, type in ipairs(s.types) do
                if table.includes(energyTypes, type) then
                    M.station = s
                    M.detectionProcess = nil
                    BJI_Events.trigger(BJI_Events.EVENTS.STATION_PROXIMITY_CHANGED)
                    return
                end
            end
        end
    end

    M.detectionProcess = target
    if M.detectionProcess == #BJI_Context.Scenario.Data.Garages +
        #BJI_Context.Scenario.Data.EnergyStations then
        M.detectionProcess = nil
    end
end

---@param ctxt TickContext
local function renderTick(ctxt)
    if ctxt.camera == BJI_Cam.CAMERAS.BIG_MAP then
        return
    end
    local ownPos = (ctxt.camera == BJI_Cam.CAMERAS.FREE or not ctxt.veh) and
        BJI_Cam.getPositionRotation().pos or
        ctxt.veh.position


    if BJI_Scenario.canRepairAtGarage() and
        BJI_Context.Scenario.Data.Garages and
        BJI_Win_ScenarioEditor.view ~= BJI_Win_ScenarioEditor.SCENARIOS.GARAGES then
        for _, g in pairs(BJI_Context.Scenario.Data.Garages) do
            if ownPos:distance(g.pos) <= M.renderStationDistance then
                BJI.Utils.ShapeDrawer.Sphere(g.pos, g.radius, M.COLORS.GARAGE)
                local textPos = vec3(g.pos)
                local zOffset = g.radius
                if ctxt.veh then
                    zOffset = ctxt.veh.veh:getInitialHeight() * 1.5
                end
                textPos.z = textPos.z + zOffset
                BJI.Utils.ShapeDrawer.Text(g.name, textPos, M.COLORS.TEXT, M.COLORS.BG)
            end
        end
    end

    if BJI_Scenario.canRefuelAtStation() and
        BJI_Context.Scenario.Data.EnergyStations and
        BJI_Win_ScenarioEditor.view ~= BJI_Win_ScenarioEditor.SCENARIOS.STATIONS then
        local energyTypes = getVehEnergyTypes(ctxt)
        if #energyTypes > 0 then
            for _, s in pairs(BJI_Context.Scenario.Data.EnergyStations) do
                if ownPos:distance(s.pos) <= M.renderStationDistance then
                    local compatible = false
                    for _, type in ipairs(s.types) do
                        if table.includes(energyTypes, type) then
                            compatible = true
                            break
                        end
                    end
                    if compatible then
                        BJI.Utils.ShapeDrawer.Sphere(s.pos, s.radius, M.COLORS.ENERGY)
                        local textPos = vec3(s.pos)
                        textPos.z = textPos.z + ctxt.veh.veh:getInitialHeight() * 1.5
                        BJI.Utils.ShapeDrawer.Text(s.name, textPos, M.COLORS.TEXT, M.COLORS.BG)
                    end
                end
            end
        end
    end
end

---@param ctxt TickContext
local function fastTick(ctxt)
    if M.station then
        if not ctxt.isOwner or not BJI_Perm.canSpawnVehicle() or
            (not BJI_Scenario.canRefuelAtStation() and
                not BJI_Scenario.canRepairAtGarage()) or
            BJI_Veh.isUnicycle(ctxt.veh.gameVehicleID) then
            M.station = nil
            BJI_Events.trigger(BJI_Events.EVENTS.STATION_PROXIMITY_CHANGED)
        elseif ctxt.veh.position:distance(M.station.pos) > M.station.radius then
            M.station = nil
            BJI_Events.trigger(BJI_Events.EVENTS.STATION_PROXIMITY_CHANGED)
        end
        return
    end

    local garagesCount = BJI_Context.Scenario.Data.Garages and
        #BJI_Context.Scenario.Data.Garages or 0
    local energyStationsCount = BJI_Context.Scenario.Data.EnergyStations and
        #BJI_Context.Scenario.Data.EnergyStations or 0
    if not BJI_Perm.canSpawnVehicle() or
        (not BJI_Scenario.canRefuelAtStation() and not BJI_Scenario.canRepairAtGarage()) or
        not ctxt.isOwner or BJI_Veh.isUnicycle(ctxt.veh.gameVehicleID) or
        (garagesCount == 0 and energyStationsCount == 0) then
        M.detectionProcess = nil
        return
    end

    if ctxt.isOwner then
        if #M.detectionStations ~= garagesCount + energyStationsCount then
            table.clear(M.detectionStations)
            for _, g in ipairs(BJI_Context.Scenario.Data.Garages) do
                table.insert(M.detectionStations, {
                    name = g.name,
                    pos = vec3(g.pos),
                    radius = tonumber(g.radius),
                    types = nil,
                    isEnergy = false,
                })
            end
            for _, s in ipairs(BJI_Context.Scenario.Data.EnergyStations) do
                table.insert(M.detectionStations, {
                    name = s.name,
                    pos = vec3(s.pos),
                    radius = tonumber(s.radius),
                    types = table.clone(s.types),
                    isEnergy = true,
                })
            end
            M.detectionProcess = nil
        end
        detectChunk(ctxt)
    end
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
local function tryRefillVehicle(ctxt, energyTypes, fillPercent, fillDuration)
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

M.tryRefillVehicle = tryRefillVehicle
M.tryRepair = tryRepair

M.onLoad = function()
    BJI_Events.addListener(BJI_Events.EVENTS.FAST_TICK, fastTick, M._name)
end
M.renderTick = renderTick

M.getRestrictions = getRestrictions

return M
