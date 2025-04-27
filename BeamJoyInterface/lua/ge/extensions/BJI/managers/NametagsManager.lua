local M = {
    _name = "BJINametags",
    state = true,

    renderConstants = {
        staffTag = nil,
        reputationTag = nil,
        self = nil,
        selfTrailer = nil,
        trailer = nil,
    },

    COLORS = {
        PLAYER = {
            TEXT = {
                key = "beamjoy.nametags.colors.player.text",
                value = ShapeDrawer.Color(1, 1, 1),
                default = ShapeDrawer.Color(1, 1, 1),
            },
            BG = {
                key = "beamjoy.nametags.colors.player.bg",
                value = ShapeDrawer.Color(0, 0, 0),
                default = ShapeDrawer.Color(0, 0, 0),
            },
        },
        IDLE = {
            TEXT = {
                key = "beamjoy.nametags.colors.idle.text",
                value = ShapeDrawer.Color(1, .6, 0),
                default = ShapeDrawer.Color(1, .6, 0),
            },
            BG = {
                key = "beamjoy.nametags.colors.idle.bg",
                value = ShapeDrawer.Color(0, 0, 0),
                default = ShapeDrawer.Color(0, 0, 0),
            },
        },
        SPEC = {
            TEXT = {
                key = "beamjoy.nametags.colors.spec.text",
                value = ShapeDrawer.Color(.6, .6, 1),
                default = ShapeDrawer.Color(.6, .6, 1),
            },
            BG = {
                key = "beamjoy.nametags.colors.spec.bg",
                value = ShapeDrawer.Color(0, 0, 0),
                default = ShapeDrawer.Color(0, 0, 0),
            },
        },
    },
}

local function onLoad()
    local function applyDefaultSettings(obj)
        if type(obj) ~= "table" then
            return
        end
        for _, el in pairs(obj) do
            if not el.key then
                applyDefaultSettings(el)
            else
                local stored = settings.getValue(el.key)
                if stored == nil then
                    local value = jsonEncode(el.default)
                    LogDebug(string.var("Assigning default setting value \"{1}\" to \"{2}\"", { el.key, value }))
                    settings.setValue(el.key, value)
                else
                    el.value = jsonDecode(stored)
                end
            end
        end
    end

    applyDefaultSettings(M.COLORS)
end

local function getAlphaByDistance(distance)
    local alpha = 1
    if settings.getValue("nameTagFadeEnabled") then
        local fadeoutDistance = settings.getValue("nameTagFadeDistance", 40)
        alpha = math.scale(distance, fadeoutDistance, 0, 0, 1, true)

        if BJICam.getCamera() ~= BJICam.CAMERAS.FREE and
            settings.getValue("nameTagFadeInvert") then
            alpha = 1 - alpha
        end

        if settings.getValue("nameTagDontFullyHide") then
            alpha = math.clamp(alpha, .3)
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

local function getNametagColor(alpha, spec, idle)
    local color
    if spec then
        color = table.clone(M.COLORS.SPEC.TEXT.value)
    elseif idle then
        color = table.clone(M.COLORS.IDLE.TEXT.value)
    else
        color = table.clone(M.COLORS.PLAYER.TEXT.value)
    end
    if not color then return ShapeDrawer.Color(0, 0, 0) end

    color.a = alpha
    return color
end
local function getNametagBgColor(alpha, spec, idle)
    local color
    if spec then
        color = table.clone(M.COLORS.SPEC.BG.value)
    elseif idle then
        color = table.clone(M.COLORS.IDLE.BG.value)
    else
        color = table.clone(M.COLORS.PLAYER.BG.value)
    end
    if not color then return ShapeDrawer.Color(0, 0, 0) end

    color.a = alpha
    return color
end

local function renderSpecs(ctxt, veh)
    if not settings.getValue("showSpectators", true) or table.length(veh.spectators) == 0 or
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
    tagPos.z = tagPos.z + zOffset + .1 -- .1 offset downward for specs

    for playerID in pairs(veh.spectators) do
        if playerID ~= ctxt.user.playerID and playerID ~= veh.ownerID then
            local name = BJIContext.Players[playerID].playerName
            if settings.getValue("shortenNametags", false) then
                name = BJIContext.Players[playerID].shortName
            end
            ShapeDrawer.Text(name, tagPos,
                getNametagColor(alpha, true),
                getNametagBgColor(alpha, true),
                false)
        end
    end
end

local function renderAI(ctxt, veh)
    renderSpecs(ctxt, veh)
end

