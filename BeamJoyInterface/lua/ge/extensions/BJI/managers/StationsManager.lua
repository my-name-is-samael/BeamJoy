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
}

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

local function detectChunk(ctxt)
    if not ctxt.vehPosRot then
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
        if s and ctxt.vehPosRot.pos:distance(s.pos) <= s.radius then
            if not s.isEnergy then
                M.station = s
                M.detectionProcess = nil
                BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.STATION_PROXIMITY_CHANGED)
                return
            end
            for _, type in ipairs(s.types) do
                if table.includes(energyTypes, type) then
                    M.station = s
                    M.detectionProcess = nil
                    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.STATION_PROXIMITY_CHANGED)
                    return
                end
            end
        end
    end

    M.detectionProcess = target
    if M.detectionProcess == #BJI.Managers.Context.Scenario.Data.Garages +
        #BJI.Managers.Context.Scenario.Data.EnergyStations then
        M.detectionProcess = nil
    end
end

local function renderTick(ctxt)
    if ctxt.camera == BJI.Managers.Cam.CAMERAS.BIG_MAP then
        return
    end
    local ownPos = (ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE or not ctxt.veh) and
        BJI.Managers.Cam.getPositionRotation().pos or
        ctxt.vehPosRot.pos


    if BJI.Managers.Scenario.canRepairAtGarage() and
        BJI.Managers.Context.Scenario.Data.Garages and
        BJI.Windows.ScenarioEditor.view ~= BJI.Windows.ScenarioEditor.SCENARIOS.GARAGES then
        for _, g in pairs(BJI.Managers.Context.Scenario.Data.Garages) do
            if ownPos:distance(g.pos) <= M.renderStationDistance then
                BJI.Utils.ShapeDrawer.Sphere(g.pos, g.radius, M.COLORS.GARAGE)
                local textPos = vec3(g.pos)
                local zOffset = g.radius
                if ctxt.veh then
                    zOffset = ctxt.veh:getInitialHeight() * 1.5
                end
                textPos.z = textPos.z + zOffset
                BJI.Utils.ShapeDrawer.Text(g.name, textPos, M.COLORS.TEXT, M.COLORS.BG)
            end
        end
    end

    if BJI.Managers.Scenario.canRefuelAtStation() and
        BJI.Managers.Context.Scenario.Data.EnergyStations and
        BJI.Windows.ScenarioEditor.view ~= BJI.Windows.ScenarioEditor.SCENARIOS.STATIONS then
        local energyTypes = getVehEnergyTypes(ctxt)
        if #energyTypes > 0 then
            for _, s in pairs(BJI.Managers.Context.Scenario.Data.EnergyStations) do
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
                        textPos.z = textPos.z + ctxt.veh:getInitialHeight() * 1.5
                        BJI.Utils.ShapeDrawer.Text(s.name, textPos, M.COLORS.TEXT, M.COLORS.BG)
                    end
                end
            end
        end
    end
end

