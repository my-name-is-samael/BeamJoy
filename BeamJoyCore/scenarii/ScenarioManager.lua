---@class BJCScenario Exclusive scenarii forcing all players into
---@field name string
---@field isForcedScenarioInProgress? fun(): boolean
---@field start fun(...)
---@field clientUpdate fun(...)
---@field stop fun(...)
---@field forceStop fun(...)
---@field canSpawnVehicle? fun(playerID, vehID, vehData): boolean
---@field canEditVehicle? fun(playerID, vehID, vehData): boolean
---@field canWalk? fun(playerID): boolean
---@field onPlayerDisconnect? fun(player: BJCPlayer): boolean
---@field onVehicleDeleted? fun(playerID, vehID): boolean
---@field getCache fun(playerID: integer?): table
---@field getCacheHash fun(): string

---@class BJCScenarioHybrid Scenarii allowing players to join and leave whenever they want
---@field name string
---@field isParticipant? fun(player: BJCPlayer): boolean
---@field onPlayerDisconnect? fun(player: BJCPlayer): boolean
---@field onVehicleDeleted? fun(playerID, vehID): boolean
---@field canSpawnVehicle? fun(playerID, vehID, vehData): boolean
---@field canEditVehicle? fun(playerID, vehID, vehData): boolean
---@field canWalk? fun(playerID): boolean
---@field getCache fun(playerID: integer?): table
---@field getCacheHash fun(): string

local M = {
    PLAYER_SCENARII = {
        FREEROAM = nil,
        RACE_SOLO = "raceSolo",
        DELIVERY_VEHICLE = "deliveryVehicle",
        DELIVERY_PACKAGE = "deliveryPackage",
        BUS_MISSION = "busMission",
    },

    RaceManager = require("scenarii/RaceManager"),
    SpeedManager = require("scenarii/SpeedManager"),
    HunterManager = require("scenarii/HunterManager"),
    DerbyManager = require("scenarii/DerbyManager"),

    ---@type BJCScenario?
    CurrentScenario = nil,
    Hybrids = { --- BJCScenarioHybrid list
        DeliveryMultiManager = require("scenarii/DeliveryMultiManager"),
        TagDuoManager = require("scenarii/TagDuoManager"),
    },
}

local function isServerScenarioInProgress()
    if M.CurrentScenario then
        if M.CurrentScenario.isForcedScenarioInProgress then
            return M.CurrentScenario.isForcedScenarioInProgress()
        end
        return true
    end
    return false
end

--- force every multiplayer scenarii to stop now<br>
--- (to allow another one to start)
local function stopServerScenarii()
    if M.CurrentScenario then
        M.CurrentScenario.forceStop()
        M.CurrentScenario = nil
    end
end

--- check if player can spawn a vehicle, depending of his current scenario<br>
--- (can be triggered by traffic toggling)
local function canSpawnVehicle(playerID, vehID, vehData)
    if not BJCPlayers.Players[playerID] then
        return false
    end

    if M.CurrentScenario then
        if M.CurrentScenario.canSpawnVehicle then
            return M.CurrentScenario.canSpawnVehicle(playerID, vehID, vehData)
        end
        return true
    end

    -- specific solo scenarii
    if BJCPlayers.Players[playerID].scenario ~= BJCScenario.PLAYER_SCENARII.FREEROAM then
        if table.includes({
                BJCScenario.PLAYER_SCENARII.RACE_SOLO
            }, BJCPlayers.Players[playerID].scenario) then
            -- restricted SOLO SCENARII
            return false
        end

        return true
    end

    -- FREEROAM
    if BJCPerm.hasMinimumGroup(playerID, BJCGroups.GROUPS.MOD) then
        return true
    else
        if not BJCConfig.Data.Freeroam.VehicleSpawning then
            return false
        end
        return true
    end
end

