local W = {
    labels = {
        title = "",
        add = "",
        remove = "",
    },
    cache = {
        ---@type string[]
        blacklist = Table(),
        ---@type {model: string, label: string}[]
        blackListDisplay = Table(),
        ---@type {value: string, label: string}[]
        modelsCombo = Table(),
        ---@type string?
        selectedModel = nil,

        disableInputs = false,
    },
}
--- gc prevention
local nextValue

local function updateLabels()
    W.labels.description = BJI_Lang.get("database.vehicles.blacklistDescription")
    W.labels.title = BJI_Lang.get("database.vehicles.blacklistedModels") .. " :"
    W.labels.add = BJI_Lang.get("common.buttons.add")
    W.labels.remove = BJI_Lang.get("common.buttons.remove")
end

local function updateCache()
    W.cache.disableInputs = false
    W.cache.blacklist = Table(BJI_Context.Database.Vehicles.ModelBlacklist):clone():sort()

    W.cache.blackListDisplay = Table()
    W.cache.modelsCombo = Table()
    local res = Table(BJI_Veh.getAllVehicleLabels(true))
        :reduce(function(res, label, model)
            if W.cache.blacklist:includes(model) then
                res.models:insert({ model = model, label = label })
            else
                res.combo:insert({ value = model, label = label })
            end
            return res
        end, Table({ models = Table(), combo = Table() }))
    res:forEach(function(list)
        list:sort(function(a, b)
            return a.label < b.label
        end)
    end)
    W.cache.blackListDisplay, W.cache.modelsCombo = res.models, res.combo
    if not W.cache.modelsCombo:any(function(mc) return mc.value == W.cache.selectedModel end) then
        W.cache.selectedModel = W.cache.modelsCombo[1].value
    end
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.LANG_CHANGED, updateLabels, W.name))

    updateCache()
    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.CACHE_LOADED,
        function(_, data)
            if data.cache == BJI_Cache.CACHES.DATABASE_VEHICLES then
                updateCache()
            end
        end, W.name))
end

local function onUnload()
    listeners:forEach(BJI_Events.removeListener)
    W.cache.modelsCombo = Table()
    W.cache.selectedModel = nil
end

---@param ctxt TickContext
local function header(ctxt)
    Text(W.labels.description)
    EmptyLine()
    Text(W.labels.title)
    if IconButton("addBlacklistedModel", BJI.Utils.Icon.ICONS.add,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                disabled = W.cache.disableInputs or not W.cache.selectedModel }) then
        W.cache.disableInputs = true
        BJI_Tx_database.vehicle(W.cache.selectedModel, true)
    end
    SameLine()
    nextValue = Combo("addBlacklistedModelList", W.cache.selectedModel, W.cache.modelsCombo)
    if nextValue then W.cache.selectedModel = nextValue end
    TooltipText(W.labels.add)
end

local function body(data)
    W.cache.blackListDisplay:forEach(function(el)
        if IconButton("removeBlacklisted-" .. el.model, BJI.Utils.Icon.ICONS.delete_forever,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR, disabled = W.cache.disableInputs }) then
            W.cache.disableInputs = true
            BJI_Tx_database.vehicle(el.model, false)
        end
        TooltipText(W.labels.remove)
        SameLine()
        Text(el.label)
    end)
end

W.onLoad = onLoad
W.onUnload = onUnload
W.header = header
W.body = body

return W
