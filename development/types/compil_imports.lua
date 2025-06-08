-- Assists IDE autocompletion

---@type BJIManagerAI
BJI.Managers.AI = require("ge/extensions/BJI/managers/AIManager")
---@type BJIManagerAsync
BJI.Managers.Async = require("ge/extensions/BJI/managers/AsyncManager")
---@type BJIManagerAutomaticLights
BJI.Managers.AutomaticLights = require("ge/extensions/BJI/managers/AutomaticLightsManager")
---@type BJIManagerBigmap
BJI.Managers.Bigmap = require("ge/extensions/BJI/managers/BigmapManager")
---@type BJIManagerBusUI
BJI.Managers.BusUI = require("ge/extensions/BJI/managers/BusUIManager")
---@type BJIManagerCache
BJI.Managers.Cache = require("ge/extensions/BJI/managers/CacheManager")
---@type BJIManagerCam
BJI.Managers.Cam = require("ge/extensions/BJI/managers/CameraManager")
---@type BJIManagerChat
BJI.Managers.Chat = require("ge/extensions/BJI/managers/ChatManager")
---@type BJIManagerCollisions
BJI.Managers.Collisions = require("ge/extensions/BJI/managers/CollisionsManager")
---@type BJIManagerContext
BJI.Managers.Context = require("ge/extensions/BJI/managers/ContextManager")
---@type BJIManagerDrift
BJI.Managers.Drift = require("ge/extensions/BJI/managers/DriftManager")
---@type BJIManagerEnvironment
BJI.Managers.Env = require("ge/extensions/BJI/managers/EnvironmentManager")
---@type BJIManagerEvents
BJI.Managers.Events = require("ge/extensions/BJI/managers/EventManager")
---@type BJIManagerGPS
BJI.Managers.GPS = require("ge/extensions/BJI/managers/GPSManager")
---@type BJIManagerLang
BJI.Managers.Lang = require("ge/extensions/BJI/managers/LangManager")
---@type BJIManagerLocalStorage
BJI.Managers.LocalStorage = require("ge/extensions/BJI/managers/LocalStorageManager")
---@type BJIManagerMessage
BJI.Managers.Message = require("ge/extensions/BJI/managers/MessageManager")
---@type BJIManagerMods
BJI.Managers.Mods = require("ge/extensions/BJI/managers/ModsManager")
---@type BJIManagerNametags
BJI.Managers.Nametags = require("ge/extensions/BJI/managers/NametagsManager")
---@type BJIManagerPerm
BJI.Managers.Perm = require("ge/extensions/BJI/managers/PermissionManager")
---@type BJIManagerPopup
BJI.Managers.Popup = require("ge/extensions/BJI/managers/PopupManager")
---@type BJIManagerRaceUI
BJI.Managers.RaceUI = require("ge/extensions/BJI/managers/RaceUIManager")
---@type BJIManagerRaceWaypoint
BJI.Managers.RaceWaypoint = require("ge/extensions/BJI/managers/RaceWaypointManager")
---@type BJIManagerReputation
BJI.Managers.Reputation = require("ge/extensions/BJI/managers/ReputationManager")
---@type BJIManagerRestrictions
BJI.Managers.Restrictions = require("ge/extensions/BJI/managers/RestrictionsManager")
---@type BJIManagerScenario
BJI.Managers.Scenario = require("ge/extensions/BJI/managers/ScenarioManager")
---@type BJIManagerSound
BJI.Managers.Sound = require("ge/extensions/BJI/managers/SoundManager")
---@type BJIManagerStations
BJI.Managers.Stations = require("ge/extensions/BJI/managers/StationsManager")
---@type BJIManagerTick
BJI.Managers.Tick = require("ge/extensions/BJI/managers/TickManager")
---@type BJIManagerToast
BJI.Managers.Toast = require("ge/extensions/BJI/managers/ToastManager")
---@type BJIManagerUI
BJI.Managers.UI = require("ge/extensions/BJI/managers/UIManager")
---@type BJIManagerVeh
BJI.Managers.Veh = require("ge/extensions/BJI/managers/VehicleManager")
---@type BJIManagerVehSelectorUI
BJI.Managers.VehSelectorUI = require("ge/extensions/BJI/managers/VehicleSelectorUIManager")
---@type BJIManagerVotes
BJI.Managers.Votes = require("ge/extensions/BJI/managers/VotesManager")
---@type BJIManagerWaypointEdit
BJI.Managers.WaypointEdit = require("ge/extensions/BJI/managers/WaypointEditManager")
---@type BJIManagerWindows
BJI.Managers.Windows = require("ge/extensions/BJI/managers/WindowsManager")
---@type BJIManagerGameState
BJI.Managers.GameState = require("ge/extensions/BJI/managers/GameStateManager")
---@type BJIManagerTournament
BJI.Managers.Tournament = require("ge/extensions/BJI/managers/TournamentManager")

