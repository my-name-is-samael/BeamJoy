local state

---@param ctxt TickContext
---@param showRacesLeaderboardButtonFn fun()?
local function draw(ctxt, showRacesLeaderboardButtonFn)
    if BeginTable("BJIMainLeaderboards", {
            { label = "##delivery-leaderboard-tree", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
            { label = "##delivery-leaderboard-races" },
        }) then
        TableNewRow()
        state = BeginTree(BJI.Managers.Lang.get("delivery.leaderboard.title"))
        TableNextColumn()
        if showRacesLeaderboardButtonFn then
            showRacesLeaderboardButtonFn()
        end
        EndTable()

        if state then
            if BeginTable("BJIMainDeliveryLeaderboard", {
                    { label = "##delivery-leaderboard-playernames" },
                    { label = "##delivery-leaderboard-scores" }
                }) then
                for i, lb in ipairs(BJI.Managers.Context.Scenario.Data.DeliveryLeaderboard) do
                    TableNewRow()
                    Text(string.var("#{1} {2} :", { i, lb.playerName }),
                        {
                            color = lb.playerName == ctxt.user.playerName and
                                BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT
                        })
                    TableNextColumn()
                    Text(
                        string.var("{1} {2}", { lb.delivery, BJI.Managers.Lang.get("delivery.leaderboard.delivered") }),
                        {
                            color = lb.playerName == ctxt.user.playerName and
                                BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or BJI.Utils.Style.TEXT_COLORS.DEFAULT
                        })
                end
                EndTable()
            end
            EndTree()
        end
    end
end

return {
    draw = draw,
}
