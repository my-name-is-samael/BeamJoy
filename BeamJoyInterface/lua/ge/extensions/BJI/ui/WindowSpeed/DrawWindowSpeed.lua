local sm

local function drawHeader(ctxt)
    sm = BJIScenario.get(BJIScenario.TYPES.SPEED)
    if not sm then return end

    LineBuilder()
        :text(BJILang.get("speed.title"))
        :build()

    local now = GetCurrentTimeMillis()
    local minSpeedLabel = string.var("{1}{2}", {
        sm.minSpeed,
        BJILang.get("speed.speedUnit"),
    })
    LineBuilder()
        :text(BJILang.get("speed.minimumSpeed"):var({ speed = minSpeedLabel }))
        :build()

    if sm.processCheck and sm.processCheck - now >= 0 then
        local remaining = math.round((sm.processCheck - now) / 1000)
        LineBuilder()
            :text(BJILang.get("speed.counterWarning"):var({ seconds = remaining }),
                TEXT_COLORS.HIGHLIGHT)
            :build()
    end
end

local function drawBody(ctxt)
    if not sm then return end
    LineBuilder()
        :text(BJILang.get("speed.leaderboard"))
        :build()

    local leaderboard = {}
    for i = 1, table.length(sm.participants) do
        local lb = sm.leaderboard[i]
        if lb then
            leaderboard[i] = {
                player = BJIContext.Players[lb.playerID],
                speed = lb.speed,
                time = lb.time,
            }
        end
    end

    local indexWidth = 0
    for i = 1, table.length(sm.participants) do
        local w = GetColumnTextWidth(string.var("{1} - ", { i }))
        if w > indexWidth then
            indexWidth = w
        end
    end

    local nameWidth = 0
    for _, lb in pairs(leaderboard) do
        local w = GetColumnTextWidth(lb.player.playerName)
        if w > nameWidth then
            nameWidth = w
        end
    end
    local cols = ColumnsBuilder("BJISpeedLeaderboard", { indexWidth, nameWidth, -1 })
    for i = 1, table.length(sm.participants) do
        local lb = leaderboard[i]
        local textColor = TEXT_COLORS.DEFAULT
        if lb and BJIContext.isSelf(lb.player.playerID) then
            textColor = TEXT_COLORS.HIGHLIGHT
        end
        cols:addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(string.var("{1} - ", { i }), textColor)
                        :build()
                end,
                lb and function()
                    LineBuilder()
                        :text(lb.player.playerName, textColor)
                        :build()
                end or nil,
                lb and function()
                    local time = ""
                    if lb.time then
                        time = string.var(", {1}", { RaceDelay(lb.time) })
                    end
                    LineBuilder()
                        :text(string.var("({1}{2}{3})", {
                            lb.speed,
                            BJILang.get("speed.speedUnit"),
                            time,
                        }), textColor)
                        :build()
                end or nil,
            }
        })
    end
    cols:build()
end

return {
    flags = {
        WINDOW_FLAGS.NO_COLLAPSE
    },
    header = drawHeader,
    body = drawBody,
}
