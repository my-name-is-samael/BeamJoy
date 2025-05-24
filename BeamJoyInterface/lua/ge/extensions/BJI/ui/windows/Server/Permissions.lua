local W = {
    name = "ServerPermissions",

    ACCORDIONS = Table({
        {
            labelKey = "groups",
            render = require("ge/extensions/BJI/ui/windows/Server/Permissions/Groups"),
        },
        {
            labelKey = "permissions",
            render = require("ge/extensions/BJI/ui/windows/Server/Permissions/Permissions"),
        },
    }),

    labels = {
        accordion = {
            groups = "",
            permissions = "",
        },
        ---@type table<string, string>
        groups = {},
        ---@type string[]
        permissionsNames = Table(),

        groupKeys = {
            level = "",
            vehicleCap = "",
            staff = "",
            banned = "",
            muted = "",
            whitelisted = "",
            permissions = "",
            newPermission = "",
        },

        newGroup = {
            title = "",
            label = "",
            level = "",
        },
    },
    cache = {
        ---@type string[]
        orderedGroups = Table(),
        readOnlyGroups = Table(),
        selfGroup = nil,
        readOnlyPermissions = Table(),
        permissionsNamesWidth = 0,
        groupsKeys = Table({ "level", "vehicleCap", "staff", "banned", "muted", "whitelisted", "permissions" }),
        groupKeysWidth = 0,

        disableInputs = false,

        groupsPermissionsInputs = Table(),

        newGroup = {
            label = "",
            level = 1,
            labelsWidth = 0,
        },
    },
}

local function updateLabels()
    W.labels.accordion.groups = BJI.Managers.Lang.get("serverConfig.permissions.groups")
    W.labels.accordion.permissions = BJI.Managers.Lang.get("serverConfig.permissions.permissions")

    W.labels.groups = {}
    Table(BJI.Managers.Perm.Groups):keys()
    ---@param gkey string
        :forEach(function(gkey)
            W.labels.groups[gkey] = BJI.Managers.Lang.get("groups." .. gkey, gkey)
        end)

    W.labels.groupKeys.level = BJI.Managers.Lang.get("serverConfig.permissions.groupKeys.level") .. " :"
    W.labels.groupKeys.vehicleCap = BJI.Managers.Lang.get("serverConfig.permissions.groupKeys.vehicleCap") .. " :"
    W.labels.groupKeys.staff = BJI.Managers.Lang.get("serverConfig.permissions.groupKeys.staff") .. " :"
    W.labels.groupKeys.banned = BJI.Managers.Lang.get("serverConfig.permissions.groupKeys.banned") .. " :"
    W.labels.groupKeys.muted = BJI.Managers.Lang.get("serverConfig.permissions.groupKeys.muted") .. " :"
    W.labels.groupKeys.whitelisted = BJI.Managers.Lang.get("serverConfig.permissions.groupKeys.whitelisted") .. " :"
    W.labels.groupKeys.permissions = BJI.Managers.Lang.get("serverConfig.permissions.groupKeys.permissions") .. " :"
    W.labels.groupKeys.newPermission = BJI.Managers.Lang.get("serverConfig.permissions.newPermission") .. " :"

    W.labels.newGroup.title = BJI.Managers.Lang.get("serverConfig.permissions.newGroup.title") .. " :"
    W.labels.newGroup.label = BJI.Managers.Lang.get("serverConfig.permissions.newGroup.label") .. " :"
    W.labels.newGroup.level = BJI.Managers.Lang.get("serverConfig.permissions.newGroup.level") .. " :"
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI.Managers.Tick.getContext()
    W.cache.disableInputs = false

    W.cache.orderedGroups = Range(1, Table(BJI.Managers.Perm.Groups):length() + 1)
        :reduce(function(acc)
            if acc.group then
                acc.res:insert(acc.group)
                acc.group = BJI.Managers.Perm.getNextGroup(acc.group)
                return acc
            else
                return acc.res
            end
        end, { group = BJI.CONSTANTS.GROUP_NAMES.NONE, res = Table() })

    W.cache.selfGroup = ctxt.group.level
    W.cache.readOnlyGroups = W.cache.orderedGroups:map(function(gkey)
            return {
                key = gkey,
                group = BJI.Managers.Perm.Groups[gkey],
            }
        end)
        :filter(function(data) return data.group.level > ctxt.group.level end)
        :map(function(data) return data.key end):values()

    W.cache.groupsPermissionsInputs = Table()

    W.cache.readOnlyPermissions = W.labels.permissionsNames:filter(function(pname)
        return ctxt.group.level < BJI.Managers.Perm.Permissions[pname]
    end)
end

local function updateWidths()
    W.cache.permissionsNamesWidth = W.labels.permissionsNames
        :reduce(function(acc, l)
            local w = BJI.Utils.Common.GetColumnTextWidth(l .. " :")
            return w > acc and w or acc
        end, 0)

    W.cache.groupKeysWidth = Table(W.labels.groupKeys)
        :reduce(function(acc, l)
            local w = BJI.Utils.Common.GetColumnTextWidth(l)
            return w > acc and w or acc
        end, 0)

    W.cache.newGroup.labelsWidth = Table(W.labels.newGroup)
        :reduce(function(acc, l)
            local w = BJI.Utils.Common.GetColumnTextWidth(l)
            return w > acc and w or acc
        end, 0)
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateLabels, W.name))

    updateCache()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.CACHE_LOADED,
        BJI.Managers.Events.EVENTS.PERMISSION_CHANGED,
    }, function(ctxt, data)
        if data._event ~= BJI.Managers.Events.EVENTS.CACHE_LOADED or
            table.includes({
                BJI.Managers.Cache.CACHES.BJC,
                BJI.Managers.Cache.CACHES.GROUPS,
                BJI.Managers.Cache.CACHES.PERMISSIONS
            }, data.cache) then
            updateLabels()
            updateCache(ctxt)
        end
    end, W.name))

    W.labels.permissionsNames = Table()
    Table(BJI.Managers.Perm.PERMISSIONS):forEach(function(permName)
        W.labels.permissionsNames:insert(permName)
    end)
    W.labels.permissionsNames:sort(function(a, b)
        return a:lower() < b:lower()
    end)

    updateWidths()
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED, updateWidths, W.name))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

local function body(ctxt)
    W.ACCORDIONS:forEach(function(a)
        AccordionBuilder()
            :label(W.labels.accordion[a.labelKey])
            :openedBehavior(function()
                a.render(W.labels, W.cache)
            end)
            :build()
    end)
end

W.onLoad = onLoad
W.onUnload = onUnload
W.body = body

return W
