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

    local tagPos = vec3(veh.position)
    local alpha = getAlphaByDistance(ownPos:distance(tagPos))

    local zOffset = 0
    if ctxt.veh and ctxt.veh:getID() == veh.gameVehicleID then
        zOffset = veh.vehicleHeight / 2
    end
    tagPos.z = tagPos.z + zOffset - .5 -- half a meter offset downward for specs

    Table(veh.spectators):keys()
        :filter(function(pid) return pid ~= veh.ownerID and (showMyself or pid ~= ctxt.user.playerID) end)
        :map(function(pid) return BJI.Managers.Context.Players[pid] end)
    ---@param spec BJIPlayer
        :forEach(function(spec)
            local label = spec.playerID == ctxt.user.playerID and M.labels.self or spec.tagName or spec.playerName
            BJI.Utils.ShapeDrawer.Text(label, tagPos,
                forcedColor or getNametagColor(alpha, true),
                forcedBgColor or getNametagBgColor(alpha, true),
                false)
        end)
end

---@param ctxt TickContext
---@param veh BJIMPVehicle
---@param ownPos vec3
local function renderAI(ctxt, veh, ownPos)
    local isMyOwnVeh = veh.ownerID == ctxt.user.playerID
    local isMyCurrentVeh = ctxt.veh and ctxt.veh:getID() == veh.gameVehicleID
    local isFreecaming = ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE
    local ownerIsSpec = veh.spectators[veh.ownerID]

    if isMyOwnVeh then
        if isMyCurrentVeh then
            local tagPos = vec3(veh.position)
            local distance = ownPos:distance(tagPos)
            local alpha = getAlphaByDistance(distance)

            local showDist = settings.getValue("nameTagShowDistance", true) and
                isFreecaming and distance > M._minDistanceShow

            local label = M.labels.self
            if showDist then
                label = string.var("{1}({2})", { label, BJI.Utils.Common.PrettyDistance(distance) })
            end

            -- offset
            tagPos.z = tagPos.z + veh.vehicleHeight / 2

            BJI.Utils.ShapeDrawer.Text(label, tagPos,
                getNametagColor(alpha, true),
                getNametagBgColor(alpha, true),
                false)
        end
    else
        if isMyCurrentVeh or ownerIsSpec then
            local tagPos = vec3(veh.position)
            local distance = ownPos:distance(tagPos)
            local alpha = getAlphaByDistance(distance)

            local showDist = settings.getValue("nameTagShowDistance", true) and
                isFreecaming and distance > M._minDistanceShow

            local owner = BJI.Managers.Context.Players[veh.ownerID]
            local label = owner.tagName
            if showDist then
                label = string.var("{1}({2})", { label, BJI.Utils.Common.PrettyDistance(distance) })
            end

            -- offset
            tagPos.z = tagPos.z + veh.vehicleHeight / 2

            BJI.Utils.ShapeDrawer.Text(label, tagPos,
                getNametagColor(alpha, ownerIsSpec, not ownerIsSpec),
                getNametagBgColor(alpha, ownerIsSpec, not ownerIsSpec),
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
local function renderTrailer(ctxt, veh, ownPos, forcedTextColor, forcedBgColor)
    local isMyOwnVeh = veh.ownerID == ctxt.user.playerID
    local isMyCurrentVeh = ctxt.veh and ctxt.veh:getID() == veh.gameVehicleID
    local isFreecaming = ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE
    local ownerIsSpectating = veh.spectators[veh.ownerID]
    local ownerIsTracting = not ownerIsSpectating and
        Table(core_vehicle_partmgmt.findAttachedVehicles(veh.gameVehicleID))
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
            local tagPos = vec3(veh.position)
            local distance = ownPos:distance(tagPos)
            local alpha = getAlphaByDistance(distance)

            local label = M.labels.selfTrailer
            local showDist = settings.getValue("nameTagShowDistance", true) and
                (not isMyCurrentVeh or isFreecaming) and
                distance > M._minDistanceShow

            if showDist then
                label = string.var("{1}({2})", { label, BJI.Utils.Common.PrettyDistance(distance) })
            end

            local zOffset = 0
            if isMyCurrentVeh then
                zOffset = veh.vehicleHeight / 2
            end
            tagPos.z = tagPos.z + zOffset

            BJI.Utils.ShapeDrawer.Text(label, tagPos,
                forcedTextColor or getNametagColor(alpha, false, not isMyCurrentVeh),
                forcedBgColor or getNametagBgColor(alpha, false, not isMyCurrentVeh),
                false)
        end
    elseif BJI.Managers.Context.Players[veh.ownerID] then
        if not ownerIsTracting or ownerIsSpectating then
            local tagPos = vec3(veh.position)
            local distance = ownPos:distance(tagPos)
            local alpha = getAlphaByDistance(distance)

            local name = BJI.Managers.Context.Players[veh.ownerID].tagName
            local label = M.labels.trailer:var({ playerName = name })
            local showDist = settings.getValue("nameTagShowDistance", true) and
                (not isMyCurrentVeh or isFreecaming) and
                distance > M._minDistanceShow

            if showDist then
                label = string.var("{1}({2})", { label, BJI.Utils.Common.PrettyDistance(distance) })
            end

            local zOffset = veh.vehicleHeight
            if isMyCurrentVeh then
                zOffset = zOffset / 2
            end
            tagPos.z = tagPos.z + zOffset

            BJI.Utils.ShapeDrawer.Text(label, tagPos,
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
            local tagPos = vec3(veh.position)
            local distance = ownPos:distance(tagPos)
            local alpha = getAlphaByDistance(distance)

            local label = M.labels.self
            if settings.getValue("nameTagShowDistance", true) and distance > M._minDistanceShow then
                label = string.var("{1}({2})", { label, BJI.Utils.Common.PrettyDistance(distance) })
            end

            local zOffset = 0
            if isMyCurrentVeh then
                zOffset = veh.vehicleHeight / 2
            end
            tagPos.z = tagPos.z + zOffset

            BJI.Utils.ShapeDrawer.Text(label, tagPos,
                forcedTextColor or getNametagColor(alpha, false, not isMyCurrentVeh),
                forcedBgColor or getNametagBgColor(alpha, false, not isMyCurrentVeh),
                false)
            showSpecs = true
        end
    elseif BJI.Managers.Context.Players[veh.ownerID] then
        local tagPos = vec3(veh.position)
        local distance = ownPos:distance(tagPos)
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
            label = string.var("{1}({2})", { label, BJI.Utils.Common.PrettyDistance(distance) })
        end

        local zOffset = veh.vehicleHeight
        if isMyCurrentVeh then
            zOffset = zOffset / 2
        end
        tagPos.z = tagPos.z + zOffset

        BJI.Utils.ShapeDrawer.Text(label, tagPos,
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
        (not BJI.Managers.Context.BJC.Freeroam or not BJI.Managers.Context.BJC.Freeroam.Nametags) and
        not BJI.Managers.Perm.isStaff() then
        return
    end

    if M.state then
        -- render rules : https://docs.google.com/spreadsheets/d/17YAlu5TkZD6BLCf3xmJ-1N0GbiUr641Xk7eFFnb-jF8?usp=sharing
        local ownPos = ctxt.camera == BJI.Managers.Cam.CAMERAS.FREE and
            BJI.Managers.Cam.getPositionRotation().pos or (ctxt.vehPosRot and ctxt.vehPosRot.pos or vec3())
        Table(BJI.Managers.Veh.getMPVehicles())
        ---@param veh BJIMPVehicle
            :filter(function(veh)
                if veh.isDeleted or not veh.isSpawned then
                    return false -- invalid veh (not ready/deleted)
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
                    if BJI.Managers.AI.isAIVehicle(veh.gameVehicleID) then
                        renderAI(ctxt, veh, ownPos)
                    elseif M.cache.vehTypes[veh.jbeam] == BJI.Managers.Veh.TYPES.TRAILER then
                        renderTrailer(ctxt, veh, ownPos, forcedTextColor, forcedBgColor)
                    else
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
end

local function getPlayerTagName(playerName, shorten, shortenLength)
    shorten = shorten or settings.getValue("shortenNametags", false)
    shortenLength = shortenLength or tonumber(settings.getValue("nametagCharLimit", 50))
    if not shorten or shortenLength > #playerName then
        return tostring(playerName)
    else
        return tostring(playerName):sub(1, shortenLength) .. "..."
    end
end

local lastShorten, lastShortenLength = false, 0
local function slowTick(ctxt)
    if M.state then
        local shorten, shortenLength = settings.getValue("shortenNametags", false),
            tonumber(settings.getValue("nametagCharLimit", 50))
        if shorten ~= lastShorten or (shorten and shortenLength ~= lastShortenLength) then
            Table(BJI.Managers.Context.Players):forEach(function(p)
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
