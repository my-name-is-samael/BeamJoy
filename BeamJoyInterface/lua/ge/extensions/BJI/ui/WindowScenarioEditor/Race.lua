local mgr
local raceEdit

local function leaveRaceEdit(ctxt)
    -- reset waypoints
    BJIWaypointEdit.reset()
    BJIScenario.switchScenario(BJIScenario.TYPES.FREEROAM, ctxt)
    -- clear race edit cache
    BJIContext.Scenario.RaceEdit = nil
end

local function updateMarkers()
    BJIWaypointEdit.reset()

    local waypoints = {}

    -- start positions
    local startPositionColor = ShapeDrawer.Color(1, 1, 0, .5)
    for i, p in ipairs(raceEdit.startPositions) do
        table.insert(waypoints, {
            name = BJILang.get("races.edit.startPositionLabel"):var({ index = i }),
            pos = p.pos,
            rot = p.rot,
            radius = 2,
            color = startPositionColor,
            textColor = startPositionColor,
            textBg = ShapeDrawer.Color(0, 0, 0, .5),
            type = BJIWaypointEdit.TYPES.ARROW,
        })
    end

    -- race waypoints
    local cpColor = ShapeDrawer.Color(1, .5, .5, .5)
    local finishColor = ShapeDrawer.Color(.66, .66, 1, .5)
    local standColor = ShapeDrawer.Color(1, .66, 0, .5)
    for iStep, step in ipairs(raceEdit.steps) do
        for _, wp in ipairs(step) do
            local color = cpColor
            if wp.stand then
                -- stand overrides finish
                color = standColor
            elseif iStep == #raceEdit.steps then
                -- finish
                color = finishColor
            end

            local parents = {}
            for _, parent in ipairs(wp.parents) do
                table.insert(parents, parent)
            end
            table.insert(waypoints, {
                name = wp.name,
                pos = wp.pos,
                rot = wp.rot,
                zOffset = wp.zOffset or 1,
                radius = wp.radius,
                color = color,
                parents = parents,
                finish = iStep == #raceEdit.steps,
                type = wp.stand and BJIWaypointEdit.TYPES.CYLINDER or BJIWaypointEdit.TYPES.RACE_GATE,
            })
        end
    end

    BJIWaypointEdit.setWaypointsWithSegments(waypoints, raceEdit.loopable)
end

local function getNewWPName()
    local max = 0
    for _, step in ipairs(raceEdit.steps) do
        for _, wp in ipairs(step) do
            if wp.name:find("^wp") then
                local num = tonumber(wp.name:sub(3))
                if num and num > max then
                    max = num
                end
            end
        end
    end

    return string.var("wp{1}", { max + 1 })
end

local function getNewWaypointRadius(iStep, iWp)
    local previousStep = raceEdit.steps[iStep - 1]
    PrintObj(previousStep, iStep - 1)
    if previousStep then
        if previousStep[iWp] then
            return previousStep[iWp].radius
        else
            return previousStep[1].radius
        end
    end
    return 1
end

local function prepareStartPositions()
    local positions = {}
    for _, sp in ipairs(raceEdit.startPositions) do
        table.insert(positions, {
            pos = { x = sp.pos.x, y = sp.pos.y, z = sp.pos.z },
            rot = { x = sp.rot.x, y = sp.rot.y, z = sp.rot.z, w = sp.rot.w },
        })
    end
    return positions
end

-- parse steps for testing
local function prepareSteps()
    local steps = {}

    for _, step in ipairs(raceEdit.steps) do
        local nStep = {}
        for _, w in ipairs(step) do
            local parents = {}
            for _, parent in ipairs(w.parents) do
                table.insert(parents, parent)
            end
            table.insert(nStep, {
                name = w.name,
                pos = { x = w.pos.x, y = w.pos.y, z = w.pos.z },
                zOffset = w.zOffset,
                rot = { x = w.rot.x, y = w.rot.y, z = w.rot.z, w = w.rot.w },
                radius = w.radius,
                parents = parents,
                stand = w.stand,
            })
        end
        table.insert(steps, nStep)
    end

    return steps
end

