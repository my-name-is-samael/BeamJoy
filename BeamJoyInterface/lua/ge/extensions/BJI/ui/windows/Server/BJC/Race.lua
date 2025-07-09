local fields = Table({
    { key = "RaceSoloTimeBroadcast", type = "bool", },
    { key = "PreparationTimeout",    type = "int",  min = 5,  max = 120, renderFormat = "%ds",  default = 10 },
    { key = "VoteTimeout",           type = "int",  min = 10, max = 120, renderFormat = "%ds",  default = 30 },
    { key = "VoteThresholdRatio",    type = "int",  min = 1,  max = 100, renderFormat = "%d%%", default = 51, multiplier = 100 },
    {
        key = "GridReadyTimeout",
        type = "int",
        min = 5,
        max = function()
            return
                BJI.Managers.Context.BJC.Race.GridTimeout - 1
        end,
        renderFormat = "%ds",
        default = 10
    },
    {
        key = "GridTimeout",
        type = "int",
        min = function()
            return BJI.Managers
                .Context.BJC.Race.GridReadyTimeout + 1
        end,
        max = 300,
        renderFormat = "%ds",
        default = 60
    },
    { key = "RaceCountdown",  type = "int", min = 10, max = 60, renderFormat = "%ds", default = 10 },
    { key = "FinishTimeout",  type = "int", min = 5,  max = 30, renderFormat = "%ds", default = 5 },
    { key = "RaceEndTimeout", type = "int", min = 5,  max = 30, renderFormat = "%ds", default = 10 },
})
--- gc prevention
local value, nextValue

return function(ctxt, labels)
    if BeginTable("BJIServerBJCRace", {
            { label = "##bjiserverbjcrace-labels" },
            { label = "##bjiserverbjcrace-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        fields:forEach(function(el)
            TableNewRow()
            Text(labels.race.keys[el.key])
            TooltipText(labels.race.keys[el.key .. "Tooltip"])
            TableNextColumn()
            value = BJI.Managers.Context.BJC.Race[el.key]
            if el.type == "bool" then
                if IconButton(el.key, not not value and
                        BJI.Utils.Icon.ICONS.check_circle or BJI.Utils.Icon.ICONS.cancel,
                        { bgLess = true, btnStyle = not not value and
                            BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.WARNING }) then
                    BJI.Managers.Context.BJC.Race[el.key] = not value
                    BJI.Tx.config.bjc("Race." .. el.key, BJI.Managers.Context.BJC.Race[el.key])
                end
                TooltipText(labels.race.keys[el.key .. "Tooltip"])
            else
                value = value * (el.multiplier or 1)
                if IconButton(el.key .. "reset", BJI.Utils.Icon.ICONS.refresh,
                        { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                            disabled = el.default == value }) then
                    value = el.default
                    BJI.Managers.Context.BJC.Race[el.key] = value / (el.multiplier or 1)
                    BJI.Tx.config.bjc("Race." .. el.key, BJI.Managers.Context.BJC.Race[el.key])
                end
                TooltipText(labels.buttons.reset)
                SameLine()
                nextValue = SliderIntPrecision(el.key, value,
                    type(el.min) == "function" and el.min() or el.min,
                    type(el.max) == "function" and el.max() or el.max,
                    { formatRender = el.renderFormat })
                TooltipText(labels.race.keys[el.key .. "Tooltip"])
                if nextValue then
                    value = nextValue
                    BJI.Managers.Context.BJC.Race[el.key] = nextValue / (el.multiplier or 1)
                    BJI.Tx.config.bjc("Race." .. el.key, BJI.Managers.Context.BJC.Race[el.key])
                end
            end
        end)

        EndTable()
    end
end
