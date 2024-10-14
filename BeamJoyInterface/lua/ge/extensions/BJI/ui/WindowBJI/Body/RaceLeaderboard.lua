local function draw(races)
    AccordionBuilder()
        :label(BJILang.get("races.leaderboard.title"))
        :openedBehavior(function()
            local labelWidth = 0
            for _, race in ipairs(races) do
                local w = GetColumnTextWidth(race.name .. ":")
                if w > labelWidth then
                    labelWidth = w
                end
            end

            local cols = ColumnsBuilder("BJIRaceLeaderboard", { labelWidth, -1 })
            for _, race in ipairs(races) do
                local color = TEXT_COLORS.DEFAULT
                if race.record.playerName == BJIContext.User.playerName then
                    color = TEXT_COLORS.HIGHLIGHT
                end
                cols:addRow({
                    cells = {
                        function()
                            LineBuilder()
                                :text(svar("{1}:", { race.name }), color)
                                :build()
                        end,
                        function()
                            LineBuilder()
                                :text(svar("{time} - {playerName} ({model})", {
                                        time = RaceDelay(race.record.time),
                                        playerName = race.record.playerName,
                                        model = BJIVeh.getModelLabel(race.record.model)
                                    }),
                                    color)
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
