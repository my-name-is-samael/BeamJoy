local fields = Table({
    { key = "PreparationTimeout",            type = "int", min = 5, max = 180, renderFormat = "%ds", default = 30 },
    { key = "HuntedStartDelay",              type = "int", min = 0, max = 60,  renderFormat = "%ds", default = 5 },
    { key = "HuntersStartDelay",             type = "int", min = 0, max = 60,  renderFormat = "%ds", default = 10 },
    { key = "HuntedStuckTimeout",            type = "int", min = 3, max = 20,  renderFormat = "%ds", default = 10 },
    { key = "HuntersRespawnDelay",           type = "int", min = 0, max = 60,  renderFormat = "%ds", default = 10 },
    { key = "HuntedResetRevealDuration",     type = "int", min = 0, max = 30,  renderFormat = "%ds", default = 5 },
    { key = "HuntedRevealProximityDistance", type = "int", min = 0, max = 500, renderFormat = "%dm", default = 50 },
    { key = "HuntedResetDistanceThreshold",  type = "int", min = 0, max = 500, renderFormat = "%dm", default = 150 },
    { key = "EndTimeout",                    type = "int", min = 5, max = 30,  renderFormat = "%ds", default = 10 },
})
--- gc prevention
local nextValue

return function(ctxt, labels)
    if BeginTable("BJIServerBJCHunter", {
            { label = "##bjiserverbjchunter-labels" },
            { label = "##bjiserverbjchunter-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        fields:forEach(function(el)
            TableNewRow()
            Text(labels.hunter.keys[el.key])
            TooltipText(labels.hunter.keys[el.key .. "Tooltip"])
            TableNextColumn()
            if IconButton(el.key .. "reset", BJI.Utils.Icon.ICONS.refresh,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        disabled = el.default == BJI.Managers.Context.BJC.Hunter[el.key] }) then
                BJI.Managers.Context.BJC.Hunter[el.key] = el.default
                BJI.Tx.config.bjc("Hunter." .. el.key, el.default)
            end
            TooltipText(labels.buttons.reset)
            SameLine()
            nextValue = SliderIntPrecision(el.key, BJI.Managers.Context.BJC.Hunter[el.key], el.min, el.max,
                { formatRender = el.renderFormat })
            TooltipText(labels.hunter.keys[el.key .. "Tooltip"])
            if nextValue then
                BJI.Managers.Context.BJC.Hunter[el.key] = nextValue
                BJI.Tx.config.bjc("Hunter." .. el.key, BJI.Managers.Context.BJC.Hunter[el.key])
            end
        end)

        EndTable()
    end
end
