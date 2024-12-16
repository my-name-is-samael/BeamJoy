local M = {
    flashQueue = {},

    realtimeData = {
        context = nil,
        msg = "",
    },
}

local function _clearFlash()
    guihooks.trigger('ScenarioFlashMessageReset')
end

local function _flash(msg)
    _clearFlash()
    guihooks.trigger('ScenarioFlashMessage', { msg })
end

local function flash(key, msg, delaySec, big, targetTime, callback, sound)
    msg = tostring(msg)
    delaySec = tonumber(delaySec) or 3
    if big == nil then big = false end
    targetTime = targetTime or GetCurrentTimeMillis()

    table.insert(M.flashQueue, {
        key = key,
        time = targetTime,
        msg = msg,
        delay = delaySec,
        big = big,
        callback = callback,
        sound = sound,
    })
end

local function cancelFlash(key)
    for i = #M.flashQueue, 1, -1 do
        if M.flashQueue[i] and M.flashQueue[i].key == key then
            table.remove(M.flashQueue, i)
        end
    end
end

local function flashCountdown(key, targetTimeMs, big, zeroLabel, max, callback, withSounds)
    local now = GetCurrentTimeMillis()
    if not zeroLabel and callback then
        zeroLabel = ""
    end

    local time = targetTimeMs

    local i = 0
    while time > now and (not max or i <= max) do
        if i > 0 or zeroLabel then
            local label = i
            if i == 0 then
                label = zeroLabel or ""
            end
            local sound = nil
            if withSounds and i <= 3 then
                if i == 0 then
                    sound = BJISound.SOUNDS.RACE_START
                else
                    sound = BJISound.SOUNDS.RACE_COUNTDOWN
                end
            end
            M.flash(key, label, i == 0 and 2 or 1, big, time, i == 0 and callback or nil, sound)
        end
        time = time - 1000
        i = i + 1
    end
end

local function renderTick(ctxt)
    local msgIndices = {}
    for i, el in ipairs(M.flashQueue) do
        if el.time <= ctxt.now then
            table.insert(msgIndices, i)
        end
    end

    if #msgIndices == 0 then
        return
    elseif #msgIndices > 1 then
        -- sort to have the latest first
        table.sort(msgIndices, function(a, b)
            return M.flashQueue[a].time > M.flashQueue[b].time
        end)
        -- remove all queue indices after 1
        for i = 2, #msgIndices do
            table.remove(M.flashQueue, msgIndices[i])
        end
    end

    local el = M.flashQueue[msgIndices[1]]
    if el then
        if #el.msg > 0 then
            _flash({ el.msg, el.delay, nil, el.big })
        end
        if el.sound then
            BJISound.play(el.sound)
        end
        if type(el.callback) == "function" then
            el.callback(ctxt)
        end
        table.remove(M.flashQueue, msgIndices[1])
    end
end

local function realtimeDisplay(context, msg)
    M.realtimeData = {
        context = context or "",
        msg = msg or "",
    }
    guihooks.trigger('ScenarioRealtimeDisplay', M.realtimeData)
end

local function stopRealtimeDisplay()
    M.realtimeData = {
        context = nil,
        msg = "",
    }
    guihooks.trigger('ScenarioRealtimeDisplay', M.realtimeData)
end

local function message(msg)
    guihooks.trigger('Message', { ttl = 1, msg = msg, category = "" })
end

M.flash = flash
M.flashCountdown = flashCountdown
M.cancelFlash = cancelFlash
M.renderTick = renderTick

M.realtimeDisplay = realtimeDisplay
M.stopRealtimeDisplay = stopRealtimeDisplay

M.message = message

RegisterBJIManager(M)
return M
