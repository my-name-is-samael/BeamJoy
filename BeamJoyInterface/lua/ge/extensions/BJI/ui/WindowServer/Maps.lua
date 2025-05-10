local function drawNewMap(ctxt)
    local canCreate = #BJIContext.Maps.new > 0 and
        #BJIContext.Maps.newLabel > 0 and
        #BJIContext.Maps.newArchive > 0
    if canCreate then
        for mapName in pairs(BJIContext.Maps.Data) do
            if not table.includes({ "new", "newLabel" }, mapName) and mapName:lower() == BJIContext.Maps.new:lower() then
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
                        :text(string.var("{1}:", { BJILang.get("serverConfig.maps.new.name") }))
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
                        :text(string.var("{1}:", { BJILang.get("serverConfig.maps.label") }))
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
                        :text(string.var("{1}:", { BJILang.get("serverConfig.maps.archive") }))
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
    local mapsList = {}
    for name, map in pairs(BJIContext.Maps.Data) do
        if not table.includes({ "new", "newLabel" }, name) then
            table.insert(mapsList, {
                name = name,
                map = map
            })
        end
    end
    table.sort(mapsList, function(a, b)
        return a.name:lower() < b.name:lower()
    end)
    for _, data in ipairs(mapsList) do
        local valid = #data.map.label > 0 and (not data.map.custom or #data.map.archive > 0)
        local line = LineBuilder()
            :text(string.var("{1}:", { data.name }))
            :text(data.map.custom and
                string.var("({1})", { BJILang.get("votemap.targetMapCustom") }) or
                "", TEXT_COLORS.HIGHLIGHT)
            :btnIconToggle({
                id = string.var("map{1}State", { data.name }),
                icon = data.map.enabled and ICONS.visibility or ICONS.visibility_off,
                state = data.map.enabled == true,
                disabled = BJIContext.UI.mapName == data.name,
                onClick = function()
                    BJITx.config.mapState(data.name, not data.map.enabled)
                    data.map.enabled = not data.map.enabled
                end,
            })
        if data.map.changed then
            line:btnIcon({
                id = string.var("map{1}save", { data.name }),
                icon = ICONS.save,
                style = BTN_PRESETS.SUCCESS,
                disabled = not valid,
                onClick = function()
                    BJITx.config.maps(data.name, data.map.label, data.map.custom and data.map.archive or nil)
                    data.map.changed = false
                end
            })
        end
        if data.map.custom then
            line:btnIcon({
                id = string.var("map{1}delete", { data.name }),
                icon = ICONS.delete_forever,
                style = BTN_PRESETS.ERROR,
                disabled = data.name == BJIContext.UI.mapName,
                onClick = function()
                    BJIContext.Maps.Data[data.name] = nil
                    BJITx.config.maps(data.name)
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
                        :text(string.var("{1}:", { BJILang.get("serverConfig.maps.label") }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :inputString({
                            id = string.var("map{1}label", { data.name }),
                            value = data.map.label,
                            onUpdate = function(val)
                                data.map.label = val
                                data.map.changed = true
                            end
                        })
                        :build()
                end,
                data.map.custom and function()
                end or nil,
            }
        })
        if data.map.custom then
            cols:addRow({
                cells = {
                    function()
                        LineBuilder()
                            :text(string.var("{1}:", { BJILang.get("serverConfig.maps.archive") }))
                            :build()
                    end,
                    function()
                        LineBuilder()
                            :inputString({
                                id = string.var("map{1}archive", { data.name }),
                                value = data.map.archive,
                                onUpdate = function(val)
                                    data.map.archive = val
                                    data.map.changed = true
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
