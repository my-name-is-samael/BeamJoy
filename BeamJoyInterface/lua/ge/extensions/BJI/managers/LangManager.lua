---@class BJIManagerLang : BJIManager
local M = {
    _name = "Lang",

    Langs = {},
    Messages = {},
}

local function onLoad()
    BJI.Managers.Cache.addRxHandler(BJI.Managers.Cache.CACHES.LANG, function(cacheData)
        BJI.Managers.Lang.Langs = cacheData.langs
        table.sort(BJI.Managers.Lang.Langs, function(a, b) return a:lower() < b:lower() end)
        BJI.Managers.Lang.Messages = cacheData.messages

        BJI.Managers.Events.trigger(BJI.Managers.Events.EVENTS.LANG_CHANGED)
    end)

    local lang = Lua:getSelectedLanguage()
    if lang and type(lang) == "string" and lang:find("_") then
        lang = lang:split2("_")[1]:lower()
        BJI.Managers.Async.task(
            function()
                return BJI.Managers.Cache.areBaseCachesFirstLoaded()
            end,
            function()
                BJI.Tx.player.lang(lang)
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

    local line = LineBuilder(true)
    if data.label then
        line:text(data.label)
    else
        line:icon({
            icon = BJI.Utils.Icon.ICONS.translate,
            style = { BJI.Utils.Style.TEXT_COLORS.DEFAULT },
            coloredIcon = true,
        })
    end
    for _, l in ipairs(M.Langs) do
        line:btn({
            id = l,
            label = l:upper(),
            style = data.selected == l and BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.INFO,
            onClick = function()
                if data.selected ~= l and data.onChange then
                    data.onChange(l)
                end
            end
        })
    end
    line:build()
end

M.get = get
M.drawSelector = drawSelector

M.onLoad = onLoad

return M
