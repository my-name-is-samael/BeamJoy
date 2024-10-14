local newModel
return function(ctxt)
    local blackListLabel = BJILang.get("serverConfig.bjc.vehicleDelivery.modelBlacklist")

    local modelLabels = BJIVeh.getAllVehicleLabels()
    local options = {}
    local selected
    local modelWidth = 0
    for model, label in pairs(modelLabels) do
        if not tincludes(BJIContext.BJC.VehicleDelivery.ModelBlacklist, model) then
            table.insert(options, {
                value = model,
                label = label,
            })
            if newModel == model then
                selected = options[#options]
            end
        end
        local w = GetColumnTextWidth("- " .. label)
        if w > modelWidth then
            modelWidth = w
        end
    end
    table.sort(options, function(a, b)
        return a.label:lower() < b.label:lower()
    end)
    if not selected and options[1] then
        selected = options[1]
    end
    if selected and newModel ~= selected.value then
        newModel = selected.value
    end

    local cols = ColumnsBuilder("BJIServerBJCVehicleDeliveryModelBlacklist",
        { GetColumnTextWidth(blackListLabel), modelWidth, -1 })
    for i, model in ipairs(BJIContext.BJC.VehicleDelivery.ModelBlacklist) do
        cols:addRow({
            cells = {
                function()
                    if i == 1 then
                        LineBuilder()
                            :text(blackListLabel,
                                #options == 0 and TEXT_COLORS.ERROR or TEXT_COLORS.DEFAULT)
                            :build()
                    end
                end,
                function()
                    LineBuilder()
                        :text(svar("- {1}", { modelLabels[model] or model }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :btnIcon({
                            id = svar("removeVehDeliveryBlackListModel{1}", { model }),
                            icon = ICONS.delete_forever,
                            background = BTN_PRESETS.ERROR,
                            onClick = function()
                                table.remove(BJIContext.BJC.VehicleDelivery.ModelBlacklist, i)
                                BJITx.config.bjc("VehicleDelivery.ModelBlacklist",
                                    BJIContext.BJC.VehicleDelivery.ModelBlacklist)
                            end
                        })
                        :build()
                end,
            }
        })
    end
    if #BJIContext.BJC.VehicleDelivery.ModelBlacklist == 0 then
        cols:addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(blackListLabel)
                        :build()
                end,
                function()
                    LineBuilder()
                        :text("/")
                        :build()
                end,
            }
        })
    end
    cols:addRow({
        cells = {
            nil,
            function()
                LineBuilder()
                    :inputCombo({
                        id = "newVehDeliveryBlackListModel",
                        items = options,
                        getLabelFn = function(item)
                            return item.label
                        end,
                        value = selected,
                        onChange = function(item)
                            newModel = item.value
                        end,
                    })
                    :build()
            end,
            function()
                LineBuilder()
                    :btnIcon({
                        id = "addVehDeliveryBlackListModel",
                        icon = ICONS.addListItem,
                        background = BTN_PRESETS.SUCCESS,
                        disabled = #options <= 1,
                        onClick = function()
                            table.insert(BJIContext.BJC.VehicleDelivery.ModelBlacklist, newModel)
                            BJITx.config.bjc("VehicleDelivery.ModelBlacklist",
                                BJIContext.BJC.VehicleDelivery.ModelBlacklist)
                        end
                    })
                    :build()
            end,
        }
    })
        :build()
end
