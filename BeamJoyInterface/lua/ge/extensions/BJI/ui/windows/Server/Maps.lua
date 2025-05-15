local W = {
    labels = {
        newMapTitle = "",
        newMapName = "",
        newMapNameTooltip = "",
        mapLabel = "",
        mapArchive = "",
        mapCustom = "",
    },
    newMap = {
        name = "",
        label = "",
        archive = "",
    },
    labelsWidth = 0,
    ---@type table<string, {label: string, custom: boolean, enabled: boolean, archive: string?}>
    maps = Table(),
    mapsOrder = Table(),
    disableInputs = false,
}

local function updateLabels()
    W.labels.newMapTitle = BJI.Managers.Lang.get("serverConfig.maps.new.title")
    W.labels.newMapName = BJI.Managers.Lang.get("serverConfig.maps.new.name") .. ":"
    W.labels.newMapNameTooltip = BJI.Managers.Lang.get("serverConfig.maps.new.nameTooltip")
    W.labels.mapLabel = BJI.Managers.Lang.get("serverConfig.maps.label") .. " :"
    W.labels.mapArchive = BJI.Managers.Lang.get("serverConfig.maps.archive") .. " :"
    W.labels.mapCustom = BJI.Managers.Lang.get("votemap.targetMapCustom")
end

local function updateWidths()
    W.labelsWidth = Table({ W.labels.newMapName .. HELPMARKER_TEXT, W.labels.mapLabel, W.labels.mapArchive })
        :addAll(Table(BJI.Managers.Context.Maps):map(function(_, n) return n .. HELPMARKER_TEXT end))
        :reduce(function(acc, l)
            local w = BJI.Utils.Common.GetColumnTextWidth(l)
            return w > acc and w or acc
        end, 0)
end

local function updateCache()
    W.disableInputs = false

    W.maps = Table(BJI.Managers.Context.Maps):clone()
    W.mapsOrder = W.maps:keys():sort()
end

local listeners = Table()
local function onLoad()
    updateLabels()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.LANG_CHANGED,
        BJI.Managers.Events.EVENTS.UI_UPDATE_REQUEST,
    }, function()
        updateLabels()
        updateWidths()
    end))

    updateWidths()
    listeners:insert(BJI.Managers.Events.addListener(BJI.Managers.Events.EVENTS.UI_SCALE_CHANGED, updateWidths))

    updateCache()
    listeners:insert(BJI.Managers.Events.addListener({
        BJI.Managers.Events.EVENTS.CACHE_LOADED,
    }, function(_, data)
        if data.cache == BJI.Managers.Cache.CACHES.MAPS then
            updateCache()
        end
    end))
end

local function onUnload()
    listeners:forEach(BJI.Managers.Events.removeListener)
end

