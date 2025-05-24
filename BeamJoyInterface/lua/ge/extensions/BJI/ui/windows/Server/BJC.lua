local W = {
    name = "ServerBJC",

    ACCORDION = Table({
        {
            labelKey = "whitelist",
            render = require("ge/extensions/BJI/ui/windows/Server/BJC/Whitelist"),
        },
        {
            labelKey = "voteKick",
            render = require("ge/extensions/BJI/ui/windows/Server/BJC/VoteKick"),
        },
        {
            labelKey = "mapVote",
            render = require("ge/extensions/BJI/ui/windows/Server/BJC/VoteMap"),
        },
        {
            permission = BJI.Managers.Perm.PERMISSIONS.BAN,
            labelKey = "tempban",
            render = require("ge/extensions/BJI/ui/windows/Server/BJC/Tempban"),
        },
        {
            permission = BJI.Managers.Perm.PERMISSIONS.SCENARIO,
            labelKey = "race",
            render = require("ge/extensions/BJI/ui/windows/Server/BJC/Race"),
        },
        {
            permission = BJI.Managers.Perm.PERMISSIONS.SCENARIO,
            labelKey = "speed",
            render = require("ge/extensions/BJI/ui/windows/Server/BJC/Speed"),
        },
        {
            permission = BJI.Managers.Perm.PERMISSIONS.SCENARIO,
            labelKey = "hunter",
            render = require("ge/extensions/BJI/ui/windows/Server/BJC/Hunter"),
        },
        {
            permission = BJI.Managers.Perm.PERMISSIONS.SCENARIO,
            labelKey = "derby",
            render = require("ge/extensions/BJI/ui/windows/Server/BJC/Derby"),
        },
        {
            permission = BJI.Managers.Perm.PERMISSIONS.SCENARIO,
            labelKey = "vehicleDelivery",
            render = require("ge/extensions/BJI/ui/windows/Server/BJC/VehicleDelivery"),
        },
        {
            minimumGroup = BJI.CONSTANTS.GROUP_NAMES.OWNER,
            labelKey = "server",
            render = require("ge/extensions/BJI/ui/windows/Server/BJC/Server"),
        },
    }),

    labels = {
        whitelist = {
            title = "",
            state = "",
            players = "",
            offlinePlayers = "",
            addOfflinePlayer = "",
            addOfflinePlayerPlaceholder = "",
        },
        voteKick = {
            title = "",
            timeout = "",
            thresholdRatio = "",
        },
        mapVote = {
            title = "",
            timeout = "",
            thresholdRatio = "",
        },
        tempban = {
            title = "",
            minTime = "",
            maxTime = "",
            zeroTooltip = "",
        },
        race = {
            title = "",
            keys = {},
        },
        speed = {
            title = "",
            keys = {},
        },
        hunter = {
            title = "",
            keys = {},
        },
        derby = {
            title = "",
            keys = {},
        },
        vehicleDelivery = {
            title = "",
            modelBlacklist = "",
        },
        server = {
            title = "",
            lang = "",
            allowMods = "",
            driftBigBroadcast = "",
            broadcasts = {
                title = "",
                tooltip = "",
                delay = "",
                lang = "",
                broadcast = "",
            },
            welcomeMessage = {
                title = "",
                tooltip = "",
                message = "",
            }
        },
    },
    cache = {
        disableInputs = false,
        whitelist = {
            online = Table(),
            offline = Table(),
            addName = "",
        },
        voteKick = {
            labelsWidth = 0,
            timeoutPretty = "",
        },
        mapVote = {
            labelsWidth = 0,
            timeoutPretty = "",
        },
        tempban = {
            minTimePretty = "",
            maxTimePretty = "",
        },
        race = {
            labelsWidth = 0,
        },
        speed = {
            labelsWidth = 0,
        },
        hunter = {
            labelsWidth = 0,
        },
        derby = {
            labelsWidth = 0,
        },
        vehicleDelivery = {
            displayList = Table(),
            ---@type {value: string, label: string}[]
            modelsCombo = Table(),
            ---@type {value: string, label: string}?
            selectedModel = nil,
        },
        server = {
            broadcasts = {
                ---@type {value: string, label: string}[]
                langs = Table(),
                ---@type {value: string, label: string}?
                selectedLang = nil,
            },
            welcomeMessage = {
                langsWidth = 0,
            }
        },
    },
}