local function saveRace(callback)
    local function _vec3export(v)
        return {
            x = tonumber(v.x),
            y = tonumber(v.y),
            z = tonumber(v.z),
        }
    end

    local function _quatexport(q)
        return {
            x = tonumber(q.x),
            y = tonumber(q.y),
            z = tonumber(q.z),
            w = tonumber(q.w),
        }
    end

    local function _finalSave()
        local race = {
            id = raceEdit.id,
            author = raceEdit.author,
            name = raceEdit.name:trim(),
            enabled = raceEdit.enabled,
            previewPosition = RoundPositionRotation({
                pos = _vec3export(raceEdit.previewPosition.pos),
                rot = _quatexport(raceEdit.previewPosition.rot)
            }),
            keepRecord = raceEdit.keepRecord,
        }

        if not raceEdit.keepRecord then
            race.loopable = raceEdit.loopable

            -- startPositions
            race.startPositions = {}
            for _, sp in ipairs(raceEdit.startPositions) do
                table.insert(race.startPositions, RoundPositionRotation({
                    pos = _vec3export(sp.pos),
                    rot = _quatexport(sp.rot),
                }))
            end

            -- steps
            race.steps = {}
            for _, step in ipairs(raceEdit.steps) do
                local nstep = {}
                for _, wp in ipairs(step) do
                    local parents = {}
                    for _, parent in ipairs(wp.parents) do
                        table.insert(parents, parent)
                    end
                    table.insert(nstep, RoundPositionRotation({
                        name = wp.name,
                        parents = parents,
                        pos = _vec3export(wp.pos),
                        zOffset = wp.zOffset,
                        rot = _quatexport(wp.rot),
                        radius = wp.radius,
                        stand = wp.stand,
                    }))
                end
                table.insert(race.steps, nstep)
            end
        end

        raceEdit.processSave = true
        raceEdit.saveSuccess = nil
        if pcall(BJITx.scenario.RaceSave, race) then
            BJIAsync.task(function()
                return raceEdit.saveSuccess ~= nil
            end, function()
                if raceEdit.saveSuccess then
                    if not race.id then
                        -- gather id for creation
                        BJIAsync.task(function()
                            for _, r in ipairs(BJIContext.Scenario.Data.Races) do
                                if r.name == raceEdit.name then
                                    raceEdit.id = r.id
                                    return true
                                end
                            end
                            return false
                        end, function() end, "BJIRaceSave")
                    end
                    raceEdit.hasRecord = raceEdit.hasRecord and raceEdit.keepRecord
                    raceEdit.keepRecord = true
                    raceEdit.changed = false
                else
                    -- error message
                    BJIToast.error(BJILang.get("races.edit.saveErrorToast"))
                end

                raceEdit.processSave = nil
                raceEdit.saveSuccess = nil
            end, "RaceSave")
            if type(callback) == "function" then
                callback()
            end
        else
            raceEdit.processSave = nil
            -- error message
            BJIToast.error(BJILang.get("races.edit.saveErrorToast"))
            error()
        end
    end

    if raceEdit.hasRecord and not raceEdit.keepRecord then
        BJIPopup.createModal(BJILang.get("races.edit.hasRecordConfirm"), {
            {
                label = BJILang.get("common.buttons.cancel"),
            },
            {
                label = BJILang.get("common.buttons.confirm"),
                onClick = _finalSave,
            },
        })
    else
        _finalSave()
    end
end

local function tryRace(ctxt)
    local validVeh = ctxt.isOwner or
        BJIVeh.getDefaultModelAndConfig() ~= nil or false
    if not validVeh then
        -- invalid default vehicle
        return
    end

    local function launch()
        mgr.initRace(
            ctxt,
            {
                laps = raceEdit.loopable and raceEdit.laps or nil,
                respawnStrategy = nil,
            },
            {
                name = raceEdit.name,
                startPositions = prepareStartPositions(),
                steps = prepareSteps(),
                author = raceEdit.author,
            },
            updateMarkers
        )
    end

    if raceEdit.changed and raceEdit.validSave then
        pcall(saveRace, launch)
    else
        launch()
    end
end

local function reverseRace()
    if not raceEdit then
        return
    end

    BJIPopup.createModal(
        BJILang.get("races.edit.reverseConfirm"),
        {
            {
                label = BJILang.get("common.buttons.cancel"),
            },
            {
                label = BJILang.get("common.buttons.confirm"),
                onClick = function()
                    local newSteps = {}
                    for iStep, step in ipairs(raceEdit.steps) do
                        if iStep == #raceEdit.steps then
                            -- last step
                            if raceEdit.loopable then
                                -- loopable race (only reverse rotation)
                                local newStepFinish = {}
                                for iFinish, finish in ipairs(step) do
                                    local newFinish = {
                                        pos = vec3(finish.pos),
                                        rot = quat(finish.rot),
                                        radius = finish.radius,
                                    }
                                    newFinish.rot = newFinish.rot * quat(0, 0, 1, 0)
                                    if #step > 1 then
                                        -- multiple finishes
                                        newFinish.name = string.var("finish{1}", { iFinish })
                                    else
                                        -- single finish
                                        newFinish.name = "finish"
                                    end
                                    table.insert(newStepFinish, newFinish)
                                end
                                table.insert(newSteps, newStepFinish)
                            elseif #raceEdit.startPositions > 0 then
                                -- sprint race (swap finish with reversed start pos)
                                local newFinish = {
                                    name = "finish",
                                    pos = vec3(raceEdit.startPositions[1].pos),
                                    rot = quat(raceEdit.startPositions[1].rot),
                                    radius = step[1].radius,
                                }
                                newFinish.rot = newFinish.rot * quat(0, 0, 1, 0)
                                table.insert(newSteps, { newFinish })
                                -- and set start pos to reversed finish and remove other starts
                                raceEdit.startPositions[1] = {
                                    pos = vec3(step[1].pos),
                                    rot = quat(step[1].rot),
                                }
                                raceEdit.startPositions[1].rot = raceEdit.startPositions[1].rot * quat(0, 0, 1, 0)
                                while raceEdit.startPositions[2] do
                                    table.remove(raceEdit.startPositions, 2)
                                end
                            end
                        else
                            -- normal step
                            local newStep = {}
                            for iWp, wp in ipairs(step) do
                                local newIStep = #raceEdit.steps - iStep
                                if #step > 1 then
                                    -- multiple wps in this step
                                    wp.name = string.var("wp{1}-{2}", { newIStep, iWp })
                                else
                                    -- single wp in this step
                                    wp.name = string.var("wp{1}", { newIStep })
                                end
                                wp.rot = wp.rot * quat(0, 0, 1, 0)
                                table.insert(newStep, wp)
                            end
                            table.insert(newSteps, 1, newStep)
                        end
                    end
                    -- update parents
                    for iStep, step in ipairs(newSteps) do
                        for _, wp in ipairs(step) do
                            if iStep == 1 then
                                wp.parents = { "start" }
                            else
                                wp.parents = {}
                                for _, parentWp in ipairs(newSteps[iStep - 1]) do
                                    table.insert(wp.parents, parentWp.name)
                                end
                            end
                        end
                    end
                    raceEdit.steps = newSteps
                    updateMarkers()
                end
            }
        })
