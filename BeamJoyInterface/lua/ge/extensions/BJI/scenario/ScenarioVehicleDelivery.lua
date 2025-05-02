local tag = "ScenarioDelivery"

local M = {
    previousCamera = nil,

    model = nil,
    modelLabel = nil,
    config = nil,
    configLabel = nil,
    paints = {},
    startPosition = nil,
    targetPosition = nil,
    init = false,
    gameVehID = nil,
    baseDistance = nil,
    distance = nil,
    nextLoop = false,

    nextResetExempt = true,     -- exempt reset fail for vehicle creation
    checkTargetProcess = false, -- process to check player reached target and stayed in its radius
}

local function reset()
    M.previousCamera = nil

    M.model = nil
    M.modelLabel = nil
    M.config = nil
    M.configLabel = nil
    M.paints = {}
    M.startPosition = nil
    M.targetPosition = nil
    M.init = false
    M.gameVehID = nil
    M.baseDistance = nil
    M.distance = nil

    M.nextResetExempt = true
    M.checkTargetProcess = false
end

local function canChangeTo(ctxt)
    return BJIScenario.isFreeroam() and
        BJICache.isFirstLoaded(BJICache.CACHES.DELIVERIES) and
        BJIContext.Scenario.Data.Deliveries and
        #BJIContext.Scenario.Data.Deliveries > 1
end

local function initVehicle()
    local models = BJIVeh.getAllVehicleConfigs()
    for _, name in ipairs(BJIContext.BJC.VehicleDelivery.ModelBlacklist) do
        models[name] = nil
    end
    if table.length(models) == 0 then
        BJIScenario.switchScenario(BJIScenario.TYPES.FREEROAM)
        return
    end
    local model = table.random(models)
    if model then
        M.model = model.key
        M.modelLabel = BJIVeh.getModelLabel(M.model)

        -- config
        local config
        while not config or config.label:find("Traffic") do
            config = table.random(model.configs)
        end
        if config then
            local configFile = BJIVeh.getConfigByModelAndKey(model.key, config.key)
            M.config = BJIVeh.getFullConfig(configFile)
            M.configLabel = config.label
        end

        -- paint
        for i = 1, 3 do
            local paint = table.random(model.paints)
            if paint then
                M.paints[i] = paint
            end
        end
    end
end

local function initPositions()
    M.startPosition = table.random(BJIContext.Scenario.Data.Deliveries)

    local targets = {}
    for _, position in ipairs(BJIContext.Scenario.Data.Deliveries) do
        -- local distance = BJIGPS.getRouteLength({ M.startPosition.pos, position.pos }) -- costs a lot
        local distance = GetHorizontalDistance(M.startPosition.pos, position.pos)
        if position ~= M.startPosition and distance > 0 then
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
    M.targetPosition = table.random(targets)
    M.targetPosition.distance = nil
end

local function initDelivery()
    BJIRestrictions.apply(BJIRestrictions.TYPES.Delivery, true)
    BJIQuickTravel.toggle(false)
    BJINametags.tryUpdate()
    BJIGPS.reset()
    BJIRaceWaypoint.resetAll()

    if not table.includes({
            BJICam.CAMERAS.FREE,
            BJICam.CAMERAS.EXTERNAL,
            BJICam.CAMERAS.BIG_MAP
        }, BJICam.getCamera()) then
        M.previousCamera = BJICam.getCamera()
    end

    if M.paint then
        if not M.config.paints then
            M.config.paints = {}
        end
        M.config.paints[1] = M.paints[1]
        M.config.paints[2] = M.paints[2]
        M.config.paints[3] = M.paints[3]
    end
    BJIVeh.replaceOrSpawnVehicle(M.model, M.config, M.startPosition)
    if M.previousCamera then
        BJIAsync.delayTask(function()
            BJICam.setCamera(M.previousCamera, false)
        end, 100, "BJIVehDeliveryCamera")
    end

    BJIGPS.prependWaypoint(BJIGPS.KEYS.DELIVERY_TARGET, M.targetPosition.pos,
        M.targetPosition.radius, nil, nil, false)
    M.baseDistance = BJIGPS.getCurrentRouteLength()
    BJIRaceWaypoint.addWaypoint("BJIVehicleDelivery", M.targetPosition.pos, M.targetPosition.radius,
        BJIRaceWaypoint.COLORS.BLUE)
end

local function onLoad(ctxt)
    reset()
    BJIVehSelector.tryClose()

    BJIUI.applyLoading(true, function()
        initPositions()

        initVehicle()

        if M.startPosition and M.targetPosition and M.model then
            initDelivery()

            BJIAsync.task(function(ctxt2)
                    return ctxt2.isOwner and
                        table.compare(M.config, BJIVeh.getFullConfig(ctxt2.veh.partConfig) or {})
                end,
                function(ctxt2)
                    BJITx.scenario.DeliveryVehicleStart()
                    M.init = true
                    M.gameVehID = ctxt2.veh:getID()
                    BJIMessage.flash("BJIDeliveryVehicleStart", BJILang.get("vehicleDelivery.flashStart"), 5, false)
                    BJIUI.applyLoading(false)
                end, "BJIDeliveryVehicleInit")
        else
            BJIUI.applyLoading(false)
            BJIScenario.switchScenario(BJIScenario.TYPES.FREEROAM, ctxt)
        end
    end)
end

local function onDeliveryFailed()
    BJITx.scenario.DeliveryVehicleFail()
    BJIMessage.flash("BJIDeliveryFail", BJILang.get("vehicleDelivery.flashFail"), 3, false, GetCurrentTime())
    reset()
    BJIScenario.switchScenario(BJIScenario.TYPES.FREEROAM)
