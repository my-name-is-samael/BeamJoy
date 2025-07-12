-- Assists IDE autocompletion

-- QUICK ACCESSES

---@type BJIManagerAI
BJI_AI = require("ge/extensions/BJI/managers/AIManager")
---@type BJIManagerAsync
BJI_Async = require("ge/extensions/BJI/managers/AsyncManager")
---@type BJIManagerAutomaticLights
BJI_AutomaticLights = require("ge/extensions/BJI/managers/AutomaticLightsManager")
---@type BJIManagerBigmap
BJI_Bigmap = require("ge/extensions/BJI/managers/BigmapManager")
---@type BJIManagerBusUI
BJI_BusUI = require("ge/extensions/BJI/managers/BusUIManager")
---@type BJIManagerCache
BJI_Cache = require("ge/extensions/BJI/managers/CacheManager")
---@type BJIManagerCam
BJI_Cam = require("ge/extensions/BJI/managers/CameraManager")
---@type BJIManagerChat
BJI_Chat = require("ge/extensions/BJI/managers/ChatManager")
---@type BJIManagerCollisions
BJI_Collisions = require("ge/extensions/BJI/managers/CollisionsManager")
---@type BJIManagerContext
BJI_Context = require("ge/extensions/BJI/managers/ContextManager")
---@type BJIManagerDrift
BJI_Drift = require("ge/extensions/BJI/managers/DriftManager")
---@type BJIManagerEnvironment
BJI_Env = require("ge/extensions/BJI/managers/EnvironmentManager")
---@type BJIManagerEvents
BJI_Events = require("ge/extensions/BJI/managers/EventManager")
---@type BJIManagerGPS
BJI_GPS = require("ge/extensions/BJI/managers/GPSManager")
---@type BJIManagerLang
BJI_Lang = require("ge/extensions/BJI/managers/LangManager")
---@type BJIManagerLocalStorage
BJI_LocalStorage = require("ge/extensions/BJI/managers/LocalStorageManager")
---@type BJIManagerMessage
BJI_Message = require("ge/extensions/BJI/managers/MessageManager")
---@type BJIManagerMods
BJI_Mods = require("ge/extensions/BJI/managers/ModsManager")
---@type BJIManagerNametags
BJI_Nametags = require("ge/extensions/BJI/managers/NametagsManager")
---@type BJIManagerPerm
BJI_Perm = require("ge/extensions/BJI/managers/PermissionManager")
---@type BJIManagerPopup
BJI_Popup = require("ge/extensions/BJI/managers/PopupManager")
---@type BJIManagerRaceUI
BJI_RaceUI = require("ge/extensions/BJI/managers/RaceUIManager")
---@type BJIManagerRaceWaypoint
BJI_RaceWaypoint = require("ge/extensions/BJI/managers/RaceWaypointManager")
---@type BJIManagerReputation
BJI_Reputation = require("ge/extensions/BJI/managers/ReputationManager")
---@type BJIManagerRestrictions
BJI_Restrictions = require("ge/extensions/BJI/managers/RestrictionsManager")
---@type BJIManagerScenario
BJI_Scenario = require("ge/extensions/BJI/managers/ScenarioManager")
---@type BJIManagerSound
BJI_Sound = require("ge/extensions/BJI/managers/SoundManager")
---@type BJIManagerStations
BJI_Stations = require("ge/extensions/BJI/managers/StationsManager")
---@type BJIManagerTick
BJI_Tick = require("ge/extensions/BJI/managers/TickManager")
---@type BJIManagerToast
BJI_Toast = require("ge/extensions/BJI/managers/ToastManager")
---@type BJIManagerUI
BJI_UI = require("ge/extensions/BJI/managers/UIManager")
---@type BJIManagerVeh
BJI_Veh = require("ge/extensions/BJI/managers/VehicleManager")
---@type BJIManagerVehSelectorUI
BJI_VehSelectorUI = require("ge/extensions/BJI/managers/VehicleSelectorUIManager")
---@type BJIManagerVotes
BJI_Votes = require("ge/extensions/BJI/managers/VotesManager")
---@type BJIManagerWaypointEdit
BJI_WaypointEdit = require("ge/extensions/BJI/managers/WaypointEditManager")
---@type BJIManagerWindows
BJI_Windows = require("ge/extensions/BJI/managers/WindowsManager")
---@type BJIManagerGameState
BJI_GameState = require("ge/extensions/BJI/managers/GameStateManager")
---@type BJIManagerTournament
BJI_Tournament = require("ge/extensions/BJI/managers/TournamentManager")
---@type BJIManagerPursuit
BJI_Pursuit = require("ge/extensions/BJI/managers/PursuitManager")
---@type BJIManagerMinimap
BJI_Minimap = require("ge/extensions/BJI/managers/MinimapManager")
---@type BJIManagerWorldObject
BJI_WorldObject = require("ge/extensions/BJI/managers/WorldObjectManager")
---@type BJIManagerInteractiveMarker
BJI_InteractiveMarker = require("ge/extensions/BJI/managers/InteractiveMarkerManager")

