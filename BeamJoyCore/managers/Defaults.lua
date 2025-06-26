local M = {}

local function config()
    return {
        Server = {
            Lang = "en",
            AllowClientMods = true,
            DriftBigBroadcast = false,
            Broadcasts = {
                delay = 120,
                en = {}
            },
            WelcomeMessage = {
                en = "Welcome to the server !"
            },
            Theme = {
                Text = {
                    DEFAULT = { 1, 1, 1, 1 },
                    HIGHLIGHT = { 1, 1, 0, 1 },
                    ERROR = { .9, .09, .04, 1 },
                    SUCCESS = { .6, .8, 0, 1 },
                    DISABLED = { 1, 1, 1, .4 },
                },
                Button = {
                    INFO = { { .44, .5, .72, .6 }, { .44, .5, .72, .8 }, { .44, .5, .72, .4 } },
                    SUCCESS = { { .6, .8, 0, .8 }, { .6, .8, 0, 1 }, { .6, .8, 0, .6 } },
                    ERROR = { { .9, .09, .04, .6 }, { .9, .09, .04, .8 }, { .9, .09, .04, .4 } },
                    WARNING = { { .8, .47, .23, .6 }, { .8, .47, .23, .8 }, { .8, .47, .23, .4 } },
                    DISABLED = { { 0, 0, 0, .6 }, { 0, 0, 0, .8 }, { 0, 0, 0, .4 } },
                    TRANSPARENT = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 } },
                },
                Input = {
                    DEFAULT = { { .44, .5, .72, .5 } },
                    ERROR = { { .9, .09, .04, .6 } },
                    DISABLED = { { 0, 0, 0, .7 }, { 1, 1, 1, .5 } },
                    TRANSPARENT = { { 0, 0, 0, 0 } },
                },
                Fields = {
                    WINDOW_BG = { .25, .1, .25, .55 },
                    CHILD_BG = { 0, 0, 0, 0 },
                    POPUP_BG = { .15, 0, .15, .7 },
                    MENUBAR_BG = { .2, 0, .2, .4 },
                    BORDER_COLOR = { .5, .25, .5, .5 },
                    RESIZE_GRIP = { 0, 0, 0, 0 },
                    RESIZE_GRIP_HOVERED = { .44, .5, .72, .8 },
                    RESIZE_GRIP_ACTIVE = { .44, .5, .72, .4 },
                    SCROLLBAR = { .44, .5, .72, .6 },
                    SCROLLBAR_HOVERED = { .44, .5, .72, .8 },
                    SCROLLBAR_ACTIVE = { .44, .5, .72, .4 },
                    TITLE_BG = { .3, .15, .3, .5 },
                    TITLE_BG_ACTIVE = { .3, 0, .3, .6 },
                    TITLE_BG_COLLAPSED = { .25, 0, .25, .5 },
                    TAB = { .5, .1, .5, .6 },
                    TAB_HOVERED = { .4, 0, .4, .6 },
                    TAB_ACTIVE = { .8, .2, .8, .6 },
                    TAB_UNFOCUSED = { .5, .1, .5, .6 },
                    TAB_UNFOCUSED_ACTIVE = { .8, .2, .8, .6 },
                    HELPMARKER = { .6, .8, 0, 1 },
                    FRAME_BG = { .44, .5, .72, .5 },
                    FRAME_BG_HOVERED = { .44, .5, .72, .3 },
                    FRAME_BG_ACTIVE = { .44, .5, .72, .7 },
                    HEADER = { .4, .25, .4, .5 },
                    HEADER_HOVERED = { .5, .33, .5, .5 },
                    HEADER_ACTIVE = { .6, .4, .6, .5 },
                    SEPARATOR = { .66, .66, .95, .75 },
                    SEPARATOR_HOVERED = { .77, .85, .95, .75 },
                    SEPARATOR_ACTIVE = { .95, .4, .95, .5 },
                    TABLE_ROW_BG = { 0, 0, 0, .1 },
                    TABLE_ROW_BG_ALT = { 0, 0, 0, .2 },
                    DOCKING_PREVIEW = { .8, .2, .8, .6 },
                    PROGRESSBAR = { 1, 1, 0, 1 },
                },
            },
        },
        Freeroam = {
            VehicleSpawning = true,
            AllowUnicycle = true,
            ResetDelay = 20,
            TeleportDelay = 30,
            Nametags = true,
            QuickTravel = true,
            DriftGood = 2000,
            DriftBig = 10000,
            PreserveEnergy = false,
            EmergencyRefuelDuration = 20,
            EmergencyRefuelPercent = 30,
        },
        Reputation = {
            KmDriveReward = 3,
            DeliveryVehicleReward = 20,
            DeliveryVehiclePristineReward = 50,
            DeliveryPackageReward = 5,
            DeliveryPackageStreakReward = 1,
            RaceParticipationReward = 20,
            RaceWinnerReward = 200,
            DriftGoodReward = 30,
            DriftBigReward = 100,
            BusMissionReward = 8,
            RaceSoloReward = 20,
            RaceRecordReward = 100,
            SpeedReward = 40,
            HunterParticipationReward = 20,
            HunterWinnerReward = 100,
            DerbyParticipationReward = 20,
            DerbyWinnerReward = 200,
        },
        Race = {
            PreparationTimeout = 10,
            VoteTimeout = 30,
            VoteThresholdRatio = .51,
            GridReadyTimeout = 10,
            GridTimeout = 60,
            RaceCountdown = 10,
            FinishTimeout = 5,
            RaceEndTimeout = 10,
            RaceSoloTimeBroadcast = false,
        },
        Hunter = {
            PreparationTimeout = 30,
            HuntedStartDelay = 0,
            HuntersStartDelay = 5,
            HuntedStuckTimeout = 10,
            HuntersRespawnDelay = 10
        },
        Speed = {
            PreparationTimeout = 10,
            VoteTimeout = 30,
            BaseSpeed = 30,
            StepSpeed = 5,
            StepDelay = 10,
            EndTimeout = 10,
        },
        Derby = {
            PreparationTimeout = 60,
            StartCountdown = 10,
            DestroyedTimeout = 5,
            EndTimeout = 10,
        },
        VehicleDelivery = {
            ModelBlacklist = { "atv", "citybus" }
        },
        Whitelist = {
            Enabled = false,
            PlayerNames = {},
        },
        VoteKick = {
            Timeout = 30,
            ThresholdRatio = .51,
        },
        VoteMap = {
            Timeout = 30,
            ThresholdRatio = .51,
        },
        TempBan = {
            minTime = 300,                -- 5 min
            maxTime = 60 * 60 * 24 * 365, -- 1 year
        },
        CEN = {
            Console = true,
            Editor = true,
            NodeGrabber = true,
        }
    }
