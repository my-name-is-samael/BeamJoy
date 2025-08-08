local fields = Table({
    { key = "PreparationTimeout",            type = "int", min = 5, max = 180, renderFormat = "%ds",  default = 30 },
    { key = "VoteTimeout",                   type = "int", min = 5, max = 180, renderFormat = "%ds",  default = 30 },
    { key = "VoteThresholdRatio",            type = "int", min = 1, max = 100, renderFormat = "%d%%", default = 51, multiplier = 100 },
    { key = "GridTimeout",                   type = "int", min = 5, max = 180, renderFormat = "%ds",  default = 60 },
    { key = "SurvivorsStartDelay",           type = "int", min = 0, max = 60,  renderFormat = "%ds",  default = 5 },
    { key = "InfectedStartDelay",            type = "int", min = 0, max = 60,  renderFormat = "%ds",  default = 10 },
    { key = "EndTimeout",                    type = "int", min = 5, max = 30,  renderFormat = "%ds",  default = 10 },
})
--- gc prevention
local value, nextValue

return function(ctxt, labels)
    if BeginTable("BJIServerBJCInfected", {
            { label = "##bjiserverbjcinfected-labels" },
            { label = "##bjiserverbjcinfected-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        fields:forEach(function(el)
            TableNewRow()
            Text(labels.infected.keys[el.key])
            TooltipText(labels.infected.keys[el.key .. "Tooltip"])
            TableNextColumn()
            value = BJI_Context.BJC.Infected[el.key] * (el.multiplier or 1)
            if IconButton(el.key .. "reset", BJI.Utils.Icon.ICONS.refresh,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        disabled = el.default == value }) then
                value = el.default
                BJI_Context.BJC.Infected[el.key] = value / (el.multiplier or 1)
                BJI_Tx_config.bjc("Infected." .. el.key, BJI_Context.BJC.Infected[el.key])
            end
            TooltipText(labels.buttons.reset)
            SameLine()
            nextValue = SliderIntPrecision(el.key, value, el.min, el.max,
                { formatRender = el.renderFormat })
            TooltipText(labels.infected.keys[el.key .. "Tooltip"])
            if nextValue then
                value = nextValue
                BJI_Context.BJC.Infected[el.key] = value / (el.multiplier or 1)
                BJI_Tx_config.bjc("Infected." .. el.key, BJI_Context.BJC.Infected[el.key])
            end
        end)

        EndTable()
    end
end
