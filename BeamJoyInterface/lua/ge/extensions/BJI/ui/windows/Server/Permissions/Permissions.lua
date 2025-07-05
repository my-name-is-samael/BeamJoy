--- gc prevention
local permLevel, group

return function(labels, cache)
    if BeginTable("BJIServerPermissions", {
            { label = "##permissions-labels" },
            { label = "##permissions-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        labels.permissionsNames:forEach(function(permName)
            permLevel = BJI.Managers.Perm.Permissions[permName]
            TableNewRow()
            Text(permName .. " :")
            TableNextColumn()
            cache.orderedGroups:forEach(function(gkey, i)
                if i > 1 then SameLine() end
                group = BJI.Managers.Perm.Groups[gkey]
                if Button(permName .. "-" .. gkey, labels.groups[gkey], { disabled = cache.readOnlyGroups:includes(gkey) or
                        cache.readOnlyPermissions:includes(permName), btnStyle = permLevel <= group.level and
                        BJI.Utils.Style.BTN_PRESETS.SUCCESS or nil }) then
                    if permLevel ~= group.level then
                        BJI.Managers.Perm.Permissions[permName] = group.level
                        BJI.Tx.config.permissions(permName, group.level)
                    end
                end
            end)
        end)

        EndTable()
    end
end
