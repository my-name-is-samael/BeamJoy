local W = {
    name = "ServerMaps",

    labels = {
        newMapTitle = "",
        newMapName = "",
        newMapNameTooltip = "",
        mapLabel = "",
        mapArchive = "",
        mapCustom = "",

        add = "",
        remove = "",
        save = "",
        reset = "",
    },
    newMap = {
        name = "",
        label = "",
        archive = "",
    },
    ---@type table<string, {label: string, custom: boolean, enabled: boolean, archive: string?}>
    maps = Table(),
    mapsOrder = Table(),
    disableInputs = false,
}
--- gc prevention
local nextValue, map

local function updateLabels()
    W.labels.newMapTitle = BJI.Managers.Lang.get("serverConfig.maps.new.title")
    W.labels.newMapName = BJI.Managers.Lang.get("serverConfig.maps.new.name") .. ":"
    W.labels.newMapNameTooltip = BJI.Managers.Lang.get("serverConfig.maps.new.nameTooltip")
    W.labels.mapLabel = BJI.Managers.Lang.get("serverConfig.maps.label") .. " :"
    W.labels.mapArchive = BJI.Managers.Lang.get("serverConfig.maps.archive") .. " :"
    W.labels.mapCustom = BJI.Managers.Lang.get("votemap.targetMapCustom")

    W.labels.add = BJI.Managers.Lang.get("common.buttons.add")
    W.labels.remove = BJI.Managers.Lang.get("common.buttons.remove")
    W.labels.save = BJI.Managers.Lang.get("common.buttons.save")
    W.labels.reset = BJI.Managers.Lang.get("common.buttons.reset")
end

local function updateCache()
    W.disableInputs = false

    W.maps = Table(BJI.Managers.Context.Maps):clone()
    W.mapsOrder = W.maps:keys():sort()
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.LANG_CHANGED, updateLabels, W.name))

    updateCache()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.CACHE_LOADED,
    }, function(_, data)
        if data.cache == BJI.Managers.Cache.CACHES.MAPS then
            updateCache()
        end
    end, W.name))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

