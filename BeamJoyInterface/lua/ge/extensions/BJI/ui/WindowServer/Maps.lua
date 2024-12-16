local function drawNewMap(ctxt)
    local canCreate = #BJIContext.Maps.new > 0 and
        #BJIContext.Maps.newLabel > 0 and
        #BJIContext.Maps.newArchive > 0
    if canCreate then
        for mapName in pairs(BJIContext.Maps.Data) do
            if not tincludes({ "new", "newLabel" }, mapName) and mapName:lower() == BJIContext.Maps.new:lower() then
                canCreate = false
                break
            end
        end
    end

    LineBuilder()
        :text(BJILang.get("serverConfig.maps.new.title"))
        :btnIcon({
            id = "addNewMap",
            icon = ICONS.save,
            style = BTN_PRESETS.SUCCESS,
            disabled = not canCreate,
            onClick = function()
                BJITx.config.maps(
                    BJIContext.Maps.new,
                    BJIContext.Maps.newLabel,
                    BJIContext.Maps.newArchive
                )
                BJIContext.Maps.new = ""
                BJIContext.Maps.newLabel = ""
                BJIContext.Maps.newArchive = ""
            end
        })
        :build()
    Indent(2)

    local labelWidth = 0
    for _, label in ipairs({
        "serverConfig.maps.new.name",
        "serverConfig.maps.label",
        "serverConfig.maps.archive",
    }) do
        local w = GetColumnTextWidth(BJILang.get(label) .. ":")
        if w > labelWidth then
            labelWidth = w
        end
    end
    ColumnsBuilder("newMap", { labelWidth, -1 })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("serverConfig.maps.new.name") }))
                        :helpMarker(BJILang.get("serverConfig.maps.new.nameTooltip"))
                        :build()
                end,
                function()
                    LineBuilder()
                        :inputString({
                            id = "new",
                            value = BJIContext.Maps.new,
                            size = BJIContext.Maps.new._size,
                            onUpdate = function(val)
                                BJIContext.Maps.new = val
                            end
                        })
                        :build()
                end
            }
        })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("serverConfig.maps.label") }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :inputString({
                            id = "newLabel",
                            value = BJIContext.Maps.newLabel,
                            onUpdate = function(val)
                                BJIContext.Maps.newLabel = val
                            end
                        })
                        :build()
                end
            }
        })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("serverConfig.maps.archive") }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :inputString({
                            id = "newArchive",
                            value = BJIContext.Maps.newArchive,
                            onUpdate = function(val)
                                BJIContext.Maps.newArchive = val
                            end
                        })
                        :build()
                end
            }
        })
        :build()


    Indent(-2)
end

local function drawMapsList(ctxt)
    local labelWidth = 0
    for _, key in ipairs({ "serverConfig.maps.label", "serverConfig.maps.archive" }) do
        local label = BJILang.get(key)
        local w = GetColumnTextWidth(label .. ":")
        if w > labelWidth then
            labelWidth = w
        end
    end
    for techName, map in pairs(BJIContext.Maps.Data) do
        local valid = #map.label > 0 and (not map.custom or #map.archive > 0)
        local line = LineBuilder()
            :text(svar("{1}:", { techName }))
            :text(map.custom and
                svar("({1})", { BJILang.get("votemap.targetMapCustom") }) or
                "", TEXT_COLORS.HIGHLIGHT)
            :btnIconToggle({
                id = svar("map{1}State", { techName }),
                icon = map.enabled and ICONS.visibility or ICONS.visibility_off,
                state = map.enabled,
                disabled = BJIContext.UI.mapName == techName,
                onClick = function()
                    BJITx.config.mapState(techName, not map.enabled)
                    map.enabled = not map.enabled
                end,
            })
        if map.changed then
            line:btnIcon({
                id = svar("map{1}save", { techName }),
                icon = ICONS.save,
                style = BTN_PRESETS.SUCCESS,
                disabled = not valid,
                onClick = function()
                    BJITx.config.maps(techName, map.label, map.custom and map.archive or nil)
                    map.changed = false
                end
            })
        end
        if map.custom then
            line:btnIcon({
                id = svar("map{1}delete", { techName }),
                icon = ICONS.delete_forever,
                style = BTN_PRESETS.ERROR,
                disabled = techName == BJIContext.UI.mapName,
                onClick = function()
                    BJIContext.Maps.Data[techName] = nil
                    BJITx.config.maps(techName)
                end
            })
        end
        line:build()
        Indent(2)
        local cols = ColumnsBuilder("mapsList", { labelWidth, -1 })
        cols:addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("serverConfig.maps.label") }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :inputString({
                            id = svar("map{1}label", { techName }),
                            value = map.label,
                            onUpdate = function(val)
                                map.label = val
                                map.changed = true
                            end
                        })
                        :build()
                end,
                map.custom and function()
                end or nil,
            }
        })
        if map.custom then
            cols:addRow({
                cells = {
                    function()
                        LineBuilder()
                            :text(svar("{1}:", { BJILang.get("serverConfig.maps.archive") }))
                            :build()
                    end,
                    function()
                        LineBuilder()
                            :inputString({
                                id = svar("map{1}archive", { techName }),
                                value = map.archive,
                                onUpdate = function(val)
                                    map.archive = val
                                    map.changed = true
                                end
                            })
                            :build()
                    end
                }
            })
        end
        cols:build()
        Indent(-2)
    end
end

local function draw(ctxt)
    drawMapsList(ctxt)
    drawNewMap(ctxt)
end
return draw
