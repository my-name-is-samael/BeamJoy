local fields = Table({
    { key = "PreparationTimeout", type = "int", min = 5,  max = 120, renderFormat = "%ds",    default = 10 },
    { key = "VoteTimeout",        type = "int", min = 5,  max = 120, renderFormat = "%ds",    default = 30 },
    { key = "BaseSpeed",          type = "int", min = 20, max = 100, renderFormat = "%dkm/h", default = 30 },
    { key = "StepSpeed",          type = "int", min = 1,  max = 50,  renderFormat = "%dkm/h", default = 5 },
    { key = "StepDelay",          type = "int", min = 2,  max = 30,  renderFormat = "%ds",    default = 10 },
    { key = "EndTimeout",         type = "int", min = 5,  max = 30,  renderFormat = "%ds",    default = 10 },
})
--- gc prevention
local nextValue

return function(ctxt, labels)
    if BeginTable("BJIServerBJCSpeed", {
            { label = "##bjiserverbjcspeed-labels" },
            { label = "##bjiserverbjcspeed-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        fields:forEach(function(el)
            TableNewRow()
            Text(labels.speed.keys[el.key])
            TooltipText(labels.speed.keys[el.key .. "Tooltip"])
            TableNextColumn()
            if IconButton(el.key .. "reset", BJI.Utils.Icon.ICONS.refresh,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                disabled = el.default == BJI.Managers.Context.BJC.Speed[el.key] }) then
                BJI.Managers.Context.BJC.Speed[el.key] = el.default
                BJI.Tx.config.bjc("Speed." .. el.key, el.default)
            end
            TooltipText(labels.buttons.reset)
            SameLine()
            nextValue = SliderIntPrecision(el.key, BJI.Managers.Context.BJC.Speed[el.key], el.min, el.max,
                { formatRender = el.renderFormat })
            TooltipText(labels.speed.keys[el.key .. "Tooltip"])
            if nextValue then
                BJI.Managers.Context.BJC.Speed[el.key] = nextValue
                BJI.Tx.config.bjc("Speed." .. el.key, BJI.Managers.Context.BJC.Speed[el.key])
            end
        end)

        EndTable()
    end
end
