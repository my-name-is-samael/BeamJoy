local M = {
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
    return M.selfLobby and table.length(M.selfLobby.players) == 2
end

local function isChasing()
    if M.selfLobby then
        return not M.waitForSpread and not M.tagMessage
    end
    return false
end

local function isTagger()
    return M.selfLobby and M.selfLobby.players[BJI.Managers.Context.User.playerID].tagger
end

local function onVehicleResetted(gameVehID)
    if M.selfLobby.players[BJI.Managers.Context.User.playerID].gameVehID == gameVehID and
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
    local selfVehID = M.selfLobby.players[BJI.Managers.Context.User.playerID].gameVehID
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
    if M.waitForSpread then
        BJI.Managers.Message.realtimeDisplay("tagduo", "Spread Out !")
    end
end

local function slowTick(ctxt)
    if M.waitForSpread and not M.selfLobby.players[ctxt.user.playerID].ready then
        local vehPositions = table.map(M.selfLobby.players, function(p)
            local veh = BJI.Managers.Veh.getVehicleObject(p.gameVehID)
            return BJI.Managers.Veh.getPositionRotation(veh).pos
        end)
        if math.horizontalDistance(vehPositions[1], vehPositions[2]) > 5 then
            BJI.Tx.scenario.TagDuoUpdate(M.selfLobbyIndex, M.CLIENT_EVENTS.READY)
        end
    end
end

local function onDataUpdate(ctxt, newLobby)
    -- TODO checks for updates
    local tagger
    local previousReadyCount, readyCount = 0, 0
    if table.length(newLobby.players) == 2 then
        for _, p in pairs(M.selfLobby.players) do
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
        M.tagMessage = true

        -- cancel reset process
        if BJI.Managers.Restrictions.getCurrentResets():sort()
            :compare(Table():addAll(BJI.Managers.Restrictions.RESET.ALL):sort() or {}) then
            BJI.Managers.Message.cancelFlash("BJITagDuoTaggedReset")
            BJI.Managers.Veh.freeze(false, M.selfLobby.players[ctxt.user.playerID].gameVehID)
            BJI.Managers.Restrictions.updateResets(Table()
                :addAll(BJI.Managers.Restrictions.RESET.TELEPORT)
                :addAll(BJI.Managers.Restrictions.RESET.HEAVY_RELOAD))
        end

        -- flash
        BJI.Managers.Message.flash("BJITagDuoTagged", "TAGGED !", 3, true, ctxt.now, function()
            M.tagMessage = false
            M.waitForSpread = true
        end)
    elseif previousReadyCount < 2 and readyCount == 2 then -- START CHASE
        M.waitForSpread = false
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

    M.selfLobby = newLobby
end

local function rxData(ctxt, data)
    M.lobbies = data.lobbies

    local foundIndex
    for i, lobby in pairs(data.lobbies) do
        if lobby.players[ctxt.user.playerID] then
            foundIndex = i
            break
        end
    end
    M.selfLobbyIndex = foundIndex

    if not M.selfLobby then
        if foundIndex then
            M.selfLobbyIndex = foundIndex
            M.selfLobby = data.lobbies[foundIndex]
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

M.canChangeTo = canChangeTo
M.onLoad = onLoad

M.isLobbyFilled = isLobbyFilled
M.isTagger = isTagger

M.onVehicleResetted = onVehicleResetted
M.onVehicleSwitched = onVehicleSwitched
M.onVehicleDestroyed = onVehicleDestroyed

M.canRefuelAtStation = TrueFn
M.canRepairAtGarage = TrueFn
M.canSpawnNewVehicle = FalseFn
M.canReplaceVehicle = FalseFn
M.canDeleteVehicle = TrueFn
M.canDeleteOtherVehicles = FalseFn

M.getPlayerListActions = getPlayerListActions

M.renderTick = renderTick
M.slowTick = slowTick

M.rxData = rxData

M.onUnload = onUnload

return M
