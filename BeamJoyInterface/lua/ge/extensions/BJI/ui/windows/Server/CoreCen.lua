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
}
--- gc prevention
local nextValue, str, parts, lastColor, char, text, newColor, colChar

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

local function updateLabels()
    W.labelsCore.formatting.title = BJI_Lang.get("serverConfig.core.formattingHints.title")
    Range(1, math.max(#FORMATTING_CODES[1], #FORMATTING_CODES[2], #FORMATTING_CODES[3]))
        :forEach(function(i)
            Range(1, 3):forEach(function(j)
                if FORMATTING_CODES[j][i] then
                    W.labelsCore.formatting[FORMATTING_CODES[j][i].key] = BJI_Lang.get(string.var(
                        "serverConfig.core.formattingHints.{1}", { FORMATTING_CODES[j][i].key }))
                end
            end)
        end)

    W.labelsCore.title = BJI_Lang.get("serverConfig.core.title") .. " :"
    W.labelsCore.previewTooltip = BJI_Lang.get("serverConfig.core.previewTooltip")
    Table(BJI_Context.Core):keys():forEach(function(k)
        W.labelsCore.keys[k] = BJI_Lang.get(string.var("serverConfig.core.{1}", { k })) .. " :"
        local tooltip = BJI_Lang.get(string.var("serverConfig.core.{1}Tooltip", { k }), "")
        if #tooltip > 0 then
            W.labelsCore.keys[k .. "Tooltip"] = tooltip
        end
    end)

    W.labelsCen.title = BJI_Lang.get("serverConfig.cen.title") .. " :"
    W.labelsCen.titleTooltip = BJI_Lang.get("serverConfig.cen.tooltip")
    Table(BJI_Context.BJC.CEN):keys():forEach(function(k)
        W.labelsCen.keys[k] = BJI_Lang.get(string.var("serverConfig.cen.{1}", { k })) .. " :"
    end)
end

local function updateCache()
    W.showCore = BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SET_CORE)
    W.showCEN = BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.SET_CEN)
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.LANG_CHANGED, updateLabels, W.name))

    updateCache()
    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.PERMISSION_CHANGED,
    }, updateCache, W.name))
end

local function onUnload()
    listeners:forEach(BJI_Events.removeListener)
end

local function renderFormattingCode(el)
    Text(el.code .. " :")
    SameLine()
    Text(W.labelsCore.formatting[el.key], { color = el.color })
end