local function renderTrailer(ctxt, veh)
    local v = BJIVeh.getVehicleObject(veh.gameVehicleID)
    if not v then return end

    local ownVeh = veh.ownerID == ctxt.user.playerID
    local currentVeh = ctxt.veh and ctxt.veh:getID() == veh.gameVehicleID
    local freecaming = ctxt.camera == BJICam.CAMERAS.FREE
    local ownerSpectating = veh.spectators[veh.ownerID]
    local ownerTracting = false
    for _, vid in ipairs(BJIVeh.findAttachedVehicles(veh.gameVehicleID)) do
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
            local label = M.renderConstants.selfTrailer

            local tagPos = BJIVeh.getPositionRotation(v).pos
            local ownPos = freecaming and BJICam.getPositionRotation().pos or
                (ctxt.vehPosRot and ctxt.vehPosRot.pos or nil)
            if not ownPos then return end
            local distance = ownPos:distance(tagPos)
            local alpha = getAlphaByDistance(distance)

            if showDist then
                label = string.var("{1}({2})", { label, PrettyDistance(distance) })
            end

            local zOffset = v:getInitialHeight()
            if currentVeh then
                zOffset = zOffset / 2
            end
            tagPos.z = tagPos.z + zOffset

            ShapeDrawer.Text(label, tagPos,
                getNametagColor(alpha, false, not currentVeh),
                getNametagBgColor(alpha, false, not currentVeh),
                false)
        end

        renderSpecs(ctxt, veh)
    else
        if not ownerTracting or ownerSpectating then
            local showDist = not currentVeh or freecaming
            local name = BJIContext.Players[veh.ownerID].playerName
            if settings.getValue("shortenNametags", false) then
                name = BJIContext.Players[veh.ownerID].shortName
            end
            local label = M.renderConstants.trailer:var({ playerName = name })

            local tagPos = BJIVeh.getPositionRotation(v).pos
            local ownPos = freecaming and BJICam.getPositionRotation().pos or
                (ctxt.vehPosRot and ctxt.vehPosRot.pos or nil)
            if not ownPos then return end
            local distance = ownPos:distance(tagPos)
            local alpha = getAlphaByDistance(distance)

            if showDist then
                label = string.var("{1}({2})", { label, PrettyDistance(distance) })
            end

            local zOffset = v:getInitialHeight()
            if currentVeh then
                zOffset = zOffset / 2
            end
            tagPos.z = tagPos.z + zOffset

            ShapeDrawer.Text(label, tagPos, getNametagColor(alpha, ownerSpectating, not ownerSpectating),
                getNametagBgColor(alpha, ownerSpectating, not ownerSpectating),
                false)
        end
        renderSpecs(ctxt, veh)
    end
end

local function renderVehicle(ctxt, veh)
    local v = BJIVeh.getVehicleObject(veh.gameVehicleID)
    if not v then return end

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

            local label = M.renderConstants.self
            if settings.getValue("nameTagShowDistance", true) then
                label = string.var("{1}({2})", { label, PrettyDistance(distance) })
            end

            tagPos.z = tagPos.z + v:getInitialHeight()

            ShapeDrawer.Text(label, tagPos,
                getNametagColor(alpha, false, not currentVeh),
                getNametagBgColor(alpha, false, not currentVeh),
                false)

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
            label = owner.shorten
        end
        if showTag then
            local tag = ""
            if BJIPerm.isStaff(veh.ownerID) then
                tag = M.renderConstants.staffTag
            else
                local reputationTag = string.var("{1}{2}",
                    { M.renderConstants.reputationTag, BJIReputation.getReputationLevel(owner.reputation) })
                tag = reputationTag
            end
            label = string.var("[{1}]{2}", { tag, label })
        end
        if showDist then
            label = string.var("{1}({2})", { label, PrettyDistance(distance) })
        end

        local zOffset = v:getInitialHeight()
        if currentVeh then
            zOffset = zOffset / 2
        end
        tagPos.z = tagPos.z + zOffset

        ShapeDrawer.Text(label, tagPos,
            getNametagColor(alpha, false, not ownerDriving),
            getNametagBgColor(alpha, false, not ownerDriving),
            false)

        renderSpecs(ctxt, veh)
    end
end

local function renderTick(ctxt)
    if true then return end
    MPVehicleGE.hideNicknames(true)

    if settings.getValue("hideNameTags", false) then
        return
    elseif (not BJIContext.BJC.Freeroam or not BJIContext.BJC.Freeroam.Nametags) and
        not BJIPerm.isStaff() then
        return
    end

    if M.state then
        -- pre-render constants
        if not settings.getValue("shortenNametags", false) then
            M.renderConstants.staffTag = BJILang.get("nametags.staffTag")
            M.renderConstants.reputationTag = BJILang.get("nametags.reputationTag")
            local nameLength = tonumber(settings.getValue("nametagCharLimit", 50))
            for _, p in pairs(BJIContext.Players) do
                local short = p.playerName:sub(1, nameLength)
                if #short ~= #p.playerName then short = string.var("{1}...", { short }) end
                p.shortName = short
            end
        end
        M.renderConstants.self = BJILang.get("nametags.self")
        M.renderConstants.selfTrailer = BJILang.get("nametags.selfTrailer")
        M.renderConstants.trailer = BJILang.get("nametags.trailer")

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

M.onLoad = onLoad

M.getNametagColor = getNametagColor
M.getNametagBgColor = getNametagBgColor

M.toggle = toggle

M.tryUpdate = tryUpdate

M.renderTick = renderTick

RegisterBJIManager(M)
return M