local function fastTick(ctxt)
    local veh = ctxt.isOwner and ctxt.veh or nil
    if M.station then
        if not veh or not BJI.Managers.Perm.canSpawnVehicle() or
            (not BJI.Managers.Scenario.canRefuelAtStation() and
                not BJI.Managers.Scenario.canRepairAtGarage()) or
            BJI.Managers.Veh.isUnicycle(veh:getID()) then
            M.station = nil
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.STATION_PROXIMITY_CHANGED)
        elseif ctxt.vehPosRot.pos:distance(M.station.pos) > M.station.radius then
            M.station = nil
            BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.STATION_PROXIMITY_CHANGED)
        end
        return
    end

    local garagesCount = BJI.Managers.Context.Scenario.Data.Garages and
        #BJI.Managers.Context.Scenario.Data.Garages or 0
    local energyStationsCount = BJI.Managers.Context.Scenario.Data.EnergyStations and
        #BJI.Managers.Context.Scenario.Data.EnergyStations or 0
    if not BJI.Managers.Perm.canSpawnVehicle() or
        (not BJI.Managers.Scenario.canRefuelAtStation() and not BJI.Managers.Scenario.canRepairAtGarage()) or
        not veh or BJI.Managers.Veh.isUnicycle(veh:getID()) or
        (garagesCount == 0 and energyStationsCount == 0) then
        M.detectionProcess = nil
        return
    end

    if veh then
        if #M.detectionStations ~= garagesCount + energyStationsCount then
            table.clear(M.detectionStations)
            for _, g in ipairs(BJI.Managers.Context.Scenario.Data.Garages) do
                table.insert(M.detectionStations, {
                    name = g.name,
                    pos = vec3(g.pos),
                    radius = tonumber(g.radius),
                    types = nil,
                    isEnergy = false,
                })
            end
            for _, s in ipairs(BJI.Managers.Context.Scenario.Data.EnergyStations) do
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
local function tryRefillVehicle(ctxt, energyTypes, fillPercent, fillDuration)
    if not ctxt.isOwner or not ctxt.vehData or not ctxt.vehData.tanks then return end
    if not energyTypes or #energyTypes == 0 then return end

    -- no values = emergency refill
    fillDuration = fillDuration or BJI.Managers.Context.BJC.Freeroam.EmergencyRefuelDuration
    fillPercent = fillPercent or math.round(BJI.Managers.Context.BJC.Freeroam.EmergencyRefuelPercent / 100, 2)


    local tanksToRefuel = {}
    for tankName, tank in pairs(ctxt.vehData.tanks) do
        if table.includes(energyTypes, tank.energyType) then
            tanksToRefuel[tankName] = tank
        end
    end
    if table.length(tanksToRefuel) == 0 then return end

    -- start process
    BJI.Managers.Veh.stopCurrentVehicle()
    ctxt.user.stationProcess = true
    BJI.Managers.Cam.forceCamera(BJI.Managers.Cam.CAMERAS.EXTERNAL)
    ctxt.vehData.freezeStation = true
    BJI.Managers.Veh.freeze(true, ctxt.vehData.gameVehID)
    ctxt.vehData.engineStation = false
    BJI.Managers.Veh.engine(false, ctxt.vehData.gameVehID)
    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.STATION_PROCESS_CHANGED)

    local completedKey = table.length(tanksToRefuel) > 1 and "energyStations.flashTanksFilled" or
        "energyStations.flashTankFilled"
    if #energyTypes == 1 and energyTypes[1] == BJI.CONSTANTS.ENERGY_STATION_TYPES.ELECTRIC then
        completedKey = "energyStations.flashBatteryFilled"
    end
    BJI.Managers.Message.flashCountdown("BJIRefill", GetCurrentTimeMillis() + fillDuration * 1000 + 10, false,
        BJI.Managers.Lang.get(completedKey), fillDuration)
    BJI.Managers.Async.delayTask(function()
        for tankName, t in pairs(tanksToRefuel) do
            local targetEnergy = math.round(t.maxEnergy * fillPercent)
            BJI.Managers.Veh.setFuel(tankName, targetEnergy)
        end
    end, fillDuration * 1000 - 1000, "BJIStationRefillFuel")
    BJI.Managers.Async.delayTask(function()
        ctxt.vehData.freezeStation = false
        if not ctxt.vehData.freeze then
            BJI.Managers.Veh.freeze(false, ctxt.vehData.gameVehID)
        end
        ctxt.vehData.engineStation = true
        if ctxt.vehData.engine then
            BJI.Managers.Veh.engine(true, ctxt.vehData.gameVehID)
        end
        BJI.Managers.Cam.resetForceCamera(true)
        BJI.Managers.Context.User.stationProcess = false
        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.STATION_PROCESS_CHANGED)
    end, fillDuration * 1000, "BJIStationRefillEnd")
end

---@param ctxt TickContext
local function tryRepair(ctxt)
    BJI.Managers.Veh.stopCurrentVehicle()
    ctxt.user.stationProcess = true
    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)
    BJI.Managers.Cam.forceCamera(BJI.Managers.Cam.CAMERAS.EXTERNAL)
    ctxt.vehData.freezeStation = true
    BJI.Managers.Veh.freeze(true, ctxt.veh:getID())
    ctxt.vehData.engineStation = false
    BJI.Managers.Veh.engine(false, ctxt.veh:getID())
    BJI.Managers.Reputation.onGarageRepair()
    BJI.Managers.Scenario.onGarageRepair()

    BJI.Managers.Message.flashCountdown("BJIRefill", GetCurrentTimeMillis() + 5010, false,
        BJI.Managers.Lang.get("garages.flashVehicleRepaired"))
    BJI.Managers.Async.delayTask(function(ctxt2)
        if ctxt2.veh then
            BJI.Managers.Veh.setPositionRotation(BJI.Managers.Veh.getPositionRotation().pos, nil, {
                safe = false
            })
            BJI.Managers.Veh.postResetPreserveEnergy(ctxt2.veh:getID())
            ctxt2.vehData.freezeStation = false
            if not ctxt2.vehData.freeze then
                BJI.Managers.Veh.freeze(false, ctxt2.veh:getID())
            end
            ctxt2.vehData.engineStation = true
            if ctxt2.vehData.engine then
                BJI.Managers.Veh.engine(true, ctxt2.veh:getID())
            end
            BJI.Managers.Cam.resetForceCamera(true)
            BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.REPAIR)
        end
        ctxt2.user.stationProcess = false
        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)
    end, 5000, "BJIStationRepair")
end

M.tryRefillVehicle = tryRefillVehicle
M.tryRepair = tryRepair

M.onLoad = function()
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.FAST_TICK, fastTick, M._name)
end
M.renderTick = renderTick

return M