local function drawMapsList(ctxt)
    if BeginTable("BJIServerMaps", {
            { label = "##maps-labels" },
            { label = "##maps-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        W.mapsOrder:forEach(function(mapName)
            map = W.maps[mapName]
            TableNewRow()
            Text(mapName, { color = map.custom and BJI.Utils.Style.TEXT_COLORS.HIGHLIGHT or nil })
            TooltipText(map.custom and W.labels.mapCustom or nil)
            TableNextColumn()
            if IconButton("map-state-" .. mapName, map.enabled and
                    BJI.Utils.Icon.ICONS.visibility or BJI.Utils.Icon.ICONS.visibility_off,
                    { btnStyle = map.enabled and BJI.Utils.Style.BTN_PRESETS.SUCCESS or BJI.Utils.Style.BTN_PRESETS.ERROR,
                        disabled = W.disableInputs or BJI.Managers.Context.UI.mapName == mapName }) then
                W.disableInputs = true
                BJI.Tx.config.mapState(mapName, not map.enabled)
                map.enabled = not map.enabled
            end
            if not table.compare(map, BJI.Managers.Context.Maps[mapName]) then
                SameLine()
                if IconButton("map-save-" .. mapName, BJI.Utils.Icon.ICONS.save,
                        { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                            disabled = W.disableInputs or #map.label == 0 or (map.custom and #map.archive == 0) }) then
                    W.disableInputs = true
                    BJI.Tx.config.maps(mapName, map.label, map.custom and map.archive or nil)
                end
                TooltipText(W.labels.save)
            end
            if map.custom then
                SameLine()
                if IconButton("map-delete-" .. mapName, BJI.Utils.Icon.ICONS.delete_forever,
                        { btnStyle = BJI.Utils.Style.BTN_PRESETS.ERROR,
                            disabled = W.disableInputs or mapName == BJI.Managers.Context.UI.mapName }) then
                    W.disableInputs = true
                    BJI.Tx.config.maps(mapName)
                end
                TooltipText(W.labels.remove)
            end

            TableNewRow()
            Indent()
            Text(W.labels.mapLabel)
            Unindent()
            TableNextColumn()
            if IconButton("map-label-reset-" .. mapName, BJI.Utils.Icon.ICONS.refresh,
                    { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                        disabled = W.disableInputs or map.label == BJI.Managers.Context.Maps[mapName].label }) then
                map.label = BJI.Managers.Context.Maps[mapName].label
            end
            TooltipText(W.labels.reset)
            SameLine()
            nextValue = InputText("map-label-" .. mapName, map.label,
                {
                    disabled = W.disableInputs,
                    inputStyle = #map.label == 0 and
                        BJI.Utils.Style.INPUT_PRESETS.ERROR or nil,
                })
            if nextValue then map.label = nextValue end

            if map.custom then
                TableNewRow()
                Indent()
                Text(W.labels.mapArchive)
                Unindent()
                TableNextColumn()
                if IconButton("map-archive-reset-" .. mapName, BJI.Utils.Icon.ICONS.refresh,
                        { btnStyle = BJI.Utils.Style.BTN_PRESETS.WARNING,
                            disabled = W.disableInputs or map.archive == BJI.Managers.Context.Maps[mapName].archive }) then
                    map.archive = BJI.Managers.Context.Maps[mapName].archive
                end
                TooltipText(W.labels.reset)
                SameLine()
                nextValue = InputText("map-archive-" .. mapName, map.archive,
                    {
                        disabled = W.disableInputs,
                        inputStyle = #map.archive == 0 and
                            BJI.Utils.Style.INPUT_PRESETS.ERROR or nil,
                    })
                if nextValue then map.archive = nextValue end
            end
        end)

        EndTable()
    end
end

local function drawNewMap(ctxt)
    Text(W.labels.newMapTitle)
    SameLine()
    if IconButton("addNewMap", BJI.Utils.Icon.ICONS.save,
            { btnStyle = BJI.Utils.Style.BTN_PRESETS.SUCCESS, disabled = W.disableInputs or
                #W.newMap.name == 0 or #W.newMap.label == 0 or #W.newMap.archive == 0 or
                BJI.Managers.Context.Maps[W.newMap.name] ~= nil }) then
        W.disableInputs = true
        BJI.Tx.config.maps(W.newMap.name, W.newMap.label, W.newMap.archive)
        W.newMap.name = ""
        W.newMap.label = ""
        W.newMap.archive = ""
    end
    TooltipText(W.labels.add)
    Indent()
    if BeginTable("BJIServerMapsNew", {
            { label = "##newMap-labels" },
            { label = "##newMap-inputs", flags = { TABLE_COLUMNS_FLAGS.WIDTH_STRETCH } },
        }) then
        TableNewRow()
        Text(W.labels.newMapName)
        TooltipText(W.labels.newMapNameTooltip)
        TableNextColumn()
        nextValue = InputText("newMapName", W.newMap.name,
            {
                inputStyle = (#W.newMap.name == 0 or BJI.Managers.Context.Maps[W.newMap.name] ~= nil) and
                    BJI.Utils.Style.INPUT_PRESETS.ERROR or nil,
                disabled = W.disableInputs
            })
        if nextValue then W.newMap.name = nextValue end

        TableNewRow()
        Text(W.labels.mapLabel)
        TableNextColumn()
        nextValue = InputText("newMapLabel", W.newMap.label,
            {
                inputStyle = #W.newMap.label == 0 and BJI.Utils.Style.INPUT_PRESETS.ERROR or nil,
                disabled = W.disableInputs
            })
        if nextValue then W.newMap.label = nextValue end

        TableNewRow()
        Text(W.labels.mapArchive)
        TableNextColumn()
        nextValue = InputText("newMapArchive", W.newMap.archive,
            {
                inputStyle = #W.newMap.archive == 0 and BJI.Utils.Style.INPUT_PRESETS.ERROR or nil,
                disabled = W.disableInputs
            })
        if nextValue then W.newMap.archive = nextValue end

        EndTable()
    end
    Unindent()
end

local function body(ctxt)
    drawMapsList(ctxt)
    drawNewMap(ctxt)
end

W.onLoad = onLoad
W.onUnload = onUnload
W.body = body

return W
