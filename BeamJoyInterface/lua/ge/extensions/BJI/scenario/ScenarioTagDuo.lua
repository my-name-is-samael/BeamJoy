local S = {
    CLIENT_EVENTS = {
        READY = "ready",
        TOUCH = "touch",
    },
    lobbies = {},

    selfLobby = nil,
    selfLobbyIndex = nil,

    tagMessage = false,
    waitForSpread = true,
}

local function canChangeTo(ctxt)
    return ctxt.isOwner and BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.FREEROAM)
end

local function onLoad(ctxt)
    BJI.Windows.VehSelector.tryClose()
    BJI.Managers.Restrictions.update({ {
        restrictions = Table({
            BJI.Managers.Restrictions.RESET.TELEPORT,
            BJI.Managers.Restrictions.RESET.HEAVY_RELOAD,
            BJI.Managers.Restrictions.OTHER.AI_CONTROL,
            BJI.Managers.Restrictions.OTHER.VEHICLE_SELECTOR,
            BJI.Managers.Restrictions.OTHER.VEHICLE_PARTS_SELECTOR,
            BJI.Managers.Restrictions.OTHER.VEHICLE_DEBUG,
            BJI.Managers.Restrictions.OTHER.WALKING,
            BJI.Managers.Restrictions.OTHER.BIG_MAP,
            BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
            BJI.Managers.Restrictions.OTHER.FREE_CAM,
        }):flat(),
        state = BJI.Managers.Restrictions.STATE.RESTRICTED,
    } })
    BJI.Managers.Bigmap.toggleQuickTravel(false)
    BJI.Managers.RaceWaypoint.resetAll()
    BJI.Managers.WaypointEdit.reset()
    BJI.Managers.GPS.reset()
    BJI.Managers.Cam.addRestrictedCamera(BJI.Managers.Cam.CAMERAS.BIG_MAP)
    BJI.Managers.Cam.addRestrictedCamera(BJI.Managers.Cam.CAMERAS.FREE)
end

local function isLobbyFilled()
    return S.selfLobby and table.length(S.selfLobby.players) == 2
end

local function isChasing()
    if S.selfLobby then
        return not S.waitForSpread and not S.tagMessage
    end
    return false
end

local function isTagger()
    return S.selfLobby and S.selfLobby.players[BJI.Managers.Context.User.playerID].tagger
end

