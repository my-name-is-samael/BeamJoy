local M = {
    -- server data
    MINIMUM_PARTICIPANTS = 2,
    isEvent = false,
    startTime = nil,
    participants = {},
    leaderboard = {},
    minSpeed = 0,
    eliminationDelay = 5,

    -- self data
    speed = 0,
    processCheck = nil,
}

-- can switch to scenario hook
local function canChangeTo(ctxt)
    return true
end

-- load hook
local function onLoad(ctxt)
    BJIVehSelector.tryClose()
    BJIQuickTravel.toggle(false)
    BJIGPS.reset()
    BJICam.addRestrictedCamera(BJICam.CAMERAS.BIG_MAP)
    M.processCheck = nil
end

local function switchToRandomParticipant()
    local vehs = {}
    for playerID, gameVehID in pairs(M.participants) do
        if not M.isEliminated(playerID) then
            table.insert(vehs, gameVehID)
        end
    end
    local gameVehID = table.random(vehs)
    if gameVehID then
        BJIVeh.focusVehicle(gameVehID)
    end
end

-- player vehicle switch hook
local function onVehicleSwitched(oldGameVehID, newGameVehID)
    if M.isParticipant() and not M.isEliminated() then
        -- fail
        BJITx.scenario.SpeedFail(GetCurrentTimeMillis() - M.startTime)
    end

    -- spec switch
    if M.isSpec() then
        for _, gameVehID in pairs(M.participants) do
            if gameVehID == newGameVehID then
                switchToRandomParticipant()
                break
            end
        end
    end
end

local function canVehUpdate()
    return false
end

-- player list contextual actions getter
local function getPlayerListActions(player, ctxt)
    local actions = {}

    if M.isSpec() and
        not M.isSpec(player.playerID) then
        local finalGameVehID = BJIVeh.getVehicleObject(M.participants[player.playerID])
        finalGameVehID = finalGameVehID and finalGameVehID:getID() or nil
        table.insert(actions, {
            id = string.var("focus{1}", { player.playerID }),
            icon = ICONS.visibility,
            style = BTN_PRESETS.INFO,
            disabled = not finalGameVehID or
                (ctxt.veh and ctxt.veh:getID() == finalGameVehID),
            onClick = function()
                BJIVeh.focusVehicle(finalGameVehID)
            end
        })
    end

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

-- each frame tick hook
local function renderTick(ctxt)
    local speedLabel = string.var("{1}{2}", { M.minSpeed, BJILang.get("speed.speedUnit") })
    BJIMessage.realtimeDisplay("minspeed", BJILang.get("speed.realtimeMinSpeed")
        :var({ speed = speedLabel }))

    if M.isParticipant() and not M.isEliminated() then
        if not ctxt.isOwner then
            BJITx.scenario.SpeedFail(ctxt.now - M.startTime)
        else
            ctxt.veh:queueLuaCommand([[
                obj:queueGameEngineLua("BJIScenario.get(BJIScenario.TYPES.SPEED).speed =" .. obj:getAirflowSpeed())
            ]])
            local kmh = M.speed * 3.6
            if M.processCheck then
                if kmh >= M.minSpeed then
                    M.processCheck = nil
                    BJIMessage.cancelFlash("BJISpeedCheck")
                end
            else
                if kmh < M.minSpeed then
                    M.processCheck = ctxt.now + 5010
                    BJIMessage.flashCountdown("BJISpeedCheck", M.processCheck, false,
                        BJILang.get("speed.flashFailed"), nil, function()
                            local time = ctxt.now - M.startTime
                            BJITx.scenario.SpeedFail(time)
                            for i = table.length(M.participants), 1, -1 do
                                if not M.leaderboard[i] then
                                    -- manual elimination
                                    M.leaderboard[i] = {
                                        playerID = BJIContext.User.playerID,
                                        time = time,
                                        speed = M.minSpeed,
                                    }
                                    break
                                elseif M.leaderboard[i] and M.leaderboard[i].playerID == BJIContext.User.playerID then
                                    break
                                end
                            end
                            BJIAsync.delayTask(function()
                                if not M.leaderboard[2] then
                                    switchToRandomParticipant()
                                end
                            end, 3000, "BJISpeedFail")
                        end)
                end
            end
        end
    end
end

-- unload hook (before switch to another scenario)
local function onUnload(ctxt)
    BJIRestrictions.updateReset(BJIRestrictions.TYPES.RESET_ALL)
    BJIMessage.stopRealtimeDisplay()
    BJIMessage.cancelFlash("BJISpeedCheck")
end

local function initScenario(data)
    M.startTime = BJITick.applyTimeOffset(data.startTime)
    BJIScenario.switchScenario(BJIScenario.TYPES.SPEED)

    if M.isParticipant() then
        BJIRestrictions.updateReset(BJIRestrictions.TYPES.RESET_NONE)
        BJIMessage.flash("BJISpeedStart", BJILang.get("speed.flashStart"), 3, false)
    end
end

local function stop()
    if M.leaderboard[1] then
        local winner = BJIContext.Players[M.leaderboard[1].playerID]
        local playerName
        if winner then
            playerName = winner.playerName
        else
            playerName = BJILang.get("common.unknown")
        end
        BJIMessage.flash("BJISpeedWinner",
            BJILang.get("speed.flashWinner"):var({ playerName = playerName }),
            5, false)
    end

    BJIScenario.switchScenario(BJIScenario.TYPES.FREEROAM)
    M.startTime = nil
end

local function rxData(data)
    M.MINIMUM_PARTICIPANTS = data.minimumParticipants
    M.isEvent = data.isEvent
    M.participants = data.participants
    M.leaderboard = data.leaderboard
    M.minSpeed = data.minSpeed
    M.eliminationDelay = data.eliminationDelay

    if data.startTime then
        if not BJIScenario.is(BJIScenario.TYPES.SPEED) and
            (M.isParticipant() or M.isEvent) then
            initScenario(data)
        end
    else
        if BJIScenario.is(BJIScenario.TYPES.SPEED) then
            M.stop()
        end
    end
end

local function isParticipant(playerID)
    playerID = playerID or BJIContext.User.playerID
    return not not M.participants[playerID]
end

local function isEliminated(playerID)
    playerID = playerID or BJIContext.User.playerID
    if not M.isParticipant(playerID) or
        table.length(M.leaderboard) == 0 then
        return false
    end
    local inLeaderboard = false
    for _, v in pairs(M.leaderboard) do
        if v.playerID == playerID then
            inLeaderboard = true
            break
        end
    end
    return inLeaderboard
end

local function isSpec(playerID)
    return not M.isParticipant(playerID) or M.isEliminated(playerID)
end

M.canChangeTo = canChangeTo
M.onLoad = onLoad

M.onVehicleSwitched = onVehicleSwitched

M.canSelectVehicle = canVehUpdate
M.canSpawnNewVehicle = canVehUpdate
M.canReplaceVehicle = canVehUpdate
M.canDeleteVehicle = canVehUpdate
M.canDeleteOtherVehicles = canVehUpdate
M.canEditVehicle = canVehUpdate

M.getPlayerListActions = getPlayerListActions

M.renderTick = renderTick

M.onUnload = onUnload

M.rxData = rxData
M.isParticipant = isParticipant
M.isEliminated = isEliminated
M.isSpec = isSpec

M.stop = stop

return M
