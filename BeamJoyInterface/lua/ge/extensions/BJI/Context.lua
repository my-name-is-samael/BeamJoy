local C = {
    DEBUG = false,
    GUI = {
        setupEditorGuiTheme = nop,
    },

    physics = {
        physmult = 1,
        VehiclePristineThreshold = 100,
    },

    WorldReadyState = 0,
    WorldCache = {},

    UI = {
        map = "",
        gravity = nil, -- save current gravity preset if there is one
        speed = nil,   -- save current speed preset if not default
    },

    User = {
        playerID = 0,
        playerName = "",
        group = nil,
        lang = nil,
        freeze = false,
        engine = true,
        currentVehicle = nil,
        delivery = 0,
        vehicles = {},
    },

    UserSettings = {
        open = false,
    },

    UserStats = {},

    -- CONFIG DATA
    BJC = {},     -- BeamJoy config
    Players = {}, -- player list
    Scenario = {
        FreeroamSettingsOpen = false,
        Data = {}, -- Scenarii data
        RaceSettings = nil,
        Race = nil,

        RaceEdit = nil,
        EnergyStationsEdit = nil,
        GaragesEdit = nil,
        DeliveryEdit = nil,
        HunterEdit = nil,
    },
    Database = {},

    -- CONFIG WINDOWS STATES
    ServerEditorOpen = false,
    EnvironmentEditorOpen = false,
    DatabaseEditorOpen = false,
}

function C.Scenario.isEditorOpen()
    return C.Scenario.RaceEdit or
        C.Scenario.EnergyStationsEdit or
        C.Scenario.GaragesEdit or
        C.Scenario.DeliveryEdit or
        C.Scenario.BusLinesEdit or
        C.Scenario.HunterEdit or
        C.Scenario.DerbyEdit
end

function C.setPhysicsSpeed(val)
    C.physics.physmult = val
end

function C.isSelf(playerID)
    return C.User.playerID == playerID
end

RegisterBJIManager(C)
return C
