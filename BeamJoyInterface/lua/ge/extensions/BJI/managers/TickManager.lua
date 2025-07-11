---@class TickContext
---@field now integer
---@field user BJIUser
---@field group BJIGroup
---@field players tablelib<integer, BJIPlayer> index playerID
---@field veh? BJIMPVehicle
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
    local veh = BJI_Context.User.currentVehicle and
        BJI_Veh.getMPVehicle(BJI_Context.User.currentVehicle) or nil
    local vehData
    if veh and veh.isLocal then
        for _, v in pairs(BJI_Context.User.vehicles) do
            if veh and v.gameVehID == veh.gameVehicleID then
                vehData = v
                break
            end
        end
    end
    local ctxt = {
        now = GetCurrentTimeMillis(),
        user = BJI_Context.User,
        group = BJI_Perm.Groups[BJI_Context.User.group],
        players = BJI_Context.Players,
        veh = veh,
        isOwner = veh and veh.isLocal,
        vehData = vehData,
        camera = BJI_Cam.getCamera(),
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
        BJI_Events.trigger(BJI_Events.EVENTS.FAST_TICK, ctxt)
    end
end

--- gc prevention
local ctxt, start
-- ClientTick (each render tick)
local function client()
    if BJI_Context.WorldReadyState == 2 and MPGameNetwork.launcherConnected() then
        ctxt = getContext()
        Table(BJI.Managers):forEach(function(m)
            if m.renderTick then
                start = GetCurrentTimeMillis()
                m.renderTick(ctxt)
                if BJI.Bench.STATE == 1 then
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
        BJI_Env.tryApplyTimeFromServer(serverData.ToD)
    end

    lastServerData = serverData
    BJI_Events.trigger(BJI_Events.EVENTS.SLOW_TICK)
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
