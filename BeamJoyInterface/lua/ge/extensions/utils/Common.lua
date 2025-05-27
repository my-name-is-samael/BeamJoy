local U = {}

---@param text string
---@return integer
function U.GetTextWidth(text)
    if type(text) ~= "string" then
        return 0
    end
    return math.round(ui_imgui.CalcTextSize(text).x * (BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.UI_SCALE) or 1))
end

local function getColumnsMargin()
    return U.GetTextWidth("  ")
end

---@param text string
---@return integer
function U.GetColumnTextWidth(text)
    return U.GetTextWidth(text) + getColumnsMargin()
end

---@param content any
---@param typeNumber? boolean
---@return integer
function U.GetInputWidthByContent(content, typeNumber)
    local inputOffset = 4 + (typeNumber and 50 or 0)
    return U.GetTextWidth(tostring(content)) + inputOffset
end

---@param secs number
---@return string
function U.PrettyDelay(secs)
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
        local monthLabel = BJI.Managers.Lang.get("common.time.months")
        return string.var("{months} {monthLabel}", { months = months, monthLabel = monthLabel })
    elseif months == 1 then
        local monthLabel = BJI.Managers.Lang.get("common.time.month")
        local dayLabel = BJI.Managers.Lang.get("common.time.day")
        local andLabel = BJI.Managers.Lang.get("common.time.and")
        if days > 1 then
            dayLabel = BJI.Managers.Lang.get("common.time.days")
        end
        if days > 0 then
            return string.var("{months} {monthLabel} {andLabel} {days} {dayLabel}",
                { months = months, monthLabel = monthLabel, andLabel = andLabel, days = days, dayLabel = dayLabel })
        else
            return string.var("{months} {monthLabel}", { months = months, monthLabel = monthLabel })
        end
    end

    if days > 1 then
        local dayLabel = BJI.Managers.Lang.get("common.time.days")
        return string.var("{days} {dayLabel}", { days = days, dayLabel = dayLabel })
    elseif days == 1 then
        local dayLabel = BJI.Managers.Lang.get("common.time.day")
        local hourLabel = BJI.Managers.Lang.get("common.time.hour")
        local andLabel = BJI.Managers.Lang.get("common.time.and")
        if hours > 1 then
            hourLabel = BJI.Managers.Lang.get("common.time.hours")
        end
        if hours > 0 then
            return string.var("{days} {dayLabel} {andLabel} {hours} {hourLabel}",
                { days = days, dayLabel = dayLabel, andLabel = andLabel, hours = hours, hourLabel = hourLabel })
        else
            return string.var("{days} {dayLabel}", { days = days, dayLabel = dayLabel })
        end
    end

    if hours > 1 then
        local hourLabel = BJI.Managers.Lang.get("common.time.hours")
        return string.var("{hours} {hourLabel}", { hours = hours, hourLabel = hourLabel })
    elseif hours == 1 then
        local hourLabel = BJI.Managers.Lang.get("common.time.hour")
        local minuteLabel = BJI.Managers.Lang.get("common.time.minute")
        local andLabel = BJI.Managers.Lang.get("common.time.and")
        if mins > 1 then
            minuteLabel = BJI.Managers.Lang.get("common.time.minutes")
        end
        if mins > 0 then
            return string.var("{hours} {hourLabel} {andLabel} {mins} {minuteLabel}",
                { hours = hours, hourLabel = hourLabel, andLabel = andLabel, mins = mins, minuteLabel = minuteLabel })
        else
            return string.var("{hours} {hourLabel}", { hours = hours, hourLabel = hourLabel })
        end
    end

    if mins > 1 then
        local minLabel = BJI.Managers.Lang.get("common.time.minutes")
        return string.var("{mins} {minLabel}", { mins = mins, minLabel = minLabel })
    elseif mins == 1 then
        local minLabel = BJI.Managers.Lang.get("common.time.minute")
        local secLabel = BJI.Managers.Lang.get("common.time.second")
        local andLabel = BJI.Managers.Lang.get("common.time.and")
        if secs > 0 then
            return string.var("{mins} {minLabel} {andLabel} {secs} {secLabel}",
                { mins = mins, minLabel = minLabel, andLabel = andLabel, secs = secs, secLabel = secLabel })
        else
            return string.var("{mins} {minLabel}", { mins = mins, minLabel = minLabel })
        end
    end

    local secondLabel = BJI.Managers.Lang.get("common.time.second")
    if secs > 1 then
        secondLabel = BJI.Managers.Lang.get("common.time.seconds")
    end
    return string.var("{secs} {secondLabel}", { secs = secs, secondLabel = secondLabel })
end

---@param ms integer
---@return string
function U.RaceDelay(ms)
    ms = math.round(ms or 0)
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

---@param meter? number
---@return string
function U.PrettyDistance(meter)
    meter = tonumber(meter)
    if not meter then
        return "0m"
    end
    if settings.getValue("uiUnitLength") == "imperial" then
        local foot = meter * 3.28084
        local miles = foot / 5280
        if miles >= .5 then
            return string.var("{1}mi", { math.round(miles, 1) })
        else
            return string.var("{1}ft", { math.round(foot) })
        end
    else
        local kms = meter / 1000
        if kms >= .5 then
            return string.var("{1}km", { math.round(kms, 1) })
        else
            return string.var("{1}m", { math.round(meter) })
        end
    end
