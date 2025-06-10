---@class BJIScenarioSpeed : BJIScenario
local S = {
    _name = "Speed",
    _key = "SPEED",
    _isSolo = false,

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
    BJI.Managers.Restrictions.update({ {
        restrictions = Table({
            BJI.Managers.Restrictions.OTHER.BIG_MAP,
            BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
            BJI.Managers.Restrictions.OTHER.FREE_CAM,
        }):flat(),
        state = BJI.Managers.Restrictions.STATE.RESTRICTED,
    } })
    BJI.Windows.VehSelector.tryClose()
    BJI.Managers.GPS.reset()
    BJI.Managers.Cam.addRestrictedCamera(BJI.Managers.Cam.CAMERAS.BIG_MAP)
    S.processCheck = nil
end

-- unload hook (before switch to another scenario)
local function onUnload(ctxt)
    BJI.Managers.Restrictions.update({ {
        restrictions = Table({
            BJI.Managers.Restrictions.OTHER.BIG_MAP,
            BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
            BJI.Managers.Restrictions.OTHER.FREE_CAM,
        }):flat(),
        state = BJI.Managers.Restrictions.STATE.ALLOWED,
    } })
    BJI.Managers.Message.stopRealtimeDisplay()
    BJI.Managers.Message.cancelFlash("BJISpeedCheck")
end

local function switchToRandomParticipant()
    local vehs = {}
    for playerID, gameVehID in pairs(S.participants) do
        if not S.isEliminated(playerID) then
            table.insert(vehs, gameVehID)
        end
    end
    local gameVehID = table.random(vehs)
    if gameVehID then
        BJI.Managers.Veh.focusVehicle(gameVehID)
    end
end

-- player list contextual actions getter
local function getPlayerListActions(player, ctxt)
    local actions = {}

    if S.isSpec() and S.isParticipant(player.playerID) then
        local finalGameVehID = BJI.Managers.Veh.getVehicleObject(S.participants[player.playerID])
        finalGameVehID = finalGameVehID and finalGameVehID:getID() or nil
        table.insert(actions, {
            id = string.var("focus{1}", { player.playerID }),
            icon = BJI.Utils.Icon.ICONS.visibility,
            style = BJI.Utils.Style.BTN_PRESETS.INFO,
            disabled = not finalGameVehID or
                (ctxt.veh and ctxt.veh:getID() == finalGameVehID) or
                not S.isSpec(player.playerID),
            tooltip = BJI.Managers.Lang.get("common.buttons.show"),
            onClick = function()
                BJI.Managers.Veh.focusVehicle(finalGameVehID)
            end
        })
    end

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

local function onVehicleSwitched(oldGameVehID, newGameVehID)
    if newGameVehID ~= -1 then
        local ownerID = BJI.Managers.Veh.getVehOwnerID(newGameVehID)
        if not S.isParticipant(ownerID) or S.isEliminated(ownerID) then
            BJI.Managers.Veh.focusNextVehicle()
        end
    end
end

local function onElimination()
    switchToRandomParticipant()
    BJI.Managers.Restrictions.update({ {
        restrictions = Table({
            BJI.Managers.Restrictions.OTHER.FREE_CAM,
            BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
        }):flat(),
        state = BJI.Managers.Restrictions.STATE.ALLOWED,
    } })
end

-- each frame tick hook
local function renderTick(ctxt)
    if S.isParticipant() and not S.isEliminated() then
        if not ctxt.isOwner then
            BJI.Tx.scenario.SpeedFail(ctxt.now - S.startTime)
        else
            ctxt.veh:queueLuaCommand([[
                obj:queueGameEngineLua("BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.SPEED).speed =" .. obj:getAirflowSpeed())
            ]])
        end
    end
end

local function fastTick(ctxt)
    if ctxt.isOwner and S.isParticipant() and not S.isEliminated() and S.speed then
        local kmh = S.speed * 3.6
        if S.processCheck then
            if kmh >= S.minSpeed then
                S.processCheck = nil
                BJI.Managers.Message.cancelFlash("BJISpeedCheck")
            end
        elseif not S.startLock and kmh < S.minSpeed then
            S.processCheck = ctxt.now + 5010
            BJI.Managers.Message.flashCountdown("BJISpeedCheck", S.processCheck, false,
                BJI.Managers.Lang.get("speed.flashFailed"), nil, function()
                    local time = ctxt.now - S.startTime
                    BJI.Tx.scenario.SpeedFail(time)
                    for i = table.length(S.participants), 1, -1 do
                        if not S.leaderboard[i] then
                            -- manual elimination
                            S.leaderboard[i] = {
                                playerID = BJI.Managers.Context.User.playerID,
                                time = time,
                                speed = S.minSpeed,
                            }
                            break
                        elseif S.leaderboard[i] and S.leaderboard[i].playerID == BJI.Managers.Context.User.playerID then
                            break
                        end
                    end
                    BJI.Managers.Async.delayTask(function()
                        if not S.leaderboard[2] then
                            onElimination()
                        end
                    end, 3000, "BJISpeedFail")
                end)
        end
    end
end

local function showMinSpeedDisplay(kmh)
    local speedLabel = string.var("{1}{2}", { kmh, BJI.Managers.Lang.get("speed.speedUnit") })
    BJI.Managers.Message.realtimeDisplay("minspeed", BJI.Managers.Lang.get("speed.realtimeMinSpeed")
        :var({ speed = speedLabel }))
end

local function initScenario(data)
    S.startTime = BJI.Managers.Tick.applyTimeOffset(data.startTime)
    BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.SPEED)

    BJI.Managers.Message.flash("BJISpeedStart", BJI.Managers.Lang.get("speed.flashStart"), 3, false)
    BJI.Managers.Restrictions.update({ {
        restrictions = Table({
            BJI.Managers.Restrictions.OTHER.BIG_MAP,
        }):flat(),
        state = BJI.Managers.Restrictions.STATE.RESTRICTED,
    } })
    if S.isSpec() then
        BJI.Managers.Restrictions.update({ {
            restrictions = Table({
                BJI.Managers.Restrictions.OTHER.BIG_MAP,
                BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                BJI.Managers.Restrictions.OTHER.FREE_CAM,
            }):flat(),
            state = BJI.Managers.Restrictions.STATE.ALLOWED,
        } })
        local ownerID = BJI.Managers.Veh.getVehOwnerID()
        if not ownerID or not S.participants[ownerID] then
            switchToRandomParticipant()
        end
    else
        S.startLock = true
        BJI.Managers.Restrictions.update({ {
            restrictions = BJI.Managers.Restrictions.OTHER.PHOTO_MODE,
            state = BJI.Managers.Restrictions.STATE.RESTRICTED,
        } })
        BJI.Managers.Async.delayTask(function()
            S.startLock = false
        end, 1000, "BJISpeedStartLock")
    end
    showMinSpeedDisplay(S.minSpeed)
