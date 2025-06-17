---@class BJIScenarioVehicleDelivery : BJIScenario
local S = {
    _name = "VehicleDelivery",
    _key = "VEHICLE_DELIVERY",
    _isSolo = true,

    previousCamera = nil,

    model = nil,
    modelLabel = nil,
    ---@type { model: string, parts: table<string, string>, paints?: number[][] }?
    config = nil,
    configLabel = nil,
    paints = {},
    ---@type BJIPositionRotation?
    startPosition = nil,
    ---@type { pos: vec3, radius: number, distance?: number }?
    targetPosition = nil,
    gameVehID = nil,
    baseDistance = nil,
    distance = nil,

    nextResetExempt = false, -- scenario start fail-safe

    ---@type integer?
    checkTargetTime = nil, -- process to check player reached target and stayed in its radius
}

local function reset()
    S.previousCamera = nil

    S.model = nil
    S.modelLabel = nil
    S.config = nil
    S.configLabel = nil
    S.paints = {}
    S.startPosition = nil
    S.targetPosition = nil
    S.gameVehID = nil
    S.baseDistance = nil
    S.distance = nil

    S.checkTargetTime = nil
end

local function canChangeTo(ctxt)
    return BJI.Managers.Scenario.isFreeroam() and
        BJI.Managers.Cache.isFirstLoaded(BJI.Managers.Cache.CACHES.DELIVERIES) and
        BJI.Managers.Context.Scenario.Data.Deliveries and
        #BJI.Managers.Context.Scenario.Data.Deliveries > 1
end

local function initVehicle()
    local models = BJI.Managers.Veh.getAllVehicleConfigs()
    for _, name in ipairs(BJI.Managers.Context.BJC.VehicleDelivery.ModelBlacklist) do
        models[name] = nil
    end
    if table.length(models) == 0 then
        BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.FREEROAM)
        return
    end
    local model = table.random(models)
    if model then
        S.model = model.key
        S.modelLabel = BJI.Managers.Veh.getModelLabel(S.model)

        -- config
        local config
        while not config or config.label:lower():find("simplified") do
            config = table.random(model.configs)
        end
        if config then
            local configFile = BJI.Managers.Veh.getConfigByModelAndKey(model.key, config.key)
            S.config = BJI.Managers.Veh.getFullConfig(configFile)
            S.configLabel = config.label
        end

        -- paint
        for i = 1, 3 do
            local paint = table.random(model.paints)
            if paint then
                S.paints[i] = paint
            end
        end
    end
end