BJI.Tx.cache = require("ge/extensions/BJI/tx/CacheTx")(BJI.Tx)
BJI.Tx.config = require("ge/extensions/BJI/tx/ConfigTx")(BJI.Tx)
BJI.Tx.database = require("ge/extensions/BJI/tx/DatabaseTx")(BJI.Tx)
BJI.Tx.moderation = require("ge/extensions/BJI/tx/ModerationTx")(BJI.Tx)
BJI.Tx.player = require("ge/extensions/BJI/tx/PlayerTx")(BJI.Tx)
BJI.Tx.scenario = require("ge/extensions/BJI/tx/ScenarioTx")(BJI.Tx)
BJI.Tx.votekick = require("ge/extensions/BJI/tx/VoteKickTx")(BJI.Tx)
BJI.Tx.votemap = require("ge/extensions/BJI/tx/VoteMapTx")(BJI.Tx)
BJI.Tx.voterace = require("ge/extensions/BJI/tx/VoteRaceTx")(BJI.Tx)
BJI.Tx.tournament = require("ge/extensions/BJI/tx/TournamentTx")(BJI.Tx)

BJI.Rx.ctrls.CACHE = require("ge/extensions/BJI/rx/CacheRx")
BJI.Rx.ctrls.DATABASE = require("ge/extensions/BJI/rx/DatabaseRx")
BJI.Rx.ctrls.PLAYER = require("ge/extensions/BJI/rx/PlayerRx")
BJI.Rx.ctrls.SCENARIO = require("ge/extensions/BJI/rx/ScenarioRx")

---@type BJIWindowMain
BJI.Windows.Main = require("ge/extensions/BJI/ui/windows/Main")
---@type BJIWindowStation
BJI.Windows.Station = require("ge/extensions/BJI/ui/windows/Station")
---@type BJIWindowUserSettings
BJI.Windows.UserSettings = require("ge/extensions/BJI/ui/windows/UserSettings")
---@type BJIWindowRacesLeaderboard
BJI.Windows.RacesLeaderboard = require("ge/extensions/BJI/ui/windows/RacesLeaderboard")
---@type BJIWindowVehSelector
BJI.Windows.VehSelector = require("ge/extensions/BJI/ui/windows/VehSelector")
---@type BJIWindowVehSelectorPreview
BJI.Windows.VehSelectorPreview = require("ge/extensions/BJI/ui/windows/VehSelectorPreview")
---@type BJIWindowBusMissionPreparation
BJI.Windows.BusMissionPreparation = require("ge/extensions/BJI/ui/windows/BusMissionPreparation")
---@type BJIWindowTheme
BJI.Windows.Theme = require("ge/extensions/BJI/ui/windows/Theme")
---@type BJIWindowFreeroamSettings
BJI.Windows.FreeroamSettings = require("ge/extensions/BJI/ui/windows/FreeroamSettings")
---@type BJIWindowEnvironment
BJI.Windows.Environment = require("ge/extensions/BJI/ui/windows/Environment")
---@type BJIWindowHunterSettings
BJI.Windows.HunterSettings = require("ge/extensions/BJI/ui/windows/HunterSettings")
---@type BJIWindowHunter
BJI.Windows.Hunter = require("ge/extensions/BJI/ui/windows/Hunter")
---@type BJIWindowDerbySettings
BJI.Windows.DerbySettings = require("ge/extensions/BJI/ui/windows/DerbySettings")
---@type BJIWindowDerby
BJI.Windows.Derby = require("ge/extensions/BJI/ui/windows/Derby")
---@type BJIWindowRaceSettings
BJI.Windows.RaceSettings = require("ge/extensions/BJI/ui/windows/RaceSettings")
---@type BJIWindowRace
BJI.Windows.Race = require("ge/extensions/BJI/ui/windows/Race")
---@type BJIWindowDeliveryMulti
BJI.Windows.DeliveryMulti = require("ge/extensions/BJI/ui/windows/DeliveryMulti")
---@type BJIWindowSpeed
BJI.Windows.Speed = require("ge/extensions/BJI/ui/windows/Speed")
---@type BJIWindowDatabase
BJI.Windows.Database = require("ge/extensions/BJI/ui/windows/Database")
---@type BJIWindowServer
BJI.Windows.Server = require("ge/extensions/BJI/ui/windows/Server")
---@type BJIWindowScenarioEditor
BJI.Windows.ScenarioEditor = require("ge/extensions/BJI/ui/windows/ScenarioEditor")
---@type BJIWindowSelection
BJI.Windows.Selection = require("ge/extensions/BJI/ui/windows/Selection")
---@type BJIWindowTournament
BJI.Windows.Tournament = require("ge/extensions/BJI/ui/windows/Tournament")


