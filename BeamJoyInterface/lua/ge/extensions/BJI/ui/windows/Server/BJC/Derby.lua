local fields = Table({
    { key = "PreparationTimeout", type = "int", min = 5,  max = 180, renderFormat = "%ds", default = 60 },
    { key = "StartCountdown",     type = "int", min = 10, max = 60,  renderFormat = "%ds", default = 10 },
    { key = "DestroyedTimeout",   type = "int", min = 3,  max = 20,  renderFormat = "%ds", default = 5 },
    { key = "EndTimeout",         type = "int", min = 5,  max = 30,  renderFormat = "%ds", default = 10 },
})
--- gc prevention
local nextValue

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
            if IconButton(el.key .. "reset", BJI.Utils.Icon.ICONS.refresh,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        disabled = el.default == BJI.Managers.Context.BJC.Derby[el.key] }) then
                BJI.Managers.Context.BJC.Derby[el.key] = el.default
                BJI.Tx.config.bjc("Derby." .. el.key, el.default)
            end
            TooltipText(labels.buttons.reset)
            SameLine()
            nextValue = SliderIntPrecision(el.key, BJI.Managers.Context.BJC.Derby[el.key], el.min, el.max,
                { formatRender = el.renderFormat })
            TooltipText(labels.derby.keys[el.key .. "Tooltip"])
            if nextValue then
                BJI.Managers.Context.BJC.Derby[el.key] = nextValue
                BJI.Tx.config.bjc("Derby." .. el.key, BJI.Managers.Context.BJC.Derby[el.key])
            end
        end)

        EndTable()
    end
end
