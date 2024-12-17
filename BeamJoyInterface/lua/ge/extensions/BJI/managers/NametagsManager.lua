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
        M.toggle(not settings.getValue("hideNameTags", false))
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
local function getNametagBgColor(alpha, spec)
    local finalAlpha = 0
    if not spec or settings.getValue("spectatorUnifiedColors", false) then
        finalAlpha = alpha * alphaRatio
    end
    return ShapeDrawer.Color(0, 0, 0, finalAlpha)
end

local function shortenName(name)
    local charLimit = tonumber(settings.getValue("nametagCharLimit", 50))
    local short = name:sub(1, charLimit)
    if #short ~= #name then short = svar("{1}...", { short }) end
    return short
end

local function renderSpecs(ctxt, veh)
    if not settings.getValue("showSpectators", true) or tlength(veh.spectators) == 0 or
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
            if settings.getValue("shortenNametags", false) then
                name = shortenName(name)
            end
            ShapeDrawer.Text(name, tagPos, getNametagColorSpec(alpha), getNametagBgColor(alpha, true), false)
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
            local name = BJIContext.Players[veh.ownerID].playerName
            if settings.getValue("shortenNametags", false) then
                name = shortenName(name)
            end
            local label = svar(trailerName, { playerName = name })

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

            local label = BJILang.get("nametags.self")
            if settings.getValue("nameTagShowDistance", true) then
                label = svar("{1}({2})", { label, PrettyDistance(distance) })
            end

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

        local showTag = not settings.getValue("shortenNametags", false) and ownerDriving
        local showDist = settings.getValue("nameTagShowDistance", true) and
            (not currentVeh or freecaming) and distance > 10

        local owner = BJIContext.Players[veh.ownerID] or error()
        local label = owner.playerName
        if settings.getValue("shortenNametags", false) then
            label = shortenName(label)
        end
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

local function renderTick(ctxt)
    MPVehicleGE.hideNicknames(true)

    if settings.getValue("hideNameTags", false) then
        return
    elseif (not BJIContext.BJC.Freeroam or not BJIContext.BJC.Freeroam.Nametags) and
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
                        pcall(renderAI, ctxt, veh)
                    elseif vehType == "Trailer" then
                        pcall(renderTrailer, ctxt, veh)
                    else
                        pcall(renderVehicle, ctxt, veh)
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
