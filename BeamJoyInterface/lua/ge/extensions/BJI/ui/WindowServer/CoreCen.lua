local FORMATTING_CODES = {
    {
        { code = "^r", key = "reset" },
        { code = "^n", key = "underline" },
        { code = "^l", key = "bold" },
        { code = "^m", key = "strike" },
        { code = "^o", key = "italic" },
    },
    {
        { code = "^0", key = "black",    color = RGBA(0, 0, 0, 1) },
        { code = "^1", key = "darkblue", color = RGBA(0, 0, .67, 1) },
        { code = "^2", key = "green",    color = RGBA(0, .67, 0, 1) },
        { code = "^3", key = "darkaqua", color = RGBA(0, .67, .67, 1) },
        { code = "^4", key = "red",      color = RGBA(.67, 0, 0, 1) },
        { code = "^5", key = "purple",   color = RGBA(.67, 0, .67, 1) },
        { code = "^6", key = "orange",   color = RGBA(1, .67, 0, 1) },
        { code = "^7", key = "grey",     color = RGBA(.67, .67, .67, 1) },
    },
    {
        { code = "^8", key = "darkgrey",   color = RGBA(.33, .33, .33, 1) },
        { code = "^9", key = "blue",       color = RGBA(.33, .33, 1, 1) },
        { code = "^a", key = "lightgreen", color = RGBA(.33, 1, .33, 1) },
        { code = "^b", key = "aqua",       color = RGBA(.33, 1, 1, 1) },
        { code = "^c", key = "lightred",   color = RGBA(1, .33, .33, 1) },
        { code = "^d", key = "pink",       color = RGBA(1, .33, 1, 1) },
        { code = "^e", key = "yellow",     color = RGBA(1, 1, .33, 1) },
        { code = "^f", key = "white",      color = RGBA(1, 1, 1, 1) },
    }
}
local FAVORITE_NAME_OFFLINE_SUFFIX = "[OFFLINE]"