local function updateLabels()
    W.labels.whitelist.title = BJI.Managers.Lang.get("serverConfig.bjc.whitelist.title")
    W.labels.voteKick.title = BJI.Managers.Lang.get("serverConfig.bjc.voteKick.title")
    W.labels.mapVote.title = BJI.Managers.Lang.get("serverConfig.bjc.mapVote.title")
    W.labels.tempban.title = BJI.Managers.Lang.get("serverConfig.bjc.tempban.title")
    W.labels.race.title = BJI.Managers.Lang.get("serverConfig.bjc.race.title")
    W.labels.speed.title = BJI.Managers.Lang.get("serverConfig.bjc.speed.title")
    W.labels.hunter.title = BJI.Managers.Lang.get("serverConfig.bjc.hunter.title")
    W.labels.derby.title = BJI.Managers.Lang.get("serverConfig.bjc.derby.title")
    W.labels.vehicleDelivery.title = BJI.Managers.Lang.get("serverConfig.bjc.vehicleDelivery.title")
    W.labels.server.title = BJI.Managers.Lang.get("serverConfig.bjc.server.title")

    W.labels.whitelist.state = BJI.Managers.Lang.get("common.state") .. " :"
    W.labels.whitelist.players = BJI.Managers.Lang.get("serverConfig.bjc.whitelist.players") .. " :"
    W.labels.whitelist.offlinePlayers = BJI.Managers.Lang.get("serverConfig.bjc.whitelist.offlinePlayers") .. " :"
    W.labels.whitelist.addOfflinePlayer = BJI.Managers.Lang.get("serverConfig.bjc.whitelist.addOfflinePlayer") .. ":"
    W.labels.whitelist.addOfflinePlayerPlaceholder = BJI.Managers.Lang.get(
        "serverConfig.bjc.whitelist.addOfflinePlayerPlaceholder")

    W.labels.voteKick.timeout = BJI.Managers.Lang.get("serverConfig.bjc.voteKick.timeout") .. " :"
    W.labels.voteKick.thresholdRatio = BJI.Managers.Lang.get("serverConfig.bjc.voteKick.thresholdRatio") .. " :"

    W.labels.mapVote.timeout = BJI.Managers.Lang.get("serverConfig.bjc.mapVote.timeout") .. " :"
    W.labels.mapVote.thresholdRatio = BJI.Managers.Lang.get("serverConfig.bjc.mapVote.thresholdRatio") .. " :"

    W.labels.tempban.minTime = BJI.Managers.Lang.get("serverConfig.bjc.tempban.minTime") .. " :"
    W.labels.tempban.maxTime = BJI.Managers.Lang.get("serverConfig.bjc.tempban.maxTime") .. " :"
    W.labels.tempban.zeroTooltip = BJI.Managers.Lang.get("serverConfig.bjc.tempban.zeroTooltip")

    Table(BJI.Managers.Context.BJC.Race):forEach(function(_, k)
        W.labels.race.keys[k] = BJI.Managers.Lang.get("serverConfig.bjc.race." .. k)
        W.labels.race.keys[k .. "Tooltip"] = BJI.Managers.Lang.get("serverConfig.bjc.race." .. k .. "Tooltip", "")
        if #W.labels.race.keys[k .. "Tooltip"] == 0 then
            W.labels.race.keys[k .. "Tooltip"] = nil
        end
    end)

    Table(BJI.Managers.Context.BJC.Speed):forEach(function(_, k)
        W.labels.speed.keys[k] = BJI.Managers.Lang.get("serverConfig.bjc.speed." .. k)
        W.labels.speed.keys[k .. "Tooltip"] = BJI.Managers.Lang.get("serverConfig.bjc.speed." .. k .. "Tooltip", "")
        if #W.labels.speed.keys[k .. "Tooltip"] == 0 then
            W.labels.speed.keys[k .. "Tooltip"] = nil
        end
    end)

    Table(BJI.Managers.Context.BJC.Hunter):forEach(function(_, k)
        W.labels.hunter.keys[k] = BJI.Managers.Lang.get("serverConfig.bjc.hunter." .. k)
        W.labels.hunter.keys[k .. "Tooltip"] = BJI.Managers.Lang.get("serverConfig.bjc.hunter." .. k .. "Tooltip",
            "")
        if #W.labels.hunter.keys[k .. "Tooltip"] == 0 then
            W.labels.hunter.keys[k .. "Tooltip"] = nil
        end
    end)

    Table(BJI.Managers.Context.BJC.Derby):forEach(function(_, k)
        W.labels.derby.keys[k] = BJI.Managers.Lang.get("serverConfig.bjc.derby." .. k)
        W.labels.derby.keys[k .. "Tooltip"] = BJI.Managers.Lang.get("serverConfig.bjc.derby." .. k .. "Tooltip", "")
        if #W.labels.derby.keys[k .. "Tooltip"] == 0 then
            W.labels.derby.keys[k .. "Tooltip"] = nil
        end
    end)

    W.labels.vehicleDelivery.modelBlacklist = BJI.Managers.Lang.get("serverConfig.bjc.vehicleDelivery.modelBlacklist")

    W.labels.server.lang = BJI.Managers.Lang.get("serverConfig.bjc.server.lang") .. " :"
    W.labels.server.allowMods = BJI.Managers.Lang.get("serverConfig.bjc.server.allowMods") .. " :"
    W.labels.server.driftBigBroadcast = BJI.Managers.Lang.get("serverConfig.bjc.server.driftBigBroadcast") .. " :"
    W.labels.server.broadcasts.title = BJI.Managers.Lang.get("serverConfig.bjc.server.broadcasts.title") .. " :"
    W.labels.server.broadcasts.tooltip = BJI.Managers.Lang.get("serverConfig.bjc.server.broadcasts.tooltip")
    W.labels.server.broadcasts.delay = BJI.Managers.Lang.get("serverConfig.bjc.server.broadcasts.delay")
    W.labels.server.broadcasts.lang = BJI.Managers.Lang.get("serverConfig.bjc.server.broadcasts.lang")
    W.labels.server.broadcasts.broadcast = BJI.Managers.Lang.get("serverConfig.bjc.server.broadcasts.broadcast")
    W.labels.server.welcomeMessage.title = BJI.Managers.Lang.get("serverConfig.bjc.server.welcomeMessage.title") .. " :"
    W.labels.server.welcomeMessage.tooltip = BJI.Managers.Lang.get("serverConfig.bjc.server.welcomeMessage.tooltip")
    W.labels.server.welcomeMessage.message = BJI.Managers.Lang.get("serverConfig.bjc.server.welcomeMessage.message")
