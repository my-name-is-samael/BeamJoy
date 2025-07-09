local fields = Table({
    { key = "PreparationTimeout", type = "int", min = 5,  max = 180, renderFormat = "%ds", default = 30 },
    { key = "VoteTimeout",        type = "int", min = 5,  max = 180, renderFormat = "%ds", default = 30 },
    { key = "VoteThresholdRatio", type = "int", min = 5,  max = 180, renderFormat = "%d%%", default = 51, multiplier = 100 },
    { key = "GridTimeout",        type = "int", min = 5,  max = 180, renderFormat = "%ds", default = 60 },
    { key = "StartCountdown",     type = "int", min = 10, max = 60,  renderFormat = "%ds", default = 10 },
    { key = "DestroyedTimeout",   type = "int", min = 3,  max = 20,  renderFormat = "%ds", default = 5 },
    { key = "EndTimeout",         type = "int", min = 5,  max = 30,  renderFormat = "%ds", default = 10 },
})
--- gc prevention
local value, nextValue

return function(ctxt, labels)
    if BeginTable("BJIServerBJCDerby", {
            { label = "##bjiserverbjcderby-labels" },
            { label = "##bjiserverbjcderby-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        fields:forEach(function(el)
            TableNewRow()
            Text(labels.derby.keys[el.key])
            TooltipText(labels.derby.keys[el.key .. "Tooltip"])
            TableNextColumn()
            value = BJI.Managers.Context.BJC.Derby[el.key] * (el.multiplier or 1)
            if IconButton(el.key .. "reset", BJI.Utils.Icon.ICONS.refresh,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        disabled = el.default == value }) then
                value = el.default
                BJI.Managers.Context.BJC.Derby[el.key] = value / (el.multiplier or 1)
                BJI.Tx.config.bjc("Derby." .. el.key, BJI.Managers.Context.BJC.Derby[el.key])
            end
            TooltipText(labels.buttons.reset)
            SameLine()
            nextValue = SliderIntPrecision(el.key, value, el.min, el.max,
                { formatRender = el.renderFormat })
            TooltipText(labels.derby.keys[el.key .. "Tooltip"])
            if nextValue then
                value = nextValue
                BJI.Managers.Context.BJC.Derby[el.key] = value / (el.multiplier or 1)
                BJI.Tx.config.bjc("Derby." .. el.key, BJI.Managers.Context.BJC.Derby[el.key])
            end
        end)

        EndTable()
    end
end
