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
--- gc prevention
local loop, remainingSec, damages, actions

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
    return BJI_Scenario.isFreeroam() and
        BJI_Cache.isFirstLoaded(BJI_Cache.CACHES.DELIVERIES) and
        #BJI_Scenario.Data.Deliveries.Points > 1
end

---@param job NGJob
local function initPositions(job)
    S.startPosition = table.random(BJI_Scenario.Data.Deliveries.Points)
    S.targetPosition = BJI_Scenario.Data.Deliveries.Points:map(function(point)
        local distance = BJI_GPS.getRouteLength({ S.startPosition.pos, point.pos }) -- costs a lot
        job.sleep(.01)
        --local distance = math.horizontalDistance(S.startPosition.pos, point.pos)
        if point ~= S.startPosition and distance > .1 then
            return {
                pos = point.pos,
                radius = point.radius,
                distance = distance,
            }
        end
        return nil
    end):sort(function(a, b)
        return a.distance > b.distance
    end):filter(function(_, i)
        return i < #BJI_Scenario.Data.Deliveries.Points * .66 -- 66% furthest
    end):random()
    S.targetPosition.distance = nil
    job.sleep(.01)
end

---@param job NGJob
local function initVehicle(job)
    local models = BJI_Veh.getAllVehicleConfigs()
    for _, name in ipairs(BJI_Context.BJC.VehicleDelivery.ModelBlacklist) do
        models[name] = nil
        job.sleep(.01)
    end
    if table.length(models) == 0 then
        BJI_Scenario.switchScenario(BJI_Scenario.TYPES.FREEROAM)
        return
    end
    local model = table.random(models)
    job.sleep(.01)
    if model then
        S.model = model.key
        S.modelLabel = BJI_Veh.getModelLabel(S.model)

        -- config
        local config
        while not config or config.label:lower():find("simplified") do
            config = table.random(model.configs)
            job.sleep(.01)
        end
        if config then
            local configFile = BJI_Veh.getConfigFilename(model.key, config.key)
            S.config = BJI_Veh.getFullConfigFromFile(configFile)
            S.configLabel = config.label
        end

        -- paint
        for i = 1, 3 do
            local paint = table.random(model.paints)
            if paint then
                S.paints[i] = paint
            end
            job.sleep(.01)
        end
    end
end

local function initDelivery()
    if not table.includes({
            BJI_Cam.CAMERAS.FREE,
            BJI_Cam.CAMERAS.EXTERNAL,
            BJI_Cam.CAMERAS.BIG_MAP
        }, BJI_Cam.getCamera()) then
        S.previousCamera = BJI_Cam.getCamera()
    end

    if S.paints then
        if not S.config.paints then
            S.config.paints = {}
        end
        S.config.paints[1] = S.paints[1]
        S.config.paints[2] = S.paints[2]
        S.config.paints[3] = S.paints[3]
    end
    BJI_Veh.replaceOrSpawnVehicle(S.model, S.config, S.startPosition)
    if S.previousCamera then
        BJI_Async.delayTask(function()
            BJI_Cam.setCamera(S.previousCamera, false)
        end, 100, "BJIVehDeliveryCamera")
    end

    BJI_GPS.prependWaypoint({
        key = BJI_GPS.KEYS.DELIVERY_TARGET,
        pos = S.targetPosition.pos,
        radius = S.targetPosition.radius,
        clearable = false
    })
    S.baseDistance = BJI_GPS.getCurrentRouteLength()
    BJI_RaceWaypoint.addWaypoint({
        name = "BJIVehicleDelivery",
        pos = S.targetPosition.pos,
        radius = S.targetPosition.radius,
        color = BJI_RaceWaypoint.COLORS.BLUE
    })
end

---@param ctxt TickContext
local function onLoad(ctxt)
    BJI_Tx_scenario.DeliveryVehicleStart()
    S.gameVehID = ctxt.veh.gameVehicleID
    BJI_Message.flash("BJIDeliveryVehicleStart",
        BJI_Lang.get("vehicleDelivery.flashStart"), 5, false)
end

---@param ctxt TickContext
local function onUnload(ctxt)
    BJI_GPS.reset()
    BJI_RaceWaypoint.resetAll()
end

---@param ctxt TickContext
---@return string[]
local function getRestrictions(ctxt)
    return Table():addAll(BJI_Restrictions.OTHER.VEHICLE_SWITCH, true)
        :addAll(BJI_Restrictions.OTHER.BIG_MAP, true)
        :addAll(BJI_Restrictions.OTHER.FREE_CAM, true)
        :addAll(BJI_Restrictions.OTHER.FUN_STUFF, true)
end

local function start()
    ---@param job NGJob
    extensions.core_jobsystem.create(function(job)
        reset()
        BJI_Win_VehSelector.tryClose()

        BJI_UI.applyLoading(true)
        job.sleep(BJI_UI.callbackDelay / 1000)

        local ok, err = pcall(function()
            initPositions(job)
            initVehicle(job)
            if S.startPosition and S.targetPosition and S.model then
                BJI_GPS.reset()
                BJI_RaceWaypoint.resetAll()
                initDelivery()
                BJI_Veh.waitForVehicleSpawn(function(ctxt)
                    S.nextResetExempt = true
                    BJI_Scenario.switchScenario(BJI_Scenario.TYPES.VEHICLE_DELIVERY, ctxt)
                    BJI_UI.applyLoading(false)
                    BJI_Async.delayTask(function()
                        S.nextResetExempt = false
                    end, 1000, "BJIVehDeliveryStartResetExempt")
                end)
            else
                error({
                    startPosition = S.startPosition,
                    targetPosition = S.targetPosition,
                    model = S.model,
                })
            end
        end)
        if not ok then
            LogError("Vehicle delivery failed to start:")
            dump(err)
            BJI_Scenario.switchScenario(BJI_Scenario.TYPES.FREEROAM)
            BJI_UI.applyLoading(false)
        end
    end, .1)