end

local function permissions()
    return {
        SendPrivateMessage = 0,

        VoteKick = 2,
        VoteMap = 2,
        TeleportTo = 2,
        StartPlayerScenario = 2,
        VoteServerScenario = 2,
        SpawnTrailers = 2,

        BypassModelBlacklist = 5,
        SpawnProps = 5,
        TeleportFrom = 5,
        DeleteVehicle = 5,
        Kick = 5,
        Mute = 5,
        Whitelist = 5,
        SetGroup = 5,
        TempBan = 5,
        FreezePlayers = 5,
        EnginePlayers = 5,
        SetConfig = 5,
        SetEnvironmentPreset = 5,
        StartServerScenario = 5,

        Ban = 7,
        DatabasePlayers = 7,
        DatabaseVehicles = 7,
        SetEnvironment = 7,
        SetReputation = 7,
        Scenario = 7,
        SwitchMap = 7,

        SetPermissions = 100,
        SetCore = 100,
        SetMaps = 100,
        SetCEN = 100,
    }
end

local function groups()
    return {
        none   = {
            level = 0,
            vehicleCap = 0,
            banned = false,
            whitelisted = false,
            muted = false,
            staff = false,
            permissions = {},
        },
        player = {
            level = 2,
            vehicleCap = 1,
            banned = false,
            whitelisted = false,
            muted = false,
            staff = false,
            permissions = {},
        },
        mod    = {
            level = 5,
            vehicleCap = -1,
            banned = false,
            whitelisted = true,
            muted = false,
            staff = true,
            permissions = {},
        },
        admin  = {
            level = 7,
            vehicleCap = -1,
            banned = false,
            whitelisted = true,
            muted = false,
            staff = true,
            permissions = {},
        },
        owner  = {
            level = 100,
            vehicleCap = -1,
            banned = false,
            whitelisted = true,
            muted = false,
            staff = true,
            permissions = {},
        },
    }