end

local function onVehicleResetted(gameVehID)
    if not M.init or gameVehID ~= M.gameVehID then
        return
    end

    if M.nextResetExempt then
        -- used only for vehicle creation
        M.nextResetExempt = false
        return
    end

    onDeliveryFailed()
end

local function onVehicleSwitched(oldGameVehID, newGameVehID)
    if M.init then
        if newGameVehID ~= M.gameVehID then
            BJIVeh.focusVehicle(M.gameVehID)
        end
    end
end

local function onStopDelivery()
    onDeliveryFailed()
end

local function drawUI(ctxt, cache)
    if M.distance then
        LineBuilder()
            :text(string.var("{1}: {2}", {
                cache.labels.delivery.current,
                cache.labels.delivery.distanceLeft
                    :var({ distance = PrettyDistance(M.distance) })
            }))
            :build()

        ProgressBar({
            floatPercent = 1 - math.max(M.distance / M.baseDistance, 0),
            width = 250,
        })
    end

    LineBuilder():text(string.var("{1}: {2}{3}", {
        cache.labels.delivery.vehicle.currentConfig, M.modelLabel, M.configLabel and
    string.var(" {1}", { M.configLabel }) or
    "",
    })):build()
    LineBuilder()
        :btnIconToggle({
            id = "vehicleDeliveryLoop",
            icon = ICONS.all_inclusive,
            state = M.nextLoop,
            onClick = function()
                M.nextLoop = not M.nextLoop
            end,
            big = true,
        })
        :btnIcon({
            id = "stopVehicleDelivery",
            icon = ICONS.exit_to_app,
            style = BTN_PRESETS.ERROR,
            onClick = M.onStopDelivery,
            big = true,
        })
        :build()
end

local function onTargetReached(ctxt)
    if not ctxt.vehData then
        M.onStopDelivery()
        return
    end

    local pristine = ctxt.vehData.damageState and
        ctxt.vehData.damageState <= BJIContext.physics.VehiclePristineThreshold
    BJITx.scenario.DeliveryVehicleSuccess(pristine)

    if M.nextLoop then
        BJIAsync.delayTask(function()
            if BJIScenario.isFreeroam() then
                BJIScenario.switchScenario(BJIScenario.TYPES.VEHICLE_DELIVERY, ctxt)
            end
        end, 3000, "BJIVehDeliveryLoop")
    end

    reset()
    BJIScenario.switchScenario(BJIScenario.TYPES.FREEROAM)
end

local function canRefuelAtStation()
    return true
end

local function canSpawnVehicle()
    return not M.init
end

local function canVehUpdate()
    return false
end

local function doShowNametagsSpecs(vehData)
    return true
end

local function slowTick(ctxt)
    if not M.init then
        return
    elseif not ctxt.isOwner then
        M.onStopDelivery()
        return
    end

    M.distance = BJIGPS.getRouteLength({
        vec3(ctxt.vehPosRot.pos),
        vec3(M.targetPosition.pos),
    })
    if M.distance > M.baseDistance then
        M.baseDistance = M.distance
    end

    local distance = ctxt.vehPosRot.pos:distance(M.targetPosition.pos)
    if distance < M.targetPosition.radius then
        if not M.checkTargetProcess then
            BJIMessage.flashCountdown("BJIDeliveryTarget", ctxt.now + 3100, false,
                BJILang.get("vehicleDelivery.flashSuccess"),
                nil,
                onTargetReached)
            M.checkTargetProcess = true
        end
    else
        if M.checkTargetProcess then
            BJIMessage.cancelFlash("BJIDeliveryTarget")
            M.checkTargetProcess = false
        end
        if #BJIGPS.targets == 0 then
            BJIGPS.prependWaypoint(BJIGPS.KEYS.DELIVERY_TARGET, M.targetPosition.pos,
                M.targetPosition.radius, nil, nil, false)
        end
    end
end

local function getPlayerListActions(player, ctxt)
    local actions = {}

    if BJIVote.Kick.canStartVote(player.playerID) then
        table.insert(actions, {
            id = string.var("voteKick{1}", { player.playerID }),
            label = BJILang.get("playersBlock.buttons.voteKick"),
            onClick = function()
                BJIVote.Kick.start(player.playerID)
            end
        })
    end

    return actions
end

local function onUnload(ctxt)
    BJIRestrictions.apply(BJIRestrictions.TYPES.Delivery, false)
    BJIQuickTravel.toggle(true)
    BJINametags.toggle(true)
    BJIGPS.reset()
    BJIRaceWaypoint.resetAll()
end

M.canChangeTo = canChangeTo
M.onLoad = onLoad

M.drawUI = drawUI

M.onVehicleResetted = onVehicleResetted
M.onVehicleSwitched = onVehicleSwitched
M.onStopDelivery = onStopDelivery
M.onTargetReached = onTargetReached

M.canRefuelAtStation = canRefuelAtStation

M.canSelectVehicle = canVehUpdate
M.canSpawnNewVehicle = canSpawnVehicle
M.canSpawnNewVehicle = canSpawnVehicle
M.canDeleteVehicle = canVehUpdate
M.canDeleteOtherVehicles = canVehUpdate
M.canEditVehicle = canVehUpdate
M.doShowNametagsSpecs = doShowNametagsSpecs

M.slowTick = slowTick

M.getPlayerListActions = getPlayerListActions

M.onUnload = onUnload
return M
