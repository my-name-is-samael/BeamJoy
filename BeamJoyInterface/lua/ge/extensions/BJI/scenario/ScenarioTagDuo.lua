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

    waitForPlayers = true,
    waitForSpread = true,
    eventLock = false,
    minDistance = 4,
}

local function canChangeTo(ctxt)
    return BJI.Managers.Scenario.isFreeroam() and
        ctxt.isOwner and
        not BJI.Managers.Veh.isUnicycle(ctxt.veh:getID())
end

local function onLoad(ctxt)
    BJI.Windows.VehSelector.tryClose()
    BJI.Managers.Restrictions.update({ {
        restrictions = Table({
            BJI.Managers.Restrictions.RESET.TELEPORT,
            BJI.Managers.Restrictions.RESET.HEAVY_RELOAD,
            BJI.Managers.Restrictions.OTHER.BIG_MAP,
            BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
            BJI.Managers.Restrictions.OTHER.FREE_CAM,
            BJI.Managers.Restrictions.OTHER.PHOTO_MODE,
        }):flat(),
        state = BJI.Managers.Restrictions.STATE.RESTRICTED,
    } })
    BJI.Managers.RaceWaypoint.resetAll()
    BJI.Managers.WaypointEdit.reset()
    BJI.Managers.GPS.reset()
    BJI.Managers.Cam.addRestrictedCamera(BJI.Managers.Cam.CAMERAS.BIG_MAP)
    BJI.Managers.Cam.addRestrictedCamera(BJI.Managers.Cam.CAMERAS.FREE)
end

local function onUnload(ctxt)
    BJI.Managers.Message.cancelFlash("BJITagDuoTaggedReset")
    BJI.Managers.Message.stopRealtimeDisplay()

    BJI.Managers.Restrictions.update({ {
        restrictions = Table({
            BJI.Managers.Restrictions.RESET.TELEPORT,
            BJI.Managers.Restrictions.RESET.HEAVY_RELOAD,
            BJI.Managers.Restrictions.OTHER.BIG_MAP,
            BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
            BJI.Managers.Restrictions.OTHER.FREE_CAM,
            BJI.Managers.Restrictions.OTHER.PHOTO_MODE,
        }):flat(),
        state = BJI.Managers.Restrictions.STATE.ALLOWED,
    } })
    BJI.Managers.Cam.removeRestrictedCamera(BJI.Managers.Cam.CAMERAS.BIG_MAP)
    BJI.Managers.Cam.removeRestrictedCamera(BJI.Managers.Cam.CAMERAS.FREE)
    BJI.Managers.GPS.reset()
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
    return S.selfLobby ~= nil and S.selfLobby.players[BJI.Managers.Context.User.playerID].tagger
end

local function onVehicleResetted(gameVehID)
    if S.selfLobby.players[BJI.Managers.Context.User.playerID].gameVehID == gameVehID and
        isChasing() and
        not isTagger() then
        BJI.Managers.Veh.freeze(true, gameVehID)
        BJI.Managers.Restrictions.updateResets(BJI.Managers.Restrictions.RESET.ALL)
        BJI.Managers.Message.flashCountdown("BJITagDuoTaggedReset", GetCurrentTimeMillis() + 5100, false, "FLEE !", nil,
            function()
                BJI.Managers.Veh.freeze(false, gameVehID)
                BJI.Managers.Restrictions.updateResets(Table()
                    :addAll(BJI.Managers.Restrictions.RESET.TELEPORT)
                    :addAll(BJI.Managers.Restrictions.RESET.HEAVY_RELOAD))
            end, false)
    end
end

local function onVehicleSwitched(oldGameVehID, newGameVehID)
    local selfVehID = S.selfLobby.players[BJI.Managers.Context.User.playerID].gameVehID
    if oldGameVehID == selfVehID or newGameVehID ~= selfVehID then
        BJI.Managers.Veh.focusVehicle(selfVehID)
    end
end

local function onVehicleDestroyed(gameVehID)
    BJI.Tx.scenario.TagDuoLeave()
