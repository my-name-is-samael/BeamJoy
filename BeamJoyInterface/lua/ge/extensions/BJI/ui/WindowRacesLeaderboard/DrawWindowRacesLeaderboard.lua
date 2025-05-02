local M = {
    AMOUNT_THRESHOLD = 5,
    show = false,
}

local cache = {
    namesWidth = 0,
    cols = {}
}

function M.onClose()
    LogError("CLOSE")
    M.show = false
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJITick.getContext()

    cache.namesWidth = 0
    cache.cols = table.filter(BJIContext.Scenario.Data.Races, function(race)
        return race.record
    end):map(function(race)
        local name = string.var("{1}:", { race.name })
        local w = GetColumnTextWidth(name)
        if w > cache.namesWidth then
            cache.namesWidth = w
        end
        return {
            cells = {
                function()
                    LineBuilder()
                        :text(name,
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
            },
            name = name,
        }
    end)

    table.sort(cache.cols, function(a, b)
        if a:find(b) then
            return false
        elseif b:find(a) then
            return true
        end
        return a.name < b.name
    end)

    if M.show then
        if #cache.cols <= M.AMOUNT_THRESHOLD then
            M.show = false
        end
    end
end

local listeners = {}
function M.onLoad()
    updateCache()
    table.insert(listeners, BJIEvents.addListener(BJIEvents.EVENTS.CACHE_LOADED, function(ctxt, data)
        if data.cache == BJICache.CACHES.RACES then
            updateCache(ctxt)
        end
    end))
end

function M.onUnload()
    table.forEach(listeners, BJIEvents.removeListener)
end

function M.body()
    local cols = ColumnsBuilder("BJIRacesLeaderboard", { cache.namesWidth, -1 })
    table.forEach(cache.cols, function(el)
        cols:addRow(el)
    end)
    cols:build()
end

return M
