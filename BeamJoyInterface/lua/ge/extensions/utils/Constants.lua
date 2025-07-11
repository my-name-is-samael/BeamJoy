local C = {}

-- SHARED CONSTANTS BETWEEN SERVER & CLIENT

C.GROUP_NAMES = {
    NONE = "none",
    PLAYER = "player",
    MOD = "mod",
    ADMIN = "admin",
    OWNER = "owner",
}

C.EVENTS = {
    SERVER_EVENT = "BJCEvent",
    SERVER_EVENT_PARTS = "BJCEventData",
    CACHE = {
        EVENT = "BJCCache",
        RX = {
            SEND = "send",
        },
        TX = {
            REQUIRE = "require",
        },
    },
    PLAYER = {
        EVENT = "BJCPlayer",
        RX = {
            SERVER_TICK = "tick",
            TOAST = "toast",
            FLASH = "flash",
            CHAT = "chat",
            TELEPORT_TO_PLAYER = "teleportToPlayer",
            TELEPORT_TO_POS = "teleportToPos",
            EXPLODE_VEHICLE = "explodeVehicle",
            SYNC_PAINT = "syncPaint",
        },
        TX = {
            CONNECTED = "connected",
            SWITCH_VEHICLE = "switchVehicle",
            LANG = "lang",
            DRIFT = "drift",
            KM_REWARD = "KmReward",
            EXPLODE_VEHICLE = "explodeVehicle",
            MARK_INVALID_VEHS = "markInvalidVehs",
            SYNC_PAINT = "syncPaint",
        }
    },
    MODERATION = {
        EVENT = "BJCModeration",
        RX = {},
        TX = {
            MUTE = "mute",
            FREEZE = "freeze",
            ENGINE = "engine",
            KICK = "kick",
            TEMPBAN = "tempban",
            BAN = "ban",
            UNBAN = "unban",
            TELEPORT_FROM = "teleportFrom",
            SET_GROUP = "setGroup",
            DELETE_VEHICLE = "deleteVehicle",
            WHITELIST = "whitelist",
        },
    },
    CONFIG = {
        EVENT = "BJCConfig",
        RX = {},
        TX = {
            BJC = "bjc",
            ENV = "env",
            ENV_PRESET = "envPreset",
            CORE = "core",
            MAP_SWITCH = "switchMap",
            PERMISSIONS = "permissions",
            PERMISSIONS_GROUP = "permissionsGroup",
            PERMISSIONS_GROUP_SPECIFIC = "permissionsGroupSpecific",
            MAPS = "maps",
            STOP = "stop",
        },
    },
    DATABASE = {
        EVENT = "BJCDatabase",
        RX = {
            PLAYERS_GET = "playersGet",
            PLAYERS_UPDATED = "playersUpdated",
        },
        TX = {
            PLAYERS_GET = "playersGet",
            VEHICLE = "vehicle",
        },
    },
    VOTE = {
        EVENT = "BJCVote",
        RX = {},
        TX = {
            KICK_START = "KickStart",
            KICK_VOTE = "KickVote",
            KICK_STOP = "KickStop",
            MAP_START = "MapStart",
            MAP_VOTE = "MapVote",
            MAP_STOP = "MapStop",
            SCENARIO_START = "ScenarioStart",
            SCENARIO_VOTE = "ScenarioVote",
            SCENARIO_STOP = "ScenarioStop",
        },
    },
    SCENARIO = {
        EVENT = "BJCScenario",
        RX = {
            RACE_DETAILS = "RaceDetails",
            RACE_SAVE = "RaceSave",
            ENERGY_STATIONS_SAVE = "EnergyStationsSave",
            GARAGES_SAVE = "GaragesSave",
            DELIVERY_SAVE = "DeliverySave",
            DELIVERY_STOP = "DeliveryStop",
            DELIVERY_PACKAGE_SUCCESS = "DeliveryPackageSuccess",
            BUS_LINES_SAVE = "BusLinesSave",
            HUNTER_INFECTED_SAVE = "HunterInfectedSave",
            DERBY_SAVE = "DerbySave",
            PURSUIT_DATA = "PursuitData",
        },
        TX = {
            RACE_DETAILS = "RaceDetails",
            RACE_SAVE = "RaceSave",
            RACE_TOGGLE = "RaceToggle",
            RACE_DELETE = "RaceDelete",
            RACE_MULTI_UPDATE = "RaceMultiUpdate",
            RACE_MULTI_STOP = "RaceMultiStop",
            RACE_SOLO_START = "RaceSoloStart",
            RACE_SOLO_UPDATE = "RaceSoloUpdate",
            RACE_SOLO_END = "RaceSoloEnd",
            ENERGY_STATIONS_SAVE = "EnergyStationsSave",
            GARAGES_SAVE = "GaragesSave",
            DELIVERY_SAVE = "DeliverySave",
            DELIVERY_VEHICLE_START = "DeliveryVehicleStart",
            DELIVERY_VEHICLE_SUCCESS = "DeliveryVehicleSuccess",
            DELIVERY_VEHICLE_FAIL = "DeliveryVehicleFail",
            DELIVERY_PACKAGE_START = "DeliveryPackageStart",
            DELIVERY_PACKAGE_SUCCESS = "DeliveryPackageSuccess",
            DELIVERY_PACKAGE_FAIL = "DeliveryPackageFail",
            DELIVERY_MULTI_JOIN = "DeliveryMultiJoin",
            DELIVERY_MULTI_RESETTED = "DeliveryMultiResetted",
            DELIVERY_MULTI_REACHED = "DeliveryMultiReached",
            DELIVERY_MULTI_LEAVE = "DeliveryMultiLeave",
            BUS_LINES_SAVE = "BusLinesSave",
            BUS_MISSION_START = "BusMissionStart",
            BUS_MISSION_REWARD = "BusMissionReward",
            BUS_MISSION_STOP = "BusMissionStop",
            SPEED_FAIL = "SpeedFail",
            SPEED_STOP = "SpeedStop",
            HUNTER_INFECTED_SAVE = "HunterInfectedSave",
            HUNTER_UPDATE = "HunterUpdate",
            HUNTER_FORCE_FUGITIVE = "HunterForceFugitive",
            HUNTER_STOP = "HunterStop",
            INFECTED_UPDATE = "InfectedUpdate",
            INFECTED_FORCE_INFECTED = "InfectedForceInfected",
            INFECTED_STOP = "InfectedStop",
            DERBY_SAVE = "DerbySave",
            DERBY_UPDATE = "DerbyUpdate",
            DERBY_STOP = "DerbyStop",
            TAG_DUO_JOIN = "TagDuoJoin",
            TAG_DUO_UPDATE = "TagDuoUpdate",
            TAG_DUO_LEAVE = "TagDuoLeave",
            TAG_SERVER_START = "TagServerStart",
            TAG_SERVER_UPDATE = "TagServerUpdate",
            TAG_SERVER_STOP = "TagServerStop",
            PURSUIT_DATA = "PursuitData",
            PURSUIT_REWARD = "PursuitReward",
        }
    },
    TOURNAMENT = {
        EVENT = "BJCTournament",
        RX = {},
        TX = {
            CLEAR = "clear",
            TOGGLE = "toggle",
            END_TOURNAMENT = "endTournament",
            TOGGLE_WHITELIST = "toggleWhitelist",
            TOGGLE_PLAYER = "togglePlayer",
            REMOVE_ACTIVITY = "removeActivity",
            EDIT_SCORE = "editScore",
            REMOVE_PLAYER = "removePlayer",
            ADD_SOLO_RACE = "addSoloRace",
            END_SOLO_ACTIVITY = "endSoloActivity",
        },
    },
}

-- BJI Constants

C.ENV_TYPES = {
    SUN = "sun",
    WEATHER = "weather",
    GRAVITY = "gravity",
    TEMPERATURE = "temperature",
    SPEED = "speed"
}

C.ENERGY_STATION_TYPES = {
    GASOLINE = "gasoline",
    DIESEL = "diesel",
    KEROSINE = "kerosine",
    ELECTRIC = "electricEnergy",
}

C.RACES_RESPAWN_STRATEGIES = {
    ALL_RESPAWNS = { key = "all", order = 1 },
    NO_RESPAWN = { key = "norespawn", order = 2 },
    LAST_CHECKPOINT = { key = "lastcheckpoint", order = 3 },
    STAND = { key = "stand", order = 4 },
}

return C