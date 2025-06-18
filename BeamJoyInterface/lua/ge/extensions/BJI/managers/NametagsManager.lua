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
        fugitive = "",
    },
    labelsInit = false,

    cache = {
        vehTypes = {},
    },

    _minDistanceShow = 10,
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

---@param ctxt TickContext
---@param veh BJIMPVehicle
---@param ownPos vec3
---@param showMyself? boolean
local function renderSpecs(ctxt, veh, ownPos, showMyself)
    if not settings.getValue("showSpectators", true) then return end
    local scenarioShow, forcedColor, forcedBgColor = BJI.Managers.Scenario.doShowNametagsSpecs(veh)
    if not scenarioShow then return end

    local alpha = getAlphaByDistance(ownPos:distance(vec3(veh.position)))

    local zOffset = veh.vehicleHeight
    if ctxt.veh and ctxt.veh:getID() == veh.gameVehicleID then
        zOffset = veh.vehicleHeight / 2
    end

    Table(veh.spectators):keys()
        :filter(function(pid) return pid ~= veh.ownerID and (showMyself or pid ~= ctxt.user.playerID) end)
        :map(function(pid) return BJI.Managers.Context.Players[pid] end)
    ---@param spec BJIPlayer
        :forEach(function(spec)
            local label = spec.playerID == ctxt.user.playerID and M.labels.self or spec.tagName or spec.playerName
            BJI.Utils.ShapeDrawer.Text(label, vec3(veh.position) + vec3(0, 0, zOffset - .5),
                forcedColor or getNametagColor(alpha, true),
                forcedBgColor or getNametagBgColor(alpha, true),
                false)
        end)
end

local function renderWalking(ctxt, unicycle, ownPos, forcedTextColor, forcedBgColor)
    local isFreecaming = ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE
    if unicycle.ownerID == ctxt.user.playerID and not isFreecaming then
        return -- do not render myself
    end

    local distance = ownPos:distance(vec3(unicycle.position))
    local alpha = getAlphaByDistance(distance)

    local showTag = not settings.getValue("shortenNametags", false)
    local showDist = settings.getValue("nameTagShowDistance", true) and distance > M._minDistanceShow

    local label
    if unicycle.ownerID == ctxt.user.playerID then
        label = M.labels.self
    else
        local owner = BJI.Managers.Context.Players[unicycle.ownerID]
        label = owner.tagName

        if showTag then
            local tag = ""
            if BJI.Managers.Perm.isStaff(unicycle.ownerID) then
                tag = M.labels.staffTag
            else
                local reputationTag = string.var("{1}{2}",
                    { M.labels.reputationTag, BJI.Managers.Reputation.getReputationLevel(owner.reputation) })
                tag = reputationTag
            end
            label = string.var("[{1}]{2}", { tag, label })
        end
    end

    if showDist then
        label = string.var("{1}({2})", { label, BJI.Utils.UI.PrettyDistance(distance) })
    end

    BJI.Utils.ShapeDrawer.Text(label, vec3(unicycle.position) + vec3(0, 0, unicycle.vehicleHeight),
        forcedTextColor or getNametagColor(alpha),
        forcedBgColor or getNametagBgColor(alpha))
end

