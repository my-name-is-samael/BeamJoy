return function(ctxt)
    local fields = {
        { key = "PreparationTimeout",  type = "int", step = 1, min = 5, max = 120, },
        { key = "HuntedStartDelay",    type = "int", step = 1, min = 0, max = 30, },
        { key = "HuntersStartDelay",   type = "int", step = 1, min = 0, max = 60, },
        { key = "HuntedStuckTimeout",  type = "int", step = 1, min = 3, max = 30, },
        { key = "HuntersRespawnDelay", type = "int", step = 1, min = 0, max = 300, },
    }

    local labelWidth = 0
    for _, v in ipairs(fields) do
        local w = GetColumnTextWidth(BJILang.get(string.var("serverConfig.bjc.hunter.{1}",
            { v.key })) .. HELPMARKER_TEXT)
        if w > labelWidth then
            labelWidth = w
        end
    end

    local cols = ColumnsBuilder("bjcHunter", { labelWidth, -1 })
    for _, v in ipairs(fields) do
        cols = cols:addRow({
            cells = {
                function()
                    local line = LineBuilder()
                        :text(BJILang.get(string.var("serverConfig.bjc.hunter.{1}", { v.key })))
                    local tooltip = BJILang.get(string.var("serverConfig.bjc.hunter.{1}Tooltip", { v.key }), "")
                    if #tooltip > 0 then
                        line:helpMarker(tooltip)
                    end
                    line:build()
                end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = v.key,
                            type = v.type,
                            value = BJIContext.BJC.Hunter[v.key],
                            min = v.min,
                            max = v.max,
                            step = v.step,
                            onUpdate = function(val)
                                BJIContext.BJC.Hunter[v.key] = val
                                BJITx.config.bjc(string.var("Hunter.{1}", { v.key }), val)
                            end
                        })
                        :build()
                end
            }
        })
    end
    cols:build()
end
