local categories = Table({
    { category = "freeroam", keys = Table({ "KmDriveReward", "DriftGoodReward", "DriftBigReward" }) },
    { category = "delivery", keys = Table({ "DeliveryVehicleReward", "DeliveryVehiclePristineReward", "DeliveryPackageReward", "DeliveryPackageStreakReward" }) },
    { category = "bus",      keys = Table({ "BusMissionReward" }) },
    { category = "race",     keys = Table({ "RaceParticipationReward", "RaceWinnerReward", "RaceSoloReward", "RaceRecordReward" }) },
    { category = "speed",    keys = Table({ "SpeedReward" }) },
    { category = "hunter",   keys = Table({ "HunterParticipationReward", "HunterWinnerReward" }) },
    { category = "derby",    keys = Table({ "DerbyParticipationReward", "DerbyWinnerReward" }) },
    { category = "tag",      keys = Table({ "TagDuoReward" }) },
})

local W = {
    name = "ServerReputation",

    labels = {
        categories = {},
        keys = {},
        tooltips = {},
    },
    labelsWidth = 0,
}

local function updateLabels()
    categories:forEach(function(c)
        W.labels.categories[c.category] = BJI.Managers.Lang.get("serverConfig.reputation.categories." ..
            tostring(c.category))
    end)
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
            local w = BJI.Utils.UI.GetColumnTextWidth(l)
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
    end, W.name))

    updateWidths()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED,
    }, updateWidths, W.name))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

local function body(ctxt)
    categories:forEach(function(c)
        LineLabel(W.labels.categories[c.category])
        Indent(1)
        Table(c.keys):reduce(function(cols, k)
            local v = BJI.Managers.Context.BJC.Reputation[k]
            return cols:addRow({
                cells = {
                    function()
                        LineLabel(W.labels.keys[k], nil, false, W.labels.tooltips[k])
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
        end, ColumnsBuilder("reputationSettings", { W.labelsWidth, -1 })):build()
        Indent(-1)
        Separator()
    end)
end

W.onLoad = onLoad
W.onUnload = onUnload
W.body = body

return W
