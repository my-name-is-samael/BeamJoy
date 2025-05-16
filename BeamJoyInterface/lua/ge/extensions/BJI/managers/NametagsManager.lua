---@class BJIManagerNametags : BJIManager
local M = {
    _name = "Nametags",

    state = true,

    labels = {
        staffTag = "",
        reputationTag = "",
        self = "",
        selfTrailer = "",
        trailer = "",
    },
}

local function getAlphaByDistance(distance)
    local alpha = 1
    if settings.getValue("nameTagFadeEnabled") then
        local fadeoutDistance = settings.getValue("nameTagFadeDistance", 40)
        alpha = math.scale(distance, fadeoutDistance, 0, 0, 1, true)

        if BJI.Managers.Cam.getCamera() ~= BJI.Managers.Cam.CAMERAS.FREE and
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
    if BJI.Managers.Scenario.isFreeroam() or BJI.Managers.Scenario.isPlayerScenarioInProgress() then
        M.toggle(not settings.getValue("hideNameTags", false))
    end
end

---@param alpha number 0-1
---@param spec? boolean
---@param idle? boolean
---@return BJIColor
local function getNametagColor(alpha, spec, idle)
    local color
    if spec then
        color = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.NAMETAGS_COLOR_SPEC_TEXT)
    elseif idle then
        color = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.NAMETAGS_COLOR_IDLE_TEXT)
    else
        color = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.NAMETAGS_COLOR_PLAYER_TEXT)
    end
    if not color then return BJI.Utils.ShapeDrawer.Color(0, 0, 0) end

    color.a = alpha
    return color
end

---@param alpha number 0-1
---@param spec? boolean
---@param idle? boolean
---@return BJIColor
local function getNametagBgColor(alpha, spec, idle)
    local color
    if spec then
        color = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.NAMETAGS_COLOR_SPEC_BG)
    elseif idle then
        color = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.NAMETAGS_COLOR_IDLE_BG)
    else
        color = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.NAMETAGS_COLOR_PLAYER_BG)
    end
    if not color then return BJI.Utils.ShapeDrawer.Color(0, 0, 0) end

    color.a = alpha
    return color
end

local function renderSpecs(ctxt, veh)
    if not settings.getValue("showSpectators", true) or table.length(veh.spectators) == 0 or
        not BJI.Managers.Scenario.doShowNametagsSpecs(veh) then
        return
    end

    local v = BJI.Managers.Veh.getVehicleObject(veh.gameVehicleID)
    if not v then return end

    local tagPos = BJI.Managers.Veh.getPositionRotation(v).pos

    local freecaming = ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE
    local ownPos = freecaming and BJI.Managers.Cam.getPositionRotation().pos or ctxt.vehPosRot.pos
    local alpha = getAlphaByDistance(ownPos:distance(tagPos))

    local zOffset = v:getInitialHeight()
    if ctxt.veh and ctxt.veh:getID() == veh.gameVehicleID then
        zOffset = zOffset / 2
    end
    tagPos.z = tagPos.z + zOffset + .1 -- .1 offset downward for specs

    for playerID in pairs(veh.spectators) do
        if playerID ~= ctxt.user.playerID and playerID ~= veh.ownerID then
            local name = BJI.Managers.Context.Players[playerID].tagName
            BJI.Utils.ShapeDrawer.Text(name, tagPos,
                getNametagColor(alpha, true),
                getNametagBgColor(alpha, true),
                false)
        end
    end
end

local function renderAI(ctxt, veh)
    renderSpecs(ctxt, veh)
end

