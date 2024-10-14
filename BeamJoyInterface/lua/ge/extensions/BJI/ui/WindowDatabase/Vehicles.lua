local function draw(data)
    local titleWidth = GetColumnTextWidth(BJILang.get("database.vehicles.blacklistedModels") .. ":")

    if not data.models then
        data.models = BJIVeh.getAllVehicleLabels(true)
    end

    local addModelOptions = {}
    local addModelSelected
    local modelWidth = 0
    for model in pairs(data.models) do
        local label = data.models[model]
        local w = GetColumnTextWidth(label)
        if w > modelWidth then
            modelWidth = w
        end

        if not tincludes(BJIContext.Database.Vehicles.ModelBlacklist, model, true) then
            table.insert(addModelOptions, {
                value = model,
                label = label,
            })
            if data.newBlacklistModel == model then
                addModelSelected = addModelOptions[#addModelOptions]
            end
        end
    end
    table.sort(addModelOptions, function(a, b)
        return a.label < b.label
    end)
    if not addModelSelected then
        addModelSelected = addModelOptions[1]
    end
    if addModelSelected.value ~= data.newBlacklistModel then
        data.newBlacklistModel = addModelSelected.value
    end

    local cols = ColumnsBuilder("BJIDatabaseVehiclesBlacklistedModels", { titleWidth, modelWidth, -1 })
    for i, model in ipairs(BJIContext.Database.Vehicles.ModelBlacklist) do
        local label = data.models[model] or model
        cols:addRow({
            cells = {
                i == 1 and function()
                    LineBuilder()
                        :text(BJILang.get("database.vehicles.blacklistedModels") .. ":  ")
                        :build()
                end or nil,
                function()
                    LineBuilder()
                        :text(label)
                        :build()
                end,
                function()
                    LineBuilder()
                        :btnIcon({
                            id = svar("removeBlacklisted-{1}", { model }),
                            icon = ICONS.delete_forever,
                            background = BTN_PRESETS.ERROR,
                            onClick = function()
                                BJITx.database.Vehicle(model, false)
                            end
                        })
                        :build()
                end,
            }
        })
    end
    if #BJIContext.Database.Vehicles.ModelBlacklist == 0 then
        cols:addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(BJILang.get("database.vehicles.blacklistedModels") .. ":  ")
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
                        id = "addBlacklistedModelList",
                        items = addModelOptions,
                        getLabelFn = function(item)
                            return item.label
                        end,
                        value = addModelSelected,
                        onChange = function(item)
                            data.newBlacklistModel = item.value
                        end
                    })
                    :build()
            end,
            function()
                LineBuilder()
                    :btnIcon({
                        id = "addBlacklistedModel",
                        icon = ICONS.addListItem,
                        background = BTN_PRESETS.SUCCESS,
                        onClick = function()
                            BJITx.database.Vehicle(data.newBlacklistModel, true)
                        end
                    })
                    :build()
            end,
        }
    })
    cols:build()
end

return draw
