local M = {
    _name = "BJIBusUI",
    id = "00",
    color = "#FF0",
    tasklist = {},

    next = 2,
}

local function draw()
    local tasklist = {}
    local direction = "Not in Service"
    local color = ""
    if #M.tasklist - (M.next - 1) > 0 then
        direction = M.tasklist[#M.tasklist]
        color = M.color
        for i = M.next, #M.tasklist do
            table.insert(tasklist, M.tasklist[i])
        end
    end

    local vehTasklist = "{"
    for i, stopName in ipairs(tasklist) do
        vehTasklist = string.var("{1}{{2}, \'{3}\'}", { vehTasklist, i, stopName })
        if i < #tasklist then
            vehTasklist = string.var("{1},", { vehTasklist })
        end
    end
    vehTasklist = string.var("{1}}", { vehTasklist })
    local strData = string.var(
        "controller.onGameplayEvent('bus_onRouteChange',{direction='{1}',routeID='{2}',routeId='{2}',routeColor='{3}',tasklist={4}})",
        { direction, M.id, color, vehTasklist })
    local veh = BJIVeh.getCurrentVehicleOwn()
    if veh then
        pcall(veh.queueLuaCommand, veh, strData)
    end

    -- veh command calls bus ui refresh with data
    --[[
    local uiTasks = {}
    for i, t in ipairs(tasklist) do
        table.insert(uiTasks, { i, t })
    end
    pcall(guihooks.trigger, 'BusDisplayUpdate', {
        routeId = M.id,
        direction = direction,
        routeColor = color,
        tasklist = uiTasks
    })
    ]]
end

local function initBusMission(id, stops, nextStop)
    M.reset()

    M.id = tostring(id)
    while #M.id < 2 do
        M.id = "0" .. M.id
    end

    for _, stop in ipairs(stops) do
        table.insert(M.tasklist, stop.name)
    end

    M.next = nextStop or 2

    draw()
end

local function requestStop(state)
    if #M.tasklist > 0 and M.next - 1 < #M.tasklist then
        pcall(guihooks.trigger, 'SetStopRequest', { stopRequested = state == true })
    else
        pcall(guihooks.trigger, 'SetStopRequest', { stopRequested = false })
    end
end

local function nextStop(val)
    M.next = val or M.next + 1
    draw()
end

local function reset()
    M.id = "00"
    M.color = "#FF0"
    M.tasklist = {}
    M.next = 2
    draw()
    M.requestStop(false)
end

M.initBusMission = initBusMission
M.requestStop = requestStop
M.nextStop = nextStop

M.reset = reset

return M
