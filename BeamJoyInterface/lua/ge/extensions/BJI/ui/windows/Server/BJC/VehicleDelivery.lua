--- gc prevention
local nextValue

return function(ctxt, labels, cache)
    if BeginTable("BJIServerBJCVehicleDelivery", {
            { label = "##bjiserverbjcvehdelivery-labels" },
            { label = "##bjiserverbjcvehdelivery-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        TableNewRow()
        Text(labels.vehicleDelivery.modelBlacklist)
        TableNextColumn()
        if IconButton("addVehDeliveryBlackListModel", BJI.Utils.Icon.ICONS.add,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                    disabled = cache.disableInputs or #cache.vehicleDelivery.modelsCombo <= 1 }) then
            cache.disableInputs = true
            table.insert(BJI.Managers.Context.BJC.VehicleDelivery.ModelBlacklist,
                cache.vehicleDelivery.selectedModel)
            BJI.Tx.config.bjc("VehicleDelivery.ModelBlacklist",
                BJI.Managers.Context.BJC.VehicleDelivery.ModelBlacklist)
        end
        TooltipText(labels.vehicleDelivery.add)
        SameLine()
        nextValue = Combo("newVehDeliveryBlackListModel", cache.vehicleDelivery.selectedModel,
            cache.vehicleDelivery.modelsCombo, { width = -1 })
        if nextValue then cache.vehicleDelivery.selectedModel = nextValue end

        cache.vehicleDelivery.displayList:forEach(function(v)
            TableNewRow()
            TableNextColumn()
            if IconButton("removeVehDeliveryBlackListModel-" .. v.model, BJI.Utils.Icon.ICONS.delete_forever,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = cache.disableInputs }) then
                cache.disableInputs = true
                table.remove(BJI.Managers.Context.BJC.VehicleDelivery.ModelBlacklist,
                    table.indexOf(BJI.Managers.Context.BJC.VehicleDelivery.ModelBlacklist, v.model))
                BJI.Tx.config.bjc("VehicleDelivery.ModelBlacklist",
                    BJI.Managers.Context.BJC.VehicleDelivery.ModelBlacklist)
            end
            TooltipText(labels.vehicleDelivery.remove)
            SameLine()
            Text(v.label)
        end)

        EndTable()
    end
end
