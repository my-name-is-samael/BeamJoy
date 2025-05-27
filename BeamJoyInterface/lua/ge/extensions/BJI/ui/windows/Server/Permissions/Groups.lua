local function drawGroupNewPermission(labels, cache, gkey, group, cols)
    local readOnly = cache.readOnlyGroups:includes(gkey) or group.level == cache.selfGroup
    return cols:addRow({
        cells = {
            function() LineLabel(labels.groupKeys.newPermission) end,
            function()
                LineBuilder()
                    :btnIcon({
                        id = string.var("newPerm{1}", { gkey }),
                        icon = ICONS.check,
                        style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                        disabled = readOnly or cache.disableInputs or not cache.groupsPermissionsInputs[gkey],
                        tooltip = labels.add,
                        onClick = function()
                            cache.disableInputs = true
                            BJI.Tx.config.permissionsGroupSpecific(gkey, cache.groupsPermissionsInputs[gkey], true)
                            cache.groupsPermissionsInputs[gkey] = nil
                        end
                    })
                    :inputCombo({
                        id = "newPerm" .. gkey,
                        items = readOnly and {} or labels.permissionsNames:filter(function(pn)
                            return not table.includes(group.permissions, pn) and
                                not cache.readOnlyPermissions:includes(pn)
                        end),
                        value = readOnly and "" or cache.groupsPermissionsInputs[gkey],
                        onChange = function(val)
                            cache.groupsPermissionsInputs[gkey] = val
                        end
                    })
                    :build()
            end,
        }
    })
end

local function isLevelAssignedToAnotherGroup(groupName, level)
    return not not Table(BJI.Managers.Perm.Groups)
        :find(function(g, k) return k ~= groupName and g.level == level end)
end

local function drawGroupData(labels, cache, gkey, group)
    local readOnly = cache.readOnlyGroups:includes(gkey) or group.level == cache.selfGroup
    local cols = ColumnsBuilder(string.var("group{1}permissions", { gkey }), { cache.groupKeysWidth, -1 }):addRow({
        cells = { -- level
            function() LineLabel(labels.groupKeys.level) end,
            function()
                LineBuilder()
                    :inputNumeric({
                        id = string.var("perm-{1}-level", { gkey }),
                        type = "int",
                        value = group.level,
                        step = 1,
                        min = 1,
                        max = 99,
                        disabled = readOnly or gkey == BJI.CONSTANTS.GROUP_NAMES.NONE,
                        onUpdate = function(val)
                            local free = not isLevelAssignedToAnotherGroup(gkey, val)
                            if val < group.level then
                                while not free do
                                    val = val - 1
                                    free = not isLevelAssignedToAnotherGroup(gkey, val)
                                end
                            else
                                while not free do
                                    val = val + 1
                                    free = not isLevelAssignedToAnotherGroup(gkey, val)
                                end
                            end
                            if val > 0 then
                                group.level = val
                                BJI.Tx.config.permissionsGroup(gkey, "level", val)
                            end
                        end
                    })
                    :build()
            end,
        }
    }):addRow({
        cells = { -- vehicleCap
            function() LineLabel(labels.groupKeys.vehicleCap) end,
            function()
                LineBuilder()
                    :inputNumeric({
                        id = string.var("perm-{1}-vehicleCap", { gkey }),
                        type = "int",
                        value = group.vehicleCap,
                        step = 1,
                        min = -1,
                        disabled = readOnly,
                        onUpdate = function(val)
                            group.vehicleCap = val
                            BJI.Tx.config.permissionsGroup(gkey, "vehicleCap", val)
                        end
                    })
                    :build()
            end,
        }
    }):addRow({
        cells = { -- staff
            function() LineLabel(labels.groupKeys.staff) end,
            function()
                LineBuilder()
                    :btnIconToggle({
                        id = string.var("perm-{1}-staff", { gkey }),
                        state = group.staff or false,
                        coloredIcon = true,
                        disabled = readOnly,
                        onClick = function()
                            group.staff = not group.staff
                            BJI.Tx.config.permissionsGroup(gkey, "staff", group.staff)
                        end
                    })
                    :build()
            end,
        }
    }):addRow({
        cells = { -- banned
            function() LineLabel(labels.groupKeys.banned) end,
            function()
                LineBuilder()
                    :btnIconToggle({
                        id = string.var("perm-{1}-banned", { gkey }),
                        state = group.banned or false,
                        coloredIcon = true,
                        disabled = readOnly,
                        onClick = function()
                            group.banned = not group.banned
                            BJI.Tx.config.permissionsGroup(gkey, "banned", group.banned)
                        end
                    })
                    :build()
            end,
        }
    }):addRow({
        cells = { -- muted
            function() LineLabel(labels.groupKeys.muted) end,
            function()
                LineBuilder()
                    :btnIconToggle({
                        id = string.var("perm-{1}-muted", { gkey }),
                        state = group.muted or false,
                        coloredIcon = true,
                        disabled = readOnly,
                        onClick = function()
                            group.muted = not group.muted
                            BJI.Tx.config.permissionsGroup(gkey, "muted", group.muted)
                        end
                    })
                    :build()
            end,
        }
    }):addRow({
        cells = { -- whitelisted
            function() LineLabel(labels.groupKeys.whitelisted) end,
            function()
                LineBuilder()
                    :btnIconToggle({
                        id = string.var("perm-{1}-whitelisted", { gkey }),
                        state = group.whitelisted or false,
                        coloredIcon = true,
                        disabled = readOnly,
                        onClick = function()
                            group.whitelisted = not group.whitelisted
                            BJI.Tx.config.permissionsGroup(gkey, "whitelisted", group.whitelisted)
                        end
                    })
                    :build()
            end,
        }
    })

    Table(group.permissions):forEach(function(permName, i)
        cols:addRow({
            cells = { -- permissions
                i == 1 and function() LineLabel(labels.groupKeys.permissions) end or nil,
                function()
                    LineBuilder()
                        :btnIcon({
                            id = string.var("deleteGroupPerm-{1}-{2}", { gkey, permName }),
                            icon = ICONS.delete_forever,
                            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                            disabled = readOnly or cache.disableInputs,
                            onClick = function()
                                cache.disableInputs = true
                                BJI.Tx.config.permissionsGroupSpecific(gkey, permName, false)
                            end
                        })
                        :text(string.var("- {1}", { permName }))
                        :build()
                end,
            }
        })
    end)
    drawGroupNewPermission(labels, cache, gkey, group, cols)
    cols:build()
