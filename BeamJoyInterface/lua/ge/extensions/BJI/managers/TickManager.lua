local M = {
    timeOffsets = {}, -- time offsets in sec
}

-- CONTEXT SHARED WITH ALL MANAGERS / RENDERS
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

local function client()
    -- ClientTick (each render tick)

    if BJIContext.WorldReadyState == 2 and MPGameNetwork.launcherConnected() then
        TriggerBJIEvent("renderTick", getContext())
    end
end

local function server(serverData)
    -- ServerTick (~1s)

    if type(serverData.serverTime) == "number" then
        -- local offsetMs = (serverData.serverTime - GetCurrentTime()) * 1000
        table.insert(M.timeOffsets, serverData.serverTime - GetCurrentTime())
        if #M.timeOffsets > 100 then
            table.remove(M.timeOffsets, 1)
        end
    end

    local ctxt = getContext()
    tdeepassign(ctxt, serverData or {})
    TriggerBJIEvent("slowTick", ctxt)
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
    return Round(avgSec * 1000, 3)
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
