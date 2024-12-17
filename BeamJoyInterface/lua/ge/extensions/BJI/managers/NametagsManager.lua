local M = {
    _name = "BJINametags",
    state = true,
}

local function getAlphaByDistance(distance)
    local alpha = 1
    if settings.getValue("nameTagFadeEnabled") then
        local fadeoutDistance = settings.getValue("nameTagFadeDistance", 40)
        alpha = Scale(distance, fadeoutDistance, 0, 0, 1, true)

        if BJICam.getCamera() ~= BJICam.CAMERAS.FREE and
            settings.getValue("nameTagFadeInvert") then
            alpha = 1 - alpha
        end

        if settings.getValue("nameTagDontFullyHide") then
            alpha = Clamp(alpha, .3)
        end
    end

    return alpha
end

local function toggle(state)
    M.state = state
end

local function tryUpdate()
    if BJIScenario.isFreeroam() or BJIScenario.isPlayerScenarioInProgress() then
        M.toggle(BJIContext.UserSettings.nametags)
    end
end

local alphaRatio = 1
local function getNametagColorDefault(alpha)
    return ShapeDrawer.Color(1, 1, 1, alpha * alphaRatio)
end
local function getNametagColorSpec(alpha)
    return ShapeDrawer.Color(.6, .6, 1, alpha * alphaRatio)
end
local function getNametagColorIdle(alpha)
    return ShapeDrawer.Color(1, .6, 0, alpha * alphaRatio)
end
local function getNametagBgColor(alpha)
    return ShapeDrawer.Color(0, 0, 0, alpha * alphaRatio)
end

local function renderSpecs(ctxt, veh)
    if tlength(veh.spectators) == 0 or
        not BJIScenario.doShowNametagsSpecs(veh) then
        return
    end

    local v = BJIVeh.getVehicleObject(veh.gameVehicleID)
    if not v then return end

    local tagPos = BJIVeh.getPositionRotation(v).pos

    local freecaming = ctxt.camera == BJICam.CAMERAS.FREE
    local ownPos = freecaming and BJICam.getPositionRotation().pos or ctxt.vehPosRot.pos
    local alpha = getAlphaByDistance(ownPos:distance(tagPos))

    local zOffset = v:getInitialHeight()
    if ctxt.veh and ctxt.veh:getID() == veh.gameVehicleID then
        zOffset = zOffset / 2
    end
    tagPos.z = tagPos.z + zOffset + .1 -- .1 offset for specs

    for playerID in pairs(veh.spectators) do
        if playerID ~= ctxt.user.playerID and playerID ~= veh.ownerID then
            local name = BJIContext.Players[playerID].playerName
            ShapeDrawer.Text(name, tagPos, getNametagColorSpec(alpha), getNametagBgColor(alpha), false)
        end
    end
end

local function renderAI(ctxt, veh)
    renderSpecs(ctxt, veh)
end

local function renderTrailer(ctxt, veh)
    local selfTrailerName = BJILang.get("nametags.selfTrailer")

    local v = BJIVeh.getVehicleObject(veh.gameVehicleID)
    if not v then return end

    local trailerName = BJILang.get("nametags.trailer")
    local ownVeh = veh.ownerID == ctxt.user.playerID
    local currentVeh = ctxt.veh and ctxt.veh:getID() == veh.gameVehicleID
    local freecaming = ctxt.camera == BJICam.CAMERAS.FREE
    local ownerSpectating = veh.spectators[veh.ownerID]
    local ownerTracting = false
    for _, vid in ipairs(core_vehicle_partmgmt.findAttachedVehicles(veh.gameVehicleID)) do
        local v2 = BJIVeh.getVehicleObject(vid)
        if v2 and BJIVeh.getType(v2.jbeam) ~= "Trailer" and
            veh.ownerID and BJIVeh.getVehOwnerID(vid) == veh.ownerID then
            ownerTracting = true
            break
        end
    end

    if ownVeh then
        if not ownerTracting then
            local showDist = not currentVeh or freecaming
            local label = selfTrailerName

            local tagPos = BJIVeh.getPositionRotation(v).pos
            local ownPos = freecaming and BJICam.getPositionRotation().pos or
                (ctxt.vehPosRot and ctxt.vehPosRot.pos or nil)
            if not ownPos then return end
            local distance = ownPos:distance(tagPos)
            local alpha = getAlphaByDistance(distance)

            if showDist then
                label = svar("{1}({2})", { label, PrettyDistance(distance) })
            end

            local zOffset = v:getInitialHeight()
            if currentVeh then
                zOffset = zOffset / 2
            end
            tagPos.z = tagPos.z + zOffset

            local color = currentVeh and getNametagColorDefault(alpha) or getNametagColorIdle(alpha)

            ShapeDrawer.Text(label, tagPos, color, getNametagBgColor(alpha), false)
        end

        renderSpecs(ctxt, veh)
    else
        if not ownerTracting or ownerSpectating then
            local showDist = not currentVeh or freecaming
            local label = svar(trailerName, { playerName = BJIContext.Players[veh.ownerID].playerName })

            local tagPos = BJIVeh.getPositionRotation(v).pos
            local ownPos = freecaming and BJICam.getPositionRotation().pos or
                (ctxt.vehPosRot and ctxt.vehPosRot.pos or nil)
            if not ownPos then return end
            local distance = ownPos:distance(tagPos)
            local alpha = getAlphaByDistance(distance)

            if showDist then
                label = svar("{1}({2})", { label, PrettyDistance(distance) })
            end

            local zOffset = v:getInitialHeight()
            if currentVeh then
                zOffset = zOffset / 2
            end
            tagPos.z = tagPos.z + zOffset

            local color = ownerSpectating and getNametagColorSpec(alpha) or getNametagColorIdle(alpha)

            ShapeDrawer.Text(label, tagPos, color, getNametagBgColor(alpha), false)
        end
        renderSpecs(ctxt, veh)
    end
