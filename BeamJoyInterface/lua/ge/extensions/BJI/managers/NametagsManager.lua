---@class BJIManagerNametags : BJIManager
local M = {
    _name = "Nametags",

    state = false,

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
-- gc prevention
local ownPos, scenarioShow, forcedTextColor, forcedBgColor, value,
isFreecaming, distance, alpha, showTag, showDist, label, owner, tag, isMyOwn, isMyCurrent,
zOffset, ownerIsSpectating, ownerVeh, ownerIsTracting, showSpecs, tagPos, color, fadeoutDistance

local function getAlphaByDistance(distance)
    alpha = 1
    if settings.getValue("nameTagFadeEnabled") then
        fadeoutDistance = settings.getValue("nameTagFadeDistance", 40)
        alpha = math.scale(distance, fadeoutDistance, 0, 0, 1, true)

        if BJI_Cam.getCamera() ~= BJI_Cam.CAMERAS.FREE and
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
    if spec then
        color = BJI_LocalStorage.get(BJI_LocalStorage.GLOBAL_VALUES.NAMETAGS_COLOR_SPEC_TEXT)
    elseif idle then
        color = BJI_LocalStorage.get(BJI_LocalStorage.GLOBAL_VALUES.NAMETAGS_COLOR_IDLE_TEXT)
    else
        color = BJI_LocalStorage.get(BJI_LocalStorage.GLOBAL_VALUES.NAMETAGS_COLOR_PLAYER_TEXT)
    end
    color = color or { r = 0, g = 0, b = 0 }
    color.a = alpha

    return BJI.Utils.ShapeDrawer.Color():fromRaw(color)
end

---@param alpha number 0-1
---@param spec? boolean
---@param idle? boolean
---@return BJIColor
local function getNametagBgColor(alpha, spec, idle)
    if spec then
        color = BJI_LocalStorage.get(BJI_LocalStorage.GLOBAL_VALUES.NAMETAGS_COLOR_SPEC_BG)
    elseif idle then
        color = BJI_LocalStorage.get(BJI_LocalStorage.GLOBAL_VALUES.NAMETAGS_COLOR_IDLE_BG)
    else
        color = BJI_LocalStorage.get(BJI_LocalStorage.GLOBAL_VALUES.NAMETAGS_COLOR_PLAYER_BG)
    end
    color = BJI.Utils.ShapeDrawer.Color():fromRaw(color or { r = 0, g = 0, b = 0 })

    color.a = alpha
    return color
end

---@param ctxt TickContext
---@param veh BJIMPVehicle
---@param ownPos vec3
---@param showMyself? boolean
local function renderSpecs(ctxt, veh, ownPos, showMyself)
    if not settings.getValue("showSpectators", true) then return end
    scenarioShow, forcedTextColor, forcedBgColor = BJI_Scenario.doShowNametagsSpecs(veh)
    if not scenarioShow then return end

    alpha = getAlphaByDistance(ownPos:distance(vec3(veh.position)))

    zOffset = veh.vehicleHeight
    if ctxt.veh and ctxt.veh.gameVehicleID == veh.gameVehicleID then
        zOffset = veh.vehicleHeight / 2
    end

    Table(veh.spectators):keys()
        :filter(function(pid) return pid ~= veh.ownerID and (showMyself or pid ~= ctxt.user.playerID) end)
        :map(function(pid) return ctxt.players[pid] end)
    ---@param spec BJIPlayer
        :forEach(function(spec)
            label = spec.playerID == ctxt.user.playerID and M.labels.self or spec.tagName or spec.playerName
            BJI.Utils.ShapeDrawer.Text(label, vec3(veh.position) + vec3(0, 0, zOffset - .5),
                forcedTextColor or getNametagColor(alpha, true),
                forcedBgColor or getNametagBgColor(alpha, true),
                false)
        end)
end

---@param ctxt TickContext
---@param unicycle BJIMPVehicle
---@param ownPos vec3
---@param forcedTextColor? BJIColor
---@param forcedBgColor? BJIColor
local function renderWalking(ctxt, unicycle, ownPos, forcedTextColor, forcedBgColor)
    isFreecaming = ctxt.camera == BJI_Cam.CAMERAS.FREE
    if unicycle.ownerID == ctxt.user.playerID and not isFreecaming then
        return -- do not render myself
    end

    distance = ownPos:distance(vec3(unicycle.position))
    alpha = getAlphaByDistance(distance)

    showTag = not settings.getValue("shortenNametags", false)
    showDist = settings.getValue("nameTagShowDistance", true) and distance > M._minDistanceShow

    if unicycle.ownerID == ctxt.user.playerID then
        label = M.labels.self
    else
        owner = ctxt.players[unicycle.ownerID]
        label = owner.tagName

        if showTag then
            if BJI_Perm.isStaff(unicycle.ownerID) then
                tag = M.labels.staffTag
            else
                tag = string.var("{1}{2}",
                    { M.labels.reputationTag, BJI_Reputation.getReputationLevel(owner.reputation) })
            end
            label = string.var("[{1}]{2}", { tag, label })
        end
    end

    if showDist then
        label = string.var("{1}({2})", { label, BJI.Utils.UI.PrettyDistance(distance) })
    end

    if BJI_Win_GameDebug.getState() then
        label = "(" .. tostring(unicycle.gameVehicleID) .. ")" .. label
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
    isMyOwn = veh.ownerID == ctxt.user.playerID
    isMyCurrent = ctxt.veh and ctxt.veh.gameVehicleID == veh.gameVehicleID
    isFreecaming = ctxt.camera == BJI_Cam.CAMERAS.FREE
    ownerIsSpectating = veh.spectators[veh.ownerID]
    ownerVeh = ctxt.players[veh.ownerID] and
        BJI_Veh.getMPVehicle(ctxt.players[veh.ownerID].currentVehicle,
            veh.ownerID == ctxt.user.playerID) or nil
    ownerIsTracting = not ownerIsSpectating and
        ownerVeh and ownerVeh.ownerID == veh.ownerID and
        BJI_Veh.findAttachedVehicles(ownerVeh.gameVehicleID):includes(veh.gameVehicleID)

    if isMyOwn then
        if not ownerIsTracting then
            distance = ownPos:distance(vec3(veh.position))
            alpha = getAlphaByDistance(distance)

            label = M.labels.selfTrailer
            showDist = settings.getValue("nameTagShowDistance", true) and
                (not isMyCurrent or isFreecaming) and
                distance > M._minDistanceShow

            if showDist then
                label = string.var("{1}({2})", { label, BJI.Utils.UI.PrettyDistance(distance) })
            end

            zOffset = veh.vehicleHeight
            if isMyCurrent then
                zOffset = veh.vehicleHeight / 2
            end

            if BJI_Win_GameDebug.getState() then
                label = "(" .. tostring(veh.gameVehicleID) .. ")" .. label
            end
            BJI.Utils.ShapeDrawer.Text(label, vec3(veh.position) + vec3(0, 0, zOffset),
                forcedTextColor or getNametagColor(alpha, false, not isMyCurrent),
                forcedBgColor or getNametagBgColor(alpha, false, not isMyCurrent),
                false)
        end
    elseif ctxt.players[veh.ownerID] then
        if not ownerIsTracting or ownerIsSpectating then
            distance = ownPos:distance(vec3(veh.position))
            alpha = getAlphaByDistance(distance)

            label = M.labels.trailer:var({ playerName = ctxt.players[veh.ownerID].tagName })
            showDist = settings.getValue("nameTagShowDistance", true) and
                (not isMyCurrent or isFreecaming) and
                distance > M._minDistanceShow

            if showDist then
                label = string.var("{1}({2})", { label, BJI.Utils.UI.PrettyDistance(distance) })
            end

            zOffset = veh.vehicleHeight
            if isMyCurrent then
                zOffset = veh.vehicleHeight / 2
            end

            if BJI_Win_GameDebug.getState() then
                label = "(" .. tostring(veh.gameVehicleID) .. ")" .. label
            end
            BJI.Utils.ShapeDrawer.Text(label, vec3(veh.position) + vec3(0, 0, zOffset),
                forcedTextColor or getNametagColor(alpha, ownerIsSpectating, not ownerIsSpectating),
                forcedBgColor or getNametagBgColor(alpha, ownerIsSpectating, not ownerIsSpectating),
                false)
        end
    end

    renderSpecs(ctxt, veh, ownPos, not isMyOwn and isMyCurrent and isFreecaming)
end

---@param ctxt TickContext
---@param veh BJIMPVehicle
---@param ownPos vec3
---@param forcedTextColor? BJIColor
---@param forcedBgColor? BJIColor
local function renderVehicle(ctxt, veh, ownPos, forcedTextColor, forcedBgColor)
    isMyOwn = veh.ownerID == ctxt.user.playerID
    isMyCurrent = ctxt.veh and ctxt.veh.gameVehicleID == veh.gameVehicleID
    isFreecaming = ctxt.camera == BJI_Cam.CAMERAS.FREE
    ownerIsSpectating = veh.spectators[veh.ownerID]
    showSpecs = false

    if isMyOwn then
        if not isMyCurrent or isFreecaming then
            distance = ownPos:distance(vec3(veh.position))
            alpha = getAlphaByDistance(distance)

            label = M.labels.self
            if settings.getValue("nameTagShowDistance", true) and distance > M._minDistanceShow then
                label = string.var("{1}({2})", { label, BJI.Utils.UI.PrettyDistance(distance) })
            end

            zOffset = veh.vehicleHeight
            if isMyCurrent then
                zOffset = veh.vehicleHeight / 2
            end

            if BJI_Win_GameDebug.getState() then
                label = "(" .. tostring(veh.gameVehicleID) .. ")" .. label
            end
            BJI.Utils.ShapeDrawer.Text(label, vec3(veh.position) + vec3(0, 0, zOffset),
                forcedTextColor or getNametagColor(alpha, false, not isMyCurrent),
                forcedBgColor or getNametagBgColor(alpha, false, not isMyCurrent),
                false)
            showSpecs = true
        end
    elseif ctxt.players[veh.ownerID] then
        distance = ownPos:distance(vec3(veh.position))
        alpha = getAlphaByDistance(distance)

        showTag = not settings.getValue("shortenNametags", false) and ownerIsSpectating
        showDist = settings.getValue("nameTagShowDistance", true) and
            (not isMyCurrent or isFreecaming) and
            distance > M._minDistanceShow

        owner = ctxt.players[veh.ownerID]
        label = owner.tagName
        if showTag then
            if BJI_Perm.isStaff(veh.ownerID) then
                tag = M.labels.staffTag
            else
                tag = string.var("{1}{2}",
                    { M.labels.reputationTag, BJI_Reputation.getReputationLevel(owner.reputation) })
            end
            label = string.var("[{1}]{2}", { tag, label })
        end
        if showDist then
            label = string.var("{1}({2})", { label, BJI.Utils.UI.PrettyDistance(distance) })
        end

        zOffset = veh.vehicleHeight
        if isMyCurrent then
            zOffset = zOffset / 2
        end

        if BJI_Win_GameDebug.getState() then
            label = "(" .. tostring(veh.gameVehicleID) .. ")" .. label
        end
        BJI.Utils.ShapeDrawer.Text(label, vec3(veh.position) + vec3(0, 0, zOffset),
            forcedTextColor or getNametagColor(alpha, false, not ownerIsSpectating),
            forcedBgColor or getNametagBgColor(alpha, false, not ownerIsSpectating),
            false)
        showSpecs = true
    end
    if showSpecs then
        renderSpecs(ctxt, veh, ownPos, not isMyOwn and isMyCurrent and isFreecaming)
    end
end

---@param ctxt TickContext
---@param veh BJIMPVehicle
---@param ownPos vec3
local function renderFugitive(ctxt, veh, ownPos)
    distance = ownPos:distance(vec3(veh.position))

    showTag = not settings.getValue("shortenNametags", false)
    showDist = settings.getValue("nameTagShowDistance", true) and
        distance > M._minDistanceShow

    if veh.isAi then
        label = M.labels.fugitive
    else
        owner = ctxt.players[veh.ownerID]
        label = owner.tagName
        if showTag then
            if BJI_Perm.isStaff(veh.ownerID) then
                tag = M.labels.staffTag
            else
                tag = string.var("{1}{2}",
                    { M.labels.reputationTag, BJI_Reputation.getReputationLevel(owner.reputation) })
            end
            label = string.var("[{1}]{2}", { tag, label })
        end
    end
    if showDist then
        label = string.var("{1}({2})", { label, BJI.Utils.UI.PrettyDistance(distance) })
    end

    if BJI_Win_GameDebug.getState() then
        label = "(" .. tostring(veh.gameVehicleID) .. ")" .. label
    end
    tagPos = vec3(veh.position) + vec3(0, 0, veh.vehicleHeight)
    forcedTextColor, forcedBgColor = BJI_Pursuit.getFugitiveNametagColors()
    BJI.Utils.ShapeDrawer.Text(label, tagPos, forcedTextColor, forcedBgColor, false)
    if not veh.isAi then
        BJI.Utils.ShapeDrawer.Text(M.labels.fugitive, tagPos + vec3(0, 0, .2), forcedTextColor, forcedBgColor, false)
    end
end

local lastHideNametags = nil
local function detectVisibilityEvent()
    value = settings.getValue("hideNameTags", false)
    if value ~= lastHideNametags then
        BJI_Events.trigger(BJI_Events.EVENTS.NAMETAGS_VISIBILITY_CHANGED, {
            visible = not value
        })
        lastHideNametags = value
    end
end

local function getState()
    if not BJI_Cache.areBaseCachesFirstLoaded() or
        not M.state or not M.labelsInit or
        settings.getValue("hideNameTags") == true or
        (
            BJI_Scenario.isFreeroam() and
            not BJI_Context.BJC.Freeroam.Nametags and
            not BJI_Perm.isStaff()
        ) then
        return false
    end
    return true
end

---@param ctxt TickContext
local function renderTick(ctxt)
    detectVisibilityEvent()
    MPVehicleGE.hideNicknames(true)
    if not M.getState() then return end

    -- render rules : https://docs.google.com/spreadsheets/d/17YAlu5TkZD6BLCf3xmJ-1N0GbiUr641Xk7eFFnb-jF8?usp=sharing
    if ctxt.camera == BJI_Cam.CAMERAS.FREE or not ctxt.veh then
        ownPos = BJI_Cam.getPositionRotation().pos
    else
        ownPos = ctxt.veh.position
    end
    Table(BJI_Veh.getMPVehicles())
    ---@param veh BJIMPVehicle
        :filter(function(veh)
            if veh.isAi and
                not BJI_Pursuit.policeTargets[veh.gameVehicleID] then
                return false
            end
            if not M.cache.vehTypes[veh.jbeam] then
                M.cache.vehTypes[veh.jbeam] = BJI_Veh.getType(veh.jbeam)
            end
            if M.cache.vehTypes[veh.jbeam] == BJI_Veh.TYPES.PROP then
                return false -- prop veh (no nametag)
            end
            return true
        end)
    ---@param veh BJIMPVehicle
        :forEach(function(veh)
            scenarioShow, forcedTextColor, forcedBgColor = BJI_Scenario.doShowNametag(veh)
            if scenarioShow then
                if veh.jbeam == "unicycle" then
                    renderWalking(ctxt, veh, ownPos, forcedTextColor, forcedBgColor)
                elseif M.cache.vehTypes[veh.jbeam] == BJI_Veh.TYPES.TRAILER then
                    renderTrailer(ctxt, veh, ownPos, forcedTextColor, forcedBgColor)
                elseif BJI_Pursuit.policeTargets[veh.gameVehicleID] then
                    renderFugitive(ctxt, veh, ownPos)
                elseif not veh.isAi then
                    renderVehicle(ctxt, veh, ownPos, forcedTextColor, forcedBgColor)
                end
            end
        end)
end

local function updateLabels()
    M.labels.staffTag = BJI_Lang.get("nametags.staffTag")
    M.labels.reputationTag = BJI_Lang.get("nametags.reputationTag")
    M.labels.self = BJI_Lang.get("nametags.self")
    M.labels.selfTrailer = BJI_Lang.get("nametags.selfTrailer")
    M.labels.trailer = BJI_Lang.get("nametags.trailer")
    M.labels.fugitive = BJI_Lang.get("nametags.fugitive")
    M.labelsInit = true
end

local lastShorten, lastShortenLength = true, -1
---@param playerName string
---@param shorten boolean?
---@param shortenLength integer?
---@return string
local function getPlayerTagName(playerName, shorten, shortenLength)
    if shorten == nil then shorten = lastShorten end
    shortenLength = shortenLength or lastShortenLength
    if not shorten or shortenLength > #playerName then
        return tostring(playerName)
    else
        return tostring(playerName):sub(1, shortenLength) .. "..."
    end
end

local changed, shorten, shortenLength
local function slowTick(ctxt)
    if M.getState() then
        shorten = settings.getValue("shortenNametags", false) == true
        shortenLength = tonumber(settings.getValue("nametagCharLimit")) or 50
        changed = false
        if lastShorten and not shorten then
            ctxt.players:forEach(function(p)
                p.tagName = p.playerName
            end)
            changed = true
        elseif shorten and
            (not lastShorten or lastShortenLength ~= shortenLength) then
            ctxt.players:forEach(function(p)
                p.tagName = getPlayerTagName(p.playerName, shorten, shortenLength)
            end)
            changed = true
        end
        if changed then
            lastShorten = shorten
            lastShortenLength = shortenLength
        end
    end
end

local function updateState()
    local function _update()
        M.state = BJI_Perm.isStaff() or BJI_Scenario.canShowNametags()
    end

    if BJI_Cache.areBaseCachesFirstLoaded() and BJI.CLIENT_READY then
        _update()
    else
        BJI_Async.task(function()
            return BJI_Cache.areBaseCachesFirstLoaded() and BJI.CLIENT_READY
        end, _update)
    end
end

M.getNametagColor = getNametagColor
M.getNametagBgColor = getNametagBgColor

M.renderTick = renderTick
M.getPlayerTagName = getPlayerTagName

M.getState = getState

M.onLoad = function()
    updateLabels()
    BJI_Events.addListener({
        BJI_Events.EVENTS.LANG_CHANGED,
        BJI_Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateLabels, M._name)
    BJI_Events.addListener(BJI_Events.EVENTS.SLOW_TICK, slowTick, M._name)
    BJI_Events.addListener({
        BJI_Events.EVENTS.CACHE_LOADED,
        BJI_Events.EVENTS.SCENARIO_CHANGED,
        BJI_Events.EVENTS.SCENARIO_UPDATED,
    }, function(_, data)
        if data.event ~= BJI_Events.EVENTS.CACHE_LOADED or
            data.cache == BJI_Cache.CACHES.BJC then
            updateState()
        end
    end, M._name)
end

return M
