---@class BJIScenarioTagDuo : BJIScenario
local S = {
    _name = "TagDuo",
    _key = "TAG_DUO",
    _isSolo = false,

    CLIENT_EVENTS = {
        READY = "ready",
        TAG = "tag",
    },
    ---@type BJTagDuoLobby[]
    lobbies = {},

    ---@type BJTagDuoLobby?
    selfLobby = nil,
    selfLobbyIndex = nil,

    playerVehs = Table(),

    resetLock = false,
    waitForPlayers = true,
    waitForSpread = true,
    eventLock = false,
    minDistance = 4,
}
--- gc prevention
local other, taggerMark, actions

---@param ctxt TickContext
---@return boolean
local function canChangeTo(ctxt)
    return BJI_Scenario.isFreeroam() and
        ctxt.isOwner and
        not BJI_Veh.isUnicycle(ctxt.veh.gameVehicleID)
end

---@param ctxt TickContext
local function onLoad(ctxt)
    S.resetLock = false
    BJI_Win_VehSelector.tryClose()
    BJI_RaceWaypoint.resetAll()
    BJI_WaypointEdit.reset()
    BJI_GPS.reset()
    BJI_Cam.addRestrictedCamera(BJI_Cam.CAMERAS.BIG_MAP)
    BJI_Cam.addRestrictedCamera(BJI_Cam.CAMERAS.FREE)
end

---@param ctxt TickContext
local function onUnload(ctxt)
    BJI_Message.cancelFlash("BJITagDuoTaggedReset")
    BJI_Message.stopRealtimeDisplay()
    S.playerVehs = Table()

    BJI_Cam.removeRestrictedCamera(BJI_Cam.CAMERAS.BIG_MAP)
    BJI_Cam.removeRestrictedCamera(BJI_Cam.CAMERAS.FREE)
    BJI_GPS.reset()
end

---@param ctxt TickContext
---@return string[]
local function getRestrictions(ctxt)
    return Table():addAll(BJI_Restrictions.OTHER.VEHICLE_SWITCH, true)
        :addAll(BJI_Restrictions.OTHER.BIG_MAP, true)
        :addAll(BJI_Restrictions.OTHER.FREE_CAM, true)
        :addAll(BJI_Restrictions.OTHER.PHOTO_MODE, true)
        :addAll(BJI_Restrictions.OTHER.FUN_STUFF, true)
end

---@return boolean
local function isLobbyFilled()
    return S.selfLobby ~= nil and not S.waitForPlayers
end

---@return boolean
local function isChasing()
    return S.selfLobby ~= nil and not S.waitForPlayers and not S.waitForSpread
end

---@return boolean
local function isTagger()
    return S.selfLobby ~= nil and S.selfLobby.players[BJI_Context.User.playerID].tagger
end

local function onVehicleResetted(gameVehID)
    if S.selfLobby.players[BJI_Context.User.playerID].gameVehID == gameVehID and isChasing() and not isTagger() then
        BJI_Veh.freeze(true, gameVehID)
        S.resetLock = true
        BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_UPDATED)
        BJI_Message.flashCountdown("BJITagDuoTaggedReset", GetCurrentTimeMillis() + 5100, false, "FLEE !", nil,
            function()
                BJI_Veh.freeze(false, gameVehID)
                S.resetLock = false
                BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_UPDATED)
            end, false)
    end
end

local function onVehicleDestroyed(gameVehID)
    if S.selfLobby and S.selfLobby.players[BJI_Context.User.playerID].gameVehID == gameVehID then
        BJI_Tx_scenario.TagDuoLeave()
    end
end

---@param vehData BJIMPVehicle
---@return boolean, BJIColor?, BJIColor?
local function doShowNametag(vehData)
    if not S.waitForPlayers and
        BJI_Context.User.playerID ~= vehData.ownerID and
        S.selfLobby.players[vehData.ownerID] then
        return true, BJI.Utils.ShapeDrawer.Color(0, 0, 0, 1), BJI.Utils.ShapeDrawer.Color(1, .33, .33, .5)
    end
    return true
end

local function getPlayerListActions(player, ctxt)
    actions = {}

    if BJI_Votes.Kick.canStartVote(player.playerID) then
        BJI.Utils.UI.AddPlayerActionVoteKick(actions, player.playerID)
    end

    return actions
end