end

local function onDeliveryFailed()
    BJI_Tx_scenario.DeliveryVehicleFail()
    BJI_Message.flash("BJIDeliveryFail", BJI_Lang.get("vehicleDelivery.flashFail"), 3, false,
        GetCurrentTime())
    reset()
    BJI_Scenario.switchScenario(BJI_Scenario.TYPES.FREEROAM)
end

local function onVehicleResetted(gameVehID)
    if gameVehID ~= S.gameVehID or
        not BJI_Veh.isVehicleOwn(gameVehID) then
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

---@param ctxt TickContext
local function drawUI(ctxt)
    loop = BJI_LocalStorage.get(BJI_LocalStorage.GLOBAL_VALUES.SCENARIO_VEHICLE_DELIVERY_LOOP)
    if IconButton("stopVehicleDelivery", BJI.Utils.Icon.ICONS.exit_to_app,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
        onStopDelivery()
    end
    TooltipText(BJI_Lang.get("menu.scenario.vehicleDelivery.stop"))
    SameLine()
    if IconButton("vehicleDeliveryLoop", BJI.Utils.Icon.ICONS.all_inclusive,
            { btnStyle = loop and BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.INFO }) then
        BJI_LocalStorage.set(BJI_LocalStorage.GLOBAL_VALUES.SCENARIO_VEHICLE_DELIVERY_LOOP,
            not loop)
    end
    TooltipText(BJI_Lang.get("common.buttons.loop"))
    SameLine()
    Text(BJI_Lang.get("vehicleDelivery.title"))
    if S.checkTargetTime then
        remainingSec = math.ceil((S.checkTargetTime - ctxt.now) / 1000)
        if remainingSec > 0 then
            SameLine()
            Text(string.var("({1})", { BJI_Lang.get("vehicleDelivery.deliveredIn"):var({
                delay = remainingSec
            }) }), { color = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT })
        end
    end

    Text(string.var("{1}: {2}{3}", {
        BJI_Lang.get("vehicleDelivery.vehicle"), S.modelLabel, S.configLabel and
    string.var(" {1}", { S.configLabel }) or "",
    }))

    damages = ctxt.veh and tonumber(ctxt.veh.veh.damageState)
    if damages and damages > BJI_Context.VehiclePristineThreshold then
        Text(BJI_Lang.get("vehicleDelivery.damagedWarning"),
            { color = BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT })
    end

    if S.distance then
        ProgressBar(1 - math.max(S.distance / S.baseDistance, 0),
            { color = BJI.Utils.Style.BTN_PRESETS.INFO[1] })
        TooltipText(string.var("{1}: {2}", {
            BJI_Lang.get("delivery.currentDelivery"),
            BJI_Lang.get("delivery.distanceLeft")
                :var({ distance = BJI.Utils.UI.PrettyDistance(S.distance) })
        }))
    end
end

---@param ctxt TickContext
local function onTargetReached(ctxt)
    if not ctxt.vehData then
        S.onStopDelivery()
        return
    end

    local damages = ctxt.veh and tonumber(ctxt.veh.veh.damageState)
    local pristine = damages and
        damages <= BJI_Context.VehiclePristineThreshold
    BJI_Tx_scenario.DeliveryVehicleSuccess(pristine)

    if BJI_LocalStorage.get(BJI_LocalStorage.GLOBAL_VALUES.SCENARIO_VEHICLE_DELIVERY_LOOP) then
        BJI_Async.delayTask(function()
            if BJI_Scenario.isFreeroam() then
                S.start()
            end
        end, 3000, "BJIVehDeliveryLoop")
    end

    reset()
    BJI_Scenario.switchScenario(BJI_Scenario.TYPES.FREEROAM)
end

---@param ctxt TickContext
local function slowTick(ctxt)
    if not ctxt.isOwner then
        S.onStopDelivery()
        return
    end

    S.distance = BJI_GPS.getCurrentRouteLength()
    if S.distance > S.baseDistance then
        S.baseDistance = S.distance
    end

    local distance = ctxt.veh.position:distance(S.targetPosition.pos)
    if distance < S.targetPosition.radius then
        if not S.checkTargetTime then
            S.checkTargetTime = ctxt.now + 3100
            BJI_Message.flashCountdown("BJIDeliveryTarget", S.checkTargetTime, false,
                BJI_Lang.get("vehicleDelivery.flashSuccess"),
                nil,
                onTargetReached)
        end
    else
        if S.checkTargetTime then
            BJI_Message.cancelFlash("BJIDeliveryTarget")
            S.checkTargetTime = nil
        end
        if #BJI_GPS.targets == 0 then
            BJI_GPS.prependWaypoint({
                key = BJI_GPS.KEYS.DELIVERY_TARGET,
                pos = S.targetPosition.pos,
                radius = S.targetPosition.radius,
                clearable = false
            })
        end
    end
end

local function getPlayerListActions(player, ctxt)
    actions = {}

    if BJI_Votes.Kick.canStartVote(player.playerID) then
        BJI.Utils.UI.AddPlayerActionVoteKick(actions, player.playerID)
    end

    return actions
end

S.canChangeTo = canChangeTo
S.onLoad = onLoad
S.onUnload = onUnload

S.getRestrictions = getRestrictions

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
