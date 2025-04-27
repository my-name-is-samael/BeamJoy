function GetTextWidth(text)
    if type(text) ~= "string" then
        return 0
    end
    return ui_imgui.CalcTextSize(text).x
end

local COLUMNS_MARGIN = GetTextWidth("  ")
function GetColumnTextWidth(text)
    return GetTextWidth(text) + COLUMNS_MARGIN
end

function GetInputWidthByContent(content, typeNumber)
    local inputOffset = 4 + (typeNumber and 50 or 0)
    return GetTextWidth(tostring(content)) + inputOffset
end

-- DISTANCE / POSITIONS ROTATIONS

function GetHorizontalDistance(pos1, pos2)
    local _, _, err = pcall(vec3, pos1)
    local _, _, err2 = pcall(vec3, pos2)
    if err or err2 then
        LogError("invalid position", "GetHorizontalDistance")
        return 0
    end

    local p1 = vec3(pos1.x, pos1.y, 0)
    local p2 = vec3(pos2.x, pos2.y, 0)
    return p1:distance(p2)
end

function TryParsePosRot(obj)
    if type(obj) ~= "table" then
        return obj
    end

    if table.includes({ "table", "userdata" }, type(obj.pos)) and
        table.every({ "x", "y", "z" }, function(k) return obj.pos[k] ~= nil end) then
        obj.pos = vec3(obj.pos.x, obj.pos.y, obj.pos.z)
    end
    if table.includes({ "table", "userdata" }, type(obj.rot)) and
        table.every({ "x", "y", "z", "w" }, function(k) return obj.rot[k] ~= nil end) then
        obj.rot = quat(obj.rot.x, obj.rot.y, obj.rot.z, obj.rot.w)
    end
    return obj
end

function RoundPositionRotation(posRot)
    if posRot and posRot.pos then
        posRot.pos.x = math.round(posRot.pos.x, 3)
        posRot.pos.y = math.round(posRot.pos.y, 3)
        posRot.pos.z = math.round(posRot.pos.z, 3)
    end
    if posRot and posRot.rot then
        posRot.rot.x = math.round(posRot.rot.x, 4)
        posRot.rot.y = math.round(posRot.rot.y, 4)
        posRot.rot.z = math.round(posRot.rot.z, 4)
        posRot.rot.w = math.round(posRot.rot.w, 4)
    end
    return posRot
end

-- FORMAT
function PrettyDelay(secs)
    local mins, hours, days, months = 0, 0, 0, 0
    if secs >= 60 then
        mins = math.floor(secs / 60)
        secs = secs - mins * 60
    end
    if mins >= 60 then
        hours = math.floor(mins / 60)
        mins = mins - hours * 60
    end
    if hours >= 24 then
        days = math.floor(hours / 24)
        hours = hours - days * 24
    end
    if days >= 30 then
        months = math.floor(days / 30)
        days = days - months * 30
    end

    if months > 1 then
        local monthLabel = BJILang.get("common.time.months")
        return string.var("{months} {monthLabel}", { months = months, monthLabel = monthLabel })
    elseif months == 1 then
        local monthLabel = BJILang.get("common.time.month")
        local dayLabel = BJILang.get("common.time.day")
        local andLabel = BJILang.get("common.time.and")
        if days > 1 then
            dayLabel = BJILang.get("common.time.days")
        end
        if days > 0 then
            return string.var("{months} {monthLabel} {andLabel} {days} {dayLabel}",
                { months = months, monthLabel = monthLabel, andLabel = andLabel, days = days, dayLabel = dayLabel })
        else
            return string.var("{months} {monthLabel}", { months = months, monthLabel = monthLabel })
        end
    end

    if days > 1 then
        local dayLabel = BJILang.get("common.time.days")
        return string.var("{days} {dayLabel}", { days = days, dayLabel = dayLabel })
    elseif days == 1 then
        local dayLabel = BJILang.get("common.time.day")
        local hourLabel = BJILang.get("common.time.hour")
        local andLabel = BJILang.get("common.time.and")
        if hours > 1 then
            hourLabel = BJILang.get("common.time.hours")
        end
        if hours > 0 then
            return string.var("{days} {dayLabel} {andLabel} {hours} {hourLabel}",
                { days = days, dayLabel = dayLabel, andLabel = andLabel, hours = hours, hourLabel = hourLabel })
        else
            return string.var("{days} {dayLabel}", { days = days, dayLabel = dayLabel })
        end
    end

    if hours > 1 then
        local hourLabel = BJILang.get("common.time.hours")
        return string.var("{hours} {hourLabel}", { hours = hours, hourLabel = hourLabel })
    elseif hours == 1 then
        local hourLabel = BJILang.get("common.time.hour")
        local minuteLabel = BJILang.get("common.time.minute")
        local andLabel = BJILang.get("common.time.and")
        if mins > 1 then
            minuteLabel = BJILang.get("common.time.minutes")
        end
        if mins > 0 then
            return string.var("{hours} {hourLabel} {andLabel} {mins} {minuteLabel}",
                { hours = hours, hourLabel = hourLabel, andLabel = andLabel, mins = mins, minuteLabel = minuteLabel })
        else
            return string.var("{hours} {hourLabel}", { hours = hours, hourLabel = hourLabel })
        end
    end

    if mins > 1 then
        local minLabel = BJILang.get("common.time.minutes")
        return string.var("{mins} {minLabel}", { mins = mins, minLabel = minLabel })
    elseif mins == 1 then
        local minLabel = BJILang.get("common.time.minute")
        local secLabel = BJILang.get("common.time.second")
        local andLabel = BJILang.get("common.time.and")
        if secs > 0 then
            return string.var("{mins} {minLabel} {andLabel} {secs} {secLabel}",
                { mins = mins, minLabel = minLabel, andLabel = andLabel, secs = secs, secLabel = secLabel })
        else
            return string.var("{mins} {minLabel}", { mins = mins, minLabel = minLabel })
        end
    end

    local secondLabel = BJILang.get("common.time.second")
    if secs > 1 then
        secondLabel = BJILang.get("common.time.seconds")
    end
    return string.var("{secs} {secondLabel}", { secs = secs, secondLabel = secondLabel })
