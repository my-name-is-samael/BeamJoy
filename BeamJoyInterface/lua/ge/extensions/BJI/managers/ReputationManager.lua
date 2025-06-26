---@class BJIManagerReputation : BJIManager
local M = {
    _name = "Reputation",

    reputation = nil,

    kmReward = {
        lastPos = nil,
        distance = nil,
    },
}

local function updateReputationSmooth(value)
    if type(value) ~= "number" then
        LogError(string.var("Invalid reputation value '{1}'", { value or "" }))
        return
    end

    if M.reputation and value > M.reputation then
        M.smoothTarget = value
    else
        M.reputation = value
    end
end

local function renderTick(ctxt)
    if M.smoothTarget then
        local diff = M.smoothTarget - M.reputation
        local lerp = diff / 10
        if lerp < 1 then
            M.reputation = M.smoothTarget
            M.smoothTarget = nil
        else
            local lastLevel = M.getReputationLevel(M.reputation)
            M.reputation = M.reputation + math.ceil(lerp)
            local newLevel = M.getReputationLevel(M.reputation)
            if newLevel > lastLevel then
                -- ON LEVEL UP
                BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.LEVEL_UP)
                BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.LEVEL_UP, {
                    level = newLevel
                })
            end
        end
    end
end

local function getReputationLevelAmount(level)
    return (20 * (level ^ 2)) - (40 * level) + 20
end

local function getReputationLevel(reputation)
    reputation = reputation or M.reputation

    local level = 1
    while getReputationLevelAmount(level + 1) < reputation do
        level = level + 1
    end
    return level
end

---@param ctxt TickContext
local function slowTick(ctxt)
    if not ctxt.isOwner then
        if M.kmReward.lastPos then
            M.kmReward.lastPos = nil
            M.kmReward.distance = nil
        end
    else
        if not M.kmReward.lastPos then
            M.kmReward.distance = 0
        else
            local drove = math.horizontalDistance(M.kmReward.lastPos, ctxt.veh.position)
            M.kmReward.distance = M.kmReward.distance + drove
            if M.kmReward.distance >= 1000 then
                M.kmReward.distance = M.kmReward.distance - 1000
                BJI.Tx.player.KmReward()
            end
        end
        M.kmReward.lastPos = ctxt.veh.position
    end
end

local function onResetOrTeleport()
    if M.exemptReset then
        M.exemptReset = nil
    elseif M.kmReward.lastPos then
        M.kmReward.lastPos = nil
        M.kmReward.distance = nil
    end
end

local function onGarageRepair()
    -- when repairing in a garage, exempt the next reset from resetting current distance
    M.exemptReset = true
end

M.updateReputationSmooth = updateReputationSmooth

M.getReputationLevelAmount = getReputationLevelAmount
M.getReputationLevel = getReputationLevel

M.vehicleResetted = onResetOrTeleport
M.vehicleTeleported = onResetOrTeleport

M.onGarageRepair = onGarageRepair

M.onLoad = function()
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.SLOW_TICK, slowTick, M._name)
end
M.renderTick = renderTick

return M
