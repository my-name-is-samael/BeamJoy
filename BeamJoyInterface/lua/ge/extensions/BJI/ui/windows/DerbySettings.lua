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
local nextValue, tooltip

local function onClose()
    W.show = false
end

local function updateLabels()
    W.labels.title = BJI_Lang.get("derby.settings.title")
    W.labels.places = BJI_Lang.get("derby.settings.places")
    W.labels.presets = BJI_Lang.get("derby.settings.presets") .. " :"
    W.labels.lives = BJI_Lang.get("derby.settings.lives")
    W.labels.configs = BJI_Lang.get("derby.settings.configs")
    W.labels.configsTooltip = BJI_Lang.get("derby.settings.configsTooltip")
    W.labels.specificConfig = BJI_Lang.get("derby.settings.specificConfig")

    W.labels.protectedVehicle = BJI_Lang.get("vehicleSelector.protectedVehicle")
    W.labels.selfProtected = BJI_Lang.get("vehicleSelector.selfProtected")

    W.labels.buttons.spawn = BJI_Lang.get("common.buttons.spawn")
    W.labels.buttons.replace = BJI_Lang.get("common.buttons.replace")
    W.labels.buttons.remove = BJI_Lang.get("common.buttons.remove")
    W.labels.buttons.add = BJI_Lang.get("common.buttons.add")
    W.labels.buttons.close = BJI_Lang.get("common.buttons.close")
    W.labels.buttons.startVote = BJI_Lang.get("common.buttons.startVote")
    W.labels.buttons.start = BJI_Lang.get("common.buttons.start")
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI_Tick.getContext()

    W.data.places = string.var("({1})", { W.labels.places:var({ places = #W.data.arena.startPositions }) })

    W.data.currentVehProtected = ctxt.veh and not ctxt.isOwner and ctxt.veh.protected
    W.data.selfProtected = ctxt.isOwner and settings.getValue("protectConfigFromClone", false) == true
    W.data.canSpawnNewVeh = BJI_Perm.canSpawnNewVehicle()

    W.data.showVoteBtn = not BJI_Tournament.state and
        BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.VOTE_SERVER_SCENARIO)
    W.data.showStartBtn = BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.START_SERVER_SCENARIO)
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI_Events.addListener(BJI_Events.EVENTS.LANG_CHANGED, updateLabels, W.name))

    updateCache()
    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.UI_SCALE_CHANGED,
        BJI_Events.EVENTS.VEHICLE_SPEC_CHANGED,
        BJI_Events.EVENTS.CONFIG_PROTECTION_UPDATED,
        BJI_Events.EVENTS.PERMISSION_CHANGED,
        BJI_Events.EVENTS.TOURNAMENT_UPDATED,
        BJI_Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateCache, W.name .. "Cache"))

    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.CACHE_LOADED,
        BJI_Events.EVENTS.PERMISSION_CHANGED,
        BJI_Events.EVENTS.SCENARIO_CHANGED,
    }, function(_, data)
        local mustClose, msg = false, ""
        if data._event == BJI_Events.EVENTS.CACHE_LOADED and
            data.cache == BJI_Cache.CACHES.PLAYERS then
            if BJI_Perm.getCountPlayersCanSpawnVehicle() < BJI_Scenario.get(BJI_Scenario.TYPES.DERBY).MINIMUM_PARTICIPANTS then
                mustClose, msg = true, BJI_Lang.get("derby.settings.notEnoughPlayers")
            end
        else
            if not BJI_Scenario.is(BJI_Scenario.TYPES.FREEROAM) or
                (not BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.START_SERVER_SCENARIO) and
                    not BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.VOTE_SERVER_SCENARIO)) then
                mustClose = true
            end
        end
        if mustClose then
            if msg then
                BJI_Toast.warning(msg)
            end
            onClose()
        end
    end, W.name .. "AutoClose"))
end

local function onUnload()
    listeners:forEach(BJI_Events.removeListener)
end