local function initPositions()
    S.startPosition = table.random(BJI.Managers.Context.Scenario.Data.Deliveries)

    local targets = {}
    for _, position in ipairs(BJI.Managers.Context.Scenario.Data.Deliveries) do
        -- local distance = BJIGPS.getRouteLength({ M.startPosition.pos, position.pos }) -- costs a lot
        local distance = math.horizontalDistance(S.startPosition.pos, position.pos)
        if position ~= S.startPosition and distance > 0 then
            table.insert(targets, {
                pos = position.pos,
                radius = position.radius,
                distance = distance,
            })
        end
    end
    table.sort(targets, function(a, b)
        return a.distance > b.distance
    end)
    if #targets > 1 then
        local threhsholdPos = math.ceil(#targets * .66) + 1 -- 66% furthest
        while targets[threhsholdPos] do
            table.remove(targets, threhsholdPos)
        end
    end
    S.targetPosition = table.random(targets)
    S.targetPosition.distance = nil
end

local function initDelivery()
    if not table.includes({
            BJI.Managers.Cam.CAMERAS.FREE,
            BJI.Managers.Cam.CAMERAS.EXTERNAL,
            BJI.Managers.Cam.CAMERAS.BIG_MAP
        }, BJI.Managers.Cam.getCamera()) then
        S.previousCamera = BJI.Managers.Cam.getCamera()
    end

    if S.paints then
        if not S.config.paints then
            S.config.paints = {}
        end
        S.config.paints[1] = S.paints[1]
        S.config.paints[2] = S.paints[2]
        S.config.paints[3] = S.paints[3]
    end
    BJI.Managers.Veh.replaceOrSpawnVehicle(S.model, S.config, S.startPosition)
    if S.previousCamera then
        BJI.Managers.Async.delayTask(function()
            BJI.Managers.Cam.setCamera(S.previousCamera, false)
        end, 100, "BJIVehDeliveryCamera")
    end

    BJI.Managers.GPS.prependWaypoint({
        key = BJI.Managers.GPS.KEYS.DELIVERY_TARGET,
        pos = S.targetPosition.pos,
        radius = S.targetPosition.radius,
        clearable = false
    })
    S.baseDistance = BJI.Managers.GPS.getCurrentRouteLength()
    BJI.Managers.RaceWaypoint.addWaypoint({
        name = "BJIVehicleDelivery",
        pos = S.targetPosition.pos,
        radius = S.targetPosition.radius,
        color = BJI.Managers.RaceWaypoint.COLORS.BLUE
    })
end

local function onLoad(ctxt)
    BJI.Managers.Restrictions.update({
        {
            restrictions = Table({
                BJI.Managers.Restrictions.OTHER.BIG_MAP,
                BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
                BJI.Managers.Restrictions.OTHER.FREE_CAM,
            }):flat(),
            state = BJI.Managers.Restrictions.STATE.RESTRICTED,
        }
    })

    BJI.Tx.scenario.DeliveryVehicleStart()
    S.gameVehID = ctxt.veh:getID()
    BJI.Managers.Message.flash("BJIDeliveryVehicleStart",
        BJI.Managers.Lang.get("vehicleDelivery.flashStart"), 5, false)
end

local function start()
    reset()
    BJI.Windows.VehSelector.tryClose()

    BJI.Managers.UI.applyLoading(true, function()
        initPositions()
        initVehicle()
        if S.startPosition and S.targetPosition and S.model then
            BJI.Managers.GPS.reset()
            BJI.Managers.RaceWaypoint.resetAll()
            initDelivery()
            BJI.Managers.Veh.waitForVehicleSpawn(function(ctxt)
                S.nextResetExempt = true
                BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.VEHICLE_DELIVERY, ctxt)
                BJI.Managers.UI.applyLoading(false)
                BJI.Managers.Async.delayTask(function()
                    S.nextResetExempt = false
                end, 1000, "BJIVehDeliveryStartResetExempt")
            end)
        else
            BJI.Managers.UI.applyLoading(false)
            BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.FREEROAM)
        end
    end)
end

local function onUnload(ctxt)
    BJI.Managers.Restrictions.update({ {
        restrictions = Table({
            BJI.Managers.Restrictions.OTHER.BIG_MAP,
            BJI.Managers.Restrictions.OTHER.VEHICLE_SWITCH,
            BJI.Managers.Restrictions.OTHER.FREE_CAM,
        }):flat(),
        state = BJI.Managers.Restrictions.STATE.ALLOWED,
    } })
    BJI.Managers.GPS.reset()
    BJI.Managers.RaceWaypoint.resetAll()
end

local function onDeliveryFailed()
    BJI.Tx.scenario.DeliveryVehicleFail()
    BJI.Managers.Message.flash("BJIDeliveryFail", BJI.Managers.Lang.get("vehicleDelivery.flashFail"), 3, false,
        GetCurrentTime())
    reset()
    BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.FREEROAM)
end

local function onVehicleResetted(gameVehID)
    if gameVehID ~= S.gameVehID or
        not BJI.Managers.Veh.isVehicleOwn(gameVehID) then
        return
    end

    if S.nextResetExempt then
        S.nextResetExempt = false
        return
    end

    onDeliveryFailed()
end

local function onStopDelivery()
    onDeliveryFailed()
end