end

-- Tools for rotating vehicle / adjusting FOV
local function drawTools(vehpos)
    if vehpos then
        LineBuilder()
            :icon({
                icon = ICONS.build,
            })
            :text(BJILang.get("races.tools.title"))
            :build()

        local line = LineBuilder()
            :text(BJILang.get("races.tools.rotation"))
        for _, r in ipairs({
            { value = -10, icon = ICONS.tb_spiral_left_inside },
            { value = -5,  icon = ICONS.tb_spiral_left_outside },
            { value = 5,   icon = ICONS.tb_spiral_right_outside },
            { value = 10,  icon = ICONS.tb_spiral_right_inside },
        }) do
            line:btnIcon({
                id = string.var("rotate{1}", { r.value }),
                icon = r.icon,
                style = BTN_PRESETS.WARNING,
                onClick = function()
                    local rot = vehpos.rot
                    rot = rot - quat(0, 0, math.round(r.value / 360, 8), 0)
                    BJIVeh.setPositionRotation(vehpos.pos, rot, { safe = false, noReset = true })
                end,
            })
        end
        line:btnIcon({
            id = "rotateVeh",
            icon = ICONS.tb_bank,
            style = BTN_PRESETS.WARNING,
            onClick = function()
                vehpos.rot = vehpos.rot * quat(0, 0, 1, 0)
                BJIVeh.setPositionRotation(vehpos.pos, vehpos.rot)
            end
        })
            :btnIcon({
                id = "reverseRace",
                icon = ICONS.reply_all,
                style = BTN_PRESETS.ERROR,
                onClick = reverseRace,
            })
            :build()
    end
end

local function drawNameAndAuthor()
    local validName = #raceEdit.name > 0
    if validName then
        for _, r in pairs(BJIContext.Scenario.Data.Races) do
            if r.id ~= raceEdit.id and raceEdit.name:trim() == r.name then
                validName = false
                break
            end
        end
    end
    LineBuilder()
        :text(BJILang.get("races.edit.name"))
        :helpMarker(BJILang.get("races.edit.nameTooltip"))
        :inputString({
            id = "raceName",
            style = not validName and INPUT_PRESETS.ERROR,
            disabled = raceEdit.processSave,
            value = raceEdit.name,
            size = raceEdit.name._size,
            onUpdate = function(val)
                raceEdit.name = val
                raceEdit.changed = true
            end
        })
        :build()
    LineBuilder()
        :text(string.var("{1}:", { BJILang.get("races.edit.author") }))
        :text(raceEdit.author,
            raceEdit.author == BJIContext.User.playerName and
            TEXT_COLORS.HIGHLIGHT or TEXT_COLORS.DEFAULT)
        :build()

    return validName
end

local function drawPreviewPosition(isFreeCam, campos)
    local line = LineBuilder()
        :icon({
            icon = ICONS.simobject_camera,
            style = raceEdit.previewPosition and BTN_PRESETS.INFO or BTN_PRESETS.ERROR
        })
        :text(BJILang.get("races.edit.previewPosition"), raceEdit.previewPosition and TEXT_COLORS.DEFAULT or TEXT_COLORS.ERROR)
        :helpMarker(BJILang.get("races.edit.previewPositionTooltip"))
        :btnIcon({
            id = "setPreviewPos",
            icon = raceEdit.previewPosition and ICONS.crosshair or ICONS.video_call,
            style = raceEdit.previewPosition and BTN_PRESETS.WARNING or BTN_PRESETS.SUCCESS,
            disabled = raceEdit.processSave,
            onClick = function()
                raceEdit.previewPosition = {
                    pos = campos.pos,
                    rot = campos.rot
                }
                raceEdit.changed = true
            end
        })
    if raceEdit.previewPosition then
        line:btnIcon({
            id = "goToPreviewPos",
            icon = ICONS.cameraFocusTopDown,
            style = BTN_PRESETS.INFO,
            onClick = function()
                if not isFreeCam then
                    BJICam.setCamera(BJICam.CAMERAS.FREE)
                end
                BJICam.setPositionRotation(raceEdit.previewPosition.pos, raceEdit.previewPosition.rot)
            end
        })
    end
    line:build()

    return raceEdit.previewPosition ~= nil
