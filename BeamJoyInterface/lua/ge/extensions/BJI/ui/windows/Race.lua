local raceSolo = require("ge/extensions/BJI/ui/windows/Race/RaceSolo")
local raceMulti = require("ge/extensions/BJI/ui/windows/Race/RaceMulti")

---@class BJIWindowRace : BJIWindow
local W = {
    name = "Race",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE,
    },
    w = 300,
    h = 280,

    ---@type table?
    type = nil,
}

local function onLoad()
    W.type = BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.RACE_SOLO) and
        raceSolo or raceMulti
    W.type.onLoad()
end

local function onUnload()
    W.type.onUnload()
    W.type = nil
end

---@param ctxt TickContext
local function header(ctxt)
    if W.type and W.type.header then
        W.type.header(ctxt)
    end
end

---@param ctxt TickContext
local function body(ctxt)
    if W.type and W.type.body then
        W.type.body(ctxt)
    end
end

---@param ctxt TickContext
local function footer(ctxt)
    if W.type and W.type.footer then
        return W.type.footer()
    end
end


W.onLoad = onLoad
W.onUnload = onUnload
W.header = header
W.body = body
W.footer = footer
W.getState = function()
    return BJI.Managers.Cache.areBaseCachesFirstLoaded() and (
        BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.RACE_SOLO) or
        BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.RACE_MULTI)
    )
end

return W
