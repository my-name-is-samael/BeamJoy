local W = {
    name = "ServerBJC",

    ---@class BJIServerAccordionConfig
    ---@field labelKey string
    ---@field render fun(ctxt: TickContext, labels: table, cache: table?)
    ---@field permission string?
    ---@field minimumGroup string?

    ---@type tablelib<integer, BJIServerAccordionConfig> index 1-N
    ACCORDION = Table({
        {
            minimumGroup = BJI.CONSTANTS.GROUP_NAMES.OWNER,
            labelKey = "server",
            render = require("ge/extensions/BJI/ui/windows/Server/BJC/Server"),
        },
        {
            permission = BJI.Managers.Perm.PERMISSIONS.WHITELIST,
            labelKey = "whitelist",
            render = require("ge/extensions/BJI/ui/windows/Server/BJC/Whitelist"),
        },
        {
            permission = BJI.Managers.Perm.PERMISSIONS.SET_CONFIG,
            labelKey = "voteKick",
            render = require("ge/extensions/BJI/ui/windows/Server/BJC/VoteKick"),
        },
        {
            permission = BJI.Managers.Perm.PERMISSIONS.SET_CONFIG,
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
            labelKey = "infected",
            render = require("ge/extensions/BJI/ui/windows/Server/BJC/Infected"),
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
    }),
    ---@type tablelib<integer, BJIServerAccordionConfig> index 1-N
    filtered = Table(),

    labels = {
        whitelist = {
            title = "",
            state = "",
            enabled = "",
            disabled = "",
            players = "",
            addAllConnectedPlayers = "",
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
            minDefault = 0,
            maxDefault = 0,
            maxOverall = 0,
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
        infected = {
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
            add = "",
            remove = "",
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
            },
        },
        buttons = {
            reset = "",
            save = "",
            resetAll = "",
            add = "",
            remove = "",
        },
    },
    cache = {
        disableInputs = false,
        whitelist = {
            online = Table(),
            offline = Table(),
            addName = "",
            canToggleState = false,
        },
        voteKick = {
            timeoutPretty = "",
        },
        mapVote = {
            timeoutPretty = "",
        },
        tempban = {
            minTime = 0,
            maxTime = 0,
            minTimePretty = "",
            maxTimePretty = "",
        },
        vehicleDelivery = {
            ---@type tablelib<integer, {model: string, label: string}> index 1-N
            displayList = Table(),
            ---@type tablelib<integer, {value: string, label: string}> index 1-N
            modelsCombo = Table(),
            ---@type string?
            selectedModel = nil,
        },
        server = {
            broadcasts = {
                prettyBrodcastsDelay = "",
                ---@type tablelib<integer, {value: string, label: string}> index 1-N
                langs = Table(),
                ---@type string?
                selectedLang = nil,
            },
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
    W.labels.infected.title = BJI.Managers.Lang.get("serverConfig.bjc.infected.title")
    W.labels.derby.title = BJI.Managers.Lang.get("serverConfig.bjc.derby.title")
    W.labels.vehicleDelivery.title = BJI.Managers.Lang.get("serverConfig.bjc.vehicleDelivery.title")
    W.labels.server.title = BJI.Managers.Lang.get("serverConfig.bjc.server.title")

    W.labels.whitelist.state = BJI.Managers.Lang.get("common.state") .. " :"
    W.labels.whitelist.enabled = BJI.Managers.Lang.get("common.enabled")
    W.labels.whitelist.disabled = BJI.Managers.Lang.get("common.disabled")
    W.labels.whitelist.players = BJI.Managers.Lang.get("serverConfig.bjc.whitelist.players") .. " :"
    W.labels.whitelist.addAllConnectedPlayers = BJI.Managers.Lang.get(
        "serverConfig.bjc.whitelist.addAllConnectedPlayers")
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

    Table(BJI.Managers.Context.BJC.Infected):forEach(function(_, k)
        W.labels.infected.keys[k] = BJI.Managers.Lang.get("serverConfig.bjc.infected." .. k)
        W.labels.infected.keys[k .. "Tooltip"] = BJI.Managers.Lang.get("serverConfig.bjc.infected." .. k .. "Tooltip",
            "")
        if #W.labels.infected.keys[k .. "Tooltip"] == 0 then
            W.labels.infected.keys[k .. "Tooltip"] = nil
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
    W.labels.vehicleDelivery.add = BJI.Managers.Lang.get("common.buttons.add")
    W.labels.vehicleDelivery.remove = BJI.Managers.Lang.get("common.buttons.remove")

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

    W.labels.buttons.reset = BJI.Managers.Lang.get("common.buttons.reset")
    W.labels.buttons.save = BJI.Managers.Lang.get("common.buttons.save")
    W.labels.buttons.resetAll = BJI.Managers.Lang.get("common.buttons.resetAll")
    W.labels.buttons.add = BJI.Managers.Lang.get("common.buttons.add")
    W.labels.buttons.remove = BJI.Managers.Lang.get("common.buttons.remove")
end

local function updateCache()
    W.cache.disableInputs = false

    if BJI.Managers.Context.BJC.Whitelist then
        W.cache.whitelist.online = BJI.Managers.Context.Players:map(function(p)
            return p.playerName
        end):values()
        W.cache.whitelist.offline = Table(BJI.Managers.Context.BJC.Whitelist.PlayerNames)
            :filter(function(p)
                return not table.includes(W.cache.whitelist.online, p)
            end):values()
        W.cache.whitelist.canToggleState = BJI.Managers.Perm.hasMinimumGroup(BJI.CONSTANTS.GROUP_NAMES.ADMIN)
    end

    if BJI.Managers.Context.BJC.VoteKick then
        W.cache.voteKick.timeoutPretty = BJI.Utils.UI.PrettyDelay(BJI.Managers.Context.BJC.VoteKick.Timeout)
    end

    if BJI.Managers.Context.BJC.VoteMap then
        W.cache.mapVote.timeoutPretty = BJI.Utils.UI.PrettyDelay(BJI.Managers.Context.BJC.VoteMap.Timeout)
    end

    if BJI.Managers.Context.BJC.TempBan then
        W.cache.tempban.minTime = BJI.Managers.Context.BJC.TempBan.minTime
        W.cache.tempban.maxTime = BJI.Managers.Context.BJC.TempBan.maxTime
        W.cache.tempban.minTimePretty = BJI.Utils.UI.PrettyDelay(BJI.Managers.Context.BJC.TempBan.minTime)
        W.cache.tempban.maxTimePretty = BJI.Utils.UI.PrettyDelay(BJI.Managers.Context.BJC.TempBan.maxTime)
        W.cache.tempban.minDefault = 300                -- 5 min
        W.cache.tempban.maxDefault = 60 * 60 * 24 * 30  -- 1 month
        W.cache.tempban.maxOverall = 60 * 60 * 24 * 365 -- 1 year
    end

    if BJI.Managers.Context.BJC.VehicleDelivery then
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
        W.cache.vehicleDelivery.modelsCombo = res.combo
        if not W.cache.vehicleDelivery.modelsCombo
            :any(function(option) return option.value == W.cache.vehicleDelivery.selectedModel end) then
            W.cache.vehicleDelivery.selectedModel = W.cache.vehicleDelivery.modelsCombo[1].value
        end
        W.cache.vehicleDelivery.displayList = res.display
    end
end

local function initServer()
    if BJI.Managers.Perm.hasMinimumGroup(W.ACCORDION[1].minimumGroup) then
        W.cache.server.broadcasts.langs = Table(BJI.Managers.Lang.Langs)
            :map(function(l)
                return {
                    value = l,
                    label = string.format("%s (%d)", l:upper(), #BJI.Managers.Context.BJC.Server.Broadcasts[l]),
                }
            end):sort(function(a, b) return a.label < b.label end)
        if not W.cache.server.broadcasts.langs
            :any(function(l) return l.value == W.cache.server.broadcasts.selectedLang end) then
            W.cache.server.broadcasts.selectedLang = W.cache.server.broadcasts.langs[1].value
        end
        W.cache.server.broadcasts.prettyBrodcastsDelay = BJI.Utils.UI.PrettyDelay(
            BJI.Managers.Context.BJC.Server.Broadcasts.delay)
    end
end

local function updateAccordions()
    ---@param accordionContent BJIServerAccordionConfig
    W.filtered = W.ACCORDION:filter(function(accordionContent)
        if accordionContent.permission and not BJI.Managers.Perm.hasPermission(accordionContent.permission) then
            return false
        end
        if accordionContent.minimumGroup and not BJI.Managers.Perm.hasMinimumGroup(accordionContent.minimumGroup) then
            return false
        end
        return true
    end)
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.LANG_CHANGED, updateLabels,
        W.name .. "Labels"))

    updateCache()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.CACHE_LOADED,
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
    }, function(_, data)
        if data._event ~= BJI.Managers.Events.EVENTS.CACHE_LOADED or
            table.includes({ BJI.Managers.Cache.CACHES.BJC,
                BJI.Managers.Cache.CACHES.PLAYERS }, data.cache) then
            updateCache()
        end
    end, W.name .. "Cache"))

    initServer()

    updateAccordions()
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        function()
            updateAccordions()
        end, W.name .. "PermissionFilter"))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

local function body(ctxt)
    if #W.filtered == 0 then
        return -- no content
    elseif #W.filtered == 1 then
        Text(W.labels[W.filtered[1].labelKey].title)
        Indent()
        W.filtered[1].render(ctxt, W.labels, W.cache)
        Unindent()
    else
        ---@param accordionContent BJIServerAccordionConfig
        W.filtered:forEach(function(accordionContent)
            if BeginTree(W.labels[accordionContent.labelKey].title) then
                accordionContent.render(ctxt, W.labels, W.cache)
                EndTree()
            end
        end)
    end
end

W.onLoad = onLoad
W.onUnload = onUnload
W.body = body

return W
