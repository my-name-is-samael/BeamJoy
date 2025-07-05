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
    processCheck = nil,
}
--- gc prevention
local actions, veh

-- can switch to scenario hook
local function canChangeTo(ctxt)
    return true
end

-- load hook
local function onLoad(ctxt)
    BJI.Windows.VehSelector.tryClose()
    BJI.Managers.GPS.reset()
    BJI.Managers.Cam.addRestrictedCamera(BJI.Managers.Cam.CAMERAS.BIG_MAP)
    S.processCheck = nil
end

-- unload hook (before switch to another scenario)
local function onUnload(ctxt)
    BJI.Managers.Message.stopRealtimeDisplay()
    BJI.Managers.Message.cancelFlash("BJISpeedCheck")
end

---@param ctxt TickContext
---@return string[]
local function getRestrictions(ctxt)
    local res = Table():addAll(BJI.Managers.Restrictions.OTHER.BIG_MAP, true)
        :addAll(BJI.Managers.Restrictions.OTHER.FUN_STUFF, true)
    if not S.isEliminated() then
        res:addAll(BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH, true)
            :addAll(BJI.Managers.Restrictions.OTHER.FREE_CAM, true)
            :addAll(BJI.Managers.Restrictions.OTHER.PHOTO_MODE, true)
    end
    return res
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
---@param player BJIPlayer
---@param ctxt TickContext
local function getPlayerListActions(player, ctxt)
    actions = {}

    if S.isSpec() and S.isParticipant(player.playerID) and not S.isEliminated(player.playerID) then
        veh = BJI.Managers.Veh.getMPVehicles({ ownerID = player.playerID }, true):find(TrueFn)
        if veh then
            table.insert(actions, {
                id = string.var("focus{1}", { player.playerID }),
                icon = BJI.Utils.Icon.ICONS.visibility,
                style = BJI.Utils.Style.BTN_PRESETS.INFO,
                disabled = ctxt.veh and ctxt.veh.gameVehicleID == veh.gameVehicleID,
                tooltip = BJI.Managers.Lang.get("common.buttons.show"),
                onClick = function()
                    BJI.Managers.Veh.focusVehicle(veh.gameVehicleID)
                end
            })
        end
    end

    if BJI.Managers.Votes.Kick.canStartVote(player.playerID) then
        BJI.Utils.UI.AddPlayerActionVoteKick(actions, player.playerID)
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
    BJI.Managers.Restrictions.update()
end

---@param ctxt TickContext
local function fastTick(ctxt)
    if ctxt.isOwner and S.isParticipant() and not S.isEliminated() and tonumber(ctxt.veh.veh.speed) then
        local kmh = tonumber(ctxt.veh.veh.speed) * 3.6
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
    if S.isSpec() then
        local ownerID = BJI.Managers.Veh.getVehOwnerID(BJI.Managers.Context.User.currentVehicle)
        if not ownerID or not S.participants[ownerID] then
            switchToRandomParticipant()
        end
    else
        S.startLock = true
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
            BJI.Managers.Restrictions.update()
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
                BJI.Managers.Restrictions.update()
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
    return S.participants[playerID] ~= nil
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

S.getRestrictions = getRestrictions

S.onVehicleSwitched = onVehicleSwitched

S.canSpawnNewVehicle = FalseFn
S.canReplaceVehicle = FalseFn
S.canPaintVehicle = FalseFn
S.canDeleteVehicle = FalseFn
S.canDeleteOtherVehicles = FalseFn

S.getPlayerListActions = getPlayerListActions

S.fastTick = fastTick

S.rxData = rxData
S.isParticipant = isParticipant
S.isEliminated = isEliminated
S.isSpec = isSpec

S.stop = stop

return S