end

local function environment()
    return {
        controlSun = true,
        ToD = .78,
        timePlay = true,
        dayLength = 1200,
        visibleDistance = 8000,
        shadowDistance = 1501, -- minimum to prevent shadows from disappearing when you go fast (140kmh+)
        shadowSoftness = .1,
        shadowSplits = 4,
        shadowTexSize = 1024,
        shadowLogWeight = .99,
        skyDay = {
            dayScale = .7,
            brightness = .8,
            sunAzimuthOverride = 113,
            sunSize = 1.3,
            skyBrightness = 20,
            rayleighScattering = .003,
            exposure = .75,
            flareScale = 5,
            occlusionScale = 1.2,
        },
        skyNight = {
            nightScale = .3,
            brightness = 30,
            moonAzimuth = 135,
            moonScale = 1,
            moonElevation = 50,
        },

        controlWeather = true,
        fogDensity = .001,
        fogDensityOffset = 250,
        fogAtmosphereHeight = 500,
        cloudHeight = 2.2,
        cloudHeightOne = 2,
        cloudCover = .25,
        cloudCoverOne = .2,
        cloudSpeed = 0,
        cloudSpeedOne = .33,
        cloudExposure = 0,
        cloudExposureOne = 3,
        rainDrops = 0,
        dropSize = 1,
        dropMinSpeed = .8,
        dropMaxSpeed = 1.6,
        precipType = "rain_medium",

        controlSimSpeed = true,
        simSpeed = 1,

        controlGravity = true,
        gravityRate = -9.81,

        useTempCurve = true,
        tempCurveNoon = 38,
        tempCurveDusk = 12,
        tempCurveMidnight = -15,
        tempCurveDawn = 12,
    }
end

local function maps()
    return {
        smallgrid = {
            label = "SmallGrid",
            custom = false,
            enabled = true,
        },
        gridmap_v2 = {
            label = "Grid Map V2",
            custom = false,
            enabled = true,
        },
        automation_test_track = {
            label = "Automation Test Track",
            custom = false,
            enabled = true,
        },
        east_coast_usa = {
            label = "East Coast",
            custom = false,
            enabled = true,
            dropSizeRatio = .17,
        },
        hirochi_raceway = {
            label = "Hirochi Raceway",
            custom = false,
            enabled = true,
        },
        italy = {
            label = "Italy",
            custom = false,
            enabled = true,
            dropSizeRatio = .14,
        },
        jungle_rock_island = {
            label = "Jungle Rock Island",
            custom = false,
            enabled = true,
            dropSizeRatio = .08,
        },
        industrial = {
            label = "Industrial",
            custom = false,
            enabled = true,
            dropSizeRatio = .08,
        },
        small_island = {
            label = "Small Island",
            custom = false,
            enabled = true,
            dropSizeRatio = .07,
        },
        utah = {
            label = "Utah",
            custom = false,
            enabled = true,
        },
        west_coast_usa = {
            label = "West Coast",
            custom = false,
            enabled = true,
            dropSizeRatio = .4,
        },
        driver_training = {
            label = "Driver Training",
            custom = false,
            enabled = true,
            dropSizeRatio = .12,
        },
        derby = {
            label = "Derby Arena",
            custom = false,
            enabled = true,
        },
        johnson_valley = {
            label = "Johnson Valley",
            custom = false,
            enabled = true,
        }
    }
end

local function vehicles()
    return {
        ModelBlacklist = {}
    }
end

M.config = config
M.permissions = permissions
M.groups = groups
M.environment = environment
M.maps = maps
M.vehicles = vehicles

return M