end

local function renderVehicle(ctxt, veh)
    local v = BJIVeh.getVehicleObject(veh.gameVehicleID)
    if not v then return end

    local staffTag = BJILang.get("nametags.staffTag")
    local reputationTag = BJILang.get("nametags.reputationTag")

    local ownVeh = veh.ownerID == ctxt.user.playerID
    local currentVeh = ctxt.veh and ctxt.veh:getID() == veh.gameVehicleID
    local freecaming = ctxt.camera == BJICam.CAMERAS.FREE
    local ownerDriving = veh.spectators[veh.ownerID]

    if ownVeh then
        if not currentVeh or freecaming then
            local tagPos = BJIVeh.getPositionRotation(v).pos
            local ownPos = freecaming and BJICam.getPositionRotation().pos or
                (ctxt.vehPosRot and ctxt.vehPosRot.pos or nil)
            if not ownPos then return end
            local distance = ownPos:distance(tagPos)
            local alpha = getAlphaByDistance(distance)

            local label = svar("{1}({2})", { BJILang.get("nametags.self"), PrettyDistance(distance) })

            tagPos.z = tagPos.z + v:getInitialHeight()

            local color = currentVeh and getNametagColorDefault(alpha) or getNametagColorIdle(alpha)

            ShapeDrawer.Text(label, tagPos, color, getNametagBgColor(alpha), false)

            renderSpecs(ctxt, veh)
        end
    else
        local tagPos = BJIVeh.getPositionRotation(v).pos
        local ownPos = freecaming and BJICam.getPositionRotation().pos or
            (ctxt.vehPosRot and ctxt.vehPosRot.pos or nil)
        if not ownPos then return end
        local distance = ownPos:distance(tagPos)
        local alpha = getAlphaByDistance(distance)

        local showTag = ownerDriving
        local showDist = (not currentVeh or freecaming) and distance > 10

        local owner = BJIContext.Players[veh.ownerID]
        if owner then -- can softlock the mod if triggered too early ? https://github.com/my-name-is-samael/BeamJoy/issues/10
            local label = owner.playerName
            if showTag then
                reputationTag = svar("{1}{2}",
                    { reputationTag, BJIReputation.getReputationLevel(owner.reputation) })
                local tag = BJIPerm.isStaff(veh.ownerID) and staffTag or reputationTag
                label = svar("[{1}]{2}", { tag, label })
            end
            if showDist then
                label = svar("{1}({2})", { label, PrettyDistance(distance) })
            end

            local zOffset = v:getInitialHeight()
            if currentVeh then
                zOffset = zOffset / 2
            end
            tagPos.z = tagPos.z + zOffset

            local color = ownerDriving and getNametagColorDefault(alpha) or getNametagColorIdle(alpha)

            ShapeDrawer.Text(label, tagPos, color, getNametagBgColor(alpha), false)

            renderSpecs(ctxt, veh)
        end
    end
end

local function renderTick(ctxt)
    MPVehicleGE.hideNicknames(true)

    if (not BJIContext.BJC.Freeroam or not BJIContext.BJC.Freeroam.Nametags) and
        not BJIPerm.isStaff() then
        return
    end

    if M.state then
        -- render rules : https://docs.google.com/spreadsheets/d/17YAlu5TkZD6BLCf3xmJ-1N0GbiUr641Xk7eFFnb-jF8?usp=sharing
        for _, veh in pairs(BJIVeh.getMPVehicles()) do
            if not veh.isDeleted and veh.isSpawned then
                local vehType = BJIVeh.getType(veh.jbeam)
                if vehType ~= "Prop" and BJIScenario.doShowNametag({
                        gameVehicleID = veh.gameVehicleID,
                        ownerID = veh.ownerID
                    }) then
                    if BJIAI.isAIVehicle(veh.gameVehicleID) then
                        local start = GetCurrentTimeMillis()
                        renderAI(ctxt, veh)
                        BenchAdd("BJINametags", "renderAI", GetCurrentTimeMillis() - start)
                    elseif vehType == "Trailer" then
                        local start = GetCurrentTimeMillis()
                        renderTrailer(ctxt, veh)
                        BenchAdd("BJINametags", "renderTrailer", GetCurrentTimeMillis() - start)
                    else
                        local start = GetCurrentTimeMillis()
                        renderVehicle(ctxt, veh)
                        BenchAdd("BJINametags", "renderVehicle", GetCurrentTimeMillis() - start)
                    end
                end
            end
        end
    end
end

M.toggle = toggle

M.tryUpdate = tryUpdate

M.renderTick = renderTick

RegisterBJIManager(M)
return M
