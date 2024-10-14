local function draw(ctxt)
    LineBuilder()
        :icon({
            icon = ICONS.event_note,
            big = true,
        })
        :build()

    local elems = {}
    table.insert(elems, {
        drawFn = require("ge/extensions/BJI/ui/WindowEvents/VoteKick"),
        show = BJIVote.Kick.started,
    })
    table.insert(elems, {
        drawFn = require("ge/extensions/BJI/ui/WindowEvents/VoteMap"),
        show = BJIVote.Map.started,
    })
    table.insert(elems, {
        drawFn = require("ge/extensions/BJI/ui/WindowEvents/RacePreparation"),
        show = BJIVote.Race.started,
    })
    table.insert(elems, {
        drawFn = require("ge/extensions/BJI/ui/WindowEvents/VoteSpeed"),
        show = BJIVote.Speed.started,
    })

    for i in ipairs(elems) do
        while elems[i] and not elems[i].show() do
            table.remove(elems, i)
        end
    end

    for i, v in ipairs(elems) do
        v.drawFn(ctxt)
        if i < #elems then
            Separator()
        end
    end
end
return {
    flags = function()
        return {
            WINDOW_FLAGS.NO_COLLAPSE
        }
    end,
    body = draw,
}
