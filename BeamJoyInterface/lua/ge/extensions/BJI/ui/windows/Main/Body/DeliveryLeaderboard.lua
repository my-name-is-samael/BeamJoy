local function newCache()
    return {
        playernamesWidth = 0,
        cols = {}
    }
end

local cache = newCache()

---@param ctxt TickContext
local function updateCache(ctxt)
    cache = newCache()

    if not BJI.Managers.Context.Scenario.Data.DeliveryLeaderboard then
        return
    end

    local labels = {}
    local scores = {}
    for i, lb in ipairs(BJI.Managers.Context.Scenario.Data.DeliveryLeaderboard) do
        labels[i] = string.var("#{1} {2} :", { i, lb.playerName })
        scores[i] = string.var("{1} {2}", { lb.delivery, BJI.Managers.Lang.get("delivery.leaderboard.delivered") })
        local w = BJI.Utils.UI.GetColumnTextWidth(labels[i])
        if w > cache.playernamesWidth then
            cache.playernamesWidth = w
        end

        table.insert(cache.cols,{
            cells = {
                function()
                    LineBuilder()
                        :text(
                            labels[i],
                            lb.playerName == ctxt.user.playerName and
                            BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or
                            BJI.Utils.Style.TEXT_COLORS.DEFAULT)
                        :build()
                end,
                function()
                    LineBuilder()
                        :text(
                            scores[i],
                            lb.playerName == ctxt.user.playerName and
                            BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or
                            BJI.Utils.Style.TEXT_COLORS.DEFAULT)
                        :build()
                end
            }
        })
    end
end

local function draw()
    AccordionBuilder()
        :label(BJI.Managers.Lang.get("delivery.leaderboard.title"))
        :openedBehavior(function()
            local cols = ColumnsBuilder("BJIDeliveryLeaderboard", { cache.playernamesWidth, -1 })
            table.forEach(cache.cols, function(el)
                cols:addRow(el)
            end)
            cols:build()
        end)
        :build()
end

return {
    updateCache = updateCache,
    draw = draw,
}