---@param ctxt TickContext
---@param veh BJIMPVehicle
---@param ownPos vec3
---@param forcedTextColor? BJIColor
---@param forcedBgColor? BJIColor
local function renderTrailer(ctxt, veh, ownPos, forcedTextColor, forcedBgColor)
    local isMyOwnVeh = veh.ownerID == ctxt.user.playerID
    local isMyCurrentVeh = ctxt.veh and ctxt.veh:getID() == veh.gameVehicleID
    local isFreecaming = ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE
    local ownerIsSpectating = veh.spectators[veh.ownerID]
    local ownerIsTracting = not ownerIsSpectating and
        Table(extensions.core_vehicle_partmgmt.findAttachedVehicles(veh.gameVehicleID))
        :map(function(vid)
            return BJI.Managers.Veh.getVehicleObject(vid)
        end)
        :filter(function(v)
            if not M.cache.vehTypes[v.jbeam] then
                M.cache.vehTypes[v.jbeam] = BJI.Managers.Veh.getType(v.jbeam)
            end
            return table.includes({ BJI.Managers.Veh.TYPES.CAR, BJI.Managers.Veh.TYPES.TRUCK },
                M.cache.vehTypes[v.jbeam])
        end)
        :any(function(v)
            return BJI.Managers.Veh.getVehOwnerID(v:getID()) == veh.ownerID
        end)

    if isMyOwnVeh then
        if not ownerIsTracting then
            local distance = ownPos:distance(vec3(veh.position))
            local alpha = getAlphaByDistance(distance)

            local label = M.labels.selfTrailer
            local showDist = settings.getValue("nameTagShowDistance", true) and
                (not isMyCurrentVeh or isFreecaming) and
                distance > M._minDistanceShow

            if showDist then
                label = string.var("{1}({2})", { label, BJI.Utils.UI.PrettyDistance(distance) })
            end

            local zOffset = 0
            if isMyCurrentVeh then
                zOffset = veh.vehicleHeight / 2
            end

            BJI.Utils.ShapeDrawer.Text(label, vec3(veh.position) + vec3(0, 0, zOffset),
                forcedTextColor or getNametagColor(alpha, false, not isMyCurrentVeh),
                forcedBgColor or getNametagBgColor(alpha, false, not isMyCurrentVeh),
                false)
        end
    elseif BJI.Managers.Context.Players[veh.ownerID] then
        if not ownerIsTracting or ownerIsSpectating then
            local distance = ownPos:distance(vec3(veh.position))
            local alpha = getAlphaByDistance(distance)

            local name = BJI.Managers.Context.Players[veh.ownerID].tagName
            local label = M.labels.trailer:var({ playerName = name })
            local showDist = settings.getValue("nameTagShowDistance", true) and
                (not isMyCurrentVeh or isFreecaming) and
                distance > M._minDistanceShow

            if showDist then
                label = string.var("{1}({2})", { label, BJI.Utils.UI.PrettyDistance(distance) })
            end

            local zOffset = veh.vehicleHeight
            if isMyCurrentVeh then
                zOffset = zOffset / 2
            end

            BJI.Utils.ShapeDrawer.Text(label, vec3(veh.position) + vec3(0, 0, zOffset),
                forcedTextColor or getNametagColor(alpha, ownerIsSpectating, not ownerIsSpectating),
                forcedBgColor or getNametagBgColor(alpha, ownerIsSpectating, not ownerIsSpectating),
                false)
        end
    end

    local showMyselfSpec = not isMyOwnVeh and isMyCurrentVeh and isFreecaming
    renderSpecs(ctxt, veh, ownPos, showMyselfSpec)
end