local function drawCoreFormattingHints()
    local function renderCode(el)
        LineBuilder()
            :text(string.var("{1} :", { el.code }))
            :text(BJILang.get(string.var("serverConfig.core.formattingHints.{1}", { el.key })), el.color)
            :build()
    end
    AccordionBuilder()
        :label(BJILang.get("serverConfig.core.formattingHints.title"))
        :openedBehavior(function()
            local cols = ColumnsBuilder("FormattingHints", { -1, -1, -1 })
            local iMax = math.max(#FORMATTING_CODES[1], #FORMATTING_CODES[2], #FORMATTING_CODES[3])
            for i = 1, iMax do
                cols:addRow({
                    cells = {
                        FORMATTING_CODES[1][i] and function()
                            renderCode(FORMATTING_CODES[1][i])
                        end,
                        FORMATTING_CODES[2][i] and function()
                            renderCode(FORMATTING_CODES[2][i])
                        end,
                        FORMATTING_CODES[3][i] and function()
                            renderCode(FORMATTING_CODES[3][i])
                        end,
                    }
                })
            end
            cols:build()
        end)
        :build()
end

local function drawCoreTextPreview(cols, value, key)
    local reset = {
        char = FORMATTING_CODES[1][1].code:sub(2),               -- RESET CHAR
        color = FORMATTING_CODES[3][#FORMATTING_CODES[3]].color, -- WHITE COLOR
    }
    local newlineChar = "p"                                      -- NEWLINE CHAR

    local str = {}
    local parts = value:split2("^")
    local lastColor = reset.color

    local function removeLastSpaceAndAdd(text, color, newline)
        if #text > 0 and text:sub(#text) == " " then
            text = text:sub(1, #text - 1)
        end
        if #text > 0 or newline then
            table.insert(str, { text = text, color = color, newline = newline })
        end
        lastColor = color
    end

    for _, p in ipairs(parts) do
        local char = p:sub(1, 1)
        local text = p:sub(2)
        if text:sub(1, 1) == " " then
            -- if first char after code is space
            text = text:sub(2)
        end
        if char == newlineChar then
            -- newline
            removeLastSpaceAndAdd(text, lastColor, key ~= "Name")
        elseif char == reset.char then
            -- char is reset
            removeLastSpaceAndAdd(text, reset.color)
        else
            local newColor
            for column = 2, #FORMATTING_CODES do
                for _, col in ipairs(FORMATTING_CODES[column]) do
                    local colChar = col.code:sub(2)
                    if colChar == char then
                        newColor = col.color
                        break
                    end
                end
                if newColor then
                    break
                end
            end
            if newColor then
                -- char is a new color
                removeLastSpaceAndAdd(text, newColor)
            else
                -- char is not a color
                removeLastSpaceAndAdd(text, lastColor)
            end
        end
    end
    if key == "Name" then
        table.insert(str, { text = FAVORITE_NAME_OFFLINE_SUFFIX, color = lastColor })
    end

    cols:addRow({
        cells = {
            function()
                LineBuilder()
                    :helpMarker(BJILang.get("serverConfig.core.previewTooltip"))
                    :build()
            end,
            function()
                local line = LineBuilder()
                for _, s in ipairs(str) do
                    if s.newline then
                        line:build()
                        line = LineBuilder()
                    end
                    line:text(s.text, s.color)
                end
                line:build()
            end
        }
    })
end

local function drawCoreConfig(ctxt)
    LineBuilder()
        :text(string.var("{1}:", { BJILang.get("serverConfig.core.title") }))
        :build()

    Indent(2)
    drawCoreFormattingHints()

    local labelWidth = 0
    for k in pairs(BJIContext.Core) do
        local label = BJILang.get(string.var("serverConfig.core.{1}", { k }))
        local w = GetColumnTextWidth(label .. ":")
        if w > labelWidth then
            labelWidth = w
        end
    end
    local cols = ColumnsBuilder("CoreSettings", { labelWidth, -1 })
    for k, v in pairs(BJIContext.Core) do
        cols:addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(string.var("{1}:", { BJILang.get(string.var("serverConfig.core.{1}", { k })) }))
                        :build()
                end,
                function()
                    if table.includes({ "Tags", "Description" }, k) then
                        LineBuilder()
                            :inputString({
                                id = string.var("core{1}", { k }),
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
                            line:btnIconToggle({
                                id = "core" .. k,
                                state = v,
                                coloredIcon = true,
                                onClick = function()
                                    BJITx.config.core(k, not v)
                                    BJIContext.Core[k] = not v
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

        if table.includes({ "Name", "Description" }, k) then
            if v:find("%^") then
                local colorFound = false
                for i = 2, #FORMATTING_CODES do
                    for _, color in ipairs(FORMATTING_CODES[i]) do
                        if v:find(string.var("%{1}", { color.code })) then
                            colorFound = true
                            break
                        end
                    end
                    if colorFound then
                        break
                    end
                end
                if colorFound then
                    drawCoreTextPreview(cols, v:gsub("\n", "%^p"), k)
                end
            end
        end
    end
    cols:build()
    Indent(-2)
end

local function drawCEN(ctxt)
    LineBuilder()
        :text(string.var("{1}:", { BJILang.get("serverConfig.cen.title") }))
        :helpMarker(BJILang.get("serverConfig.cen.tooltip"))
        :build()

    local labelWidth = 0
    for k in pairs(BJIContext.BJC.CEN) do
        local label = BJILang.get(string.var("serverConfig.cen.{1}", { k }))
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
                        :text(string.var("{1}:", { BJILang.get(string.var("serverConfig.cen.{1}", { k })) }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :btnIconToggle({
                            id = "cen" .. k,
                            state = v,
                            coloredIcon = true,
                            onClick = function()
                                BJITx.config.bjc("CEN." .. k, not v)
                                BJIContext.BJC.CEN[k] = not v
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
