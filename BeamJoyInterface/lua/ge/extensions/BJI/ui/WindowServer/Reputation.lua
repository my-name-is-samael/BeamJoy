local function draw(ctxt)
    if not BJICache.isFirstLoaded(BJICache.CACHES.BJC) then
        LineBuilder()
            :text(BJILang.get("common.loading"))
            :build()
        return
    end

    local labelWidth = 0
    for k in pairs(BJIContext.BJC.Reputation) do
        local label = BJILang.get(string.var("serverConfig.reputation.{1}", { k }))
        local tooltip = BJILang.get(string.var("serverConfig.reputation.{1}Tooltip", { k }), "")
        if #tooltip > 0 then
            label = string.var("{1}{2}", { label, HELPMARKER_TEXT })
        end
        local w = GetColumnTextWidth(label .. ":")
        if w > labelWidth then
            labelWidth = w
        end
    end

    local cols = ColumnsBuilder("reputationSettings", { labelWidth, -1 })
    for k, v in pairs(BJIContext.BJC.Reputation) do
        cols:addRow({
            cells = {
                function()
                    local line = LineBuilder()
                        :text(string.var("{1}:", { BJILang.get(string.var("serverConfig.reputation.{1}", { k })) }))
                    local tooltip = BJILang.get(string.var("serverConfig.reputation.{1}Tooltip", { k }), "")
                    if #tooltip > 0 then
                        line:helpMarker(tooltip)
                    end
                    line:build()
                end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = k,
                            type = "int",
                            value = v,
                            min = 0,
                            step = 1,
                            onUpdate = function(val)
                                BJIContext.BJC.Reputation[k] = val
                                BJITx.config.bjc(string.var("Reputation.{1}", { k }), val)
                            end,
                        })
                        :build()
                end
            }
        })
    end
    cols:build()
end
return draw
