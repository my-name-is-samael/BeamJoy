local FORMATTING_CODES = {
    {
        { code = "^r", key = "reset" },
        { code = "^n", key = "underline" },
        { code = "^l", key = "bold" },
        { code = "^m", key = "strike" },
        { code = "^o", key = "italic" },
    },
    {
        { code = "^0", key = "black",    color = BJI.Utils.Style.RGBA(0, 0, 0, 1) },
        { code = "^1", key = "darkblue", color = BJI.Utils.Style.RGBA(0, 0, .67, 1) },
        { code = "^2", key = "green",    color = BJI.Utils.Style.RGBA(0, .67, 0, 1) },
        { code = "^3", key = "darkaqua", color = BJI.Utils.Style.RGBA(0, .67, .67, 1) },
        { code = "^4", key = "red",      color = BJI.Utils.Style.RGBA(.67, 0, 0, 1) },
        { code = "^5", key = "purple",   color = BJI.Utils.Style.RGBA(.67, 0, .67, 1) },
        { code = "^6", key = "orange",   color = BJI.Utils.Style.RGBA(1, .67, 0, 1) },
        { code = "^7", key = "grey",     color = BJI.Utils.Style.RGBA(.67, .67, .67, 1) },
    },
    {
        { code = "^8", key = "darkgrey",   color = BJI.Utils.Style.RGBA(.33, .33, .33, 1) },
        { code = "^9", key = "blue",       color = BJI.Utils.Style.RGBA(.33, .33, 1, 1) },
        { code = "^a", key = "lightgreen", color = BJI.Utils.Style.RGBA(.33, 1, .33, 1) },
        { code = "^b", key = "aqua",       color = BJI.Utils.Style.RGBA(.33, 1, 1, 1) },
        { code = "^c", key = "lightred",   color = BJI.Utils.Style.RGBA(1, .33, .33, 1) },
        { code = "^d", key = "pink",       color = BJI.Utils.Style.RGBA(1, .33, 1, 1) },
        { code = "^e", key = "yellow",     color = BJI.Utils.Style.RGBA(1, 1, .33, 1) },
        { code = "^f", key = "white",      color = BJI.Utils.Style.RGBA(1, 1, 1, 1) },
    }
}
local FAVORITE_NAME_OFFLINE_SUFFIX = "[OFFLINE]"

local W = {
    name = "ServerCoreCen",

    labelsCore = {
        formatting = {
            title = "",
            hints = {},
        },
        title = "",
        previewTooltip = "",
        keys = {},
    },
    labelsCen = {
        title = "",
        titleTooltip = "",
        keys = {},
    },
    showCore = false,
    showCEN = false,
    coreLabelsWidth = 0,
    cenLabelsWidth = 0,
}

local function updateLabels()
    W.labelsCore.formatting.title = BJI.Managers.Lang.get("serverConfig.core.formattingHints.title")
    Range(1, math.max(#FORMATTING_CODES[1], #FORMATTING_CODES[2], #FORMATTING_CODES[3]))
        :forEach(function(i)
            Range(1, 3):forEach(function(j)
                if FORMATTING_CODES[j][i] then
                    W.labelsCore.formatting[FORMATTING_CODES[j][i].key] = BJI.Managers.Lang.get(string.var(
                        "serverConfig.core.formattingHints.{1}", { FORMATTING_CODES[j][i].key }))
                end
            end)
        end)

    W.labelsCore.title = BJI.Managers.Lang.get("serverConfig.core.title") .. " :"
    W.labelsCore.previewTooltip = BJI.Managers.Lang.get("serverConfig.core.previewTooltip")
    Table(BJI.Managers.Context.Core):keys():forEach(function(k)
        W.labelsCore.keys[k] = BJI.Managers.Lang.get(string.var("serverConfig.core.{1}", { k })) .. " :"
    end)

    W.labelsCen.title = BJI.Managers.Lang.get("serverConfig.cen.title") .. " :"
    W.labelsCen.titleTooltip = BJI.Managers.Lang.get("serverConfig.cen.tooltip")
    Table(BJI.Managers.Context.BJC.CEN):keys():forEach(function(k)
        W.labelsCen.keys[k] = BJI.Managers.Lang.get(string.var("serverConfig.cen.{1}", { k })) .. " :"
    end)
end

local function updateWidths()
    W.coreLabelsWidth = Table(W.labelsCore.keys):reduce(function(acc, l)
        local w = BJI.Utils.Common.GetColumnTextWidth(l)
        return w > acc and w or acc
    end, 0)

    W.cenLabelsWidth = Table(W.labelsCen.keys):reduce(function(acc, l)
        local w = BJI.Utils.Common.GetColumnTextWidth(l)
        return w > acc and w or acc
    end, 0)
end

local function updateCache()
    W.showCore = BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SET_CORE)
    W.showCEN = BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.SET_CEN)
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, function()
        updateLabels()
        updateWidths()
    end, W.name))

    updateWidths()
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED, updateWidths, W.name))

    updateCache()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
    }, updateCache, W.name))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

