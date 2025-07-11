local categories = Table({
    { category = "freeroam", keys = Table({ "KmDriveReward", "ArrestReward", "EvadeReward", "DriftGoodReward", "DriftBigReward" }) },
    { category = "delivery", keys = Table({ "DeliveryVehicleReward", "DeliveryVehiclePristineReward", "DeliveryPackageReward", "DeliveryPackageStreakReward" }) },
    { category = "bus",      keys = Table({ "BusMissionReward" }) },
    { category = "race",     keys = Table({ "RaceParticipationReward", "RaceWinnerReward", "RaceSoloReward", "RaceRecordReward" }) },
    { category = "speed",    keys = Table({ "SpeedReward" }) },
    { category = "hunter",   keys = Table({ "HunterParticipationReward", "HunterWinnerReward" }) },
    { category = "infected",   keys = Table({ "InfectedParticipationReward", "InfectedWinnerReward" }) },
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
}
--- gc prevention
local nextValue

local function updateLabels()
    categories:forEach(function(c)
        W.labels.categories[c.category] = BJI_Lang.get("serverConfig.reputation.categories." ..
            tostring(c.category))
    end)
    Table(BJI_Context.BJC.Reputation):keys()
        :forEach(function(k)
            W.labels.keys[k] = string.var("{1} :",
                { BJI_Lang.get(string.var("serverConfig.reputation.{1}", { k })) })
            W.labels.tooltips[k] = BJI_Lang.get(string.var("serverConfig.reputation.{1}Tooltip", { k }), "")
            if #W.labels.tooltips[k] == 0 then
                W.labels.tooltips[k] = nil
            end
        end)
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.LANG_CHANGED, updateLabels, W.name))
end
local function onUnload()
    listeners:forEach(BJI_Events.removeListener)
end

local function body(ctxt)
    if BeginTable("BJIServerReputation", {
            { label = "##serverreputation-labels" },
            { label = "##serverreputation-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        categories:forEach(function(c)
            TableNewRow()
            Text(W.labels.categories[c.category])

            Table(c.keys):forEach(function(k)
                TableNewRow()
                Indent()
                Text(W.labels.keys[k])
                TooltipText(W.labels.tooltips[k])
                Unindent()
                TableNextColumn()
                nextValue = InputInt(tostring(k), BJI_Context.BJC.Reputation[k],
                    { min = 0, step = 1 })
                TooltipText(W.labels.tooltips[k])
                if nextValue then
                    BJI_Context.BJC.Reputation[k] = nextValue
                    BJI_Tx_config.bjc(string.var("Reputation.{1}", { k }), BJI_Context.BJC.Reputation[k])
                end
            end)
        end)

        EndTable()
    end
end

W.onLoad = onLoad
W.onUnload = onUnload
W.body = body

return W