end

function RaceDelay(ms)
    local hours = math.floor(ms / 1000 / 60 / 60)
    ms = ms - hours * 60 * 60 * 1000
    local mins = math.floor(ms / 1000 / 60)
    ms = ms - mins * 60 * 1000
    local secs = math.floor(ms / 1000)
    ms = ms - secs * 1000

    if hours > 0 then
        return string.var("{1}:{2}:{3}.{4}",
            {
                tostring(hours),
                string.normalizeInt(mins, 2),
                string.normalizeInt(secs, 2),
                string.normalizeInt(ms, 3)
            })
    elseif mins > 0 then
        return string.var("{1}:{2}.{3}",
            {
                mins,
                string.normalizeInt(secs, 2),
                string.normalizeInt(ms, 3)
            })
    else
        return string.var("{1}.{2}", {
            secs,
            string.normalizeInt(ms, 3)
        })
    end
end

function PrettyDistance(m)
    if settings.getValue("uiUnitLength") == "imperial" then
        local foot = m * 3.28084
        local miles = foot / 5280
        if miles >= .5 then
            return string.var("{1}mi", { math.round(miles, 1) })
        else
            return string.var("{1}ft", { math.round(foot) })
        end
    else
        local kms = m / 1000
        if kms >= .5 then
            return string.var("{1}km", { math.round(kms, 1) })
        else
            return string.var("{1}m", { math.round(m) })
        end
    end
end

function PrettyTime(ToD)
    local curSecs = ToD * 86400
    if ToD >= 0 and ToD < .5 then
        curSecs = curSecs + 43200
    elseif ToD >= .5 and ToD <= 1 then
        curSecs = curSecs - 43200
    end
    local curHours = math.floor(curSecs / 3600)
    curSecs = curSecs - curHours * 3600
    local curMins = math.floor(curSecs / 60)
    curSecs = curSecs - curMins * 60
    return string.format("%02d:%02d:%02d", curHours, curMins, curSecs)
end

-- DRAW