end

---@param ToD integer
---@return string
function U.PrettyTime(ToD)
    local secs = ToD * 86400
    if ToD >= 0 and ToD < .5 then
        secs = secs + 43200
    elseif ToD >= .5 and ToD <= 1 then
        secs = secs - 43200
    end
    local curHours = math.floor(secs / 3600)
    secs = secs - curHours * 3600
    local curMins = math.floor(secs / 60)
    return string.format("%02d:%02d", curHours, curMins)
end

---@param id string
---@param value integer
---@param min? integer
---@param max? integer
---@param resetValue integer
---@param callback function
---@param disabled? boolean
function U.DrawLineDurationModifiers(id, value, min, max, resetValue, callback, disabled)
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
            label = string.var("-1{1}", { BJI.Managers.Lang.get("common.durationModifiers.month") }),
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            disabled = disabled,
            onClick = function()
                callback(math.clamp(value - (60 * 60 * 24 * 30), min, max))
            end
        })
    end
    if showDay then
        line:btn({
            id = string.var("{1}M1d", { id }),
            label = string.var("-1{1}", { BJI.Managers.Lang.get("common.durationModifiers.day") }),
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            disabled = disabled,
            onClick = function()
                callback(math.clamp(value - (60 * 60 * 24), min, max))
            end
        })
    end
    if showHour then
        line:btn({
            id = string.var("{1}M1h", { id }),
            label = string.var("-1{1}", { BJI.Managers.Lang.get("common.durationModifiers.hour") }),
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            disabled = disabled,
            onClick = function()
                callback(math.clamp(value - (60 * 60), min, max))
            end
        })
    end
    line:btn({
        id = string.var("{1}M1m", { id }),
        label = string.var("-1{1}", { BJI.Managers.Lang.get("common.durationModifiers.minute") }),
        style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            disabled = disabled,
        onClick = function()
            callback(math.clamp(value - 60, min, max))
        end
    })
        :btn({
            id = string.var("{1}P1m", { id }),
            label = string.var("+1{1}", { BJI.Managers.Lang.get("common.durationModifiers.minute") }),
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            disabled = disabled,
            onClick = function()
                callback(math.clamp(value + 60, min, max))
            end
        })
    if showHour then
        line:btn({
            id = string.var("{1}P1h", { id }),
            label = string.var("+1{1}", { BJI.Managers.Lang.get("common.durationModifiers.hour") }),
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            disabled = disabled,
            onClick = function()
                callback(math.clamp(value + (60 * 60), min, max))
            end
        })
    end
    if showDay then
        line:btn({
            id = string.var("{1}P1d", { id }),
            label = string.var("+1{1}", { BJI.Managers.Lang.get("common.durationModifiers.day") }),
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            disabled = disabled,
            onClick = function()
                callback(math.clamp(value + (60 * 60 * 24), min, max))
            end
        })
    end
    if showMonth then
        line:btn({
            id = string.var("{1}P1M", { id }),
            label = string.var("+1{1}", { BJI.Managers.Lang.get("common.durationModifiers.month") }),
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            disabled = disabled,
            onClick = function()
                callback(math.clamp(value + (60 * 60 * 24 * 30), min, max))
            end
        })
    end
    line:btnIcon({
        id = string.var("{1}reset", { id }),
        icon = ICONS.refresh,
        style = BJI.Utils.Style.BTN_PRESETS.WARNING,
            disabled = disabled,
        tooltip = BJI.Managers.Lang.get("common.buttons.reset"),
        onClick = function()
            callback(resetValue)
        end
    })
        :build()
end

---@param id string
---@param withUpdate? boolean
---@param disabled? boolean
function U.DrawTimePlayPauseButtons(id, withUpdate, disabled)
    LineBuilder()
        :btnIcon({
            id = string.var("{1}-pause", { id }),
            icon = ICONS.pause,
            style = not BJI.Managers.Env.Data.timePlay and BJI.Utils.Style.BTN_PRESETS.ERROR or BJI.Utils.Style.BTN_PRESETS.INFO,
            coloredIcon = not BJI.Managers.Env.Data.timePlay,
            disabled = disabled,
            tooltip = BJI.Managers.Lang.get("common.buttons.stop"),
            onClick = function()
                local hasRight = BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SET_ENVIRONMENT_PRESET)
                if hasRight and withUpdate and BJI.Managers.Env.Data.timePlay then
                    BJI.Tx.config.env("timePlay", not BJI.Managers.Env.Data.timePlay)
                    BJI.Managers.Env.Data.timePlay = not BJI.Managers.Env.Data.timePlay
                end
            end,
        })
        :btnIcon({
            id = string.var("{1}-play", { id }),
            icon = ICONS.play,
            style = BJI.Managers.Env.Data.timePlay and BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.INFO,
            coloredIcon = BJI.Managers.Env.Data.timePlay,
            disabled = disabled,
            tooltip = BJI.Managers.Lang.get("common.buttons.play"),
            onClick = function()
                local hasRight = BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SET_ENVIRONMENT_PRESET)
                if hasRight and withUpdate and not BJI.Managers.Env.Data.timePlay then
                    BJI.Tx.config.env("timePlay", not BJI.Managers.Env.Data.timePlay)
                    BJI.Managers.Env.Data.timePlay = not BJI.Managers.Env.Data.timePlay
                end
            end,
        })
        :build()
end

return U