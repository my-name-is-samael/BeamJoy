--- gc prevention
local group, opened, nextValue, readOnly, newPerms

local function isLevelAssignedToAnotherGroup(groupName, level)
    return not not Table(BJI_Perm.Groups)
        :find(function(g, k) return k ~= groupName and g.level == level end)
end

local function drawGroupData(labels, cache, gkey, group)
    readOnly = cache.readOnlyGroups:includes(gkey) or group.level == cache.selfGroup
    if BeginTable("group-permissions-" .. gkey, {
            { label = "##group-permissions-labels-" .. gkey },
            { label = "##group-permissions-inputs-" .. gkey, flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        TableNewRow()
        Text(labels.groupKeys.level)
        TableNextColumn()
        nextValue = InputInt("groupLevel" .. gkey, group.level, {
            min = 1,
            max = 99,
            disabled = readOnly or
                gkey == BJI.CONSTANTS.GROUP_NAMES.NONE
        })
        if nextValue then
            local free = not isLevelAssignedToAnotherGroup(gkey, nextValue)
            if nextValue < group.level then
                while not free do
                    nextValue = nextValue - 1
                    free = not isLevelAssignedToAnotherGroup(gkey, nextValue)
                end
            else
                while not free do
                    nextValue = nextValue + 1
                    free = not isLevelAssignedToAnotherGroup(gkey, nextValue)
                end
            end
            if nextValue > 0 and nextValue < 100 then
                group.level = nextValue
                BJI_Tx_config.permissionsGroup(gkey, "level", group.vehicleCap)
            end
        end

        TableNewRow()
        Text(labels.groupKeys.vehicleCap)
        TableNextColumn()
        nextValue = InputInt("groupVehicleCap" .. gkey, group.vehicleCap, { min = -1, disabled = readOnly })
        if nextValue then
            group.vehicleCap = nextValue
            BJI_Tx_config.permissionsGroup(gkey, "vehicleCap", group.vehicleCap)
        end

        TableNewRow()
        Text(labels.groupKeys.staff)
        TableNextColumn()
        if IconButton("staff" .. gkey, group.staff and BJI.Utils.Icon.ICONS.check_circle or BJI.Utils.Icon.ICONS.cancel,
                { disabled = readOnly, bgLess = true, btnStyle = group.staff and
                    BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR }) then
            group.staff = not group.staff
            BJI_Tx_config.permissionsGroup(gkey, "staff", group.staff)
        end

        TableNewRow()
        Text(labels.groupKeys.banned)
        TableNextColumn()
        if IconButton("banned" .. gkey, group.banned and BJI.Utils.Icon.ICONS.check_circle or BJI.Utils.Icon.ICONS.cancel,
                { disabled = readOnly, bgLess = true, btnStyle = group.banned and
                    BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR }) then
            group.banned = not group.banned
            BJI_Tx_config.permissionsGroup(gkey, "banned", group.banned)
        end

        TableNewRow()
        Text(labels.groupKeys.muted)
        TableNextColumn()
        if IconButton("muted" .. gkey, group.muted and BJI.Utils.Icon.ICONS.check_circle or BJI.Utils.Icon.ICONS.cancel,
                { disabled = readOnly, bgLess = true, btnStyle = group.muted and
                    BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR }) then
            group.muted = not group.muted
            BJI_Tx_config.permissionsGroup(gkey, "muted", group.muted)
        end

        TableNewRow()
        Text(labels.groupKeys.whitelisted)
        TableNextColumn()
        if IconButton("whitelisted" .. gkey, group.whitelisted and BJI.Utils.Icon.ICONS.check_circle or BJI.Utils.Icon.ICONS.cancel,
                { disabled = readOnly, bgLess = true, btnStyle = group.whitelisted and
                    BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR }) then
            group.whitelisted = not group.whitelisted
            BJI_Tx_config.permissionsGroup(gkey, "whitelisted", group.whitelisted)
        end

        TableNewRow()
        Text(labels.groupKeys.permissions)
        TableNextColumn()
        Table(group.permissions):forEach(function(permName, i)
            if IconButton("deleteGroupPerm-" .. gkey .. "-" .. permName, BJI.Utils.Icon.ICONS.delete_forever,
                    { disabled = readOnly or cache.disableInputs,
                        btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
                cache.disableInputs = true
                BJI_Tx_config.permissionsGroupSpecific(gkey, permName, false)
            end
            SameLine()
            Text("- " .. permName)
        end)

        TableNewRow()
        Text(labels.groupKeys.newPermission)
        TableNextColumn()
        if IconButton("newPerm" .. gkey, BJI.Utils.Icon.ICONS.add,
                { disabled = readOnly or cache.disableInputs or not cache.groupsPermissionsInputs[gkey],
                    btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS }) then
            cache.disableInputs = true
            BJI_Tx_config.permissionsGroupSpecific(gkey, cache.groupsPermissionsInputs[gkey], true)
            cache.groupsPermissionsInputs[gkey] = nil
        end
        TooltipText(labels.add)
        SameLine()
        newPerms = readOnly and {} or labels.permissionsNames:filter(function(pn)
            return not table.includes(group.permissions, pn) and
                not cache.readOnlyPermissions:includes(pn)
        end):map(function(pn)
            return { value = pn, label = pn }
        end):values():sort(function(a, b) return a.label:lower() < b.label:lower() end)
        if not readOnly and not newPerms
            :any(function(option) return option.value == cache.groupsPermissionsInputs[gkey] end) then
            cache.groupsPermissionsInputs[gkey] = newPerms[1].value
        end
        nextValue = Combo("newPerm" .. gkey, readOnly and "" or cache.groupsPermissionsInputs[gkey],
            newPerms)
        if nextValue then cache.groupsPermissionsInputs[gkey] = nextValue end

        EndTable()
    end
end

local function drawNewGroup(labels, cache)
    Text(labels.newGroup.title)
    Indent()
    if BeginTable("newGroup", {
            { label = "##newgroup-labels" },
            { label = "##newgroup-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        TableNewRow()
        Text(labels.newGroup.label)
        TableNextColumn()
        nextValue = InputText("newGroupLabel", cache.newGroup.label)
        if nextValue then cache.newGroup.label = nextValue end

        TableNewRow()
        Text(labels.newGroup.level)
        TableNextColumn()
        nextValue = InputInt("newGroupLevel", cache.newGroup.level, { min = 1, max = cache.selfGroup - 1 })
        if nextValue then cache.newGroup.level = nextValue end

        EndTable()
    end
    if IconButton("addNewGroup", BJI.Utils.Icon.ICONS.add, { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            disabled = cache.disableInputs or #cache.newGroup.label < 4 or
                Table(BJI_Perm.Groups):any(function(g, k)
                    return k == cache.newGroup.label or g.level == cache.newGroup.level
                end) }) then
        if not isLevelAssignedToAnotherGroup(cache.newGroup.label,
                cache.newGroup.level) then
            cache.disableInputs = true
            BJI_Tx_config.permissionsGroup(cache.newGroup.label, "level",
                cache.newGroup.level)
            cache.newGroup.label = ""
            cache.newGroup.level = 1
        end
    end
    TooltipText(labels.add)
    Unindent()
end

return function(labels, cache)
    cache.orderedGroups:forEach(function(gkey, i)
        group = BJI_Perm.Groups[gkey]
        opened = BeginTree(labels.groups[gkey], {
            color = cache.selfGroup == group.level and
                BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or nil
        })
        SameLine()
        Text(string.format("(%d)", group.level))
        if not table.includes(BJI.CONSTANTS.GROUP_NAMES, gkey) and
            group.level < cache.selfGroup then
            SameLine()
            if IconButton("deleteGroup" .. gkey,
                    BJI.Utils.Icon.ICONS.delete_forever, { disabled = cache.disableInputs,
                        btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR }) then
                BJI_Popup.createModal(
                    BJI_Lang.get("serverConfig.permissions.deleteModal")
                    :var({ groupName = gkey }), {
                        BJI_Popup.createButton(BJI_Lang.get("common.buttons.cancel")),
                        BJI_Popup.createButton(BJI_Lang.get("common.buttons.confirm"),
                            function()
                                cache.disableInputs = true
                                BJI_Tx_config.permissionsGroup(gkey, "level")
                            end),
                    })
            end
            TooltipText(labels.remove)
        end
        if opened then
            drawGroupData(labels, cache, gkey, group)
            EndTree()
        end
    end)
    drawNewGroup(labels, cache)
end