end

local function updateWidths()
    W.cache.voteKick.labelsWidth = Table({ W.labels.voteKick.timeout, W.labels.voteKick.thresholdRatio })
        :reduce(function(acc, l)
            local w = BJI.Utils.Common.GetColumnTextWidth(l)
            return w > acc and w or acc
        end, 0)

    W.cache.mapVote.labelsWidth = Table({ W.labels.mapVote.timeout, W.labels.mapVote.thresholdRatio })
        :reduce(function(acc, l)
            local w = BJI.Utils.Common.GetColumnTextWidth(l)
            return w > acc and w or acc
        end, 0)

    W.cache.race.labelsWidth = Table(W.labels.race.keys)
        ---@param k string
        :filter(function(_, k)
            return not k:endswith("Tooltip")
        end)
        :reduce(function(acc, l)
            local w = BJI.Utils.Common.GetColumnTextWidth(l)
            return w > acc and w or acc
        end, 0)

    W.cache.speed.labelsWidth = Table(W.labels.speed.keys)
        ---@param k string
        :filter(function(_, k)
            return not k:endswith("Tooltip")
        end)
        :reduce(function(acc, l)
            local w = BJI.Utils.Common.GetColumnTextWidth(l)
            return w > acc and w or acc
        end, 0)

    W.cache.hunter.labelsWidth = Table(W.labels.hunter.keys)
        ---@param k string
        :filter(function(_, k)
            return not k:endswith("Tooltip")
        end)
        :reduce(function(acc, l)
            local w = BJI.Utils.Common.GetColumnTextWidth(l)
            return w > acc and w or acc
        end, 0)

    W.cache.derby.labelsWidth = Table(W.labels.derby.keys)
        ---@param k string
        :filter(function(_, k)
            return not k:endswith("Tooltip")
        end)
        :reduce(function(acc, l)
            local w = BJI.Utils.Common.GetColumnTextWidth(l)
            return w > acc and w or acc
        end, 0)

    W.cache.server.welcomeMessage.langsWidth = Table(BJI.Managers.Lang.Langs)
        :reduce(function(acc, l)
            local w = BJI.Utils.Common.GetColumnTextWidth(W.labels.server.welcomeMessage.message
                :var({ lang = l:upper() }))
            return w > acc and w or acc
        end, 0)