local function onVehicleResetted(gameVehID)
    if S.selfLobby.players[BJI.Managers.Context.User.playerID].gameVehID == gameVehID and
        isChasing() and
        not isTagger() then
        BJI.Managers.Veh.freeze(true, gameVehID)
        BJI.Managers.Restrictions.updateResets(BJI.Managers.Restrictions.RESET.ALL)
        BJI.Managers.Message.flashCountdown("BJITagDuoTaggedReset", GetCurrentTimeMillis() + 5100, true, "FLEE !", nil, function()
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

local function getPlayerListActions(player, ctxt)
    local actions = {}

    if BJI.Managers.Votes.Kick.canStartVote(player.playerID) then
        table.insert(actions, {
            id = string.var("voteKick{1}", { player.playerID }),
            label = BJI.Managers.Lang.get("playersBlock.buttons.voteKick"),
            onClick = function()
                BJI.Managers.Votes.Kick.start(player.playerID)
            end
        })
    end

    return actions
end

local function renderTick(ctxt)
    if S.waitForSpread then
        BJI.Managers.Message.realtimeDisplay("tagduo", "Spread Out !")
    end
end

local function slowTick(ctxt)
    if S.waitForSpread and not S.selfLobby.players[ctxt.user.playerID].ready then
        local vehPositions = table.map(S.selfLobby.players, function(p)
            local veh = BJI.Managers.Veh.getVehicleObject(p.gameVehID)
            return BJI.Managers.Veh.getPositionRotation(veh).pos
        end)
        if math.horizontalDistance(vehPositions[1], vehPositions[2]) > 5 then
            BJI.Tx.scenario.TagDuoUpdate(S.selfLobbyIndex, S.CLIENT_EVENTS.READY)
        end
    end
end

local function onDataUpdate(ctxt, newLobby)
    -- TODO checks for updates
    local tagger
    local previousReadyCount, readyCount = 0, 0
    if table.length(newLobby.players) == 2 then
        for _, p in pairs(S.selfLobby.players) do
            if p.ready then
                previousReadyCount = previousReadyCount + 1
            end
        end
        for _, p in pairs(newLobby.players) do
            if p.tagger then
                tagger = p.playerID
            end
            if p.ready then
                readyCount = readyCount + 1
            end
        end
    end

    if previousReadyCount == 2 and readyCount < 2 then -- TAG
        BJI.Managers.GPS.removeByKey(BJI.Managers.GPS.KEYS.TAGGED)
        S.tagMessage = true

        -- cancel reset process
        if BJI.Managers.Restrictions.getCurrentResets():sort()
            :compare(Table():addAll(BJI.Managers.Restrictions.RESET.ALL):sort() or {}) then
            BJI.Managers.Message.cancelFlash("BJITagDuoTaggedReset")
            BJI.Managers.Veh.freeze(false, S.selfLobby.players[ctxt.user.playerID].gameVehID)
            BJI.Managers.Restrictions.updateResets(Table()
                :addAll(BJI.Managers.Restrictions.RESET.TELEPORT)
                :addAll(BJI.Managers.Restrictions.RESET.HEAVY_RELOAD))
        end

        -- flash
        BJI.Managers.Message.flash("BJITagDuoTagged", "TAGGED !", 3, true, ctxt.now, function()
            S.tagMessage = false
            S.waitForSpread = true
        end)
    elseif previousReadyCount < 2 and readyCount == 2 then -- START CHASE
        S.waitForSpread = false
        BJI.Managers.Message.stopRealtimeDisplay()
        local msg = "FLEE !"
        if tagger == ctxt.user.playerID then
            msg = "CHASE !"
        end
        BJI.Managers.Message.flash("BJITagDuoStartChase", msg, 3, true, ctxt.now)
        local other
        for _, p in pairs(newLobby.players) do
            if p.playerID ~= ctxt.user.playerID then
                other = p
                break
            end
        end
        BJI.Managers.GPS.prependWaypoint(BJI.Managers.GPS.KEYS.TAGGED, nil, 2, function()
        end, other.playerName, false)
    end

    S.selfLobby = newLobby
end

local function rxData(ctxt, data)
    S.lobbies = data.lobbies

    local foundIndex
    for i, lobby in pairs(data.lobbies) do
        if lobby.players[ctxt.user.playerID] then
            foundIndex = i
            break
        end
    end
    S.selfLobbyIndex = foundIndex

    if not S.selfLobby then
        if foundIndex then
            S.selfLobbyIndex = foundIndex
            S.selfLobby = data.lobbies[foundIndex]
            BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.TAG_DUO, ctxt)
        end
    else
        if not foundIndex then
            BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.FREEROAM, ctxt)
        else
            onDataUpdate(ctxt, data.lobbies[foundIndex])
        end
    end
end

local function onUnload(ctxt)
    BJI.Managers.Message.cancelFlash("BJITagDuoTaggedReset")
    BJI.Managers.Message.stopRealtimeDisplay()

    BJI.Managers.Restrictions.update({ {
        restrictions = Table({
            BJI.Managers.Restrictions.RESET.TELEPORT,
            BJI.Managers.Restrictions.RESET.HEAVY_RELOAD,
            BJI.Managers.Restrictions.OTHER.AI_CONTROL,
            BJI.Managers.Restrictions.OTHER.VEHICLE_SELECTOR,
            BJI.Managers.Restrictions.OTHER.VEHICLE_PARTS_SELECTOR,
            BJI.Managers.Restrictions.OTHER.VEHICLE_DEBUG,
            BJI.Managers.Restrictions.OTHER.WALKING,
            BJI.Managers.Restrictions.OTHER.BIG_MAP,
            BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
            BJI.Managers.Restrictions.OTHER.FREE_CAM,
        }):flat(),
        state = BJI.Managers.Restrictions.STATE.ALLOWED,
    } })
    BJI.Managers.Cam.removeRestrictedCamera(BJI.Managers.Cam.CAMERAS.BIG_MAP)
    BJI.Managers.Cam.removeRestrictedCamera(BJI.Managers.Cam.CAMERAS.FREE)
    BJI.Managers.GPS.reset()
    BJI.Managers.Bigmap.toggleQuickTravel(true)
end

S.canChangeTo = canChangeTo
S.onLoad = onLoad

S.isLobbyFilled = isLobbyFilled
S.isTagger = isTagger

S.onVehicleResetted = onVehicleResetted
S.onVehicleSwitched = onVehicleSwitched
S.onVehicleDestroyed = onVehicleDestroyed

S.canRefuelAtStation = TrueFn
S.canRepairAtGarage = TrueFn
S.canSpawnNewVehicle = FalseFn
S.canReplaceVehicle = FalseFn
S.canDeleteVehicle = TrueFn
S.canDeleteOtherVehicles = FalseFn

S.getPlayerListActions = getPlayerListActions

S.renderTick = renderTick
S.slowTick = slowTick

S.rxData = rxData

S.onUnload = onUnload

return S
