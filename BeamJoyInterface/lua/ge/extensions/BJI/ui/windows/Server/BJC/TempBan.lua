--- gc prevention
local nextValue, invalidRange

return function(ctxt, labels, cache)
    invalidRange = false
    if cache.tempban.maxTime > 0 and cache.tempban.minTime > cache.tempban.maxTime then
        invalidRange = true
    end
    if BeginTable("BJIServerBJCTempBan", {
            { label = "##bjiserverbjctempban-labels" },
            { label = "##bjiserverbjctempban-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        TableNewRow()
        Text(labels.tempban.minTime)
        TooltipText(labels.tempban.zeroTooltip)
        TableNextColumn()
        nextValue = SliderIntPrecision("tempBanMinTime", cache.tempban.minTime, 0,
            cache.tempban.maxOverall, {
                step = 5,
                stepFast = 60,
                disabled = cache.disableInputs,
                inputStyle = invalidRange and BJI.Utils.Style.INPUT_PRESETS.ERROR or nil,
                btnStyle = invalidRange and BJI.Utils.Style.BTN_PRESETS.ERROR or nil,
                formatRender = "%d" .. string.format(" (%s)", cache.tempban.minTimePretty),
            })
        TooltipText(labels.tempban.zeroTooltip)
        nextValue = BJI.Utils.UI.DrawLineDurationModifiers("tempBanMinTime", cache.tempban.minTime, 0,
            cache.tempban.maxOverall, cache.tempban.minDefault, cache.disableInputs) or nextValue
        if nextValue then
            cache.tempban.minTime = nextValue
            cache.tempban.minTimePretty = BJI.Utils.UI.PrettyDelay(cache.tempban.minTime)
        end

        TableNewRow()
        Text(labels.tempban.maxTime)
        TooltipText(labels.tempban.zeroTooltip)
        TableNextColumn()
        nextValue = SliderIntPrecision("tempBanMaxTime", cache.tempban.maxTime, 0, cache.tempban.maxOverall,
            {
                step = 5,
                stepFast = 60,
                disabled = cache.disableInputs,
                inputStyle = invalidRange and BJI.Utils.Style.INPUT_PRESETS.ERROR or nil,
                btnStyle = invalidRange and BJI.Utils.Style.BTN_PRESETS.ERROR or nil,
                formatRender = "%d" .. string.format(" (%s)", cache.tempban.maxTimePretty),
            })
        TooltipText(labels.tempban.zeroTooltip)
        nextValue = BJI.Utils.UI.DrawLineDurationModifiers("tempBanMaxTime", cache.tempban.maxTime, 0,
            cache.tempban.maxOverall, cache.tempban.maxDefault, cache.disableInputs) or nextValue
        if nextValue then
            cache.tempban.maxTime = nextValue
            cache.tempban.maxTimePretty = BJI.Utils.UI.PrettyDelay(cache.tempban.maxTime)
        end

        TableNewRow()
        TableNextColumn()
        if IconButton("tempBanSave", BJI.Utils.Icon.ICONS.save, { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                disabled = cache.disableInputs or invalidRange }) then
            cache.disableInputs = true
            BJI.Tx.config.bjc("TempBan.minTime", cache.tempban.minTime)
            BJI.Tx.config.bjc("TempBan.maxTime", cache.tempban.maxTime)
        end
        TooltipText(labels.buttons.save)
        SameLine()
        if IconButton("tempBanReset", BJI.Utils.Icon.ICONS.refresh,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING, disabled = cache.disableInputs or
                    (BJI.Managers.Context.BJC.TempBan.minTime == cache.tempban.minTime and
                        BJI.Managers.Context.BJC.TempBan.maxTime == cache.tempban.maxTime) }) then
            cache.tempban.minTime = BJI.Managers.Context.BJC.TempBan.minTime
            cache.tempban.maxTime = BJI.Managers.Context.BJC.TempBan.maxTime
            cache.tempban.minTimePretty = BJI.Utils.UI.PrettyDelay(cache.tempban.minTime)
            cache.tempban.maxTimePretty = BJI.Utils.UI.PrettyDelay(cache.tempban.maxTime)
        end
        TooltipText(labels.buttons.resetAll)

        EndTable()
    end
end
