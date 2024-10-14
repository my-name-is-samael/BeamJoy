local function drawGroupNewPermission(groupName, cols)
    local group = BJIPerm.Groups[groupName]
    if not group then
        return
    end

    local options = {}
    if group._new == "" then
        table.insert(options, "")
    end
    for _, permName in pairs(BJIPerm.PERMISSIONS) do
        if not tincludes(group.permissions, permName, true) then
            table.insert(options, permName)
        end
    end
    table.sort(options, function(a, b)
        if a == "" then
            return true
        elseif b == "" then
            return false
        end
        return a < b
    end)

    cols:addRow({
        cells = {
            function()
                LineBuilder()
                    :text(BJILang.get("serverConfig.permissions.newPermission"))
                    :build()
            end,
            function()
                LineBuilder()
                    :inputCombo({
                        id = "newPerm" .. groupName,
                        items = options,
                        value = group._new,
                        onChange = function(val)
                            group._new = val
                        end
                    })
                    :build()
            end,
            function()
                LineBuilder()
                    :btnIcon({
                        id = svar("newPerm" .. groupName),
                        icon = ICONS.done,
                        background = BTN_PRESETS.SUCCESS,
                        disabled = group._new == "",
                        onClick = function()
                            BJITx.config.permissionsGroupSpecific(groupName, group._new, true)
                            group._new = ""
                        end
                    })
                    :build()
            end,
        }
    })
end

local function _isLevelAssignedToAnotherGroup(groupName, level)
    for g2Name, g2 in pairs(BJIPerm.Groups) do
        if not tincludes({ "_new", "_newLevel" }, g2Name) and
            groupName ~= g2Name and
            g2.level == level then
            return true
        end
    end
    return false
end

