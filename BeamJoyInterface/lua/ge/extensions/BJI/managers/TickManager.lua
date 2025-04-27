---@class TickContext
---@field now integer
---@field user BJIUser
---@field group BJIGroup
---@field veh? userdata|any
---@field vehPosRot? BJIPositionRotation
---@field isOwner boolean
---@field vehData? BJIVehicleData
---@field camera string

---@class SlowTickContext : TickContext
---@field serverTime integer
---@field cachesHashes table<string, string>
---@field ToD? number

local M = {
    _name = "BJITick",
    timeOffsets = {}, -- time offsets in sec
}

-- CONTEXT SHARED WITH ALL MANAGERS / RENDERS
---@return TickContext
local function getContext()
    local veh = BJIVeh.getCurrentVehicle()
    local isOwner = veh and BJIVeh.isVehicleOwn(veh:getID())
    local vehData
    if isOwner then
        for _, v in pairs(BJIContext.User.vehicles) do
            if v.gameVehID == veh:getID() then
                vehData = v
                break
            end
        end
    end
    return {
        now = GetCurrentTimeMillis(),
        user = BJIContext.User,
        group = BJIPerm.Groups[BJIContext.User.group],
        veh = veh,
        vehPosRot = veh and BJIVeh.getPositionRotation(veh) or nil,
        isOwner = isOwner,
        vehData = vehData,
        camera = BJICam.getCamera(),
    }
end

-- ClientTick (each render tick)
local function client()
    if BJIContext.WorldReadyState == 2 and MPGameNetwork.launcherConnected() then
        TriggerBJIManagerEvent("renderTick", getContext())
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

    ---@type SlowTickContext|any
    local ctxt = getContext()
    table.assign(ctxt, serverData or {})
    TriggerBJIManagerEvent("slowTick", ctxt)
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

RegisterBJIManager(M)
return M