end

-- laps amount & start/finish waypoint
local function drawLoopable()
    LineBuilder()
        :text(BJILang.get("races.edit.loopable"))
        :btnIconToggle({
            id = "toggleLoopable",
            icon = ICONS.rotate_90_degrees_ccw,
            state = raceEdit.loopable,
            disabled = raceEdit.processSave,
            onClick = function()
                raceEdit.loopable = not raceEdit.loopable
                if raceEdit.loopable and not raceEdit.laps then
                    raceEdit.laps = 1
                end
                raceEdit.changed = true
                raceEdit.keepRecord = false
                updateMarkers()
            end,
        })
        :build()

    if raceEdit.loopable then
        Indent(2)
        LineBuilder()
            :text(BJILang.get("races.edit.laps"))
            :helpMarker(BJILang.get("races.edit.lapsTooltip"))
            :inputNumeric({
                id = "raceLaps",
                type = "int",
                value = raceEdit.laps,
                min = 1,
                max = 100,
                step = 1,
                onUpdate = function(val)
                    raceEdit.laps = val
                end
            })
            :build()
        Indent(-2)
    end
end

local function drawStartPositions(vehpos, campos, ctxt)
    AccordionBuilder()
        :label("##startPositions")
        :commonStart(
            function()
                LineBuilder(true)
                    :icon({
                        icon = ICONS.simobject_player_spawn_sphere,
                    })
                    :text(string.var("{1}:", { BJILang.get("races.edit.startPositions") }))
                    :text(#raceEdit.startPositions == 0 and "Missing" or "", TEXT_COLORS.ERROR)
                    :build()
            end
        )
        :openedBehavior(
            function()
                LineBuilder()
                    :btnIcon({
                        id = "addStartPos",
                        icon = ICONS.addListItem,
                        style = BTN_PRESETS.SUCCESS,
                        disabled = not vehpos or ctxt.camera == BJICam.CAMERAS.FREE or raceEdit.processSave,
                        onClick = function()
                            table.insert(raceEdit.startPositions, {
                                pos = vehpos.pos,
                                rot = vehpos.rot,
                            })
                            raceEdit.changed = true
                            raceEdit.keepRecord = false
                            updateMarkers()
                        end,
                    })
                    :build()

                local nameWidth = 0
                for i in ipairs(raceEdit.startPositions) do
                    local label = BJILang.get("races.edit.startPositionLabel"):var({ index = i })
                    local w = GetColumnTextWidth(string.var("{1}{2}", { label, HELPMARKER_TEXT }))
                    if w > nameWidth then
                        nameWidth = w
                    end
                end

                local cols = ColumnsBuilder("BJIScenarioEditorRaceStartPositions", { nameWidth, -1 })
                for i, sp in ipairs(raceEdit.startPositions) do
                    cols:addRow({
                        cells = {
                            function()
                                LineBuilder()
                                    :text(BJILang.get("races.edit.startPositionLabel"):var({ index = i }))
                                    :helpMarker(BJILang.get("races.edit.startPositionsNameTooltip"))
                                    :build()
                            end,
                            function()
                                LineBuilder()
                                    :btnIcon({
                                        id = "moveUpStartPos" .. tostring(i),
                                        icon = ICONS.arrow_drop_up,
                                        style = BTN_PRESETS.WARNING,
                                        disabled = i == 1 or raceEdit.processSave,
                                        onClick = function()
                                            table.insert(raceEdit.startPositions, i - 1, raceEdit.startPositions[i])
                                            table.remove(raceEdit.startPositions, i + 1)
                                            raceEdit.changed = true
                                            raceEdit.keepRecord = false
                                            updateMarkers()
                                        end,
                                    })
                                    :btnIcon({
                                        id = "moveDownStartPos" .. tostring(i),
                                        icon = ICONS.arrow_drop_down,
                                        style = BTN_PRESETS.WARNING,
                                        disabled = i == #raceEdit.startPositions or raceEdit.processSave,
                                        onClick = function()
                                            table.insert(raceEdit.startPositions, i + 2, raceEdit.startPositions[i])
                                            table.remove(raceEdit.startPositions, i)
                                            raceEdit.changed = true
                                            raceEdit.keepRecord = false
                                            updateMarkers()
                                        end,
                                    })
                                    :btnIcon({
                                        id = "goToStartPos" .. tostring(i),
                                        icon = ICONS.cameraFocusOnVehicle2,
                                        style = BTN_PRESETS.INFO,
                                        disabled = not vehpos and not campos,
                                        onClick = function()
                                            if vehpos then
                                                BJIVeh.setPositionRotation(sp.pos, sp.rot, { saveHome = true })
                                                if ctxt.camera == BJICam.CAMERAS.FREE then
                                                    BJICam.setCamera(BJICam.CAMERAS.ORBIT)
                                                end
                                            elseif campos then
                                                BJICam.setPositionRotation(sp.pos)
                                            end
                                        end,
                                    })
                                    :btnIcon({
                                        id = "moveStartPos" .. tostring(i),
                                        icon = ICONS.crosshair,
                                        style = BTN_PRESETS.WARNING,
                                        disabled = not vehpos or ctxt.camera == BJICam.CAMERAS.FREE or
                                            raceEdit.processSave,
                                        onClick = function()
                                            sp.pos = vehpos.pos
                                            sp.rot = vehpos.rot
                                            raceEdit.changed = true
                                            raceEdit.keepRecord = false
                                            updateMarkers()
                                        end,
                                    })
                                    :btnIcon({
                                        id = "deleteStartPos" .. tostring(i),
                                        icon = ICONS.delete_forever,
                                        style = BTN_PRESETS.ERROR,
                                        disabled = raceEdit.processSave,
                                        onClick = function()
                                            table.remove(raceEdit.startPositions, i)
                                            raceEdit.changed = true
                                            raceEdit.keepRecord = false
                                            updateMarkers()
                                        end,
                                    })
                                    :build()
                            end
                        }
                    })
                end
                cols:build()
            end
        )
        :build()

    return #raceEdit.startPositions > 0
end

-- search for existing wp child within next steps (mandatory), except for last step
local function childExists(wpName, currStep)
    if currStep >= #raceEdit.steps then return false end -- no child if last step
    for i, step in ipairs(raceEdit.steps) do
        if i > currStep then
            for _, wp in ipairs(step) do
                for _, parent in ipairs(wp.parents) do
                    if parent == wpName then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- search for existing wp by name in all previous steps (or all steps if currStep isnil)
local function findWP(wpName, currStep)
    if currStep == nil then currStep = #raceEdit.steps + 1 end
    for i, step in ipairs(raceEdit.steps) do
        if i == currStep then
            break
        end
        for _, wp in ipairs(step) do
            if wp.name == wpName then
                return wp
            end
        end
    end
    return nil
end

local function drawSteps(canSetPos, vehpos, campos, ctxt)
    local valid = #raceEdit.steps > 0

    LineBuilder():text(BJILang.get("races.edit.stepsFinishWarning"), TEXT_COLORS.HIGHLIGHT):build()


    AccordionBuilder()
        :label("##raceSteps")
        :commonStart(
            function()
                LineBuilder(true)
                    :icon({
                        icon = ICONS.simobject_bng_waypoint,
                    })
                    :text(string.var("{1}:", { BJILang.get("races.edit.steps") }))
                    :text(#raceEdit.steps == 0 and BJILang.get("errors.missing") or "", TEXT_COLORS.ERROR)
                    :build()
            end
        )
        :openedBehavior(
            function()
                -- STEPS
                for iStep, step in ipairs(raceEdit.steps) do
                    LineBuilder()
                        :text(string.var("{1} {2}", { BJILang.get("races.edit.step"), iStep }), TEXT_COLORS.HIGHLIGHT)
                        :btnIcon({
                            id = string.var("moveupStep{1}", { iStep }),
                            icon = ICONS.arrow_drop_up,
                            style = BTN_PRESETS.WARNING,
                            disabled = iStep == 1 or raceEdit.processSave,
                            onClick = function()
                                table.insert(raceEdit.steps, iStep - 1, raceEdit.steps[iStep])
                                table.remove(raceEdit.steps, iStep + 1)

                                if iStep == 2 then
                                    -- reset parents to start if moved to first step
                                    for _, wp in ipairs(step) do
                                        wp.parents = {
                                            "start",
                                        }
                                    end
                                end
                                raceEdit.changed = true
                                raceEdit.keepRecord = false
                                updateMarkers()
                            end
                        })
                        :btnIcon({
                            id = string.var("movedownStep{1}", { iStep }),
                            icon = ICONS.arrow_drop_down,
                            style = BTN_PRESETS.WARNING,
                            disabled = iStep == #raceEdit.steps or raceEdit.processSave,
                            onClick = function()
                                if iStep == 1 then
                                    -- set new firsts parent to start
                                    for _, wp in ipairs(raceEdit.steps[iStep + 1]) do
                                        wp.parents = {
                                            "start",
                                        }
                                    end
                                end
                                table.insert(raceEdit.steps, iStep + 2, raceEdit.steps[iStep])
                                table.remove(raceEdit.steps, iStep)
                                raceEdit.changed = true
                                raceEdit.keepRecord = false
                                updateMarkers()
                            end
                        })
                        :btnIcon({
                            id = string.var("deleteStep{1}", { iStep }),
                            icon = ICONS.delete_forever,
                            style = BTN_PRESETS.ERROR,
                            disabled = raceEdit.processSave,
                            onClick = function()
                                if iStep == 1 and raceEdit.steps[iStep + 1] then
                                    -- set new firsts parent to start
                                    for _, wp in ipairs(raceEdit.steps[iStep + 1]) do
                                        wp.parents = {
                                            "start",
                                        }
                                    end
                                end
                                table.remove(raceEdit.steps, iStep)
                                raceEdit.changed = true
                                raceEdit.keepRecord = false
                                updateMarkers()
                            end
                        })
                        :build()
                    -- WAYPOINTS
                    Indent(2)
                    for iWp, wp in ipairs(step) do
                        local existsByName = #wp.name > 0 and findWP(wp.name)
                        local validName = #wp.name > 0 and
                            (not existsByName or existsByName == wp) and
                            wp.name ~= "start"
                        local validChildren = #wp.name > 0 and
                            (iStep == #raceEdit.steps or
                                childExists(wp.name, iStep))
                        if not validName then
                            valid = false
                        elseif not validChildren then
                            valid = false
                        end
                        local line = LineBuilder()
                        if #step == 1 then
                            line:text(BJILang.get("races.edit.waypoint"))
                        else
                            line:text(string.var("{1} {2}", { BJILang.get("races.edit.branch"), iWp }))
                        end
                        line:btnIcon({
                            id = string.var("goToWP-{1}-{2}", { iStep, iWp }),
                            icon = ICONS.cameraFocusOnVehicle2,
                            style = BTN_PRESETS.INFO,
                            disabled = not vehpos and not campos,
                            onClick = function()
                                if vehpos then
                                    BJIVeh.setPositionRotation(wp.pos, wp.rot, { saveHome = true })
                                    if ctxt.camera == BJICam.CAMERAS.FREE then
                                        BJICam.setCamera(BJICam.CAMERAS.ORBIT)
                                    end
                                elseif campos then
                                    BJICam.setPositionRotation(wp.pos)
                                end
                            end,
                        })
                            :btnIcon({
                                id = string.var("moveWP-{1}-{2}", { iStep, iWp }),
                                icon = ICONS.crosshair,
                                style = BTN_PRESETS.WARNING,
                                disabled = not canSetPos or not vehpos or ctxt.camera == BJICam.CAMERAS.FREE or
                                    raceEdit.processSave,
                                onClick = function()
                                    wp.pos = vehpos.pos
                                    wp.rot = vehpos.rot
                                    raceEdit.changed = true
                                    raceEdit.keepRecord = false
                                    updateMarkers()
                                end,
                            })
                            :btnIconToggle({
                                id = string.var("toggleStandWP-{1}-{2}", { iStep, iWp }),
                                icon = ICONS.local_gas_station,
                                state = wp.stand == true,
                                disabled = raceEdit.processSave,
                                onClick = function()
                                    wp.stand = not wp.stand
                                    raceEdit.changed = true
                                    raceEdit.keepRecord = false
                                    updateMarkers()
                                end
                            })
                            :btnIcon({
                                id = string.var("deleteWP-{1}-{2}", { iStep, iWp }),
                                icon = ICONS.delete_forever,
                                style = BTN_PRESETS.ERROR,
                                disabled = raceEdit.processSave,
                                onClick = function()
                                    if iWp == 1 and #step == 1 then
                                        -- remove step
                                        table.remove(raceEdit.steps, iStep)
                                    else
                                        table.remove(step, iWp)
                                    end
                                    raceEdit.changed = true
                                    raceEdit.keepRecord = false
                                    updateMarkers()
                                end
                            })
                        if not validChildren then
                            line:text(BJILang.get("races.edit.errors.noChild"), TEXT_COLORS.ERROR)
                        end
                        line:build()
                        Indent(2)
                        local labelWidth = 0
                        for _, key in ipairs({
                            "races.edit.wpName",
                            "races.edit.radius",
                            "races.edit.size",
                            "races.edit.bottomHeight",
                            "races.edit.parent",
                        }) do
                            local label = BJILang.get(key)
                            local w = GetColumnTextWidth(label)
                            if w > labelWidth then
                                labelWidth = w
                            end
                        end
                        ColumnsBuilder(string.var("BJIScenarioEditorRaceStep{1}branch{2}", { iStep, iWp }), { labelWidth, -1 })
                            :addRow({
                                cells = {
                                    function()
                                        LineBuilder()
                                            :text(BJILang.get("races.edit.wpName"),
                                                validName and TEXT_COLORS.DEFAULT or TEXT_COLORS.ERROR)
                                            :build()
                                    end,
                                    function()
                                        LineBuilder()
                                            :inputString({
                                                id = string.var("nameWP-{1}-{2}", { iStep, iWp }),
                                                value = wp.name,
                                                style = validName and INPUT_PRESETS.DEFAULT or INPUT_PRESETS.ERROR,
                                                disabled = raceEdit.processSave,
                                                onUpdate = function(val)
                                                    wp.name = val
                                                    raceEdit.changed = true
                                                    raceEdit.keepRecord = false
                                                    updateMarkers()
                                                end,
                                            })
                                            :build()
                                    end,
                                }
                            })
                            :addRow({
                                cells = {
                                    function()
                                        LineBuilder()
                                            :text(string.var("{1}:", {
                                                wp.stand and
                                                BJILang.get("races.edit.radius") or
                                                BJILang.get("races.edit.size")
                                            }))
                                            :build()
                                    end,
                                    function()
                                        LineBuilder()
                                            :inputNumeric({
                                                id = string.var("radiusWP-{1}-{2}", { iStep, iWp }),
                                                type = "float",
                                                value = wp.radius,
                                                min = 1,
                                                max = 50,
                                                step = .5,
                                                disabled = raceEdit.processSave,
                                                onUpdate = function(val)
                                                    wp.radius = val
                                                    raceEdit.changed = true
                                                    raceEdit.keepRecord = false
                                                    updateMarkers()
                                                end
                                            })
                                            :build()
                                    end,
                                }
                            })
                            :addRow({
                                cells = {
                                    function()
                                        LineBuilder()
                                            :text(string.var("{1}:", { BJILang.get("races.edit.bottomHeight") }))
                                            :build()
                                    end,
                                    function()
                                        LineBuilder()
                                            :inputNumeric({
                                                id = string.var("bottomHeightWP-{1}-{2}", { iStep, iWp }),
                                                type = "float",
                                                value = wp.zOffset or 1,
                                                min = 0,
                                                max = 10,
                                                step = .25,
                                                disabled = raceEdit.processSave,
                                                onUpdate = function(val)
                                                    if val == 1 then
                                                        wp.zOffset = nil
                                                    else
                                                        wp.zOffset = val
                                                    end
                                                    raceEdit.changed = true
                                                    raceEdit.keepRecord = false
                                                    updateMarkers()
                                                end
                                            })
                                            :build()
                                    end,
                                }
                            })
                            :addRow({
                                cells = {
                                    function()
                                        LineBuilder()
                                            :text(BJILang.get("races.edit.parent"))
                                            :build()
                                    end,
                                    function()
                                        if iStep == 1 then
                                            LineBuilder()
                                                :text(wp.parents[1])
                                                :helpMarker(BJILang.get("races.edit.parentStartTooltip"))
                                                :build()
                                        else
                                            local btnWidth = GetIconSize() + 10 * BJIContext.UserSettings.UIScale
                                            local parentInputWidth = ui_imgui.GetContentRegionAvail().x -
                                                (labelWidth + btnWidth)
                                            for iParent, parent in ipairs(wp.parents) do
                                                local validParent = #parent > 0
                                                if validParent then
                                                    for iParent2, parent2 in ipairs(wp.parents) do
                                                        if iParent ~= iParent2 and parent == parent2 then
                                                            validParent = false
                                                            break
                                                        end
                                                    end
                                                end
                                                if validParent and parent ~= "start" and not findWP(parent, iStep) then
                                                    validParent = false
                                                    valid = false
                                                end

                                                line = LineBuilder()
                                                    :inputString({
                                                        id = string.var("WPParent-{1}-{2}-{3}", { iStep, iWp, iParent }),
                                                        width = parentInputWidth,
                                                        disabled = raceEdit.processSave,
                                                        value = parent,
                                                        style = not validParent and INPUT_PRESETS.ERROR or
                                                            INPUT_PRESETS.DEFAULT,
                                                        onUpdate = function(val)
                                                            wp.parents[iParent] = val
                                                            raceEdit.changed = true
                                                            raceEdit.keepRecord = false
                                                            updateMarkers()
                                                        end
                                                    })
                                                if #wp.parents > 1 then
                                                    line:btnIcon({
                                                        id = string.var("deleteWPParent-{1}-{2}-{3}", { iStep, iWp, iParent }),
                                                        icon = ICONS.delete_forever,
                                                        style = BTN_PRESETS.ERROR,
                                                        disabled = raceEdit.processSave,
                                                        onClick = function()
                                                            table.remove(wp.parents, iParent)
                                                            raceEdit.changed = true
                                                            raceEdit.keepRecord = false
                                                            updateMarkers()
                                                        end
                                                    })
                                                end
                                                line:build()
                                            end
                                            LineBuilder()
                                                :btnIcon({
                                                    id = string.var("addWPParent-{1}-{2}", { iStep, iWp }),
                                                    icon = ICONS.add_box,
                                                    style = BTN_PRESETS.SUCCESS,
                                                    disabled = raceEdit.processSave,
                                                    onClick = function()
                                                        table.insert(wp.parents, "")
                                                        raceEdit.changed = true
                                                        raceEdit.keepRecord = false
                                                        updateMarkers()
                                                    end
                                                })
                                                :build()
                                        end
                                    end,
                                }
                            })
                            :build()
                        Indent(-2)
                    end
                    LineBuilder()
                        :btnIcon({
                            id = string.var("addStepBranch{1}", { iStep }),
                            icon = ICONS.fg_sideways,
                            style = BTN_PRESETS.SUCCESS,
                            disabled = not canSetPos or not vehpos or ctxt.camera == BJICam.CAMERAS.FREE or
                                raceEdit.processSave,
                            onClick = function()
                                local parents = {}
                                if iStep == 1 then
                                    table.insert(parents, "start")
                                else
                                    for _, wp in ipairs(raceEdit.steps[iStep - 1]) do
                                        table.insert(parents, wp.name)
                                    end
                                end
                                table.insert(step, {
                                    name = getNewWPName(),
                                    pos = vehpos.pos,
                                    rot = vehpos.rot,
                                    parents = parents,
                                    radius = getNewWaypointRadius(iStep, #step + 1),
                                })
                                raceEdit.changed = true
                                raceEdit.keepRecord = false
                                updateMarkers()
                            end
                        })
                    Indent(-2)
                end
                LineBuilder()
                    :btnIcon({
                        id = "addRaceStep",
                        icon = ICONS.pin_drop,
                        style = BTN_PRESETS.SUCCESS,
                        disabled = not canSetPos or not vehpos or ctxt.camera == BJICam.CAMERAS.FREE or
                            raceEdit.processSave,
                        onClick = function()
                            local parents = {}
                            if #raceEdit.steps == 0 then
                                table.insert(parents, "start")
                            else
                                for _, wp in ipairs(raceEdit.steps[#raceEdit.steps]) do
                                    table.insert(parents, wp.name)
                                end
                            end
                            table.insert(raceEdit.steps, { {
                                name = getNewWPName(),
                                pos = vehpos.pos,
                                rot = vehpos.rot,
                                parents = parents,
                                radius = getNewWaypointRadius(#raceEdit.steps + 1, 1),
                            } })
                            raceEdit.changed = true
                            raceEdit.keepRecord = false
                            updateMarkers()
                        end
                    })
                    :build()
            end
        )
        :build()


    return valid
end

local function drawHeader(ctxt)
    mgr = BJIScenario.get(BJIScenario.TYPES.RACE_SOLO)
    raceEdit = BJIContext.Scenario.RaceEdit or {}

    -- init
    if not raceEdit.init then
        raceEdit.init = true
        updateMarkers()
    end

    LineBuilder()
        :text(BJILang.get("races.edit.title"))
        :btnIcon({
            id = "reloadMarkers",
            icon = ICONS.sync,
            style = BTN_PRESETS.INFO,
            onClick = updateMarkers,
        })
        :build()

    local vehpos = ctxt.isOwner and ctxt.vehPosRot or nil

    drawTools(vehpos)
    Separator()

    raceEdit.validSave = true
    raceEdit.validTry = true

    raceEdit.check = drawNameAndAuthor()
    if not raceEdit.check then
        raceEdit.validSave = false
    end

    LineBuilder()
        :text(BJILang.get("races.edit.enabled"))
        :btnIconToggle({
            id = "raceEnabled",
            icon = raceEdit.enabled and ICONS.visibility or ICONS.visibility_off,
            state = raceEdit.enabled,
            onClick = function()
                raceEdit.enabled = not raceEdit.enabled
                raceEdit.changed = true
            end
        })
end

local function drawBody(ctxt)
    local isFreeCam = ctxt.camera == BJICam.CAMERAS.FREE
    local canSetPos = ctxt.isOwner or isFreeCam
    local vehpos = ctxt.isOwner and ctxt.vehPosRot or nil
    local campos = canSetPos and BJICam.getPositionRotation(true) or nil

    raceEdit.check = drawPreviewPosition(isFreeCam, campos)
    if not raceEdit.check then
        raceEdit.validSave = false
        raceEdit.validTry = false
    end
    Separator()

    drawLoopable()
    Separator()

    raceEdit.check = drawStartPositions(vehpos, campos, ctxt)
    if not raceEdit.check then
        raceEdit.validSave = false
        raceEdit.validTry = false
    end
    Separator()

    raceEdit.check = drawSteps(canSetPos, vehpos, campos, ctxt)
    if not raceEdit.check then
        raceEdit.validSave = false
        raceEdit.validTry = false
    end
end

local function drawFooter(ctxt)
    local line = LineBuilder()
        :btnIcon({
            id = "cancel",
            icon = ICONS.exit_to_app,
            style = BTN_PRESETS.ERROR,
            onClick = function()
                leaveRaceEdit(ctxt)
            end,
        })
        :btnIcon({
            id = "tryRace",
            icon = ICONS.fg_vehicle_race_car,
            style = BTN_PRESETS.WARNING,
            disabled = not raceEdit.validTry or
                not mgr.canChangeTo(ctxt) or
                (not BJIVeh.getDefaultModelAndConfig() and not ctxt.isOwner),
            onClick = function()
                tryRace(ctxt)
            end,
        })
    if raceEdit.changed or not raceEdit.id then
        line:btnIcon({
            id = "saveRace",
            icon = ICONS.save,
            style = BTN_PRESETS.SUCCESS,
            disabled = not raceEdit.validSave or raceEdit.processSave,
            onClick = saveRace,
        })
    end
    line:build()
end

return {
    flags = {
        WINDOW_FLAGS.NO_COLLAPSE
    },
    header = drawHeader,
    body = drawBody,
    footer = drawFooter,
    onClose = leaveRaceEdit,
}