---@param ctxt TickContext
local function drawUI(ctxt)
    if not S.selfLobby then
        return
    end

    other = not S.waitForPlayers and ctxt.players
        [S.selfLobby.players:keys():find(function(p) return p ~= ctxt.user.playerID end)] or nil

    if IconButton("leaveTagDuo", BJI.Utils.Icon.ICONS.exit_to_app,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
        BJI_Tx_scenario.TagDuoLeave()
    end
    TooltipText(BJI_Lang.get("menu.scenario.tagduo.leave"))
    SameLine()
    Text(string.var(BJI_Lang.get("tagduo.title"),
            { playerName = ctxt.players[S.selfLobby.host].playerName }),
        {
            color = S.selfLobby.host == ctxt.user.playerID and
                BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or nil
        })

    if S.waitForPlayers then
        Text(BJI_Lang.get("tagduo.flashWaitingForPlayer"))
    elseif S.waitForSpread then
        Text(BJI_Lang.get("tagduo.flashWaitForSpread"))
    elseif S.selfLobby.players[ctxt.user.playerID].tagger then
        Text(BJI_Lang.get("tagduo.flashChase"))
    else
        Text(BJI_Lang.get("tagduo.flashFlee"))
    end

    taggerMark = string.var("({1})", { BJI_Lang.get("tagduo.taggerMark") })
    Text(ctxt.user.playerName, { color = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT })
    if S.selfLobby.players[ctxt.user.playerID].tagger then
        SameLine()
        Text(taggerMark, { color = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT })
    end
    if other then
        SameLine()
        SetCursorPosX(GetWindowSize().x / 2)
        Text(other.playerName)
        if S.selfLobby.players[other.playerID].tagger then
            SameLine()
            Text(taggerMark, BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT)
        end
    end
end

local function getVehsDistance()
    if S.waitForPlayers or #S.playerVehs < 2 then
        return -1
    end
    local vehsPos = S.playerVehs:map(function(v)
        return BJI_Veh.getPositionRotation(v)
    end):values()
    if #vehsPos < 2 then
        error("Invalid vehicles")
    end
    return math.horizontalDistance(vehsPos[1], vehsPos[2])
end

local function renderTick(ctxt)
    if S.waitForPlayers then
        BJI_Message.realtimeDisplay("tagduo", BJI_Lang.get("tagduo.flashWaitingForPlayer"))
    elseif S.waitForSpread then
        BJI_Message.realtimeDisplay("tagduo", BJI_Lang.get("tagduo.flashWaitForSpread"))
    else
        if BJI_Message.realtimeData.context then
            BJI_Message.stopRealtimeDisplay()
        end

        -- check tag distance
        if not S.eventLock and S.selfLobby.players[ctxt.user.playerID].tagger and getVehsDistance() < S.minDistance then
            S.eventLock = true
            BJI_GPS.removeByKey(BJI_GPS.KEYS.PLAYER)
            BJI_Tx_scenario.TagDuoUpdate(S.selfLobbyIndex, S.CLIENT_EVENTS.TAG)
            local timeout = ctxt.now + 5000
            BJI_Async.task(function(ctxt2)
                return ctxt2.now >= timeout or (S.selfLobby ~= nil and not S.selfLobby.players[ctxt.user.playerID].ready)
            end, function()
                S.eventLock = false
            end, "BJITagDuoTagLock")
        end
    end
end

local function fastTick(ctxt)
    if not S.eventLock and not S.waitForPlayers and S.waitForSpread and
        not S.selfLobby.players[ctxt.user.playerID].ready and getVehsDistance() >= S.minDistance * 10 then
        S.eventLock = true
        BJI_Tx_scenario.TagDuoUpdate(S.selfLobbyIndex, S.CLIENT_EVENTS.READY)
        local timeout = ctxt.now + 5000
        BJI_Async.task(function(ctxt2)
            return ctxt2.now >= timeout or (S.selfLobby ~= nil and S.selfLobby.players[ctxt.user.playerID].ready)
        end, function()
            S.eventLock = false
        end, "BJITagDuoReadyLock")
    end
end

---@param ctxt TickContext
---@param newLobby BJTagDuoLobby
local function onDataUpdate(ctxt, newLobby)
    local tagger
    local previousReadyCount, readyCount = 0, 0
    if not S.waitForPlayers then
        for _, p in pairs(S.selfLobby.players) do
            if p.ready then
                previousReadyCount = previousReadyCount + 1
            end
        end
        for pid, p in pairs(newLobby.players) do
            if p.tagger then
                tagger = pid
            end
            if p.ready then
                readyCount = readyCount + 1
            end
        end
    end

    if previousReadyCount == 2 and readyCount < 2 then -- TAG or LEFT
        -- cancel reset process
        BJI_Message.cancelFlash("BJITagDuoTaggedReset")
        BJI_Veh.freeze(false, S.selfLobby.players[ctxt.user.playerID].gameVehID)

        BJI_Message.flash("BJITagDuoTagged", BJI_Lang.get("tagduo.flashTag"), 3)
    elseif previousReadyCount < 2 and readyCount == 2 then -- START CHASE
        BJI_Message.stopRealtimeDisplay()
        local msg
        if tagger == ctxt.user.playerID then
            msg = BJI_Lang.get("tagduo.flashChase")
        else
            msg = BJI_Lang.get("tagduo.flashFlee")
        end
        BJI_Message.flash("BJITagDuoStartChase", msg, 3, false, ctxt.now)
        if newLobby.players[ctxt.user.playerID].tagger then
            Table(newLobby.players):find(function(_, pid) return pid ~= ctxt.user.playerID end, function(_, pid)
                if ctxt.players[pid] then
                    BJI_GPS.prependWaypoint({
                        key = BJI_GPS.KEYS.PLAYER,
                        radius = 0,
                        playerName = ctxt.players[pid].playerName,
                        clearable = false
                    })
                end
            end)
        end
    end

    S.selfLobby = newLobby
end

---@param newLobby BJTagDuoLobby
local function initVehsAndMinDistance(newLobby)
    if S.waitForPlayers then
        return
    end

    if S.playerVehs:length() < 2 then
        S.playerVehs = Table(newLobby.players):map(function(p)
            return BJI_Veh.getVehicleObject(p.gameVehID)
        end):values()
    end

    S.minDistance = math.round(
        Table(newLobby.players):map(function(p)
            local veh = BJI_Veh.getVehicleObject(p.gameVehID)
            if not veh then
                return 2
            end
            return math.sqrt((veh:getInitialLength() / 2) ^ 2 + (veh:getInitialWidth() / 2) ^ 2)
        end):reduce(function(res, diag)
            return res + diag
        end, 0), 1
    )
end

---@param data {lobbies: BJTagDuoLobby[]}
local function rxData(data)
    local ctxt = BJI_Tick.getContext()
    S.lobbies = data.lobbies

    if not Table(data.lobbies):find(function(l) return l.players[ctxt.user.playerID] end, function(l, foundIndex)
            S.selfLobbyIndex = foundIndex

            local previousPlayersCount = not S.selfLobby and 0 or table.length(S.selfLobby.players)
            S.waitForPlayers = table.length(l.players) < 2
            S.waitForSpread = #Table(l.players):filter(function(p) return p.ready end):values() < 2

            -- init min distance for tag
            if not S.waitForPlayers and previousPlayersCount < 2 then
                -- player joined
                initVehsAndMinDistance(l)
            elseif S.waitForPlayers then
                -- lobby not filled
                S.playerVehs = Table()
            end

            if not S.selfLobby then
                S.selfLobby = l
                BJI_Scenario.switchScenario(BJI_Scenario.TYPES.TAG_DUO, ctxt)
            else
                onDataUpdate(ctxt, l)
            end
        end) and S.selfLobby then
        S.selfLobbyIndex = nil
        S.selfLobby = nil
        BJI_Scenario.switchScenario(BJI_Scenario.TYPES.FREEROAM, ctxt)
    end

    BJI_Events.trigger(BJI_Events.EVENTS.SCENARIO_UPDATED)
end

S.canChangeTo = canChangeTo
S.onLoad = onLoad
S.onUnload = onUnload

S.getRestrictions = getRestrictions

S.isLobbyFilled = isLobbyFilled
S.isTagger = isTagger

S.onVehicleResetted = onVehicleResetted
S.onVehicleDestroyed = onVehicleDestroyed

S.canRefuelAtStation = TrueFn
S.canRepairAtGarage = TrueFn
S.canRecoverVehicle = TrueFn
S.canSpawnAI = TrueFn

S.canDeleteVehicle = FalseFn
S.canSpawnNewVehicle = FalseFn
S.canReplaceVehicle = FalseFn
S.canPaintVehicle = FalseFn
S.doShowNametagsSpecs = FalseFn

S.doShowNametag = doShowNametag
S.getPlayerListActions = getPlayerListActions

S.drawUI = drawUI

S.renderTick = renderTick
S.fastTick = fastTick

S.rxData = rxData

return S