BJI.Managers.Scenario.TYPES.FREEROAM = "FREEROAM"
BJI.Managers.Scenario.TYPES.RACE_SOLO = "RACE_SOLO"
BJI.Managers.Scenario.TYPES.RACE_MULTI = "RACE_MULTI"
BJI.Managers.Scenario.TYPES.VEHICLE_DELIVERY = "VEHICLE_DELIVERY"
BJI.Managers.Scenario.TYPES.PACKAGE_DELIVERY = "PACKAGE_DELIVERY"
BJI.Managers.Scenario.TYPES.BUS_MISSION = "BUS_MISSION"
BJI.Managers.Scenario.TYPES.SPEED = "SPEED"
BJI.Managers.Scenario.TYPES.DELIVERY_MULTI = "DELIVERY_MULTI"
BJI.Managers.Scenario.TYPES.HUNTER = "HUNTER"
BJI.Managers.Scenario.TYPES.DERBY = "DERBY"
BJI.Managers.Scenario.TYPES.TAG_DUO = "TAG_DUO"

BJI.Managers.Scenario.scenarii[BJI.Managers.Scenario.TYPES.FREEROAM] = require(
    "ge/extensions/BJI/scenario/ScenarioFreeRoam")
BJI.Managers.Scenario.scenarii[BJI.Managers.Scenario.TYPES.RACE_SOLO] = require(
    "ge/extensions/BJI/scenario/ScenarioRaceSolo")
BJI.Managers.Scenario.scenarii[BJI.Managers.Scenario.TYPES.RACE_MULTI] = require(
    "ge/extensions/BJI/scenario/ScenarioRaceMulti")
BJI.Managers.Scenario.scenarii[BJI.Managers.Scenario.TYPES.VEHICLE_DELIVERY] = require(
    "ge/extensions/BJI/scenario/ScenarioDeliveryVehicle")
BJI.Managers.Scenario.scenarii[BJI.Managers.Scenario.TYPES.PACKAGE_DELIVERY] = require(
    "ge/extensions/BJI/scenario/ScenarioDeliveryPackage")
BJI.Managers.Scenario.scenarii[BJI.Managers.Scenario.TYPES.BUS_MISSION] = require(
    "ge/extensions/BJI/scenario/ScenarioBusMission")
BJI.Managers.Scenario.scenarii[BJI.Managers.Scenario.TYPES.SPEED] = require(
    "ge/extensions/BJI/scenario/ScenarioSpeed")
BJI.Managers.Scenario.scenarii[BJI.Managers.Scenario.TYPES.DELIVERY_MULTI] = require(
    "ge/extensions/BJI/scenario/ScenarioDeliveryMulti")
BJI.Managers.Scenario.scenarii[BJI.Managers.Scenario.TYPES.HUNTER] = require(
    "ge/extensions/BJI/scenario/ScenarioHunter")
BJI.Managers.Scenario.scenarii[BJI.Managers.Scenario.TYPES.DERBY] = require(
    "ge/extensions/BJI/scenario/ScenarioDerby")
BJI.Managers.Scenario.scenarii[BJI.Managers.Scenario.TYPES.TAG_DUO] = require(
    "ge/extensions/BJI/scenario/ScenarioTagDuo")