function DrawLineDurationModifiers(id, value, min, max, resetValue, callback)
    local showMonth = true
    if max and max < 60 * 60 * 24 * 30 then
        showMonth = false
    end
    local showDay = true
    if max and max < 60 * 60 * 24 then
        showDay = false
    end
    local showHour = true
    if max and max < 60 * 60 then
        showHour = false
    end

    local line = LineBuilder()
    if showMonth then
        line:btn({
            id = string.var("{1}M1M", { id }),
            label = string.var("-1{1}", { BJILang.get("common.durationModifiers.month") }),
            style = BTN_PRESETS.ERROR,
            onClick = function()
                callback(math.clamp(value - (60 * 60 * 24 * 30), min, max))
            end
        })
    end
    if showDay then
        line:btn({
            id = string.var("{1}M1d", { id }),
            label = string.var("-1{1}", { BJILang.get("common.durationModifiers.day") }),
            style = BTN_PRESETS.ERROR,
            onClick = function()
                callback(math.clamp(value - (60 * 60 * 24), min, max))
            end
        })
    end
    if showHour then
        line:btn({
            id = string.var("{1}M1h", { id }),
            label = string.var("-1{1}", { BJILang.get("common.durationModifiers.hour") }),
            style = BTN_PRESETS.ERROR,
            onClick = function()
                callback(math.clamp(value - (60 * 60), min, max))
            end
        })
    end
    line:btn({
        id = string.var("{1}M1m", { id }),
        label = string.var("-1{1}", { BJILang.get("common.durationModifiers.minute") }),
        style = BTN_PRESETS.ERROR,
        onClick = function()
            callback(math.clamp(value - 60, min, max))
        end
    })
        :btn({
            id = string.var("{1}P1m", { id }),
            label = string.var("+1{1}", { BJILang.get("common.durationModifiers.minute") }),
            style = BTN_PRESETS.SUCCESS,
            onClick = function()
                callback(math.clamp(value + 60, min, max))
            end
        })
    if showHour then
        line:btn({
            id = string.var("{1}P1h", { id }),
            label = string.var("+1{1}", { BJILang.get("common.durationModifiers.hour") }),
            style = BTN_PRESETS.SUCCESS,
            onClick = function()
                callback(math.clamp(value + (60 * 60), min, max))
            end
        })
    end
    if showDay then
        line:btn({
            id = string.var("{1}P1d", { id }),
            label = string.var("+1{1}", { BJILang.get("common.durationModifiers.day") }),
            style = BTN_PRESETS.SUCCESS,
            onClick = function()
                callback(math.clamp(value + (60 * 60 * 24), min, max))
            end
        })
    end
    if showMonth then
        line:btn({
            id = string.var("{1}P1M", { id }),
            label = string.var("+1{1}", { BJILang.get("common.durationModifiers.month") }),
            style = BTN_PRESETS.SUCCESS,
            onClick = function()
                callback(math.clamp(value + (60 * 60 * 24 * 30), min, max))
            end
        })
    end
    line:btnIcon({
        id = string.var("{1}reset", { id }),
        icon = ICONS.refresh,
        style = BTN_PRESETS.WARNING,
        onClick = function()
            callback(resetValue)
        end
    })
        :build()
end

-- TIMER

function TimerCreate()
    return ({
        _timer = hptimer(),
        get = function(self)
            local timeStr = tostring(self._timer):gsub("s", "")
            return math.floor(tonumber(timeStr) or 0)
        end,
        reset = function(self)
            self._timer:stopAndReset()
        end
    })
end

function DrawTimePlayPauseButtons(id, withUpdate)
    LineBuilder()
        :btnIcon({
            id = string.var("{1}-pause", { id }),
            icon = ICONS.pause,
            style = not BJIEnv.Data.timePlay and BTN_PRESETS.ERROR or BTN_PRESETS.INFO,
            coloredIcon = not BJIEnv.Data.timePlay,
            onClick = function()
                local hasRight = BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_ENVIRONMENT_PRESET)
                if hasRight and withUpdate and BJIEnv.Data.timePlay then
                    BJITx.config.env("timePlay", not BJIEnv.Data.timePlay)
                    BJIEnv.Data.timePlay = not BJIEnv.Data.timePlay
                end
            end,
        })
        :btnIcon({
            id = string.var("{1}-play", { id }),
            icon = ICONS.play,
            style = BJIEnv.Data.timePlay and BTN_PRESETS.SUCCESS or BTN_PRESETS.INFO,
            coloredIcon = BJIEnv.Data.timePlay,
            onClick = function()
                local hasRight = BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_ENVIRONMENT_PRESET)
                if hasRight and withUpdate and not BJIEnv.Data.timePlay then
                    BJITx.config.env("timePlay", not BJIEnv.Data.timePlay)
                    BJIEnv.Data.timePlay = not BJIEnv.Data.timePlay
                end
            end,
        })
        :build()
end
