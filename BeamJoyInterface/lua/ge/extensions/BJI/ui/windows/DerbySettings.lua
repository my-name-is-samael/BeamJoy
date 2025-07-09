---@class BJIWindowDerbySettings : BJIWindow
local W = {
    name = "DerbySettings",
    flags = {
        BJI.Utils.Style.WINDOW_FLAGS.NO_COLLAPSE,
    },
    minSize = ImVec2(450, 300),
    maxSize = ImVec2(800, 300),

    show = false,

    labels = {
        title = "",
        places = "",
        presets = "",
        lives = "",
        configs = "",
        configsTooltip = "",
        specificConfig = "",

        protectedVehicle = "",
        selfProtected = "",

        buttons = {
            spawn = "",
            replace = "",
            remove = "",
            add = "",
            close = "",
            startVote = "",
            start = "",
        },
    },
    data = {
        arenaIndex = 0,
        arena = {},
        lives = 3,
        ---@type {label: string, model: string, key?: string, custom: boolean, config: table}[]|tablelib
        configs = Table(),

        places = "",

        currentVehProtected = false,
        selfProtected = false,
        canSpawnNewVeh = false,

        showVoteBtn = false,
        showStartBtn = false,
    },

    presets = require("ge/extensions/utils/VehiclePresets").getDerbyPresets(),
}
--- gc prevention
local nextValue, tooltip, j

local function onClose()
    W.show = false
end

local function updateLabels()
    W.labels.title = BJI.Managers.Lang.get("derby.settings.title")
    W.labels.places = BJI.Managers.Lang.get("derby.settings.places")
    W.labels.presets = BJI.Managers.Lang.get("derby.settings.presets") .. " :"
    W.labels.lives = BJI.Managers.Lang.get("derby.settings.lives")
    W.labels.configs = BJI.Managers.Lang.get("derby.settings.configs")
    W.labels.configsTooltip = BJI.Managers.Lang.get("derby.settings.configsTooltip")
    W.labels.specificConfig = BJI.Managers.Lang.get("derby.settings.specificConfig")

    W.labels.protectedVehicle = BJI.Managers.Lang.get("vehicleSelector.protectedVehicle")
    W.labels.selfProtected = BJI.Managers.Lang.get("vehicleSelector.selfProtected")

    W.labels.buttons.spawn = BJI.Managers.Lang.get("common.buttons.spawn")
    W.labels.buttons.replace = BJI.Managers.Lang.get("common.buttons.replace")
    W.labels.buttons.remove = BJI.Managers.Lang.get("common.buttons.remove")
    W.labels.buttons.add = BJI.Managers.Lang.get("common.buttons.add")
    W.labels.buttons.close = BJI.Managers.Lang.get("common.buttons.close")
    W.labels.buttons.startVote = BJI.Managers.Lang.get("common.buttons.startVote")
    W.labels.buttons.start = BJI.Managers.Lang.get("common.buttons.start")
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI.Managers.Tick.getContext()

    W.data.places = string.var("({1})", { W.labels.places:var({ places = #W.data.arena.startPositions }) })

    W.data.currentVehProtected = ctxt.veh and not ctxt.isOwner and ctxt.veh.protected
    W.data.selfProtected = ctxt.isOwner and settings.getValue("protectConfigFromClone", false) == true
    W.data.canSpawnNewVeh = BJI.Managers.Perm.canSpawnNewVehicle()

    W.data.showVoteBtn = not BJI.Managers.Tournament.state and
        BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.VOTE_SERVER_SCENARIO)
    W.data.showStartBtn = BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_SERVER_SCENARIO)
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.LANG_CHANGED, updateLabels, W.name))

    updateCache()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED,
        BJI.Managers.Events.EVENTS.VEHICLE_SPEC_CHANGED,
        BJI.Managers.Events.EVENTS.CONFIG_PROTECTION_UPDATED,
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        BJI.Managers.Events.EVENTS.TOURNAMENT_UPDATED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateCache, W.name .. "Cache"))

    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.CACHE_LOADED,
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
        BJI.Managers.Events.EVENTS.SCENARIO_CHANGED,
    }, function(_, data)
        local mustClose, msg = false, ""
        if data._event == BJI.Managers.Events.EVENTS.CACHE_LOADED and
            data.cache == BJI.Managers.Cache.CACHES.PLAYERS then
            if BJI.Managers.Perm.getCountPlayersCanSpawnVehicle() < BJI.Managers.Scenario.get(BJI.Managers.Scenario.TYPES.DERBY).MINIMUM_PARTICIPANTS then
                mustClose, msg = true, BJI.Managers.Lang.get("derby.settings.notEnoughPlayers")
            end
        else
            if not BJI.Managers.Scenario.is(BJI.Managers.Scenario.TYPES.FREEROAM) or
                (not BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.START_SERVER_SCENARIO) and
                    not BJI.Managers.Perm.hasPermission(BJI.Managers.Perm.PERMISSIONS.VOTE_SERVER_SCENARIO)) then
                mustClose = true
            end
        end
        if mustClose then
            if msg then
                BJI.Managers.Toast.warning(msg)
            end
            onClose()
        end
    end, W.name .. "AutoClose"))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

---@param arenaIndex integer
local function open(arenaIndex)
    if not BJI.Managers.Context.Scenario.Data.Derby or
        not BJI.Managers.Context.Scenario.Data.Derby[arenaIndex] then
        return
    end

    W.data.arenaIndex = arenaIndex
    W.data.arena = BJI.Managers.Context.Scenario.Data.Derby[arenaIndex]
    if W.show then updateCache() end
    W.show = true