local function drawCoreFormattingHints()
    if BeginTree(W.labelsCore.formatting.title) then
        if BeginTable("FormattingHints", {
                { label = "##formattinghints-1", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
                { label = "##formattinghints-2", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
                { label = "##formattinghints-3", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
            }) then
            local iMax = math.max(#FORMATTING_CODES[1], #FORMATTING_CODES[2], #FORMATTING_CODES[3])
            for i = 1, iMax do
                TableNewRow()
                if FORMATTING_CODES[1][i] then
                    renderFormattingCode(FORMATTING_CODES[1][i])
                end
                TableNextColumn()
                if FORMATTING_CODES[2][i] then
                    renderFormattingCode(FORMATTING_CODES[2][i])
                end
                TableNextColumn()
                if FORMATTING_CODES[3][i] then
                    renderFormattingCode(FORMATTING_CODES[3][i])
                end
            end
            EndTable()
        end
        EndTree()
    end
end

---@param value string
---@return boolean
local function isContainingColors(value)
    if value:find("%^") then
        for i = 2, #FORMATTING_CODES do
            for _, color in ipairs(FORMATTING_CODES[i]) do
                if value:find("%" .. color.code) then
                    return true
                end
            end
        end
    end
    return false
end

local newlineChar = "p"                                      -- NEWLINE CHAR
local reset = {
    char = FORMATTING_CODES[1][1].code:sub(2),               -- RESET CHAR
    color = FORMATTING_CODES[3][#FORMATTING_CODES[3]].color, -- WHITE COLOR
}
local function removeLastSpaceAndAdd(str, text, color, newline)
    if #text > 0 and text:sub(#text) == " " then
        text = text:sub(1, #text - 1)
    end
    if #text > 0 or newline then
        table.insert(str, { text = text, color = color, newline = newline })
    end
    lastColor = color
end
---@param value string
---@param key string
local function drawCoreTextPreview(value, key)
    str = {}
    parts = value:split2("^")
    lastColor = reset.color

    for _, p in ipairs(parts) do
        char = p:sub(1, 1)
        text = p:sub(2)
        if text:startswith(" ") then
            -- if first char after code is space
            text = text:sub(2)
        end
        if char == newlineChar then
            -- newline
            removeLastSpaceAndAdd(str, text, lastColor, key ~= "Name")
        elseif char == reset.char then
            -- char is reset
            removeLastSpaceAndAdd(str, text, reset.color)
        else
            newColor = nil
            for column = 2, #FORMATTING_CODES do
                for _, col in ipairs(FORMATTING_CODES[column]) do
                    colChar = col.code:sub(2)
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
                removeLastSpaceAndAdd(str, text, newColor)
            else
                -- char is not a color
                removeLastSpaceAndAdd(str, text, lastColor)
            end
        end
    end
    if key == "Name" then
        table.insert(str, { text = FAVORITE_NAME_OFFLINE_SUFFIX, color = lastColor })
    end

    TableNewRow()
    TableNextColumn()
    for i, s in ipairs(str) do
        if i > 1 and not s.newline then
            SameLine()
        end
        Text(s.text, { color = s.color })
        TooltipText(W.labelsCore.previewTooltip)
    end
end

local CORE_CONFIG = Table({
    {
        key = "Name",
        render = function(label, tooltip)
            TableNewRow()
            Text(label)
            TooltipText(tooltip)
            TableNextColumn()
            nextValue = InputText("coreName", BJI_Context.Core.Name,
                { size = 250 })
            if nextValue then
                BJI_Context.Core.Name = nextValue
                BJI_Tx_config.core("Name", BJI_Context.Core.Name)
            end
            if isContainingColors(BJI_Context.Core.Name) then
                drawCoreTextPreview(BJI_Context.Core.Name, "Name")
            end
        end
    },
    {
        key = "Description",
        render = function(label, tooltip)
            TableNewRow()
            Text(label)
            TooltipText(tooltip)
            TableNextColumn()
            nextValue = InputTextMultiline("coreDescription", BJI_Context.Core.Description,
                { size = 1000 })
            if nextValue then
                BJI_Context.Core.Description = nextValue
                BJI_Tx_config.core("Description", BJI_Context.Core.Description)
            end
            if isContainingColors(BJI_Context.Core.Description) then
                drawCoreTextPreview(BJI_Context.Core.Description:gsub("\n", "%^p"),
                    "Description")
            end
        end
    },
    {
        key = "MaxPlayers",
        render = function(label, tooltip)
            TableNewRow()
            Text(label)
            TooltipText(tooltip)
            TableNextColumn()
            nextValue = InputInt("coreMaxPlayers", BJI_Context.Core.MaxPlayers,
                { min = 1, step = 1 })
            if nextValue then
                BJI_Context.Core.MaxPlayers = nextValue
                BJI_Tx_config.core("MaxPlayers", BJI_Context.Core.MaxPlayers)
            end
        end
    },
    {
        key = "Private",
        render = function(label, tooltip)
            TableNewRow()
            Text(label)
            TooltipText(tooltip)
            TableNextColumn()
            if IconButton("corePrivate", BJI_Context.Core.Private and BJI.Utils.Icon.ICONS.check_circle or
                    BJI.Utils.Icon.ICONS.cancel, { bgLess = true, btnStyle = BJI_Context.Core.Private and
                        BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR }) then
                BJI_Context.Core.Private = not BJI_Context.Core.Private
                BJI_Tx_config.core("Private", BJI_Context.Core.Private)
            end
        end
    },
    {
        key = "Debug",
        render = function(label, tooltip)
            TableNewRow()
            Text(label)
            TooltipText(tooltip)
            TableNextColumn()
            if IconButton("coreDebug", BJI_Context.Core.Debug and BJI.Utils.Icon.ICONS.check_circle or
                    BJI.Utils.Icon.ICONS.cancel, { bgLess = true, btnStyle = BJI_Context.Core.Debug and
                        BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR }) then
                BJI_Context.Core.Debug = not BJI_Context.Core.Debug
                BJI_Tx_config.core("Debug", BJI_Context.Core.Debug)
            end
        end
    },
    {
        key = "InformationPacket",
        render = function(label, tooltip)
            TableNewRow()
            Text(label)
            TooltipText(tooltip)
            TableNextColumn()
            if IconButton("coreInformationPacket", BJI_Context.Core.InformationPacket and
                    BJI.Utils.Icon.ICONS.check_circle or BJI.Utils.Icon.ICONS.cancel, { bgLess = true,
                        btnStyle = BJI_Context.Core.InformationPacket and
                            BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR }) then
                BJI_Context.Core.InformationPacket = not BJI_Context.Core
                    .InformationPacket
                BJI_Tx_config.core("InformationPacket", BJI_Context.Core.InformationPacket)
            end
        end
    }
})

local function drawCoreConfig(ctxt)
    Text(W.labelsCore.title)

    Indent(); Indent()
    drawCoreFormattingHints()
    if BeginTable("BJIServerCore", {
            { label = "##core-labels" },
            { label = "##core-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        CORE_CONFIG:forEach(function(conf)
            if BJI_Context.Core[conf.key] ~= nil then
                conf.render(W.labelsCore.keys[conf.key], W.labelsCore.keys[conf.key .. "Tooltip"])
            end
        end)

        EndTable()
    end
    Unindent(); Unindent()
end

local function drawCEN(ctxt)
    Text(W.labelsCen.title)
    TooltipText(W.labelsCen.titleTooltip)

    Indent(); Indent()
    if BeginTable("BJIServerCEN", {
            { label = "##cen-labels" },
            { label = "##cen-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        for k, v in pairs(BJI_Context.BJC.CEN) do
            TableNewRow()
            Text(W.labelsCen.keys[k])
            TableNextColumn()
            if IconButton("cen-" .. k, v and BJI.Utils.Icon.ICONS.check_circle or BJI.Utils.Icon.ICONS.cancel,
                    { bgLess = true, btnStyle = v and BJI.Utils.Style.BTN_PRESETS.SUCCESS or
                        BJI.Utils.Style.BTN_PRESETS.ERROR }) then
                BJI_Context.BJC.CEN[k] = not v
                BJI_Tx_config.bjc("CEN." .. k, BJI_Context.BJC.CEN[k])
            end
        end

        EndTable()
    end
    Unindent(); Unindent()
end

local function body(ctxt)
    if W.showCore then drawCoreConfig(ctxt) end
    if W.showCore and W.showCEN then Separator() end
    if W.showCEN then drawCEN(ctxt) end
end

W.onLoad = onLoad
W.onUnload = onUnload
W.body = body

return W