local function drawUI(ctxt)
    local loop = BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.SCENARIO_VEHICLE_DELIVERY_LOOP)
    local line = LineBuilder():btnIcon({
        id = "stopVehicleDelivery",
        icon = BJI.Utils.Icon.ICONS.exit_to_app,
        style = BJI.Utils.Style.BTN_PRESETS.ERROR,
        tooltip = BJI.Managers.Lang.get("menu.scenario.vehicleDelivery.stop"),
        onClick = S.onStopDelivery,
    }):btnIconToggle({
        id = "vehicleDeliveryLoop",
        icon = BJI.Utils.Icon.ICONS.all_inclusive,
        state = loop,
        tooltip = BJI.Managers.Lang.get("common.buttons.loop"),
        onClick = function()
            BJI.Managers.LocalStorage.set(BJI.Managers.LocalStorage.GLOBAL_VALUES.SCENARIO_VEHICLE_DELIVERY_LOOP,
                not loop)
        end,
    }):text(BJI.Managers.Lang.get("vehicleDelivery.title"))
    if S.checkTargetTime then
        local remainingSec = math.ceil((S.checkTargetTime - ctxt.now) / 1000)
        if remainingSec > 0 then
            line:text(string.var("({1})", { BJI.Managers.Lang.get("vehicleDelivery.deliveredIn"):var({
                delay = remainingSec
            }) }), BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT)
        end
    end
    line:build()

    LineLabel(string.var("{1}: {2}{3}", {
        BJI.Managers.Lang.get("vehicleDelivery.vehicle"), S.modelLabel, S.configLabel and
    string.var(" {1}", { S.configLabel }) or "",
    }))

    local damages = tonumber(ctxt.veh.damageState)
    if damages and damages > BJI.Managers.Context.VehiclePristineThreshold then
        LineLabel(BJI.Managers.Lang.get("vehicleDelivery.damagedWarning"), BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT)
    end

    if S.distance then
        ProgressBar({
            floatPercent = 1 - math.max(S.distance / S.baseDistance, 0),
            style = BJI.Utils.Style.BTN_PRESETS.INFO[1],
            tooltip = string.var("{1}: {2}", {
                BJI.Managers.Lang.get("delivery.currentDelivery"),
                BJI.Managers.Lang.get("delivery.distanceLeft")
                    :var({ distance = BJI.Utils.UI.PrettyDistance(S.distance) })
            }),
        })
    end
end

local function onTargetReached(ctxt)
    if not ctxt.vehData then
        S.onStopDelivery()
        return
    end

    local damages = tonumber(ctxt.veh.damageState)
    local pristine = damages and
        damages <= BJI.Managers.Context.VehiclePristineThreshold
    BJI.Tx.scenario.DeliveryVehicleSuccess(pristine)

    if BJI.Managers.LocalStorage.get(BJI.Managers.LocalStorage.GLOBAL_VALUES.SCENARIO_VEHICLE_DELIVERY_LOOP) then
        BJI.Managers.Async.delayTask(function()
            if BJI.Managers.Scenario.isFreeroam() then
                S.start()
            end
        end, 3000, "BJIVehDeliveryLoop")
    end

    reset()
    BJI.Managers.Scenario.switchScenario(BJI.Managers.Scenario.TYPES.FREEROAM)
end

local function slowTick(ctxt)
    if not ctxt.isOwner then
        S.onStopDelivery()
        return
    end

    S.distance = BJI.Managers.GPS.getCurrentRouteLength()
    if S.distance > S.baseDistance then
        S.baseDistance = S.distance
    end

    local distance = ctxt.vehPosRot.pos:distance(S.targetPosition.pos)
    if distance < S.targetPosition.radius then
        if not S.checkTargetTime then
            S.checkTargetTime = ctxt.now + 3100
            BJI.Managers.Message.flashCountdown("BJIDeliveryTarget", S.checkTargetTime, false,
                BJI.Managers.Lang.get("vehicleDelivery.flashSuccess"),
                nil,
                onTargetReached)
        end
    else
        if S.checkTargetTime then
            BJI.Managers.Message.cancelFlash("BJIDeliveryTarget")
            S.checkTargetTime = nil
        end
        if #BJI.Managers.GPS.targets == 0 then
            BJI.Managers.GPS.prependWaypoint({
                key = BJI.Managers.GPS.KEYS.DELIVERY_TARGET,
                pos = S.targetPosition.pos,
                radius = S.targetPosition.radius,
                clearable = false
            })
        end
    end
end

local function getPlayerListActions(player, ctxt)
    local actions = {}

    if BJI.Managers.Votes.Kick.canStartVote(player.playerID) then
        BJI.Utils.UI.AddPlayerActionVoteKick(actions, player.playerID)
    end

    return actions
end

S.canChangeTo = canChangeTo
S.onLoad = onLoad
S.onUnload = onUnload

S.start = start

S.drawUI = drawUI

S.onVehicleResetted = onVehicleResetted
S.onStopDelivery = onStopDelivery
S.onTargetReached = onTargetReached

S.canRefuelAtStation = TrueFn
S.canSpawnAI = TrueFn
S.doShowNametagsSpecs = TrueFn

S.canSpawnNewVehicle = FalseFn
S.canReplaceVehicle = FalseFn
S.canPaintVehicle = FalseFn
S.canDeleteVehicle = FalseFn
S.canDeleteOtherVehicles = FalseFn

S.slowTick = slowTick

S.getPlayerListActions = getPlayerListActions

return S