end

---@param ctxt TickContext
local function header(ctxt)
    if BeginTable("BJIDerbyHeader", {
            { label = "##derby-settings-header-label" },
            { label = "##derby-settings-header-presets" }
        }, { flags = { TABLE_FLAGS.SIZING_STRETCH_SAME } }) then
        TableNewRow()
        Text(W.labels.title)
        Text(W.data.arena.name)
        SameLine()
        Text(W.data.places)
        TableNextColumn()
        Text(W.labels.presets)
        Table(W.presets):forEach(function(preset, i)
            if i > 1 then
                SameLine()
            end
            if Button("derby-preset-" .. tostring(i), preset.label,
                    { disabled = #W.data.configs == 5 }) then
                W.data.configs:addAll(
                    Range(1, 5 - #W.data.configs)
                    :reduce(function(acc)
                        j = nil
                        while not j do
                            j = math.random(#acc.configs)
                            if W.data.configs:find(function(c)
                                    return c.model == acc.configs[j].model and
                                        c.key == acc.configs[j].key
                                end) then
                                acc.configs:remove(j)
                                j = nil
                            end
                        end
                        acc.gen:insert(acc.configs:remove(j))
                        return acc
                    end, { gen = Table(), configs = table.clone(preset.configs) }).gen
                    :map(function(gen)
                        return BJI.Managers.Veh.getFullConfig(BJI.Managers.Veh
                            .getConfigByModelAndKey(gen.model, gen.key))
                    end)
                )
            end
        end)

        EndTable()
    end
end

---@param ctxt TickContext
local function addCurrentConfig(ctxt)
    local config = BJI.Managers.Veh.getFullConfig(ctxt.veh.veh.partConfig) or {}
    ---@param c ClientVehicleConfig
    if W.data.configs:any(function(c)
            return table.compare(config.parts, c.parts)
        end) then
        BJI.Managers.Toast.error(BJI.Managers.Lang.get("derby.settings.toastConfigAlreadySaved"))
    else
        W.data.configs:insert(config)
    end
end

---@param ctxt TickContext
local function body(ctxt)
    if BeginTable("BJIDerbySettings", {
            { label = "##derby-settings-labels" },
            { label = "##derby-settings-configs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } }
        }) then
        -- lives
        TableNewRow()
        Text(W.labels.lives)
        TableNextColumn()
        nextValue = SliderInt("derbyLives", W.data.lives, 0, 5)
        if nextValue then
            W.data.lives = nextValue
        end

        -- configs
        TableNewRow()
        Text(W.labels.configs)
        TooltipText(W.labels.configsTooltip)
        TableNextColumn()
        W.data.configs:forEach(function(config, i)
            if IconButton("showDerbyConfig" .. tostring(i), BJI.Utils.Icon.ICONS.visibility,
                    { btnStyle = ctxt.isOwner and BJI.Utils.Style.BTN_PRESETS.WARNING or
                        BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = not ctxt.isOwner and
                        not W.data.canSpawnNewVeh }) then
                BJI.Managers.Veh.replaceOrSpawnVehicle(config.model, config.key or config)
            end
            TooltipText(ctxt.isOwner and W.labels.buttons.replace or W.labels.buttons.spawn)
            SameLine()
            if IconButton("removeDerbyConfig" .. tostring(i), BJI.Utils.Icon.ICONS.delete_forever,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
                W.data.configs:remove(i)
            end
            TooltipText(W.labels.buttons.remove)
            SameLine()
            Text(config.label)
        end)
        if #W.data.configs < 5 then
            if IconButton("addDerbyConfig", BJI.Utils.Icon.ICONS.add,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                        disabled = not ctxt.veh or W.data.currentVehProtected or W.data.selfProtected }) then
                addCurrentConfig(ctxt)
            end
            if W.data.currentVehProtected then
                tooltip = W.labels.protectedVehicle
            elseif W.data.selfProtected then
                tooltip = W.labels.selfProtected
            else
                tooltip = W.labels.buttons.add
            end
            TooltipText(tooltip)
        end

        EndTable()
    end
end

---@param ctxt TickContext
local function footer(ctxt)
    if IconButton("closeDerbySettings", BJI.Utils.Icon.ICONS.exit_to_app,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
        onClose()
    end
    TooltipText(W.labels.buttons.close)
    if W.data.showVoteBtn then
        SameLine()
        if IconButton("startVoteDerby", BJI.Utils.Icon.ICONS.event_available,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
            BJI.Tx.vote.ScenarioStart(BJI.Managers.Votes.SCENARIO_TYPES.DERBY, true, {
                arenaIndex = W.data.arenaIndex,
                lives = W.data.lives,
                configs = W.data.configs,
            })
            onClose()
        end
        TooltipText(W.labels.buttons.startVote)
    end
    if W.data.showStartBtn then
        SameLine()
        if IconButton("startDerby", BJI.Utils.Icon.ICONS.videogame_asset,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
            BJI.Tx.vote.ScenarioStart(BJI.Managers.Votes.SCENARIO_TYPES.DERBY, false, {
                arenaIndex = W.data.arenaIndex,
                lives = W.data.lives,
                configs = W.data.configs,
            })
            onClose()
        end
        TooltipText(W.labels.buttons.start)
    end
end

W.onLoad = onLoad
W.onUnload = onUnload
W.open = open
W.header = header
W.body = body
W.footer = footer
W.onClose = onClose
W.getState = function() return W.show end

return W
