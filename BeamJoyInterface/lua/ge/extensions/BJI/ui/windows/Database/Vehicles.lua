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
        ---@type {value: string, label: string}?
        selectedModel = nil,

        disableInputs = false,
    },
}

local function updateLabels()
    W.labels.title = BJI.Managers.Lang.get("database.vehicles.blacklistedModels") .. " :"
    W.labels.add = BJI.Managers.Lang.get("common.buttons.add")
    W.labels.remove = BJI.Managers.Lang.get("common.buttons.remove")
end

local function updateCache()
    W.cache.disableInputs = false
    W.cache.blacklist = Table(BJI.Managers.Context.Database.Vehicles.ModelBlacklist):sort()

    W.cache.blackListDisplay = Table()
    W.cache.modelsCombo = Table()
    local res = Table(BJI.Managers.Veh.getAllVehicleLabels(true))
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
    if not W.cache.selectedModel or
        not W.cache.modelsCombo:find(function(mc) return mc.value == W.cache.selectedModel.value end) then
        W.cache.selectedModel = W.cache.modelsCombo[1]
    end
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateLabels, W.name))

    updateCache()
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.CACHE_LOADED,
        function(_, data)
            if data.cache == BJI.Managers.Cache.CACHES.DATABASE_VEHICLES then
                updateCache()
            end
        end, W.name))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
    W.cache.modelsCombo = Table()
    W.cache.selectedModel = nil
end

---@param ctxt TickContext
local function header(ctxt)
    LineLabel(W.labels.title)
    LineBuilder():btnIcon({
        id = "addBlacklistedModel",
        icon = ICONS.add,
        style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
        disabled = W.cache.disableInputs or not W.cache.selectedModel,
        tooltip = W.labels.add,
        onClick = function()
            W.cache.disableInputs = true
            BJI.Tx.database.vehicle(W.cache.selectedModel.value, true)
        end
    }):inputCombo({
        id = "addBlacklistedModelList",
        items = W.cache.modelsCombo,
        getLabelFn = function(item)
            return item.label
        end,
        value = W.cache.selectedModel,
        onChange = function(item)
            W.cache.selectedModel = item
        end
    }):build()
end

local function body(data)
    W.cache.blackListDisplay:forEach(function(el)
        LineBuilder():btnIcon({
            id = string.var("removeBlacklisted-{1}", { el.model }),
            icon = ICONS.delete_forever,
            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
            disabled = W.cache.disableInputs,
            tooltip = W.labels.remove,
            onClick = function()
                W.cache.disableInputs = true
                BJI.Tx.database.vehicle(el.model, false)
            end
        }):text(el.label):build()
    end)
end

W.onLoad = onLoad
W.onUnload = onUnload
W.header = header
W.body = body

return W