local function drawMapsList(ctxt)
    W.mapsOrder:reduce(function(cols, mapName)
        local map = W.maps[mapName]
        cols:addRow({
            cells = {
                function()
                    local line = LineBuilder()
                        :text(mapName)
                    if map.custom then
                        line:helpMarker(W.labels.mapCustom)
                    end
                    line:build()
                end,
                function()
                    local line = LineBuilder()
                        :btnIconToggle({
                            id = string.var("map{1}State", { mapName }),
                            icon = map.enabled and ICONS.visibility or ICONS.visibility_off,
                            state = map.enabled == true,
                            disabled = W.disableInputs or BJI.Managers.Context.UI.mapName == mapName,
                            onClick = function()
                                W.disableInputs = true
                                BJI.Tx.config.mapState(mapName, not map.enabled)
                                map.enabled = not map.enabled
                            end,
                        })
                    if not table.compare(map, BJI.Managers.Context.Maps[mapName]) then
                        line:btnIcon({
                            id = string.var("map{1}save", { mapName }),
                            icon = ICONS.save,
                            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
                            disabled = W.disableInputs or #map.label == 0 or
                                (map.custom and #map.archive == 0),
                            onClick = function()
                                W.disableInputs = true
                                BJI.Tx.config.maps(mapName, map.label, map.custom and map.archive or nil)
                            end
                        })
                    end
                    if map.custom then
                        line:btnIcon({
                            id = string.var("map{1}delete", { mapName }),
                            icon = ICONS.delete_forever,
                            style = BJI.Utils.Style.BTN_PRESETS.ERROR,
                            disabled = W.disableInputs or mapName == BJI.Managers.Context.UI.mapName,
                            onClick = function()
                                W.disableInputs = true
                                BJI.Tx.config.maps(mapName)
                            end
                        })
                    end
                    line:build()
                end,
            }
        }):addRow({
            cells = {
                function() LineLabel(W.labels.mapLabel) end,
                function()
                    LineBuilder()
                        :btnIcon({
                            id = string.var("map{1}reset", { mapName }),
                            icon = ICONS.refresh,
                            style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                            disabled = W.disableInputs or map.label == BJI.Managers.Context.Maps[mapName].label,
                            onClick = function()
                                map.label = BJI.Managers.Context.Maps[mapName].label
                            end
                        })
                        :inputString({
                            id = string.var("map{1}label", { mapName }),
                            value = map.label,
                            style = #map.label == 0 and
                                BJI.Utils.Style.INPUT_PRESETS.ERROR or BJI.Utils.Style.INPUT_PRESETS.DEFAULT,
                            disabled = W.disableInputs,
                            onUpdate = function(val)
                                map.label = val
                            end
                        })
                        :build()
                end,
            }
        })
        if map.custom then
            cols:addRow({
                cells = {
                    function() LineLabel(W.labels.mapArchive) end,
                    function()
                        LineBuilder()
                            :btnIcon({
                                id = string.var("map{1}reset", { mapName }),
                                icon = ICONS.refresh,
                                style = BJI.Utils.Style.BTN_PRESETS.WARNING,
                                disabled = W.disableInputs or map.archive == BJI.Managers.Context.Maps[mapName].archive,
                                onClick = function()
                                    map.archive = BJI.Managers.Context.Maps[mapName].archive
                                end
                            })
                            :inputString({
                                id = string.var("map{1}archive", { mapName }),
                                value = map.archive,
                                style = #map.archive == 0 and
                                    BJI.Utils.Style.INPUT_PRESETS.ERROR or BJI.Utils.Style.INPUT_PRESETS.DEFAULT,
                                disabled = W.disableInputs,
                                onUpdate = function(val)
                                    map.archive = val
                                end
                            })
                            :build()
                    end
                }
            })
        end
        return cols
    end, ColumnsBuilder("mapsList", { W.labelsWidth, -1 }))
        :build()
end

local function drawNewMap(ctxt)
    LineBuilder()
        :text(W.labels.newMapTitle)
        :btnIcon({
            id = "addNewMap",
            icon = ICONS.save,
            style = BJI.Utils.Style.BTN_PRESETS.SUCCESS,
            disabled = W.disableInputs or #W.newMap.name == 0 or
                #W.newMap.label == 0 or
                #W.newMap.archive == 0 or
                BJI.Managers.Context.Maps[W.newMap.name] ~= nil,
            onClick = function()
                W.disableInputs = true
                BJI.Tx.config.maps(W.newMap.name, W.newMap.label, W.newMap.archive)
                W.newMap.name = ""
                W.newMap.label = ""
                W.newMap.archive = ""
            end
        })
        :build()
    Indent(1)
    ColumnsBuilder("newMap", { W.labelsWidth, -1 })
        :addRow({
            cells = {
                function()
                    LineBuilder()
                        :text(W.labels.newMapName)
                        :helpMarker(W.labels.newMapNameTooltip)
                        :build()
                end,
                function()
                    LineBuilder()
                        :inputString({
                            id = "new",
                            value = W.newMap.name,
                            style = (#W.newMap.name == 0 or BJI.Managers.Context.Maps[W.newMap.name] ~= nil) and
                                BJI.Utils.Style.INPUT_PRESETS.ERROR or BJI.Utils.Style.INPUT_PRESETS.DEFAULT,
                            disabled = W.disableInputs,
                            onUpdate = function(val)
                                W.newMap.name = val
                            end
                        })
                        :build()
                end
            }
        })
        :addRow({
            cells = {
                function() LineLabel(W.labels.mapLabel) end,
                function()
                    LineBuilder()
                        :inputString({
                            id = "newLabel",
                            value = W.newMap.label,
                            style = #W.newMap.label == 0 and
                                BJI.Utils.Style.INPUT_PRESETS.ERROR or BJI.Utils.Style.INPUT_PRESETS.DEFAULT,
                            disabled = W.disableInputs,
                            onUpdate = function(val)
                                W.newMap.label = val
                            end
                        })
                        :build()
                end
            }
        })
        :addRow({
            cells = {
                function() LineLabel(W.labels.mapArchive) end,
                function()
                    LineBuilder()
                        :inputString({
                            id = "newArchive",
                            value = W.newMap.archive,
                            style = #W.newMap.archive == 0 and
                                BJI.Utils.Style.INPUT_PRESETS.ERROR or BJI.Utils.Style.INPUT_PRESETS.DEFAULT,
                            disabled = W.disableInputs,
                            onUpdate = function(val)
                                W.newMap.archive = val
                            end
                        })
                        :build()
                end
            }
        })
        :build()
    Indent(-1)
end

local function body(ctxt)
    drawMapsList(ctxt)
    drawNewMap(ctxt)
end

W.onLoad = onLoad
W.onUnload = onUnload
W.body = body

return W