end

local function updateData(data, previousMinSpeed)
    if data.leaderboard[1] then
        -- on mode finished
        BJI.Managers.Message.stopRealtimeDisplay()
        local winner = BJI.Managers.Context.Players[data.leaderboard[1].playerID]
        BJI.Managers.Message.flash("BJISpeedWinner",
            BJI.Managers.Lang.get("speed.flashWinner"):var({
                playerName = winner and
                    winner.playerName or BJI.Managers.Lang.get("common.unknown")
            }),
            5, false)
    elseif data.minSpeed ~= previousMinSpeed then
        -- on minspeed updated
        showMinSpeedDisplay(data.minSpeed)
    else
        -- on player eliminated/forfeited
        if BJI.Managers.Restrictions.getState(BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH) and
            Table(S.participants):any(function(p) return p.playerID == BJI.Managers.Context.User.playerID end) then
            BJI.Managers.Restrictions.update({ {
                restrictions = Table({
                    BJI.Managers.Restrictions.OTHER.BIG_MAP,
                    BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                    BJI.Managers.Restrictions.OTHER.FREE_CAM,
                    BJI.Managers.Restrictions.OTHER.PHOTO_MODE,
                }):flat(),
                state = BJI.Managers.Restrictions.STATE.ALLOWED,
            } })
        end
    end
end

local function stop()
    BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.FREEROAM)
    S.startTime = nil
    S.minSpeed = 0
    Table(BJI.Managers.Context.User.vehicles):find(TrueFn, function(v)
        BJI.Managers.Veh.focusVehicle(v.gameVehID)
        BJI.Managers.Veh.recoverInPlace()
    end)
end

local function rxData(data)
    S.MINIMUM_PARTICIPANTS = data.minimumParticipants
    S.isEvent = data.isEvent
    S.participants = data.participants
    S.leaderboard = data.leaderboard
    local previousMinSpeed = S.minSpeed
    S.minSpeed = data.minSpeed
    S.eliminationDelay = data.eliminationDelay

    if data.startTime then
        if S.isParticipant() or S.isEvent then
            if not BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.SPEED) then
                initScenario(data)
            else
                updateData(data, previousMinSpeed)
            end
        end
    elseif BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.SPEED) then
        S.stop()
    end
    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SCENARIO_UPDATED)
end

local function isParticipant(playerID)
    playerID = playerID or BJI.Managers.Context.User.playerID
    return not not S.participants[playerID]
end

local function isEliminated(playerID)
    playerID = playerID or BJI.Managers.Context.User.playerID
    if not S.isParticipant(playerID) or
        table.length(S.leaderboard) == 0 then
        return false
    end
    local inLeaderboard = false
    for _, v in pairs(S.leaderboard) do
        if v.playerID == playerID then
            inLeaderboard = true
            break
        end
    end
    return inLeaderboard
end

local function isSpec(playerID)
    return (not S.isParticipant(playerID) and S.isEvent) or S.isEliminated(playerID)
end

S.canChangeTo = canChangeTo
S.onLoad = onLoad
S.onUnload = onUnload

S.onVehicleSwitched = onVehicleSwitched

S.canSpawnNewVehicle = FalseFn
S.canReplaceVehicle = FalseFn
S.canPaintVehicle = FalseFn
S.canDeleteVehicle = FalseFn
S.canDeleteOtherVehicles = FalseFn

S.getPlayerListActions = getPlayerListActions

S.renderTick = renderTick
S.fastTick = fastTick

S.rxData = rxData
S.isParticipant = isParticipant
S.isEliminated = isEliminated
S.isSpec = isSpec

S.stop = stop

return S