---@param ctxt TickContext
---@param veh BJIMPVehicle
---@param ownPos vec3
---@param forcedTextColor? BJIColor
---@param forcedBgColor? BJIColor
local function renderVehicle(ctxt, veh, ownPos, forcedTextColor, forcedBgColor)
    local isMyOwnVeh = veh.ownerID == ctxt.user.playerID
    local isMyCurrentVeh = ctxt.veh and ctxt.veh:getID() == veh.gameVehicleID
    local isFreecaming = ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE
    local ownerIsDriving = veh.spectators[veh.ownerID]
    local showSpecs = false

    if isMyOwnVeh then
        if not isMyCurrentVeh or isFreecaming then
            local distance = ownPos:distance(vec3(veh.position))
            local alpha = getAlphaByDistance(distance)

            local label = M.labels.self
            if settings.getValue("nameTagShowDistance", true) and distance > M._minDistanceShow then
                label = string.var("{1}({2})", { label, BJI.Utils.UI.PrettyDistance(distance) })
            end

            local zOffset = veh.vehicleHeight
            if isMyCurrentVeh then
                zOffset = veh.vehicleHeight / 2
            end

            BJI.Utils.ShapeDrawer.Text(label, vec3(veh.position) + vec3(0, 0, zOffset),
                forcedTextColor or getNametagColor(alpha, false, not isMyCurrentVeh),
                forcedBgColor or getNametagBgColor(alpha, false, not isMyCurrentVeh),
                false)
            showSpecs = true
        end
    elseif BJI.Managers.Context.Players[veh.ownerID] then
        local distance = ownPos:distance(vec3(veh.position))
        local alpha = getAlphaByDistance(distance)

        local showTag = not settings.getValue("shortenNametags", false) and ownerIsDriving
        local showDist = settings.getValue("nameTagShowDistance", true) and
            (not isMyCurrentVeh or isFreecaming) and
            distance > M._minDistanceShow

        local owner = BJI.Managers.Context.Players[veh.ownerID]
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
            label = string.var("{1}({2})", { label, BJI.Utils.UI.PrettyDistance(distance) })
        end

        local zOffset = veh.vehicleHeight
        if isMyCurrentVeh then
            zOffset = zOffset / 2
        end

        BJI.Utils.ShapeDrawer.Text(label, vec3(veh.position) + vec3(0, 0, zOffset),
            forcedTextColor or getNametagColor(alpha, false, not ownerIsDriving),
            forcedBgColor or getNametagBgColor(alpha, false, not ownerIsDriving),
            false)
        showSpecs = true
    end
    if showSpecs then
        local showMyselfSpec = not isMyOwnVeh and isMyCurrentVeh and isFreecaming
        renderSpecs(ctxt, veh, ownPos, showMyselfSpec)
    end
end

---@param ctxt TickContext
---@param veh BJIMPVehicle
---@param ownPos vec3
local function renderFugitive(ctxt, veh, ownPos)
    local distance = ownPos:distance(vec3(veh.position))

    local showTag = not settings.getValue("shortenNametags", false)
    local showDist = settings.getValue("nameTagShowDistance", true) and
        distance > M._minDistanceShow

    local label
    if veh.isAi then
        label = M.labels.fugitive
    else
        local owner = BJI.Managers.Context.Players[veh.ownerID]
        label = owner.tagName
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
    end
    if showDist then
        label = string.var("{1}({2})", { label, BJI.Utils.UI.PrettyDistance(distance) })
    end

    local tagPos = vec3(veh.position) + vec3(0, 0, veh.vehicleHeight)

    local textColor, bgColor = BJI.Managers.Pursuit.getFugitiveNametagColors()
    BJI.Utils.ShapeDrawer.Text(label, tagPos, textColor, bgColor, false)
    if not veh.isAi then
        BJI.Utils.ShapeDrawer.Text(M.labels.fugitive, tagPos + vec3(0, 0, .2), textColor, bgColor, false)
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

