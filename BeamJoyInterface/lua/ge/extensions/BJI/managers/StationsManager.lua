local M = {
    renderStationDistance = 50,
    COLORS = {
        GARAGE = ShapeDrawer.Color(1, .4, 0, .02),
        ENERGY = ShapeDrawer.Color(.2, 1, .2, .02),
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
        if s and GetHorizontalDistance(s.pos, ctxt.vehPosRot.pos) < s.radius then
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
    local ownPos = (ctxt.camera == BJICam.CAMERAS.FREE or not ctxt.veh)
        and BJICam.getPositionRotation().pos or
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
        elseif GetHorizontalDistance(M.station.pos, ctxt.vehPosRot.pos) >= M.station.radius then
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

M.renderTick = renderTick

RegisterBJIManager(M)
return M
