return function(labels, cache)
    labels.permissionsNames:reduce(function(cols, permName)
        local permLevel = BJI.Managers.Perm.Permissions[permName]
        return cols:addRow({
            cells = {
                function()
                    LineLabel(permName .. " :")
                end,
                function()
                    cache.orderedGroups:reduce(function(line, gkey)
                        local group = BJI.Managers.Perm.Groups[gkey]
                        return line:btn({
                            id = string.var("{1}{2}", { permName, gkey }),
                            label = labels.groups[gkey],
                            style = permLevel <= group.level and BJI.Utils.Style.BTN_PRESETS.SUCCESS or
                                BJI.Utils.Style.BTN_PRESETS.INFO,
                            disabled = cache.readOnlyGroups:includes(gkey) or
                                cache.readOnlyPermissions:includes(permName),
                            onClick = function()
                                if permLevel ~= group.level then
                                    BJI.Managers.Perm.Permissions[permName] = group.level
                                    BJI.Tx.config.permissions(permName, group.level)
                                end
                            end
                        })
                    end, LineBuilder()):build()
                end,
            }
        })
    end, ColumnsBuilder("permissionsList", { cache.permissionsNamesWidth, -1 }))
        :build()
end
