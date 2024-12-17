local M = {
    _name = "BJILang",
    Langs = {},
    Messages = {},
}

local function initClient()
    local lang = Lua:getSelectedLanguage()
    if lang and type(lang) == "string" and lang:find("_") then
        lang = ssplit(lang, "_")[1]:lower()
        BJIAsync.task(
            function()
                return BJICache.areBaseCachesFirstLoaded()
            end,
            function()
                BJITx.player.lang(lang)
            end,
            "BJILangInit"
        )
    end
end

local function get(key, defaultValue)
    if not defaultValue then
        defaultValue = key
    end
    if not key or type(key) ~= "string" then
        LogError(svar("Invalid key {1}", { key }))
        return "invalid"
    end

    local parts = ssplit(key, ".")
    local val = M.Messages
    for i = 1, #parts do
        if val[parts[i]] == nil then
            return tostring(defaultValue)
        end
        val = val[parts[i]]
    end
    if type(val) ~= "string" then
        return tostring(defaultValue)
    end
    return tostring(val)
end

local function drawSelector(data)
    if not data then
        LogError(M.get("errors.invalidData"), M._name)
        return
    end

    local line = LineBuilder(true)
    if data.label then
        line:text(data.label)
    else
        line:icon({
            icon = ICONS.translate,
        })
    end
    for _, l in ipairs(M.Langs) do
        line:btn({
            id = l,
            label = l:upper(),
            style = data.selected == l and BTN_PRESETS.SUCCESS or BTN_PRESETS.INFO,
            onClick = function()
                if data.selected ~= l and data.onChange then
                    data.onChange(l)
                end
            end
        })
    end
    line:build()
end

M.initClient = initClient
M.get = get
M.drawSelector = drawSelector

RegisterBJIManager(M)
return M