local function drawGroupData(groupName)
    local group = BJIPerm.Groups[groupName]

    local keys = { "level", "vehicleCap", "staff", "banned", "muted", "whitelisted", "permissions" }
    local labelWidth = 0
    for _, k in ipairs(keys) do
        local label = BJILang.get(svar("serverConfig.permissions.groupKeys.{1}", { k }), k)
        local w = GetColumnTextWidth(label .. ":")
        if w > labelWidth then
            labelWidth = w
        end
    end
    local labelNewPermission = BJILang.get("serverConfig.permissions.newPermission")
    if GetColumnTextWidth(labelNewPermission) > labelWidth then
        labelWidth = GetColumnTextWidth(labelNewPermission)
    end
    local valueWidth = 200 -- min width for inputs
    for _, permName in pairs(group.permissions) do
        local w = GetColumnTextWidth(svar("- {1}", { permName }))
        if w > valueWidth then
            valueWidth = w
        end
    end
    local widths = { labelWidth, valueWidth, -1 }

    local cols = ColumnsBuilder(svar("group{1}permissions", { groupName }), widths)
        -- level
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:",
                            { BJILang.get("serverConfig.permissions.groupKeys.level") }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = svar("perm-{1}-level", { groupName }),
                            type = "int",
                            value = group.level,
                            step = 1,
                            min = 0,
                            disabled = groupName == BJI_GROUP_NAMES.NONE,
                            onUpdate = function(val)
                                local free = not _isLevelAssignedToAnotherGroup(groupName, val)
                                if val < group.level then
                                    while not free do
                                        val = val - 1
                                        free = not _isLevelAssignedToAnotherGroup(groupName, val)
                                    end
                                else
                                    while not free do
                                        val = val + 1
                                        free = not _isLevelAssignedToAnotherGroup(groupName, val)
                                    end
                                end
                                group.level = val
                                BJITx.config.permissionsGroup(groupName, "level", val)
                            end
                        })
                        :build()
                end,
            }
        })
        -- vehicleCap
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:",
                            { BJILang.get("serverConfig.permissions.groupKeys.vehicleCap") }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = svar("perm-{1}-vehicleCap", { groupName }),
                            type = "int",
                            value = group.vehicleCap,
                            step = 1,
                            min = -1,
                            onUpdate = function(val)
                                group.vehicleCap = val
                                BJITx.config.permissionsGroup(groupName, "vehicleCap", val)
                            end
                        })
                        :build()
                end,
            }
        })
        -- staff
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:",
                            { BJILang.get("serverConfig.permissions.groupKeys.staff") }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :btnSwitchEnabledDisabled({
                            id = svar("perm-{1}-staff", { groupName }),
                            state = group.staff,
                            onClick = function()
                                BJITx.config.permissionsGroup(groupName, "staff", not group.staff)
                            end
                        })
                        :build()
                end,
            }
        })
        -- banned
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:",
                            { BJILang.get("serverConfig.permissions.groupKeys.banned") }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :btnSwitchEnabledDisabled({
                            id = svar("perm-{1}-banned", { groupName }),
                            state = group.banned,
                            onClick = function()
                                BJITx.config.permissionsGroup(groupName, "banned", not group.banned)
                            end
                        })
                        :build()
                end,
            }
        })
        -- muted
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:",
                            { BJILang.get("serverConfig.permissions.groupKeys.muted") }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :btnSwitchEnabledDisabled({
                            id = svar("perm-{1}-muted", { groupName }),
                            state = group.muted,
                            onClick = function()
                                BJITx.config.permissionsGroup(groupName, "muted", not group.muted)
                            end
                        })
                        :build()
                end,
            }
        })
        -- whitelisted
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:",
                            { BJILang.get("serverConfig.permissions.groupKeys.whitelisted") }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :btnSwitchEnabledDisabled({
                            id = svar("perm-{1}-whitelisted", { groupName }),
                            state = group.whitelisted,
                            onClick = function()
                                BJITx.config.permissionsGroup(groupName, "whitelisted", not group.whitelisted)
                            end
                        })
                        :build()
                end,
            }
        })
    -- permissions
    for i, permName in pairs(group.permissions) do
        cols:addRow({
            cells = {
                i == 1 and function()
                    LineBuilder()
                        :text(svar("{1}:",
                            { BJILang.get("serverConfig.permissions.groupKeys.permissions") }))
                        :build()
                end or nil,
                function()
                    LineBuilder()
                        :text(svar("- {1}", { permName }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :btnIcon({
                            id = svar("deleteGroupPerm-{1}-{2}", { groupName, permName }),
                            icon = ICONS.delete_forever,
                            background = BTN_PRESETS.ERROR,
                            onClick = function()
                                BJITx.config.permissionsGroupSpecific(groupName, permName, false)
                            end
                        })
                        :build()
                end
            }
        })
    end
    drawGroupNewPermission(groupName, cols)
    cols:build()
end

local function drawNewGroup()
    local canCreate = #BJIPerm.Groups._new > 0 and
        not tincludes({ "_new", "_newLevel" }, BJIPerm.Groups._new)
    if canCreate then
        for k, v in pairs(BJIPerm.Groups) do
            if not tincludes({ "_new", "_newLevel" }, k) and
                (k == BJIPerm.Groups._new or v.level == BJIPerm.Groups._newLevel) then
                canCreate = false
                break
            end
        end
    end
    LineBuilder()
        :text(svar("{1}:", { BJILang.get("serverConfig.permissions.newGroup.title") }))
        :build()
    Indent(1)
    local labelWidth = 0
    for _, key in ipairs({
        "serverConfig.permissions.newGroup.label",
        "serverConfig.permissions.newGroup.level"
    }) do
        local label = BJILang.get(key)
        local w = GetColumnTextWidth(label .. ":")
        if w > labelWidth then
            labelWidth = w
        end
    end
    ColumnsBuilder("newGroup", { labelWidth, -1 })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("serverConfig.permissions.newGroup.label") }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :inputString({
                            id = "newGroup",
                            value = BJIPerm.Groups._new,
                            onUpdate = function(val)
                                BJIPerm.Groups._new = val
                            end
                        })
                        :build()
                end
            }
        })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { BJILang.get("serverConfig.permissions.newGroup.level") }))
                        :build()
                end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = "newGroupLevel",
                            type = "int",
                            value = BJIPerm.Groups._newLevel,
                            step = 1,
                            min = 0,
                            onUpdate = function(val)
                                BJIPerm.Groups._newLevel = val
                            end
                        })
                        :build()
                end
            }
        })
        :build()
    LineBuilder()
        :btn({
            id = "addNewGroup",
            label = BJILang.get("common.buttons.add"),
            style = BTN_PRESETS.SUCCESS,
            disabled = not canCreate,
            onClick = function()
                if not _isLevelAssignedToAnotherGroup(BJIPerm.Groups._new, BJIPerm.Groups._newLevel) then
                    BJITx.config.permissionsGroup(BJIPerm.Groups._new, "level", BJIPerm.Groups._newLevel)
                    BJIPerm.Groups._new = ""
                    BJIPerm.Groups._newLevel = 0
                end
            end
        })
        :build()
    Indent(-1)