local function renderTrailer(ctxt, veh, forcedTextColor, forcedBgColor)
    local v = BJI.Managers.Veh.getVehicleObject(veh.gameVehicleID)
    if not v then return end

    local ownVeh = veh.ownerID == ctxt.user.playerID
    local currentVeh = ctxt.veh and ctxt.veh:getID() == veh.gameVehicleID
    local freecaming = ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE
    local ownerSpectating = veh.spectators[veh.ownerID]
    local ownerTracting = false
    for _, vid in ipairs(core_vehicle_partmgmt.findAttachedVehicles(veh.gameVehicleID)) do
        local v2 = BJI.Managers.Veh.getVehicleObject(vid)
        if v2 and BJI.Managers.Veh.getType(v2.jbeam) ~= "Trailer" and
            veh.ownerID and BJI.Managers.Veh.getVehOwnerID(vid) == veh.ownerID then
            ownerTracting = true
            break
        end
    end

    if ownVeh then
        if not ownerTracting then
            local showDist = not currentVeh or freecaming
            local label = M.labels.selfTrailer

            local tagPos = BJI.Managers.Veh.getPositionRotation(v).pos
            local ownPos = freecaming and BJI.Managers.Cam.getPositionRotation().pos or
                (ctxt.vehPosRot and ctxt.vehPosRot.pos or nil)
            if not ownPos then return end
            local distance = ownPos:distance(tagPos)
            local alpha = getAlphaByDistance(distance)

            if showDist then
                label = string.var("{1}({2})", { label, BJI.Utils.Common.PrettyDistance(distance) })
            end

            local zOffset = v:getInitialHeight()
            if currentVeh then
                zOffset = zOffset / 2
            end
            tagPos.z = tagPos.z + zOffset

            BJI.Utils.ShapeDrawer.Text(label, tagPos,
                forcedTextColor or getNametagColor(alpha, false, not currentVeh),
                forcedBgColor or getNametagBgColor(alpha, false, not currentVeh),
                false)
        end

        renderSpecs(ctxt, veh)
    else
        if not ownerTracting or ownerSpectating then
            local showDist = not currentVeh or freecaming
            local name = BJI.Managers.Context.Players[veh.ownerID].tagName
            local label = M.labels.trailer:var({ playerName = name })

            local tagPos = BJI.Managers.Veh.getPositionRotation(v).pos
            local ownPos = freecaming and BJI.Managers.Cam.getPositionRotation().pos or
                (ctxt.vehPosRot and ctxt.vehPosRot.pos or nil)
            if not ownPos then return end
            local distance = ownPos:distance(tagPos)
            local alpha = getAlphaByDistance(distance)

            if showDist then
                label = string.var("{1}({2})", { label, BJI.Utils.Common.PrettyDistance(distance) })
            end

            local zOffset = v:getInitialHeight()
            if currentVeh then
                zOffset = zOffset / 2
            end
            tagPos.z = tagPos.z + zOffset

            BJI.Utils.ShapeDrawer.Text(label, tagPos,
                forcedTextColor or getNametagColor(alpha, ownerSpectating, not ownerSpectating),
                forcedBgColor or getNametagBgColor(alpha, ownerSpectating, not ownerSpectating),
                false)
        end
        renderSpecs(ctxt, veh)
    end
end

local function renderVehicle(ctxt, veh, forcedTextColor, forcedBgColor)
    local v = BJI.Managers.Veh.getVehicleObject(veh.gameVehicleID)
    if not v then return end

    local ownVeh = veh.ownerID == ctxt.user.playerID
    local currentVeh = ctxt.veh and ctxt.veh:getID() == veh.gameVehicleID
    local freecaming = ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE
    local ownerDriving = veh.spectators[veh.ownerID]

    if ownVeh then
        if not currentVeh or freecaming then
            local tagPos = BJI.Managers.Veh.getPositionRotation(v).pos
            local ownPos = freecaming and BJI.Managers.Cam.getPositionRotation().pos or
                (ctxt.vehPosRot and ctxt.vehPosRot.pos or nil)
            if not ownPos then return end
            local distance = ownPos:distance(tagPos)
            local alpha = getAlphaByDistance(distance)

            local label = M.labels.self
            if settings.getValue("nameTagShowDistance", true) then
                label = string.var("{1}({2})", { label, BJI.Utils.Common.PrettyDistance(distance) })
            end

            tagPos.z = tagPos.z + v:getInitialHeight()

            BJI.Utils.ShapeDrawer.Text(label, tagPos,
                forcedTextColor or getNametagColor(alpha, false, not currentVeh),
                forcedBgColor or getNametagBgColor(alpha, false, not currentVeh),
                false)

            renderSpecs(ctxt, veh)
        end
    else
        local tagPos = BJI.Managers.Veh.getPositionRotation(v).pos
        local ownPos = freecaming and BJI.Managers.Cam.getPositionRotation().pos or
            (ctxt.vehPosRot and ctxt.vehPosRot.pos or nil)
        if not ownPos then return end
        local distance = ownPos:distance(tagPos)
        local alpha = getAlphaByDistance(distance)

        local showTag = not settings.getValue("shortenNametags", false) and ownerDriving
        local showDist = settings.getValue("nameTagShowDistance", true) and
            (not currentVeh or freecaming) and distance > 10

        local owner = BJI.Managers.Context.Players[veh.ownerID] or error()
        local label = owner.tagName
        if showTag then
            local tag = ""
            if BJI.Managers.Perm.isStaff(veh.ownerID) then
                tag = M.labels.staffTag
            else
                local reputationTag = string.var("{1}{2}",
                    { M.labels.reputationTag, BJI.Managers.Reputation.getReputationLevel(owner.reputation) })
                tag = reputationTag
            end
            label = string.var("[{1}]{2}", { tag, label })
        end
        if showDist then
            label = string.var("{1}({2})", { label, BJI.Utils.Common.PrettyDistance(distance) })
        end

        local zOffset = v:getInitialHeight()
        if currentVeh then
            zOffset = zOffset / 2
        end
        tagPos.z = tagPos.z + zOffset

        BJI.Utils.ShapeDrawer.Text(label, tagPos,
            forcedTextColor or getNametagColor(alpha, false, not ownerDriving),
            forcedBgColor or getNametagBgColor(alpha, false, not ownerDriving),
            false)

        renderSpecs(ctxt, veh)
    end
