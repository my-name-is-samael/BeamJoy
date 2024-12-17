local M = {
    _name = "BJIStations",
    renderStationDistance = 50,
    COLORS = {
        GARAGE = ShapeDrawer.Color(1, .4, 0, .05),
        ENERGY = ShapeDrawer.Color(.2, 1, .2, .05),
        TEXT = ShapeDrawer.Color(1, 1, 1, .5),
        BG = ShapeDrawer.Color(0, 0, 0, .3),
    },

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
        if not tincludes(energyTypes, tank.energyType, true) then
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
        if s and
            ctxt.vehPosRot.pos:distance(s.pos) <= s.radius then
            if not s.types then
                M.station = s
                M.detectionProcess = nil
                return
            end
            for _, type in ipairs(s.types) do
                if tincludes(energyTypes, type, true) then
                    M.station = s
                    M.detectionProcess = nil
                    return
                end
            end
        end
    end

    M.detectionProcess = target
    if M.detectionProcess == #BJIContext.Scenario.Data.Garages + #BJIContext.Scenario.Data.EnergyStations then
        M.detectionProcess = nil
    end
end

local function renderStations(ctxt)
    if ctxt.camera == BJICam.CAMERAS.BIG_MAP then
        return
    end
    local ownPos = (ctxt.camera == BJICam.CAMERAS.FREE or not ctxt.veh) and
        BJICam.getPositionRotation().pos or
        ctxt.vehPosRot.pos


    if BJIScenario.canRepairAtGarage() and
        BJIContext.Scenario.Data.Garages and
        not BJIContext.Scenario.GaragesEdit then
        for _, g in pairs(BJIContext.Scenario.Data.Garages) do
            if ownPos:distance(g.pos) <= M.renderStationDistance then
                ShapeDrawer.Sphere(g.pos, g.radius, M.COLORS.GARAGE)
                local textPos = vec3(g.pos)
                local zOffset = g.radius
                if ctxt.veh then
                    zOffset = ctxt.veh:getInitialHeight() * 1.5
                end
                textPos.z = textPos.z + zOffset
                ShapeDrawer.Text(g.name, textPos, M.COLORS.TEXT, M.COLORS.BG)
            end
        end
    end

    if BJIScenario.canRefuelAtStation() and
        BJIContext.Scenario.Data.EnergyStations and
        not BJIContext.Scenario.EnergyStationsEdit then
        local energyTypes = getVehEnergyTypes(ctxt)
        if #energyTypes > 0 then
            for _, s in pairs(BJIContext.Scenario.Data.EnergyStations) do
                if ownPos:distance(s.pos) <= M.renderStationDistance then
                    local compatible = false
                    for _, type in ipairs(s.types) do
                        if tincludes(energyTypes, type, true) then
                            compatible = true
                            break
                        end
                    end
                    if compatible then
                        ShapeDrawer.Sphere(s.pos, s.radius, M.COLORS.ENERGY)
                        local textPos = vec3(s.pos)
                        textPos.z = textPos.z + ctxt.veh:getInitialHeight() * 1.5
                        ShapeDrawer.Text(s.name, textPos, M.COLORS.TEXT, M.COLORS.BG)
                    end
                end
            end
        end
    end
end

local function renderTick(ctxt)
    renderStations(ctxt)

    local veh = ctxt.isOwner and ctxt.veh or nil
    if M.station then
        if not BJIPerm.canSpawnVehicle() or
            (not BJIScenario.canRefuelAtStation() and not BJIScenario.canRepairAtGarage()) or
            not veh or
            BJIVeh.isUnicycle(veh:getID()) then
            M.station = nil
        elseif ctxt.vehPosRot.pos:distance(M.station.pos) > M.station.radius then
            M.station = nil
        end
        return
    end

    local garagesCount = BJIContext.Scenario.Data.Garages and
        #BJIContext.Scenario.Data.Garages or 0
    local energyStationsCount = BJIContext.Scenario.Data.EnergyStations and
        #BJIContext.Scenario.Data.EnergyStations or 0
    if not BJIPerm.canSpawnVehicle() or
        (not BJIScenario.canRefuelAtStation() and not BJIScenario.canRepairAtGarage()) or
        not veh or BJIVeh.isUnicycle(veh:getID()) or
        (garagesCount == 0 and energyStationsCount == 0) then
        M.detectionProcess = nil
        return
    end

    if veh then
        if #M.detectionStations ~= garagesCount + energyStationsCount then
            table.clear(M.detectionStations)
            for _, g in ipairs(BJIContext.Scenario.Data.Garages) do
                table.insert(M.detectionStations, {
                    name = g.name,
                    pos = vec3(g.pos),
                    radius = tonumber(g.radius),
                    types = nil,
                    isEnergy = false,
                })
            end
            for _, s in ipairs(BJIContext.Scenario.Data.EnergyStations) do
                table.insert(M.detectionStations, {
                    name = s.name,
                    pos = vec3(s.pos),
                    radius = tonumber(s.radius),
                    types = tdeepcopy(s.types),
                    isEnergy = true,
                })
            end
            M.detectionProcess = nil
        end
        detectChunk(ctxt)
    end
end

local function tryRefillVehicle(ctxt, energyTypes, fillPercent, fillDuration)
    if not ctxt.isOwner or not ctxt.vehData or not ctxt.vehData.tanks then return end
    if not energyTypes or #energyTypes == 0 then return end

    -- no values = emergency refill
    fillDuration = fillDuration or BJIContext.BJC.Freeroam.EmergencyRefuelDuration
    fillPercent = fillPercent or Round(BJIContext.BJC.Freeroam.EmergencyRefuelPercent / 100, 2)


    local tanksToRefuel = {}
    for tankName, tank in pairs(ctxt.vehData.tanks) do
        if tincludes(energyTypes, tank.energyType, true) then
            tanksToRefuel[tankName] = tank
        end
    end
    if tlength(tanksToRefuel) == 0 then return end

    -- start process
    BJIVeh.stopCurrentVehicle()
    BJIContext.User.stationProcess = true
    local wasResetRestricted = BJIRestrictions.getState(BJIRestrictions.TYPES.Reset)
    if not wasResetRestricted then
        BJIRestrictions.apply(BJIRestrictions.TYPES.Reset, true)
    end
    BJICam.forceCamera(BJICam.CAMERAS.EXTERNAL)
    ctxt.vehData.freezeStation = true
    BJIVeh.freeze(true, ctxt.vehData.vehGameID)
    ctxt.vehData.engineStation = false
    BJIVeh.engine(false, ctxt.vehData.vehGameID)

    local completedKey = tlength(tanksToRefuel) > 1 and "energyStations.flashTanksFilled" or
        "energyStations.flashTankFilled"
    if #energyTypes == 1 and energyTypes[1] == BJI_ENERGY_STATION_TYPES.ELECTRIC then
        completedKey = "energyStations.flashBatteryFilled"
    end
    BJIMessage.flashCountdown("BJIRefill", GetCurrentTimeMillis() + fillDuration * 1000 + 10, false,
        BJILang.get(completedKey), fillDuration)
    BJIAsync.delayTask(function()
        for tankName, t in pairs(tanksToRefuel) do
            local targetEnergy = Round(t.maxEnergy * fillPercent)
            BJIVeh.setFuel(tankName, targetEnergy)
        end
    end, fillDuration * 1000 - 1000, "BJIStationRefillFuel")
    BJIAsync.delayTask(function()
        ctxt.vehData.freezeStation = false
        if not ctxt.vehData.freeze then
            BJIVeh.freeze(false, ctxt.vehData.vehGameID)
        end
        ctxt.vehData.engineStation = true
        if ctxt.vehData.engine then
            BJIVeh.engine(true, ctxt.vehData.vehGameID)
        end
        BJICam.resetForceCamera()
        if not wasResetRestricted then
            BJIRestrictions.apply(BJIRestrictions.TYPES.Reset, false)
        end
        BJIContext.User.stationProcess = false
    end, fillDuration * 1000, "BJIStationRefillEnd")
end

M.renderTick = renderTick
M.tryRefillVehicle = tryRefillVehicle

RegisterBJIManager(M)
return M
