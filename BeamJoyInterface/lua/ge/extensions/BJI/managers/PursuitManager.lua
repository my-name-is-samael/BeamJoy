---@class BJIManagerPoliceDuty: BJIManager
local M = {
    _name = "Pursuit",

    selfPursuit = {
        active = false,
        ---@type integer?
        targetID = nil,
        isFugitive = false,
    },
}

local function reset()
    M.selfPursuit.active = false
    M.selfPursuit.targetID = nil
    BJI.Managers.GPS.removeByKey(BJI.Managers.GPS.KEYS.VEHICLE)
end

local function onPursuitActionUpdate(targetID, event, pursuitData)
    local ctxt = BJI.Managers.Tick.getContext()
    local isFugitive = ctxt.veh and ctxt.veh:getID() == targetID
    local isPolice = ctxt.veh and gameplay_traffic.getTrafficData()[ctxt.veh:getID()] and
        gameplay_traffic.getTrafficData()[ctxt.veh:getID()].role.name == "police"
    if (isFugitive or isPolice) and BJI.Managers.Veh.isCurrentVehicleOwn() and
        not BJI.Managers.AI.isSelfAIVehicle(ctxt.veh:getID()) then
        if event == "start" then
            M.selfPursuit.active = true
            M.selfPursuit.targetID = targetID
            M.selfPursuit.isFugitive = isFugitive
            BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_START)
            if isPolice then
                BJI.Managers.GPS.prependWaypoint({
                    key = BJI.Managers.GPS.KEYS.VEHICLE,
                    radius = 0,
                    gameVehID = targetID,
                    clearable = false,
                })
            end
        elseif event == "arrest" then
            if M.selfPursuit.isFugitive then
                BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_FAIL)
            else
                local targetVeh = BJI.Managers.Veh.getVehicleObject(targetID)
                BJI.Managers.Veh.getPositionRotation(targetVeh, function(pos)
                    if ctxt.vehPosRot.pos:distance(pos) < 10 then
                        BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_SUCCESS)
                        -- TODO reward
                    end
                end)
            end
            reset()
        elseif event == "evade" then
            if M.selfPursuit.isFugitive then
                BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_SUCCESS)
                -- TODO reward
            else
                BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_FAIL)
            end
            reset()
        elseif event == "reset" and M.selfPursuit.active then
            BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_FAIL)
            reset()
        end
    end
end

local function onFail()
    if M.selfPursuit.active then
        BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_FAIL)
        reset()
    end
end

---@param gameVehID integer
---@param aiState string
local function onAIChanged(gameVehID, aiState)
    local ctxt = BJI.Managers.Tick.getContext()
    if ctxt.veh and ctxt.veh:getID() == gameVehID then
        onFail()
    end
end

---@param gameVehID integer
local function onVehicleResetted(gameVehID)
    if M.selfPursuit.active and gameVehID == M.selfPursuit.targetID then
        BJI.Managers.Sound.play(BJI.Managers.Sound.SOUNDS.PURSUIT_FAIL)
        reset()
    end
end

---@param ctxt TickContext
local function renderTick(ctxt)
    if M.selfPursuit.active and not M.selfPursuit.isFugitive then
        local targetVeh = BJI.Managers.Veh.getVehicleObject(M.selfPursuit.targetID)
        if targetVeh then
            BJI.Managers.Veh.getPositionRotation(targetVeh, function(targetVehPos)
                local finalPos = vec3(targetVehPos) + vec3(0, 0, targetVeh:getInitialHeight())
                BJI.Utils.ShapeDrawer.Text("Fugitive", finalPos, BJI.Utils.ShapeDrawer.Color(0, 0, 0, 1),
                    BJI.Utils.ShapeDrawer.Color(1, 0, 0, .5), false)
            end)
        end
    end
end

M.onLoad = function()
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_PURSUIT_ACTION, onPursuitActionUpdate, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_PURSUIT_MODE_UPDATE, function() end, M._name) -- not in use for now
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_AI_MODE_CHANGE, onAIChanged, M._name)
    BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.NG_VEHICLE_RESETTED, onVehicleResetted, M._name)
    BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.SCENARIO_CHANGED,
        BJI.Managers.Events.EVENTS.NG_VEHICLE_SWITCHED,
    }, onFail, M._name)
end

M.renderTick = renderTick

return M