end

local function drawListGroups(groupNames)
    for _, groupName in ipairs(groupNames) do
        local group = BJIPerm.Groups[groupName]
        if group then
            AccordionBuilder()
                :label(BJILang.get("groups." .. groupName, groupName))
                :commonStart(
                    function()
                        local line = LineBuilder(true)
                            :text(svar("({1})", { group.level }))
                        if not tincludes(BJI_GROUP_NAMES, groupName) then
                            line:btn({
                                id = "deleteGroup" .. groupName,
                                label = BJILang.get("common.buttons.delete"),
                                style = BTN_PRESETS.ERROR,
                                onClick = function()
                                    BJITx.config.permissionsGroup(groupName, "level")
                                    BJIPerm.Groups[groupName] = nil
                                end
                            })
                        end
                        line:build()
                    end
                )
                :openedBehavior(
                    function()
                        drawGroupData(groupName)
                    end
                )
                :build()
        end
    end

    drawNewGroup()
end

local function drawListPermissions(groupNames)
    local permNames = {}
    for _, permissionName in pairs(BJIPerm.PERMISSIONS) do
        table.insert(permNames, permissionName)
    end
    table.sort(permNames)

    local labelWidth = 0
    for _, permName in ipairs(permNames) do
        local w = GetColumnTextWidth(permName .. ":")
        if w > labelWidth then
            labelWidth = w
        end
    end
    local cols = ColumnsBuilder("permissionsList", { labelWidth, -1 })
    for _, permName in ipairs(permNames) do
        local permLevel = BJIPerm.Permissions[permName]
        cols:addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(svar("{1}:", { permName }))
                        :build()
                end,
                function()
                    -- each group button
                    local line = LineBuilder()
                    for _, groupName in ipairs(groupNames) do
                        local group = BJIPerm.Groups[groupName]
                        line:btn({
                            id = svar("{1}{2}", { permName, groupName }),
                            label = BJILang.get("groups." .. groupName, groupName),
                            style = permLevel <= group.level and BTN_PRESETS.SUCCESS or BTN_PRESETS.INFO,
                            onClick = function()
                                if permLevel ~= group.level then
                                    BJITx.config.permissions(permName, group.level)
                                end
                            end
                        })
                    end
                    line:build()
                end
            }
        })
    end
    cols:build()
end

local function draw(ctxt)
    local orderedGroupNames = {}
    local groupName = BJI_GROUP_NAMES.NONE
    while #groupName > 0 and BJIPerm.Groups[groupName] do
        table.insert(orderedGroupNames, groupName)
        groupName = BJIPerm.getNextGroup(groupName) or ""
    end

    AccordionBuilder()
        :label(BJILang.get("serverConfig.permissions.groups"))
        :openedBehavior(
            function()
                drawListGroups(orderedGroupNames)
            end
        )
        :build()
    AccordionBuilder()
        :label(BJILang.get("serverConfig.permissions.permissions"))
        :openedBehavior(
            function()
                drawListPermissions(orderedGroupNames)
            end
        )
        :build()
end

return draw
