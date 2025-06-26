---@class TickContext
---@field now integer
---@field user BJIUser
---@field group BJIGroup
---@field players tablelib<integer, BJIPlayer> index playerID
---@field veh? NGVehicle
---@field vehPosRot? BJIPositionRotation
---@field isOwner boolean
---@field vehData? BJIVehicleData
---@field camera string

---@class SlowTickContext : TickContext
---@field serverTime integer
---@field cachesHashes table<string, string>
---@field ToD? number

---@class BJIManagerTick : BJIManager
local M = {
    _name = "Tick",

    timeOffsets = {}, -- time offsets in sec
}

-- CONTEXT SHARED WITH ALL MANAGERS / RENDERS

local lastServerData = nil

---@param slow? boolean
---@return TickContext
local function getContext(slow)
    local veh = BJI.Managers.Veh.getCurrentVehicle()
    local isOwner = veh and BJI.Managers.Veh.isVehicleOwn(veh:getID())
    local vehData
    if isOwner then
        for _, v in pairs(BJI.Managers.Context.User.vehicles) do
            if veh and v.gameVehID == veh:getID() then
                vehData = v
                break
            end
        end
    end
    local pos, rot
    if veh then
        pos, rot = BJI.Managers.Veh.getPositionRotation(veh)
    end
    local ctxt = {
        now = GetCurrentTimeMillis(),
        user = BJI.Managers.Context.User,
        group = BJI.Managers.Perm.Groups[BJI.Managers.Context.User.group],
        players = BJI.Managers.Context.Players,
        veh = veh,
        vehPosRot = pos and {
            pos = pos,
            rot = rot,
        } or nil,
        isOwner = isOwner,
        vehData = vehData,
        camera = BJI.Managers.Cam.getCamera(),
    }
    if slow and lastServerData then
        return table.assign(ctxt, lastServerData)
    end
    return ctxt
end

local lastFastTickTime = 0
---@param ctxt TickContext
local function processFastTick(ctxt)
    if ctxt.now >= lastFastTickTime + 250 then
        lastFastTickTime = ctxt.now
        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.FAST_TICK, ctxt)
    end
end

-- ClientTick (each render tick)
local function client()
    if BJI.Managers.Context.WorldReadyState == 2 and MPGameNetwork.launcherConnected() then
        local ctxt = getContext()
        Table(BJI.Managers):forEach(function(m)
            if m.renderTick then
                local start = GetCurrentTimeMillis()
                m.renderTick(ctxt)
                if BJI.Bench.STATE then
                    BJI.Bench.add(m._name, "renderTick", GetCurrentTimeMillis() - start)
                end
            end
        end)
        processFastTick(ctxt)
    end
end

-- ServerTick (~1s)
local function server(serverData)
    if type(serverData.serverTime) == "number" then
        table.insert(M.timeOffsets, serverData.serverTime - GetCurrentTime())
        if #M.timeOffsets > 100 then
            table.remove(M.timeOffsets, 1)
        end
    end

    if serverData.ToD then
        BJI.Managers.Env.tryApplyTimeFromServer(serverData.ToD)
    end

    lastServerData = serverData
    BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.SLOW_TICK)
end

local function getAvgOffsetMs()
    if #M.timeOffsets == 0 then
        return 0
    end

    local count = 0
    for _, offset in ipairs(M.timeOffsets) do
        count = count + offset
    end
    local avgSec = count / #M.timeOffsets
    return math.round(avgSec * 1000, 3)
end

local function applyTimeOffset(timeSec)
    if type(timeSec) == "number" then
        return (timeSec * 1000) - M.getAvgOffsetMs()
    end
    return timeSec
end

M.getContext = getContext

M.client = client
M.server = server

M.getAvgOffsetMs = getAvgOffsetMs
M.applyTimeOffset = applyTimeOffset

return M
