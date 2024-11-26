local function drawCoreConfig(ctxt)
    LineBuilder()
        :text(svar("{1}:", { BJILang.get("serverConfig.core.title") }))
        :build()

    local labelWidth = 0
    for k in pairs(BJIContext.Core) do
        local label = svar(BJILang.get(svar("serverConfig.core.{1}", { k })))
        local w = GetColumnTextWidth(label .. ":")
        if w > labelWidth then
            labelWidth = w
        end
    end
    Indent(2)
    local cols = ColumnsBuilder("CoreSettings", { labelWidth, -1 })
    for k, v in pairs(BJIContext.Core) do
        cols:addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { svar(BJILang.get(svar("serverConfig.core.{1}", { k }))) }))
                        :build()
                end,
                function()
                    if tincludes({ "Tags", "Description" }, k) then
                        LineBuilder()
                            :inputString({
                                id = svar("core{1}", { k }),
                                value = v,
                                multiline = true,
                                autoheight = true,
                                onUpdate = function(val)
                                    BJIContext.Core[k] = val
                                    BJITx.config.core(k, val)
                                end
                            })
                            :build()
                    else
                        local line = LineBuilder()
                        if type(v) == "boolean" then
                            line:btnSwitchEnabledDisabled({
                                id = "core" .. k,
                                state = v,
                                onClick = function()
                                    BJITx.config.core(k, not v)
                                end
                            })
                        elseif type(v) == "number" then
                            line:inputNumeric({
                                id = "core" .. k,
                                type = "int",
                                value = v,
                                step = 1,
                                min = 0,
                                onUpdate = function(val)
                                    BJIContext.Core[k] = val
                                    BJITx.config.core(k, val)
                                end
                            })
                        elseif type(v) == "string" then
                            line:inputString({
                                id = "core" .. k,
                                value = v,
                                onUpdate = function(val)
                                    BJIContext.Core[k] = val
                                    BJITx.config.core(k, val)
                                end
                            })
                        else
                            line:text(v)
                        end
                        line:build()
                    end
                end
            }
        })
    end
    cols:build()
    Indent(-2)
end

local function drawCEN(ctxt)
    LineBuilder()
        :text(svar("{1}:", { BJILang.get("serverConfig.cen.title") }))
        :helpMarker(BJILang.get("serverConfig.cen.tooltip"))
        :build()

    local labelWidth = 0
    for k in pairs(BJIContext.BJC.CEN) do
        local label = BJILang.get(svar("serverConfig.cen.{1}", { k }))
        local w = GetColumnTextWidth(label .. ":")
        if w > labelWidth then
            labelWidth = w
        end
    end
    Indent(2)
    local cols = ColumnsBuilder("CENSettings", { labelWidth, -1 })
    for k, v in pairs(BJIContext.BJC.CEN) do
        cols:addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get(svar("serverConfig.cen.{1}", { k })) }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :btnSwitchEnabledDisabled({
                            id = "cen" .. k,
                            state = v,
                            onClick = function()
                                BJITx.config.bjc("CEN." .. k, not v)
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

local function draw(ctxt)
    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CORE) then
        drawCoreConfig(ctxt)
    end

    if BJIPerm.hasPermission(BJIPerm.PERMISSIONS.SET_CEN) then
        drawCEN(ctxt)
    end
end


return draw