local function drawCoreFormattingHints()
    local function renderCode(el)
        LineBuilder()
            :text(el.code .. " :")
            :text(W.labelsCore.formatting[el.key], el.color)
            :build()
    end
    AccordionBuilder()
        :label(BJI.Managers.Lang.get("serverConfig.core.formattingHints.title"))
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
            nil,
            function()
                local line = LineBuilder()
                for _, s in ipairs(str) do
                    if s.newline then
                        line:build()
                        line = LineBuilder()
                    end
                    line:text(s.text, s.color, W.labelsCore.previewTooltip)
                end
                line:build()
            end
        }
    })
end

local function drawCoreConfig(ctxt)
    LineLabel(W.labelsCore.title)

    Indent(2)
    drawCoreFormattingHints()

    local cols = ColumnsBuilder("CoreSettings", { W.coreLabelsWidth, -1 })
    for k, v in pairs(BJI.Managers.Context.Core) do
        cols:addRow({
            cells = {
                function() LineLabel(W.labelsCore.keys[k]) end,
                function()
                    if table.includes({ "Tags", "Description" }, k) then
                        LineBuilder()
                            :inputString({
                                id = string.var("core{1}", { k }),
                                value = v,
                                multiline = true,
                                autoheight = true,
                                size = k == "Description" and 512 or 128,
                                onUpdate = function(val)
                                    BJI.Managers.Context.Core[k] = val
                                    BJI.Tx.config.core(k, val)
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
                                    BJI.Tx.config.core(k, not v)
                                    BJI.Managers.Context.Core[k] = not v
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
                                    BJI.Managers.Context.Core[k] = val
                                    BJI.Tx.config.core(k, val)
                                end
                            })
                        elseif type(v) == "string" then
                            line:inputString({
                                id = "core" .. k,
                                value = v,
                                onUpdate = function(val)
                                    BJI.Managers.Context.Core[k] = val
                                    BJI.Tx.config.core(k, val)
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
    LineLabel(W.labelsCen.title, nil, false, W.labelsCen.titleTooltip)

    Indent(2)
    local cols = ColumnsBuilder("CENSettings", { W.cenLabelsWidth, -1 })
    for k, v in pairs(BJI.Managers.Context.BJC.CEN) do
        cols:addRow({
            cells = {
                function() LineLabel(W.labelsCen.keys[k]) end,
                function()
                    LineBuilder()
                        :btnIconToggle({
                            id = "cen" .. k,
                            state = v,
                            coloredIcon = true,
                            onClick = function()
                                BJI.Tx.config.bjc("CEN." .. k, not v)
                                BJI.Managers.Context.BJC.CEN[k] = not v
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

local function body(ctxt)
    if W.showCore then
        drawCoreConfig(ctxt)
    end

    if W.showCEN then
        drawCEN(ctxt)
    end
end

W.onLoad = onLoad
W.onUnload = onUnload
W.body = body

return W
