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
    return ctxt.isOwner and BJIScenario.is(BJIScenario.TYPES.FREEROAM)
end

local function onLoad(ctxt)
    BJIVehSelector.tryClose()
    BJIRestrictions.update({ {
        restrictions = Table({
            BJIRestrictions.RESET.TELEPORT,
            BJIRestrictions.RESET.HEAVY_RELOAD,
            BJIRestrictions.OTHER.AI_CONTROL,
            BJIRestrictions.OTHER.VEHICLE_SELECTOR,
            BJIRestrictions.OTHER.VEHICLE_PARTS_SELECTOR,
            BJIRestrictions.OTHER.VEHICLE_DEBUG,
            BJIRestrictions.OTHER.WALKING,
            BJIRestrictions.OTHER.BIG_MAP,
            BJIRestrictions.OTHER.VEHICLE_SWITCH,
            BJIRestrictions.OTHER.FREE_CAM,
        }):flat(),
        state = BJIRestrictions.STATE.RESTRICTED,
    } })
    BJIBigmap.toggleQuickTravel(false)
    BJIRaceWaypoint.resetAll()
    BJIWaypointEdit.reset()
    BJIGPS.reset()
    BJICam.addRestrictedCamera(BJICam.CAMERAS.BIG_MAP)
    BJICam.addRestrictedCamera(BJICam.CAMERAS.FREE)
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
    return M.selfLobby and M.selfLobby.players[BJIContext.User.playerID].tagger
end

local function onVehicleResetted(gameVehID)
    if M.selfLobby.players[BJIContext.User.playerID].gameVehID == gameVehID and
        isChasing() and
        not isTagger() then
        BJIVeh.freeze(true, gameVehID)
        BJIRestrictions.updateResets(BJIRestrictions.RESET.ALL)
        BJIMessage.flashCountdown("BJITagDuoTaggedReset", GetCurrentTimeMillis() + 5100, true, "FLEE !", nil, function()
            BJIVeh.freeze(false, gameVehID)
            BJIRestrictions.updateResets(Table()
                :addAll(BJIRestrictions.RESET.TELEPORT)
                :addAll(BJIRestrictions.RESET.HEAVY_RELOAD))
        end, false)
    end
end

local function onVehicleSwitched(oldGameVehID, newGameVehID)
    local selfVehID = M.selfLobby.players[BJIContext.User.playerID].gameVehID
    if oldGameVehID == selfVehID or newGameVehID ~= selfVehID then
        BJIVeh.focusVehicle(selfVehID)
    end
end

local function onVehicleDestroyed(gameVehID)
    BJITx.scenario.TagDuoLeave()
end

local function getPlayerListActions(player, ctxt)
    local actions = {}

    if BJIVote.Kick.canStartVote(player.playerID) then
        table.insert(actions, {
            id = string.var("voteKick{1}", { player.playerID }),
            label = BJILang.get("playersBlock.buttons.voteKick"),
            onClick = function()
                BJIVote.Kick.start(player.playerID)
            end
        })
    end

    return actions
end

local function renderTick(ctxt)
    if M.waitForSpread then
        BJIMessage.realtimeDisplay("tagduo", "Spread Out !")
    end
end

local function slowTick(ctxt)
    if M.waitForSpread and not M.selfLobby.players[ctxt.user.playerID].ready then
        local vehPositions = table.map(M.selfLobby.players, function(p)
            local veh = BJIVeh.getVehicleObject(p.gameVehID)
            return BJIVeh.getPositionRotation(veh).pos
        end)
        if GetHorizontalDistance(vehPositions[1], vehPositions[2]) > 5 then
            BJITx.scenario.TagDuoUpdate(M.selfLobbyIndex, M.CLIENT_EVENTS.READY)
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
        BJIGPS.removeByKey(BJIGPS.KEYS.TAGGED)
        M.tagMessage = true

        -- cancel reset process
        if BJIRestrictions.getCurrentResets():sort()
            :compare(Table():addAll(BJIRestrictions.RESET.ALL):sort() or {}) then
            BJIMessage.cancelFlash("BJITagDuoTaggedReset")
            BJIVeh.freeze(false, M.selfLobby.players[ctxt.user.playerID].gameVehID)
            BJIRestrictions.updateResets(Table()
                :addAll(BJIRestrictions.RESET.TELEPORT)
                :addAll(BJIRestrictions.RESET.HEAVY_RELOAD))
        end

        -- flash
        BJIMessage.flash("BJITagDuoTagged", "TAGGED !", 3, true, ctxt.now, function()
            M.tagMessage = false
            M.waitForSpread = true
        end)
    elseif previousReadyCount < 2 and readyCount == 2 then -- START CHASE
        M.waitForSpread = false
        BJIMessage.stopRealtimeDisplay()
        local msg = "FLEE !"
        if tagger == ctxt.user.playerID then
            msg = "CHASE !"
        end
        BJIMessage.flash("BJITagDuoStartChase", msg, 3, true, ctxt.now)
        local other
        for _, p in pairs(newLobby.players) do
            if p.playerID ~= ctxt.user.playerID then
                other = p
                break
            end
        end
        BJIGPS.prependWaypoint(BJIGPS.KEYS.TAGGED, nil, 2, function()
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
            BJIScenario.switchScenario(BJIScenario.TYPES.TAG_DUO, ctxt)
        end
    else
        if not foundIndex then
            BJIScenario.switchScenario(BJIScenario.TYPES.FREEROAM, ctxt)
        else
            onDataUpdate(ctxt, data.lobbies[foundIndex])
        end
    end
end

local function onUnload(ctxt)
    BJIMessage.cancelFlash("BJITagDuoTaggedReset")
    BJIMessage.stopRealtimeDisplay()

    BJIRestrictions.update({ {
        restrictions = Table({
            BJIRestrictions.RESET.TELEPORT,
            BJIRestrictions.RESET.HEAVY_RELOAD,
            BJIRestrictions.OTHER.AI_CONTROL,
            BJIRestrictions.OTHER.VEHICLE_SELECTOR,
            BJIRestrictions.OTHER.VEHICLE_PARTS_SELECTOR,
            BJIRestrictions.OTHER.VEHICLE_DEBUG,
            BJIRestrictions.OTHER.WALKING,
            BJIRestrictions.OTHER.BIG_MAP,
            BJIRestrictions.OTHER.VEHICLE_SWITCH,
            BJIRestrictions.OTHER.FREE_CAM,
        }):flat(),
        state = BJIRestrictions.STATE.ALLOWED,
    } })
    BJICam.removeRestrictedCamera(BJICam.CAMERAS.BIG_MAP)
    BJICam.removeRestrictedCamera(BJICam.CAMERAS.FREE)
    BJIGPS.reset()
    BJIBigmap.toggleQuickTravel(true)
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
