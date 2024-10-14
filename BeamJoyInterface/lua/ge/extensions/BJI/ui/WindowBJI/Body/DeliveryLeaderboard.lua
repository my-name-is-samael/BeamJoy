local function draw()
    AccordionBuilder()
        :label(BJILang.get("delivery.leaderboard.title"))
        :openedBehavior(function()
            local labelWidth = 0
            local labels = {}
            for i, lb in ipairs(BJIContext.Scenario.Data.DeliveryLeaderboard) do
                labels[i] = svar("#{1} {2} :", { i, lb.playerName })
                local w = GetColumnTextWidth(labels[i])
                if w > labelWidth then
                    labelWidth = w
                end
            end
            local cols = ColumnsBuilder("BJIDeliveryLeaderboard", { labelWidth, -1 })
            for i, lb in ipairs(BJIContext.Scenario.Data.DeliveryLeaderboard) do
                cols:addRow({
                    cells = {
                        function()
                            LineBuilder()
                                :text(
                                    labels[i],
                                    lb.playerName == BJIContext.User.playerName and
                                    TEXT_COLORS.HIGHLIGHT or
                                    TEXT_COLORS.DEFAULT)
                                :build()
                        end,
                        function()
                            LineBuilder()
                                :text(
                                    svar("{1} {2}",
                                        { lb.delivery, BJILang.get("delivery.leaderboard.delivered") }),
                                    lb.playerName == BJIContext.User.playerName and
                                    TEXT_COLORS.HIGHLIGHT or
                                    TEXT_COLORS.DEFAULT)
                                :build()
                        end
                    }
                })
            end
            cols:build()
        end)
        :build()
end
return draw