local function addPresetConfigs(preset)
    W.data.configs:addAll(
        Range(1, 5 - #W.data.configs)
        :reduce(function(acc)
            local i = nil
            while not i do
                i = math.random(#acc.configs)
                if W.data.configs:find(function(c)
                        return c.model == acc.configs[i].model and
                            c.key == acc.configs[i].key
                    end) then
                    acc.configs:remove(i)
                    i = nil
                end
            end
            acc.gen:insert(acc.configs:remove(i))
            return acc
        end, { gen = Table(), configs = table.clone(preset.configs) }).gen
        :map(function(gen)
            return BJI_Veh.getFullConfig(BJI_Veh
                .getConfigByModelAndKey(gen.model, gen.key))
        end)
    )
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
                addPresetConfigs(preset)
            end
        end)

        EndTable()
    end
end

---@param ctxt TickContext
local function addCurrentConfig(ctxt)
    local config = ctxt.veh and ctxt.veh.isVehicle and
        BJI_Veh.getFullConfig(ctxt.veh.veh.partConfig)
    if not config then return BJI_Toast.error(BJI_Lang.get("vehicleSelector.invalidVeh")) end
    ---@param c ClientVehicleConfig
    if W.data.configs:any(function(c)
            return table.compare(config.parts, c.parts)
        end) then
        BJI_Toast.error(BJI_Lang.get("derby.settings.toastConfigAlreadySaved"))
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
                BJI_Veh.replaceOrSpawnVehicle(config.model, config.key or config)
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

---@param isVote boolean?
local function start(isVote)
    BJI_Tx_vote.ScenarioStart(BJI_Votes.SCENARIO_TYPES.DERBY, isVote == true, {
        arenaIndex = W.data.arenaIndex,
        lives = W.data.lives,
        configs = W.data.configs,
    })
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
            start(true)
            onClose()
        end
        TooltipText(W.labels.buttons.startVote)
    end
    if W.data.showStartBtn then
        SameLine()
        if IconButton("startDerby", BJI.Utils.Icon.ICONS.videogame_asset,
                { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
            start()
            onClose()
        end
        TooltipText(W.labels.buttons.start)
    end
end

---@param arenaIndex integer
local function open(arenaIndex)
    if not BJI_Scenario.Data.Derby[arenaIndex] then return end

    W.data.arenaIndex = arenaIndex
    W.data.arena = BJI_Scenario.Data.Derby[arenaIndex]
    if W.show then updateCache() end
    W.show = true
end

local function openPromptFlow(arenaIndex)
    if not BJI_Scenario.Data.Derby[arenaIndex] then return end
    if W.show then W.onClose() end
    W.data.arenaIndex = arenaIndex
    W.data.arena = BJI_Scenario.Data.Derby[arenaIndex]
    updateLabels()
    updateCache()

    local settingsButton = {
        icon = BJI_Prompt.quickIcons.settings,
        label = W.labels.title,
        needConfirm = true,
        onClick = function()
            W.open(W.data.arenaIndex)
        end,
    }
    local cancelButton = {
        label = BJI_Lang.get("common.buttons.cancel"),
    }
    local buttons
    local steps = Table()
    local titlePrefix = string.format("%s (%s) - ", W.labels.title,
        W.data.arena.name)

    -- lives
    buttons = Table({ 0, 1, 2, 3, 4, 5 }):map(function(l)
        return {
            icon = l > 0 and BJI_Prompt.quickIcons.derby_lives:var({ amount = l }) or
                BJI_Prompt.quickIcons.forbidden,
            label = BJI_Lang.get(l < 2 and "derby.play.amountLife" or
                "derby.play.amountLives"):var({ amount = l }),
            onClick = function(ctxt, nextStep)
                W.data.lives = l
                nextStep(2)
            end,
        }
    end)
    buttons:insert(settingsButton)
    steps:insert({
        id = 1,
        title = string.format("%s%s", titlePrefix, W.labels.lives),
        cancelButton = cancelButton,
        buttons = buttons,
    })

    -- vehicle(s)
    buttons = Table({
        {
            icon = BJI_Prompt.quickIcons.all_models,
            label = BJI_Lang.get("races.settings.vehicles.all"),
            onClick = function(ctxt, nextStep)
                W.data.configs = Table()
                nextStep(3)
            end,
        }
    })
    local ctxt = BJI_Tick.getContext()
    if ctxt.veh and ctxt.veh.isVehicle then
        buttons:insert({
            icon = BJI_Prompt.quickIcons.config,
            label = BJI_Lang.get("races.settings.vehicles.currentConfig"),
            onClick = function(ctxt, nextStep)
                W.data.configs = Table()
                addCurrentConfig(ctxt)
                nextStep(3)
            end,
        })
    end
    buttons:addAll(Table(W.presets):map(function(preset)
        return {
            icon = BJI_Prompt.quickIcons.all_models,
            label = preset.label,
            onClick = function(ctxt, nextStep)
                addPresetConfigs(preset)
                nextStep(3)
            end,
        }
    end))
    buttons:insert(settingsButton)
    steps:insert({
        id = 2,
        title = string.format("%s%s", titlePrefix, W.labels.configs),
        cancelButton = cancelButton,
        buttons = buttons,
    })

    -- start vote or start derby
    buttons = Table()
    if BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.VOTE_SERVER_SCENARIO) then
        buttons:insert({
            icon = BJI_Prompt.quickIcons.vote,
            label = W.labels.buttons.startVote,
            needConfirm = true,
            onClick = function() start(true) end,
        })
    end
    if BJI_Perm.hasPermission(BJI_Perm.PERMISSIONS.START_SERVER_SCENARIO) then
        buttons:insert({
            icon = BJI_Prompt.quickIcons.start,
            label = W.labels.buttons.start,
            needConfirm = true,
            onClick = function() start() end,
        })
    end
    buttons:insert(settingsButton)
    steps:insert({
        id = 3,
        title = string.format("%s%s", titlePrefix, W.labels.buttons.start),
        cancelButton = cancelButton,
        buttons = buttons,
    })

    BJI_Prompt.createFlow(steps)
end

W.onLoad = onLoad
W.onUnload = onUnload
W.header = header
W.body = body
W.footer = footer
W.onClose = onClose
W.getState = function() return W.show end

W.open = open
W.openPromptFlow = openPromptFlow

return W