---@type BJIWindowMain
BJI_Win_Main = require("ge/extensions/BJI/ui/windows/Main")
---@type BJIWindowStation
BJI_Win_Station = require("ge/extensions/BJI/ui/windows/Station")
---@type BJIWindowUserSettings
BJI_Win_UserSettings = require("ge/extensions/BJI/ui/windows/UserSettings")
---@type BJIWindowRacesLeaderboard
BJI_Win_RacesLeaderboard = require("ge/extensions/BJI/ui/windows/RacesLeaderboard")
---@type BJIWindowVehSelector
BJI_Win_VehSelector = require("ge/extensions/BJI/ui/windows/VehSelector")
---@type BJIWindowBusMissionPreparation
BJI_Win_BusMissionPreparation = require("ge/extensions/BJI/ui/windows/BusMissionPreparation")
---@type BJIWindowTheme
BJI_Win_Theme = require("ge/extensions/BJI/ui/windows/Theme")
---@type BJIWindowFreeroamSettings
BJI_Win_FreeroamSettings = require("ge/extensions/BJI/ui/windows/FreeroamSettings")
---@type BJIWindowEnvironment
BJI_Win_Environment = require("ge/extensions/BJI/ui/windows/Environment")
---@type BJIWindowHunterSettings
BJI_Win_HunterSettings = require("ge/extensions/BJI/ui/windows/HunterSettings")
---@type BJIWindowHunter
BJI_Win_Hunter = require("ge/extensions/BJI/ui/windows/Hunter")
---@type BJIWindowInfectedSettings
BJI_Win_InfectedSettings = require("ge/extensions/BJI/ui/windows/InfectedSettings")
---@type BJIWindowInfected
BJI_Win_Infected = require("ge/extensions/BJI/ui/windows/Infected")
---@type BJIWindowDerbySettings
BJI_Win_DerbySettings = require("ge/extensions/BJI/ui/windows/DerbySettings")
---@type BJIWindowDerby
BJI_Win_Derby = require("ge/extensions/BJI/ui/windows/Derby")
---@type BJIWindowRaceSettings
BJI_Win_RaceSettings = require("ge/extensions/BJI/ui/windows/RaceSettings")
---@type BJIWindowRace
BJI_Win_Race = require("ge/extensions/BJI/ui/windows/Race")
---@type BJIWindowSpeed
BJI_Win_Speed = require("ge/extensions/BJI/ui/windows/Speed")
---@type BJIWindowDatabase
BJI_Win_Database = require("ge/extensions/BJI/ui/windows/Database")
---@type BJIWindowServer
BJI_Win_Server = require("ge/extensions/BJI/ui/windows/Server")
---@type BJIWindowScenarioEditor
BJI_Win_ScenarioEditor = require("ge/extensions/BJI/ui/windows/ScenarioEditor")
---@type BJIWindowSelection
BJI_Win_Selection = require("ge/extensions/BJI/ui/windows/Selection")
---@type BJIWindowTournament
BJI_Win_Tournament = require("ge/extensions/BJI/ui/windows/Tournament")
---@type BJIWindowGameDebug
BJI_Win_GameDebug = require("ge/extensions/BJI/ui/windows/GameDebug")

BJI_Tx_cache = require("ge/extensions/BJI/tx/CacheTx")(BJI.Tx)
BJI_Tx_config = require("ge/extensions/BJI/tx/ConfigTx")(BJI.Tx)
BJI_Tx_database = require("ge/extensions/BJI/tx/DatabaseTx")(BJI.Tx)
BJI_Tx_moderation = require("ge/extensions/BJI/tx/ModerationTx")(BJI.Tx)
BJI_Tx_player = require("ge/extensions/BJI/tx/PlayerTx")(BJI.Tx)
BJI_Tx_scenario = require("ge/extensions/BJI/tx/ScenarioTx")(BJI.Tx)
BJI_Tx_vote = require("ge/extensions/BJI/tx/VoteTx")(BJI.Tx)
BJI_Tx_tournament = require("ge/extensions/BJI/tx/TournamentTx")(BJI.Tx)

BJI_Rx_CACHE = require("ge/extensions/BJI/rx/CacheRx")
BJI_Rx_DATABASE = require("ge/extensions/BJI/rx/DatabaseRx")
BJI_Rx_PLAYER = require("ge/extensions/BJI/rx/PlayerRx")
BJI_Rx_SCENARIO = require("ge/extensions/BJI/rx/ScenarioRx")