end

local function updateCache()
    W.cache.disableInputs = false

    W.cache.whitelist.online = Table(BJI.Managers.Context.Players):map(function(p)
        return p.playerName
    end):values()
    W.cache.whitelist.offline = Table(BJI.Managers.Context.BJC.Whitelist.PlayerNames)
        :filter(function(p)
            return not table.includes(W.cache.whitelist.online, p)
        end):values()

    W.cache.voteKick.timeoutPretty = BJI.Utils.Common.PrettyDelay(BJI.Managers.Context.BJC.VoteKick.Timeout)

    W.cache.mapVote.timeoutPretty = BJI.Utils.Common.PrettyDelay(BJI.Managers.Context.BJC.VoteMap.Timeout)

    W.cache.tempban.minTimePretty = BJI.Utils.Common.PrettyDelay(BJI.Managers.Context.BJC.TempBan.minTime)
    W.cache.tempban.maxTimePretty = BJI.Utils.Common.PrettyDelay(BJI.Managers.Context.BJC.TempBan.maxTime)

    local res = Table(BJI.Managers.Veh.getAllVehicleLabels())
        :map(function(label, model)
            return {
                value = model,
                label = string.var("{1} ({2})", { label, model }),
            }
        end)
        :reduce(function(res, el)
            if table.includes(BJI.Managers.Context.BJC.VehicleDelivery.ModelBlacklist, el.value) then
                res.display:insert({ model = el.value, label = el.label })
            else
                res.combo:insert({ value = el.value, label = el.label })
            end
            return res
        end, Table({ combo = Table(), display = Table() }))
    res:forEach(function(list)
        list:sort(function(a, b)
            return a.label:lower() < b.label:lower()
        end)
    end)
    W.cache.vehicleDelivery.displayList = Table(res.display)
    W.cache.vehicleDelivery.modelsCombo = Table(res.combo)
    if not W.cache.vehicleDelivery.selectedModel or not W.cache.vehicleDelivery.modelsCombo
        :find(function(mc) return mc.value == W.cache.vehicleDelivery.selectedModel.value end) then
        W.cache.vehicleDelivery.selectedModel = W.cache.vehicleDelivery.modelsCombo[1]
    end
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, function()
        updateLabels()
        updateWidths()
    end, W.name))

    updateWidths()
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED, updateWidths, W.name))

    updateCache()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.CACHE_LOADED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, function(_, data)
        if data._event ~= BJI.Managers.Events.EVENTS.CACHE_LOADED or
            table.includes({ BJI.Managers.Cache.CACHES.BJC,
                BJI.Managers.Cache.CACHES.PLAYERS }, data.cache) then
            updateCache()
        end
    end, W.name))

    W.cache.server.broadcasts.langs = Table(BJI.Managers.Lang.Langs)
        :map(function(l)
            return {
                value = l,
                label = l:upper(),
            }
        end):sort(function(a, b) return a.label < b.label end)
    if not W.cache.server.broadcasts.selectedLang then
        W.cache.server.broadcasts.selectedLang = W.cache.server.broadcasts.langs[1]
    end
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

local function body(ctxt)
    W.ACCORDION:filter(function(a)
        if a.permission and not BJI.Managers.Perm.hasPermission(a.permission) then
            return false
        end
        if a.minimumGroup and not BJI.Managers.Perm.hasMinimumGroup(a.minimumGroup) then
            return false
        end
        return true
    end):forEach(function(a)
        AccordionBuilder()
            :label(W.labels[a.labelKey].title)
            :openedBehavior(function() a.render(ctxt, W.labels, W.cache) end)
            :build()
    end)
end

W.onLoad = onLoad
W.onUnload = onUnload
W.body = body

return W