end

---@param vehData BJIMPVehicle
---@return boolean, BJIColor?, BJIColor?
local function doShowNametag(vehData)
    if not S.waitForPlayers and
        BJI.Managers.Context.User.playerID ~= vehData.ownerID and
        S.selfLobby.players[vehData.ownerID] then
        return true, BJI.Utils.ShapeDrawer.Color(0, 0, 0, 1), BJI.Utils.ShapeDrawer.Color(1, .33, .33, .5)
    end
    return true
end

local function getPlayerListActions(player, ctxt)
    local actions = {}

    if BJI.Managers.Votes.Kick.canStartVote(player.playerID) then
        table.insert(actions, {
            id = string.var("voteKick{1}", { player.playerID }),
            icon = BJI.Utils.Icon.ICONS.event_busy,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            tooltip = BJI.Managers.Lang.get("playersBlock.buttons.voteKick"),
            onClick = function()
                BJI.Managers.Votes.Kick.start(player.playerID)
            end
        })
    end

    return actions
end

---@param ctxt TickContext
local function drawUI(ctxt)
    if not S.selfLobby then
        return
    end

    local other
    if not S.waitForPlayers then
        other = BJI.Managers.Context.Players
            [S.selfLobby.players:keys():find(function(p) return p ~= ctxt.user.playerID end)]
    end
    LineBuilder():btnIcon({
        id = "leaveTagDuo",
        icon = BJI.Utils.Icon.ICONS.exit_to_app,
        style = BJI.Utils.Style.BTN_PRESETS.ERROR,
        tooltip = BJI.Managers.Lang.get("menu.scenario.tagDuo.leave"),
        onClick = function()
            BJI.Tx.scenario.TagDuoLeave()
        end
    }):text(string.var(BJI.Managers.Lang.get("tagduo.title"),
            {
                playerName = S.selfLobby.host == ctxt.user.playerID and
                    ctxt.user.playerName or other.playerName
            }),
        S.selfLobby.host == ctxt.user.playerID and
        BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or nil):build()

    if S.waitForPlayers then
        LineLabel(BJI.Managers.Lang.get("tagduo.flashWaitingForPlayer"))
    elseif S.waitForSpread then
        LineLabel(BJI.Managers.Lang.get("tagduo.flashWaitForSpread"))
    elseif S.selfLobby.players[ctxt.user.playerID].tagger then
        LineLabel(BJI.Managers.Lang.get("tagduo.flashChase"))
    else
        LineLabel(BJI.Managers.Lang.get("tagduo.flashFlee"))
    end

    local taggerMark = string.var("({1})", { BJI.Managers.Lang.get("tagduo.taggerMark") })
    ColumnsBuilder("BJITagDuoUI", { -1, -1 }):addRow({
        cells = {
            function()
                local line = LineBuilder():text(ctxt.user.playerName,
                    BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT)
                if S.selfLobby.players[ctxt.user.playerID].tagger then
                    line:text(taggerMark, BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT)
                end
                line:build()
            end,
            other and function()
                local line = LineBuilder():text(other.playerName)
                if S.selfLobby.players[other.playerID].tagger then
                    line:text(taggerMark, BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT)
                end
                line:build()
            end or nil,
        }
    }):build()
end

local function getVehsDistance()
    if S.waitForPlayers or #S.playerVehs < 2 then
        return -1
    end
    return S.playerVehs:map(function(v)
        return BJI.Managers.Veh.getPositionRotation(v).pos
    end):reduce(function(res, pos)
        if not res then
            return pos
        else
            return math.horizontalDistance(res, pos)
        end
    end)
end

