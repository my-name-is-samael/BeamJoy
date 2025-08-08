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

        add = "",
        remove = "",
    },
    cache = {
        ---@type string[]
        orderedGroups = Table(),
        readOnlyGroups = Table(),
        selfGroup = nil,
        readOnlyPermissions = Table(),
        groupsKeys = Table({ "level", "vehicleCap", "staff", "banned", "muted", "whitelisted", "permissions" }),

        disableInputs = false,

        groupsPermissionsInputs = Table(),

        newGroup = {
            label = "",
            level = 1,
        },
    },
}

local function updateLabels()
    W.labels.accordion.groups = BJI_Lang.get("serverConfig.permissions.groups")
    W.labels.accordion.permissions = BJI_Lang.get("serverConfig.permissions.permissions")

    W.labels.groups = {}
    Table(BJI_Perm.Groups):keys()
    ---@param gkey string
        :forEach(function(gkey)
            W.labels.groups[gkey] = BJI_Lang.get("groups." .. gkey, gkey)
        end)

    W.labels.groupKeys.level = BJI_Lang.get("serverConfig.permissions.groupKeys.level") .. " :"
    W.labels.groupKeys.vehicleCap = BJI_Lang.get("serverConfig.permissions.groupKeys.vehicleCap") .. " :"
    W.labels.groupKeys.staff = BJI_Lang.get("serverConfig.permissions.groupKeys.staff") .. " :"
    W.labels.groupKeys.banned = BJI_Lang.get("serverConfig.permissions.groupKeys.banned") .. " :"
    W.labels.groupKeys.muted = BJI_Lang.get("serverConfig.permissions.groupKeys.muted") .. " :"
    W.labels.groupKeys.whitelisted = BJI_Lang.get("serverConfig.permissions.groupKeys.whitelisted") .. " :"
    W.labels.groupKeys.permissions = BJI_Lang.get("serverConfig.permissions.groupKeys.permissions") .. " :"
    W.labels.groupKeys.newPermission = BJI_Lang.get("serverConfig.permissions.newPermission") .. " :"

    W.labels.newGroup.title = BJI_Lang.get("serverConfig.permissions.newGroup.title") .. " :"
    W.labels.newGroup.label = BJI_Lang.get("serverConfig.permissions.newGroup.label") .. " :"
    W.labels.newGroup.level = BJI_Lang.get("serverConfig.permissions.newGroup.level") .. " :"

    W.labels.add = BJI_Lang.get("common.buttons.add")
    W.labels.remove = BJI_Lang.get("common.buttons.remove")
end

---@param ctxt? TickContext
local function updateCache(ctxt)
    ctxt = ctxt or BJI_Tick.getContext()
    W.cache.disableInputs = false

    W.cache.orderedGroups = Range(1, Table(BJI_Perm.Groups):length() + 1)
        :reduce(function(acc)
            if acc.group then
                acc.res:insert(acc.group)
                acc.group = BJI_Perm.getNextGroup(acc.group)
                return acc
            else
                return acc.res
            end
        end, { group = BJI.CONSTANTS.GROUP_NAMES.NONE, res = Table() })

    W.cache.selfGroup = ctxt.group.level
    W.cache.readOnlyGroups = W.cache.orderedGroups:map(function(gkey)
            return {
                key = gkey,
                group = BJI_Perm.Groups[gkey],
            }
        end)
        :filter(function(data) return data.group.level > ctxt.group.level end)
        :map(function(data) return data.key end):values()

    W.cache.groupsPermissionsInputs = Table()

    W.cache.readOnlyPermissions = W.labels.permissionsNames:filter(function(pname)
        return ctxt.group.level < BJI_Perm.Permissions[pname]
    end)
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.LANG_CHANGED,
        BJI_Events.EVENTS.UI_UPDATE_REQUEST,
    }, updateLabels, W.name))

    updateCache()
    listeners:insert(BJI_Events.addListener({
        BJI_Events.EVENTS.CACHE_LOADED,
        BJI_Events.EVENTS.PERMISSION_CHANGED,
    }, function(ctxt, data)
        if data._event ~= BJI_Events.EVENTS.CACHE_LOADED or
            table.includes({
                BJI_Cache.CACHES.BJC,
                BJI_Cache.CACHES.GROUPS,
                BJI_Cache.CACHES.PERMISSIONS
            }, data.cache) then
            updateLabels()
            updateCache(ctxt)
        end
    end, W.name))

    W.labels.permissionsNames = Table(BJI_Perm.PERMISSIONS):values()
        :sort(function(a, b)
            return a:lower() < b:lower()
        end)
end

local function onUnload()
    listeners:forEach(BJI_Events.removeListener)
end

local function body(ctxt)
    W.ACCORDIONS:forEach(function(a)
        if BeginTree(W.labels.accordion[a.labelKey]) then
            a.render(W.labels, W.cache)
            EndTree()
        end
    end)
end

W.onLoad = onLoad
W.onUnload = onUnload
W.body = body

return W