-- OBJECT TREE ACCESSES

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
---@type BJIManagerPursuit
BJI.Managers.Pursuit = require("ge/extensions/BJI/managers/PursuitManager")
---@type BJIManagerMinimap
BJI.Managers.Minimap = require("ge/extensions/BJI/managers/MinimapManager")
---@type BJIManagerWorldObject
BJI.Managers.WorldObject = require("ge/extensions/BJI/managers/WorldObjectManager")
---@type BJIManagerInteractiveMarker
BJI.Managers.InteractiveMarker = require("ge/extensions/BJI/managers/InteractiveMarkerManager")

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
---@type BJIWindowInfectedSettings
BJI.Windows.InfectedSettings = require("ge/extensions/BJI/ui/windows/InfectedSettings")
---@type BJIWindowInfected
BJI.Windows.Infected = require("ge/extensions/BJI/ui/windows/Infected")
---@type BJIWindowDerbySettings
BJI.Windows.DerbySettings = require("ge/extensions/BJI/ui/windows/DerbySettings")
---@type BJIWindowDerby
BJI.Windows.Derby = require("ge/extensions/BJI/ui/windows/Derby")
---@type BJIWindowRaceSettings
BJI.Windows.RaceSettings = require("ge/extensions/BJI/ui/windows/RaceSettings")
---@type BJIWindowRace
BJI.Windows.Race = require("ge/extensions/BJI/ui/windows/Race")
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
---@type BJIWindowGameDebug
BJI.Windows.GameDebug = require("ge/extensions/BJI/ui/windows/GameDebug")

BJI.Tx.cache = require("ge/extensions/BJI/tx/CacheTx")(BJI.Tx)
BJI.Tx.config = require("ge/extensions/BJI/tx/ConfigTx")(BJI.Tx)
BJI.Tx.database = require("ge/extensions/BJI/tx/DatabaseTx")(BJI.Tx)
BJI.Tx.moderation = require("ge/extensions/BJI/tx/ModerationTx")(BJI.Tx)
BJI.Tx.player = require("ge/extensions/BJI/tx/PlayerTx")(BJI.Tx)
BJI.Tx.scenario = require("ge/extensions/BJI/tx/ScenarioTx")(BJI.Tx)
BJI.Tx.vote = require("ge/extensions/BJI/tx/VoteTx")(BJI.Tx)
BJI.Tx.tournament = require("ge/extensions/BJI/tx/TournamentTx")(BJI.Tx)

BJI.Rx.ctrls.CACHE = require("ge/extensions/BJI/rx/CacheRx")
BJI.Rx.ctrls.DATABASE = require("ge/extensions/BJI/rx/DatabaseRx")
BJI.Rx.ctrls.PLAYER = require("ge/extensions/BJI/rx/PlayerRx")
BJI.Rx.ctrls.SCENARIO = require("ge/extensions/BJI/rx/ScenarioRx")

BJI_Scenario.TYPES.FREEROAM = "FREEROAM"
BJI_Scenario.TYPES.RACE_SOLO = "RACE_SOLO"
BJI_Scenario.TYPES.RACE_MULTI = "RACE_MULTI"
BJI_Scenario.TYPES.VEHICLE_DELIVERY = "VEHICLE_DELIVERY"
BJI_Scenario.TYPES.PACKAGE_DELIVERY = "PACKAGE_DELIVERY"
BJI_Scenario.TYPES.BUS_MISSION = "BUS_MISSION"
BJI_Scenario.TYPES.SPEED = "SPEED"
BJI_Scenario.TYPES.DELIVERY_MULTI = "DELIVERY_MULTI"
BJI_Scenario.TYPES.HUNTER = "HUNTER"
BJI_Scenario.TYPES.INFECTED = "INFECTED"
BJI_Scenario.TYPES.DERBY = "DERBY"
BJI_Scenario.TYPES.TAG_DUO = "TAG_DUO"

BJI_Scenario.scenarii[BJI_Scenario.TYPES.FREEROAM] = require("ge/extensions/BJI/scenario/ScenarioFreeRoam")
BJI_Scenario.scenarii[BJI_Scenario.TYPES.RACE_SOLO] = require("ge/extensions/BJI/scenario/ScenarioRaceSolo")
BJI_Scenario.scenarii[BJI_Scenario.TYPES.RACE_MULTI] = require("ge/extensions/BJI/scenario/ScenarioRaceMulti")
BJI_Scenario.scenarii[BJI_Scenario.TYPES.VEHICLE_DELIVERY] = require("ge/extensions/BJI/scenario/ScenarioDeliveryVehicle")
BJI_Scenario.scenarii[BJI_Scenario.TYPES.PACKAGE_DELIVERY] = require("ge/extensions/BJI/scenario/ScenarioDeliveryPackage")
BJI_Scenario.scenarii[BJI_Scenario.TYPES.BUS_MISSION] = require("ge/extensions/BJI/scenario/ScenarioBusMission")
BJI_Scenario.scenarii[BJI_Scenario.TYPES.SPEED] = require("ge/extensions/BJI/scenario/ScenarioSpeed")
BJI_Scenario.scenarii[BJI_Scenario.TYPES.DELIVERY_MULTI] = require("ge/extensions/BJI/scenario/ScenarioDeliveryMulti")
BJI_Scenario.scenarii[BJI_Scenario.TYPES.HUNTER] = require("ge/extensions/BJI/scenario/ScenarioHunter")
BJI_Scenario.scenarii[BJI_Scenario.TYPES.INFECTED] = require("ge/extensions/BJI/scenario/ScenarioInfected")
BJI_Scenario.scenarii[BJI_Scenario.TYPES.DERBY] = require("ge/extensions/BJI/scenario/ScenarioDerby")
BJI_Scenario.scenarii[BJI_Scenario.TYPES.TAG_DUO] = require("ge/extensions/BJI/scenario/ScenarioTagDuo")