end

local lastHideNametags = nil
local function detectVisibilityEvent()
    local val = settings.getValue("hideNameTags", false)
    if val ~= lastHideNametags then
        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.NAMETAGS_VISIBILITY_CHANGED, {
            visible = not val
        })
        lastHideNametags = val
    end
end

local function renderTick(ctxt)
    detectVisibilityEvent()

    MPVehicleGE.hideNicknames(true)

    if settings.getValue("hideNameTags", false) then
        return
    elseif (not BJI.Managers.Context.BJC.Freeroam or not BJI.Managers.Context.BJC.Freeroam.Nametags) and
        not BJI.Managers.Perm.isStaff() then
        return
    end

    if M.state then
        -- render rules : https://docs.google.com/spreadsheets/d/17YAlu5TkZD6BLCf3xmJ-1N0GbiUr641Xk7eFFnb-jF8?usp=sharing
        for _, veh in pairs(BJI.Managers.Veh.getMPVehicles()) do
            if not veh.isDeleted and veh.isSpawned then
                local vehType = BJI.Managers.Veh.getType(veh.jbeam)
                if vehType ~= "Prop" then
                    local scenarioShow, forcedTextColor, forcedBgColor = BJI.Managers.Scenario.doShowNametag({
                        gameVehicleID = veh.gameVehicleID,
                        ownerID = veh.ownerID
                    })
                    if scenarioShow then
                        if BJI.Managers.AI.isAIVehicle(veh.gameVehicleID) then
                            pcall(renderAI, ctxt, veh)
                        elseif vehType == "Trailer" then
                            pcall(renderTrailer, ctxt, veh, forcedTextColor, forcedBgColor)
                        else
                            pcall(renderVehicle, ctxt, veh, forcedTextColor, forcedBgColor)
                        end
                    end
                end
            end
        end
    end
end

local function slowTick(ctxt)
    if M.state then
        -- pre-render constants
        if settings.getValue("shortenNametags", false) then
            M.labels.staffTag = BJI.Managers.Lang.get("nametags.staffTag")
            M.labels.reputationTag = BJI.Managers.Lang.get("nametags.reputationTag")
            local nameLength = tonumber(settings.getValue("nametagCharLimit", 50))
            for _, p in pairs(BJI.Managers.Context.Players) do
                if #p.playerName > nameLength and (not p.tagName or #p.tagName ~= nameLength) then
                    local short = p.playerName:sub(1, nameLength)
                    p.tagName = string.var("{1}...", { short })
                else
                    p.tagName = p.playerName
                end
            end
        end
        M.labels.self = BJI.Managers.Lang.get("nametags.self")
        M.labels.selfTrailer = BJI.Managers.Lang.get("nametags.selfTrailer")
        M.labels.trailer = BJI.Managers.Lang.get("nametags.trailer")
    end
end

M.getNametagColor = getNametagColor
M.getNametagBgColor = getNametagBgColor

M.toggle = toggle

M.tryUpdate = tryUpdate

M.renderTick = renderTick

M.onLoad = function()
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.SLOW_TICK, slowTick)
end

return M