--- check if player can edit a vehicle, depending of his current scenario
local function canEditVehicle(playerID, vehID, vehData)
    if not BJCPlayers.Players[playerID] then
        return false
    end

    if M.CurrentScenario then
        if M.canEditVehicle then
            return M.CurrentScenario.canEditVehicle(playerID, vehID, vehData)
        end
        return true
    end

    -- specific solo scenarii
    if BJCPlayers.Players[playerID].scenario ~= BJCScenario.PLAYER_SCENARII.FREEROAM then
        if table.includes({
                BJCScenario.PLAYER_SCENARII.DELIVERY_VEHICLE,
                BJCScenario.PLAYER_SCENARII.DELIVERY_PACKAGE
            }, BJCPlayers.Players[playerID].scenario) then
            -- SOLO DELIVERY
            local self = BJCPlayers.Players[playerID]
            local veh = self and self.vehicles[vehID] or nil
            return veh and veh.vid ~= self.currentVehicle
        end
        return true
    end

    -- FREEROAM
    return true
end

---@param playerID integer
local function canWalk(playerID)
    if not BJCPlayers.Players[playerID] then
        return false
    end

    if M.CurrentScenario then
        if M.CurrentScenario.canWalk then
            local res = M.CurrentScenario.canWalk(playerID)
            return res
        end
        return false
    end

    -- specific solo scenarii
    if BJCPlayers.Players[playerID].scenario ~= BJCScenario.PLAYER_SCENARII.FREEROAM then
        return false
    end

    -- FREEROAM
    return true
end

--- check if spawned vehicle is the same than the required one<br>
--- config export in-game and vehdata given by server hooks
--- are not completely equals, so we need to give an approximation
--- of answer (+90% match minimum)
--- @param askedParts table<string, string>
--- @param spawnedParts table<string, string>
--- @return boolean bool if matches enough
local function isVehicleSpawnedMatchesRequired(spawnedParts, askedParts)
    if not askedParts and spawnedParts or not spawnedParts then
        return false
    end

    -- remove empty parts
    askedParts = Table(askedParts):filter(function(v) return #v > 0 end)
    spawnedParts = Table(spawnedParts):filter(function(v, k) return askedParts[k] ~= nil and #v > 0 end)

    local res = Table()
    askedParts:forEach(function(v, k)
        res[k] = v == spawnedParts[k]
    end)
    spawnedParts:filter(function(_, k)
        return res[k] == nil
    end):forEach(function(v, k)
        res[k] = v == askedParts[k]
    end)

    local matches = res:filter(function(v) return v end):length()
    local ratio = matches / res:length()
    local logFn = ratio > .8 and Log or LogError
    logFn(string.var("Vehicle matches requirements up to {1}%%", { math.round(ratio * 100, 1) }))
    return ratio > .8
end

---@param playerID integer
---@param vehID integer
local function onVehicleDeleted(playerID, vehID)
    if not BJCPlayers.Players[playerID] then
        return false
    end

    if M.CurrentScenario then
        if M.CurrentScenario.onVehicleDeleted then
            M.CurrentScenario.onVehicleDeleted(playerID, vehID)
        end
        return
    end

    if Table(M.Hybrids):find(function(s)
            return s.isParticipant(playerID)
        end, function(s)
            s.onVehicleDeleted(playerID, vehID)
        end) then
        return
    end

    -- SOLO SCENARIO & FREEROAM
    -- nothing
end

---@param player BJCPlayer
local function onPlayerDisconnect(player)
    if M.CurrentScenario then
        if M.CurrentScenario.onPlayerDisconnect then
            M.CurrentScenario.onPlayerDisconnect(player)
        end
        return
    end

    if Table(M.Hybrids):find(function(s)
            return s.isParticipant(player)
        end, function(s)
            s.onPlayerDisconnect(player)
        end) then
        return
    end

    -- SOLO SCENARIO & FREEROAM
    -- nothing
end

M.isServerScenarioInProgress = isServerScenarioInProgress
M.stopServerScenarii = stopServerScenarii
M.canSpawnVehicle = canSpawnVehicle
M.canEditVehicle = canEditVehicle
M.canWalk = canWalk

M.isVehicleSpawnedMatchesRequired = isVehicleSpawnedMatchesRequired

BJCEvents.addListener(BJCEvents.EVENTS.MP_VEHICLE_DELETED, onVehicleDeleted, "ScenarioManager")
BJCEvents.addListener(BJCEvents.EVENTS.PLAYER_DISCONNECTED, onPlayerDisconnect, "ScenarioManager")

return M
