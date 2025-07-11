---@class BJIManagerLang : BJIManager
local M = {
    _name = "Lang",

    Langs = {},
    Messages = {},
}

local function onLoad()
    BJI_Cache.addRxHandler(BJI_Cache.CACHES.LANG, function(cacheData)
        BJI_Lang.Langs = cacheData.langs
        table.sort(BJI_Lang.Langs, function(a, b) return a:lower() < b:lower() end)
        BJI_Lang.Messages = cacheData.messages

        BJI_Events.trigger(BJI_Events.EVENTS.LANG_CHANGED)
    end)

    local lang = Lua:getSelectedLanguage()
    if lang and type(lang) == "string" and lang:find("_") then
        lang = lang:split2("_")[1]:lower()
        BJI_Async.task(
            function()
                return BJI_Cache.areBaseCachesFirstLoaded()
            end,
            function()
                BJI_Tx_player.lang(lang)
            end,
            "BJILangInit"
        )
    end
end

---@param key string
---@param defaultValue? string
---@return string|"invalid"
local function get(key, defaultValue)
    if not defaultValue then
        defaultValue = key
    end
    if not key or type(key) ~= "string" then
        LogError(string.var("Invalid key {1}", { key }))
        return "invalid"
    end

    local parts = key:split2(".")
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

    if data.label then
        Text(data.label)
    else
        Icon(BJI.Utils.Icon.ICONS.translate)
    end
    for _, l in ipairs(M.Langs) do
        SameLine()
        if Button(l, l:upper(), { btnStyle = data.selected == l and
                BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.INFO }) then
            if data.selected ~= l and data.onChange then
                data.onChange(l)
            end
        end
    end
end

M.get = get
M.drawSelector = drawSelector

M.onLoad = onLoad

return M
