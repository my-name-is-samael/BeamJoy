local function newCache()
    return {
        title = "",
        raceNamesWidth = 0,
        cols = {},
    }
end

local cache = newCache()

---@param ctxt TickContext
local function updateCache(ctxt, cacheIn)
    cache = newCache()

    cache.title = cacheIn.labels.raceLeaderboard.title
    for _, race in ipairs(cacheIn.data.raceLeaderboard.races) do
        local w = GetColumnTextWidth(race.name .. ":")
        if w > cache.raceNamesWidth then
            cache.raceNamesWidth = w
        end

        table.insert(cache.cols, {
            cells = {
                function()
                    LineBuilder()
                        :text(string.var("{1}:", { race.name }),
                            race.record.playerName == ctxt.user.playerName and
                            TEXT_COLORS.HIGHLIGHT or
                            TEXT_COLORS.DEFAULT)
                        :build()
                end,
                function()
                    LineBuilder()
                        :text(string.var("{time} - {playerName} - {model}", {
                                time = RaceDelay(race.record.time),
                                playerName = race.record.playerName,
                                model = BJIVeh.getModelLabel(race.record.model)
                            }),
                            race.record.playerName == ctxt.user.playerName and
                            TEXT_COLORS.HIGHLIGHT or
                            TEXT_COLORS.DEFAULT)
                        :build()
                end
            }
        })
    end
end

local function draw()
    AccordionBuilder()
        :label(cache.title)
        :openedBehavior(function()
            local cols = ColumnsBuilder("BJIRacesLeaderboard", { cache.raceNamesWidth, -1 })
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