local function renderTick(ctxt)
    if S.waitForPlayers then
        BJI.Managers.Message.realtimeDisplay("tagduo", BJI.Managers.Lang.get("tagduo.flashWaitingForPlayer"))
    elseif S.waitForSpread then
        BJI.Managers.Message.realtimeDisplay("tagduo", BJI.Managers.Lang.get("tagduo.flashWaitForSpread"))
    else
        if BJI.Managers.Message.realtimeData.context then
            BJI.Managers.Message.stopRealtimeDisplay()
        end

        -- check tag distance
        if not S.eventLock and S.selfLobby.players[ctxt.user.playerID].tagger and getVehsDistance() < S.minDistance then
            S.eventLock = true
            BJI.Managers.GPS.removeByKey(BJI.Managers.GPS.KEYS.PLAYER)
            BJI.Tx.scenario.TagDuoUpdate(S.selfLobbyIndex, S.CLIENT_EVENTS.TAG)
            local timeout = ctxt.now + 5000
            BJI.Managers.Async.task(function(ctxt2)
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
        BJI.Tx.scenario.TagDuoUpdate(S.selfLobbyIndex, S.CLIENT_EVENTS.READY)
        local timeout = ctxt.now + 5000
        BJI.Managers.Async.task(function(ctxt2)
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
        if BJI.Managers.Restrictions.getState(BJI.Managers.Restrictions.RESET.ALL) then
            BJI.Managers.Message.cancelFlash("BJITagDuoTaggedReset")
            BJI.Managers.Veh.freeze(false, S.selfLobby.players[ctxt.user.playerID].gameVehID)
            BJI.Managers.Restrictions.updateResets(Table()
                :addAll(BJI.Managers.Restrictions.RESET.TELEPORT)
                :addAll(BJI.Managers.Restrictions.RESET.HEAVY_RELOAD))
        end

        BJI.Managers.Message.flash("BJITagDuoTagged", BJI.Managers.Lang.get("tagduo.flashTag"), 3)
    elseif previousReadyCount < 2 and readyCount == 2 then -- START CHASE
        BJI.Managers.Message.stopRealtimeDisplay()
        local msg
        if tagger == ctxt.user.playerID then
            msg = BJI.Managers.Lang.get("tagduo.flashChase")
        else
            msg = BJI.Managers.Lang.get("tagduo.flashFlee")
        end
        BJI.Managers.Message.flash("BJITagDuoStartChase", msg, 3, false, ctxt.now)
        if newLobby.players[ctxt.user.playerID].tagger then
            Table(newLobby.players):find(function(_, pid) return pid ~= ctxt.user.playerID end, function(_, pid)
                local other = BJI.Managers.Context.Players[pid]
                if other then
                    BJI.Managers.GPS.prependWaypoint(BJI.Managers.GPS.KEYS.PLAYER, nil, 0, nil,
                        other.playerName, false)
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
            return BJI.Managers.Veh.getVehicleObject(p.gameVehID)
        end):values()
    end

    S.minDistance = math.round(
        Table(newLobby.players):map(function(p)
            local veh = BJI.Managers.Veh.getVehicleObject(p.gameVehID)
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
    local ctxt = BJI.Managers.Tick.getContext()
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
                BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.TAG_DUO, ctxt)
            else
                onDataUpdate(ctxt, l)
            end
        end) and S.selfLobby then
        S.selfLobbyIndex = nil
        S.selfLobby = nil
        BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.FREEROAM, ctxt)
    end

    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)
end

S.canChangeTo = canChangeTo
S.onLoad = onLoad
S.onUnload = onUnload

S.isLobbyFilled = isLobbyFilled
S.isTagger = isTagger

S.onVehicleResetted = onVehicleResetted
S.onVehicleSwitched = onVehicleSwitched
S.onVehicleDestroyed = onVehicleDestroyed

S.canRefuelAtStation = TrueFn

S.canRepairAtGarage = FalseFn
S.canDeleteVehicle = FalseFn
S.canSpawnNewVehicle = FalseFn
S.canReplaceVehicle = FalseFn
S.canPaintVehicle = FalseFn
S.canDeleteOtherVehicles = FalseFn
S.doShowNametagsSpecs = FalseFn

S.doShowNametag = doShowNametag
S.getPlayerListActions = getPlayerListActions

S.drawUI = drawUI

S.renderTick = renderTick
S.fastTick = fastTick

S.rxData = rxData

return S
