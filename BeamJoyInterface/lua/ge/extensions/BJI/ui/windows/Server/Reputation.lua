local W = {
    labels = {
        keys = {},
        tooltips = {},
    },
    labelsWidth = 0,
}

local function updateLabels()
    Table(BJI.Managers.Context.BJC.Reputation):keys()
        :forEach(function(k)
            W.labels.keys[k] = string.var("{1} :",
                { BJI.Managers.Lang.get(string.var("serverConfig.reputation.{1}", { k })) })
            W.labels.tooltips[k] = BJI.Managers.Lang.get(string.var("serverConfig.reputation.{1}Tooltip", { k }), "")
            if #W.labels.tooltips[k] == 0 then
                W.labels.tooltips[k] = nil
            end
        end)
end

local function updateWidths()
    W.labelsWidth = Table(W.labels.keys)
        :reduce(function(acc, l, k)
            local w = BJI.Utils.Common.GetColumnTextWidth(l .. (W.labels.tooltips[k] and HELPMARKER_TEXT or ""))
            return w > acc and w or acc
        end, 0)
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
    end))

    updateWidths()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED,
    }, updateWidths))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

local function body(ctxt)
    Table(BJI.Managers.Context.BJC.Reputation):reduce(function(cols, v, k)
        return cols:addRow({
            cells = {
                function()
                    if W.labels.tooltips[k] then
                        LineBuilder()
                            :text(W.labels.keys[k])
                            :helpMarker(W.labels.tooltips[k])
                            :build()
                    else
                        LineLabel(W.labels.keys[k])
                    end
                end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = tostring(k),
                            type = "int",
                            value = v,
                            min = 0,
                            step = 1,
                            onUpdate = function(val)
                                BJI.Managers.Context.BJC.Reputation[k] = val
                                BJI.Tx.config.bjc(string.var("Reputation.{1}", { k }), val)
                            end,
                        })
                        :build()
                end,
            }
        })
    end, ColumnsBuilder("reputationSettings", { W.labelsWidth, -1 }))
        :build()
end

W.onLoad = onLoad
W.onUnload = onUnload
W.body = body

return W