---@param ctxt TickContext
local function renderTick(ctxt)
    detectVisibilityEvent()

    MPVehicleGE.hideNicknames(true)

    if settings.getValue("hideNameTags", false) then
        return
    elseif BJI.Managers.Scenario.isFreeroam() and
        not BJI.Managers.Context.BJC.Freeroam.Nametags and
        not BJI.Managers.Perm.isStaff() then
        return
    elseif not M.labelsInit then
        return
    end

    if M.state then
        -- render rules : https://docs.google.com/spreadsheets/d/17YAlu5TkZD6BLCf3xmJ-1N0GbiUr641Xk7eFFnb-jF8?usp=sharing
        local ownPos = ctxt.vehPosRot and ctxt.vehPosRot.pos or
            BJI.Managers.Cam.getPositionRotation().pos
        Table(BJI.Managers.Veh.getMPVehicles())
        ---@param veh BJIMPVehicle
            :filter(function(veh)
                if veh.isAi and
                    not BJI.Managers.Pursuit.policeTargets[veh.gameVehicleID] then
                    return false
                end
                if not M.cache.vehTypes[veh.jbeam] then
                    M.cache.vehTypes[veh.jbeam] = BJI.Managers.Veh.getType(veh.jbeam)
                end
                if M.cache.vehTypes[veh.jbeam] == BJI.Managers.Veh.TYPES.PROP then
                    return false -- prop veh (no nametag)
                end
                return true
            end)
        ---@param veh BJIMPVehicle
            :forEach(function(veh)
                local scenarioShow, forcedTextColor, forcedBgColor = BJI.Managers.Scenario.doShowNametag(veh)
                if scenarioShow then
                    if veh.jbeam == "unicycle" then
                        renderWalking(ctxt, veh, ownPos, forcedTextColor, forcedBgColor)
                    elseif M.cache.vehTypes[veh.jbeam] == BJI.Managers.Veh.TYPES.TRAILER then
                        renderTrailer(ctxt, veh, ownPos, forcedTextColor, forcedBgColor)
                    elseif BJI.Managers.Pursuit.policeTargets[veh.gameVehicleID] then
                        renderFugitive(ctxt, veh, ownPos)
                    elseif not veh.isAi then
                        renderVehicle(ctxt, veh, ownPos, forcedTextColor, forcedBgColor)
                    end
                end
            end)
    end
end

local function updateLabels()
    M.labels.staffTag = BJI.Managers.Lang.get("nametags.staffTag")
    M.labels.reputationTag = BJI.Managers.Lang.get("nametags.reputationTag")
    M.labels.self = BJI.Managers.Lang.get("nametags.self")
    M.labels.selfTrailer = BJI.Managers.Lang.get("nametags.selfTrailer")
    M.labels.trailer = BJI.Managers.Lang.get("nametags.trailer")
    M.labels.fugitive = BJI.Managers.Lang.get("nametags.fugitive")
    M.labelsInit = true
end

local lastShorten, lastShortenLength = false, 0
local function getPlayerTagName(playerName, shorten, shortenLength)
    shorten = shorten or lastShorten
    shortenLength = shortenLength or lastShortenLength
    if not shorten or shortenLength > #playerName then
        return tostring(playerName)
    else
        return tostring(playerName):sub(1, shortenLength) .. "..."
    end
end

local function slowTick(ctxt)
    if M.state then
        local shorten, shortenLength = settings.getValue("shortenNametags", false),
            tonumber(settings.getValue("nametagCharLimit", 50))
        if shorten ~= lastShorten or (shorten and shortenLength ~= lastShortenLength) then
            BJI.Managers.Context.Players:forEach(function(p)
                p.tagName = getPlayerTagName(p.playerName, shorten, shortenLength)
            end)
            lastShorten = shorten
            lastShortenLength = shortenLength or 0
        end
    end
end

local function updateState()
    local function _update()
        M.state = BJI.Managers.Perm.isStaff() or BJI.Managers.Scenario.canShowNametags()
    end

    if BJI.Managers.Cache.areBaseCachesFirstLoaded() and BJI.CLIENT_READY then
        _update()
    else
        BJI.Managers.Async.task(function()
            return BJI.Managers.Cache.areBaseCachesFirstLoaded() and BJI.CLIENT_READY
        end, _update)
    end
end

M.getNametagColor = getNametagColor
M.getNametagBgColor = getNametagBgColor

M.renderTick = renderTick
M.getPlayerTagName = getPlayerTagName

M.onLoad = function()
    updateLabels()
    BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateLabels, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.SLOW_TICK, slowTick, M._name)
    BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.CACHE_LOADED,
        BJI.Managers.Events.EVENTS.SCENARIO_CHANGED,
        BJI.Managers.Events.EVENTS.SCENARIO_UPDATED,
    }, function(_, data)
        if data.event ~= BJI.Managers.Events.EVENTS.CACHE_LOADED or
            data.cache == BJI.Managers.Cache.CACHES.BJC then
            updateState()
        end
    end, M._name)
end

return M