end

local function drawNewGroup(labels, cache)
    LineLabel(labels.newGroup.title)
    Indent(1)
    ColumnsBuilder("newGroup", { cache.newGroup.labelsWidth, -1 })
        :addRow({
            cells = {
                function() LineLabel(labels.newGroup.label) end,
                function()
                    LineBuilder()
                        :inputString({
                            id = "newGroupLabel",
                            value = cache.newGroup.label,
                            onUpdate = function(val)
                                cache.newGroup.label = val
                            end
                        })
                        :build()
                end
            }
        })
        :addRow({
            cells = {
                function() LineLabel(labels.newGroup.level) end,
                function()
                    LineBuilder()
                        :inputNumeric({
                            id = "newGroupLevel",
                            type = "int",
                            value = cache.newGroup.level,
                            step = 1,
                            min = 1,
                            max = cache.selfGroup - 1,
                            onUpdate = function(val)
                                cache.newGroup.level = val
                            end
                        })
                        :build()
                end
            }
        })
        :build()
    LineBuilder()
        :btnIcon({
            id = "addNewGroup",
            icon = ICONS.addListItem,
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            disabled = cache.disableInputs or #cache.newGroup.label < 4 or
                Table(BJI.Managers.Perm.Groups):any(function(g, k)
                    return k == cache.newGroup.label or
                        g.level == cache.newGroup.level
                end),
            tooltip = labels.add,
            onClick = function()
                if not isLevelAssignedToAnotherGroup(cache.newGroup.label,
                        cache.newGroup.level) then
                    cache.disableInputs = true
                    BJI.Tx.config.permissionsGroup(cache.newGroup.label, "level",
                        cache.newGroup.level)
                    cache.newGroup.label = ""
                    cache.newGroup.level = 1
                end
            end
        })
        :build()
    Indent(-1)
end

return function(labels, cache)
    cache.orderedGroups:forEach(function(gkey, i)
        local group = BJI.Managers.Perm.Groups[gkey]
        AccordionBuilder()
            :label(labels.groups[gkey], cache.selfGroup == group.level and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or nil)
            :commonStart(function()
                local line = LineBuilder(true)
                    :text(string.var("({1})", { group.level }))
                if not table.includes(BJI.CONSTANTS.GROUP_NAMES, gkey) and
                    group.level < cache.selfGroup then
                    line:btnIcon({
                        id = "deleteGroup" .. gkey,
                        icon = ICONS.delete_forever,
                        style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                        disabled = cache.disableInputs,
                        tooltip = labels.remove,
                        onClick = function()
                            BJI.Managers.Popup.createModal(
                                BJI.Managers.Lang.get("serverConfig.permissions.deleteModal")
                                :var({ groupName = gkey }), {
                                    BJI.Managers.Popup.createButton(BJI.Managers.Lang.get("common.buttons.cancel")),
                                    BJI.Managers.Popup.createButton(BJI.Managers.Lang.get("common.buttons.confirm"),
                                        function()
                                            cache.disableInputs = true
                                            BJI.Tx.config.permissionsGroup(gkey, "level")
                                        end),
                                })
                        end
                    })
                end
                line:build()
            end)
            :openedBehavior(
                function()
                    drawGroupData(labels, cache, gkey, group)
                end
            )
            :build()
    end)
    drawNewGroup(labels, cache)
end
