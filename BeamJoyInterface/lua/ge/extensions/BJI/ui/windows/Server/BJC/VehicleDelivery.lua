local newModel
return function(ctxt, labels, cache)
    LineLabel(labels.vehicleDelivery.modelBlacklist)
    LineBuilder()
        :btnIcon({
            id = "addVehDeliveryBlackListModel",
            icon = BJI.Utils.Icon.ICONS.add,
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            disabled = cache.disableInputs or #cache.vehicleDelivery.modelsCombo <= 1,
            tooltip = labels.vehicleDelivery.add,
            onClick = function()
                cache.disableInputs = true
                table.insert(BJI.Managers.Context.BJC.VehicleDelivery.ModelBlacklist,
                    cache.vehicleDelivery.selectedModel.value)
                BJI.Tx.config.bjc("VehicleDelivery.ModelBlacklist",
                    BJI.Managers.Context.BJC.VehicleDelivery.ModelBlacklist)
            end
        })
        :inputCombo({
            id = "newVehDeliveryBlackListModel",
            items = cache.vehicleDelivery.modelsCombo,
            getLabelFn = function(item)
                return item.label
            end,
            value = cache.vehicleDelivery.selectedModel,
            onChange = function(item)
                cache.vehicleDelivery.selectedModel = item
            end,
        })
        :build()

    Table(cache.vehicleDelivery.displayList):forEach(function(v)
        LineBuilder()
            :btnIcon({
                id = string.var("removeVehDeliveryBlackListModel{1}", { v.model }),
                icon = BJI.Utils.Icon.ICONS.delete_forever,
                style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                disabled = cache.disableInputs,
                tooltip = labels.vehicleDelivery.remove,
                onClick = function()
                    cache.disableInputs = true
                    table.remove(BJI.Managers.Context.BJC.VehicleDelivery.ModelBlacklist,
                        table.indexOf(BJI.Managers.Context.BJC.VehicleDelivery.ModelBlacklist, v.model))
                    BJI.Tx.config.bjc("VehicleDelivery.ModelBlacklist",
                        BJI.Managers.Context.BJC.VehicleDelivery.ModelBlacklist)
                end
            })
            :text(v.label)
            :build()
    end)
end
