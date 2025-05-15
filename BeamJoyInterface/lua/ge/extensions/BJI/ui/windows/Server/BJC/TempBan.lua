return function(ctxt, labels, cache)
    LineBuilder()
        :text(labels.tempban.minTime)
        :helpMarker(labels.tempban.zeroTooltip)
        :inputNumeric({
            id = "tempbanMinTime",
            type = "int",
            value = BJI.Managers.Context.BJC.TempBan.minTime,
            min = 0,
            step = 5,
            stepFast = 60,
            width = 120,
            onUpdate = function(val)
                BJI.Managers.Context.BJC.TempBan.minTime = val
            end
        })
        :text(cache.tempban.minTimePretty)
        :build()
    BJI.Utils.Common.DrawLineDurationModifiers("tempBanMinTime", BJI.Managers.Context.BJC.TempBan.minTime, 0, nil, 300,
        function(val)
            BJI.Managers.Context.BJC.TempBan.minTime = val
            cache.tempban.minTimePretty = BJI.Utils.Common.PrettyDelay(val)
        end, cache.disableInputs)

    LineBuilder()
        :text(labels.tempban.maxTime)
        :helpMarker(labels.tempban.zeroTooltip)
        :inputNumeric({
            id = "tempbanMaxTime",
            type = "int",
            value = BJI.Managers.Context.BJC.TempBan.maxTime,
            min = 0,
            step = 5,
            stepFast = 60,
            width = 120,
            onUpdate = function(val)
                BJI.Managers.Context.BJC.TempBan.maxTime = val
            end
        })
        :text(cache.tempban.maxTimePretty)
        :build()
    BJI.Utils.Common.DrawLineDurationModifiers("tempBanMaxTime", BJI.Managers.Context.BJC.TempBan.maxTime, 0, nil,
        31536000, function(val)
            BJI.Managers.Context.BJC.TempBan.maxTime = val
            cache.tempban.maxTimePretty = BJI.Utils.Common.PrettyDelay(val)
        end, cache.disableInputs)

    local canSave =
        LineBuilder()
        :btnIcon({
            id = "tempBanLimitsSave",
            icon = ICONS.save,
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            disabled = cache.disableInputs or
                BJI.Managers.Context.BJC.TempBan.minTime < 0 or
                BJI.Managers.Context.BJC.TempBan.maxTime < 0 or
                BJI.Managers.Context.BJC.TempBan.minTime > BJI.Managers.Context.BJC.TempBan.maxTime,
            onClick = function()
                cache.disableInputs = true
                BJI.Tx.config.bjc("TempBan.minTime", BJI.Managers.Context.BJC.TempBan.minTime)
                BJI.Tx.config.bjc("TempBan.maxTime", BJI.Managers.Context.BJC.TempBan.maxTime)
            end
        })
end
