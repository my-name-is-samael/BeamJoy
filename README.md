# BeamJoy
All-in-One mod for BeamMP

This mod purpose is to give an easy access to moderation tools and activities for your BeamMP server's players.
In addition, this mod has a built-in framework to make it modular and to allow developers to easily create new features for it.

## Summary
1. [Features](#features)
2. [How To Install](#how-to-install)
3. [How To Add A Modded Map](#how-to-add-a-modded-map-to-your-server)
4. [How To Install Basegame Data (Gas Stations, Garages, Delivery points, Races, ...)](#how-to-install-basegame-maps-data)
5. [How To Set Or Add Langage](#how-to-set-or-add-langage-to-your-server)
6. [Video Tutorials](#video-tutorials)
7. [Participating](#participating)
8. [Known Issues](#known-issues)
9. [Roadmap](#roadmap)
10. [Credits](#credits)

## Features

### Global and Sync

- Toggle sync on Sun, Weather, Gravity, Simulation speed and Atmosphere temperature per hour.
- Configure each settings for Sun, Weather, Gravity, Simulation speed and Atmosphere temperature per hour.
- Can play time in sync between all players
- Prevent players to pause the simulation.
- Optimized map switcher (none of your modded map needs to be served to joining players and have them waiting before play).
- Vote for map switch by players.
- Reputation Level system (XP-like). Each player gain points driving and doing activities, highly customizable. The reputation level is not linked to any progression system but is only here to attribute rank to players.
- Complete internationalization (I have only validated EN and FR, so feel free to issue modifications on other langages).
- Modular permission system, allowing you to add groups and adjusting them.
- Customizable welcome message per langage.
- Chat entries when player join and left.
- Broadcast system to have messages shouted every specified delay by lang, highly customizable.
- Every server configuration can be changed in-game with the sufficient permissions, no configuration has to be made within files.
- Toggleable Console, WorldEditor and NodeGrabber for your players (certain scenario are disabling some to avoid cheat)

### QoL

- Reworked and toggleable player nametags, showing who's spectating, who's playing and idle vehicles. Props do not show Nametags and neither trailers if their owner is tracting them.
- Reworked in-game chat with Rank or Reputation level.
- Toggleable automatic headlights of night and day cycle.
- Toggleable smooth free camera.
- Precise FoV selector.
- Ghost mode to avoid speeding player to crash into freshly (re)spawned players.
- Toggleable drift indicator on-screen.
- Toggleable broadcast on big drifts.
- Reputation rewards by drift length.
- Almost all base game UI applications are working for each scenario.
- BigMap missions are removed since they are unavailable on BeamMP.
- Traffic spawning managed with per-group VehicleCap permission and preventing game softlock when missing permission.
- Preventing user activating their own mods and ruining your server experience.
- Second highly reactive vehicle selector, having all the base functionnalities but the preview images. Working with modded vehicles.
- Complete theme editor for the windows for admins+ and selected players.
- Vehicle model blacklist to prevent their usage on your server (only staff can see and spawn them).
- Specific permission to spawn trailer, and another to spawn props. Vehicles in a category you don't have the permission for will be hided in both vehicle selectors.
- Built-in presets for game time (dusk noon, dawn, midnight) and weather (clear, cloudy, light rain, rainy, light snow and snowy).
- Toggleable preservation of fuel/energy when a vehicle is resetted, making gas stations and charging stations mandatory.

### Facilities

- Gas Stations and Charging Stations, with independant fuel types.
- Complete stations editor for admin+ and selected players.
- Garages to repair vehicles and refill NOS.
- Complete garages editor for admin+ and selected players.
- Working GPS to find gas stations, garages and players (and more within scenarii).

### Moderation

- Mute players.
- Kick Players.
- TempBan players.
- Ban Players.
- Players can vote to kick annoying griefers.
- Freeze specific player vehicle (all or specific vehicle).
- Turn off and on specific player engine (all or specific vehicle).
- Explode specific player vehicle (only specific vehicle).
- Teleport Vehicle
- Toggleable Nametags.
- Toggleable quicktravel points in BigMap.
- Toggleable allowing players to create unicycles (walking)
- Toggleable whitelist (overrideable by staff)
- By default, the default player group does not have the permission to spawn any vehicle, they are placed in a different list so moderators+ can promote them easily (to change that, change the **VehicleCap** of the *none* group)
- Anti idle unicycles system and anti unicycle spam system

### Scenarii

#### Races

- Multiplayer races with leaderboard and time delta.
- Solo races with leaderboard and time delta.
- Race editor for admins+ and selected players.
- Multiplayer race can be forced by staff or voted by players.
- Working stands.
- Multiple respawn strategies: All respawn types, no respawn (with a DNF counter), respawn to the last checkpoint.
- Working stand pit.
- Players can use any vehicle, a specified model or a specified configuration, setted at the race launch
- Dynamic branching race mapping allowing shortcut or reroutes.
- Persistent record by race.
- Reputation rewards for participating, winning races and beating records, highly customizable.
- Own race time counter in realtime and flashing time when reaching a checkpoint with UI applications

#### Hunter / CarHunt

- Working hunter system where the fugitive and hunters cannot see other team's nametags.
- The fugitive have to take the specified amount of checkpoint around the map without being taken down by hunters or it's own driving skills.
- Each hunters can reset it's own vehicle but will have a 10 seconds penalty before it can resume the chase.
- Vehicle configurations can be forced at launch.
- Complete editor for starting positions (Hunters and Fugitive) and checkpoints for admins+ and selected players.
- Reputation rewards for participating and winners, highly customizable.

#### Deliveries

- Vehicle deliveries (as present in the solo game).
- Package deliveries.
- Package deliveries Together (all participant are delivering to the same destination at the same time).
- Delivery points editor for admins+ and selected players.
- Reputation rewards, highly customizable.
- Customizable vehicle models blacklist for this scenario (by default *atv* and *citybus*)

#### Bus Mission

- Bus routes (as present in the solo game).
- Working UI applications.
- Dynamic bus informations.
- Bus route editor for admins+ and selected players.
- Reputation rewards by-kilometer driven, highly customizable.

#### Speed Game

- BattleRoyal-like game where players have to stay above the increasing minimum speed. Stay below for too long and you will explode.
- Can be forced by staff or voted by players.
- Reputation rewards, highly customizable.

#### Destruction Derby

- Battleroyal-like game where the last moving vehicle wins.
- Can be launched with a lives amount setting.
- Specific(s) vehicles model(s) can be set at launch to have a thematic game.
- Can have multiple arenas per map.
- Complete arenas and starting positions editor for admins+ and selected players.
- Reputation rewards for participating and winning, highly customizable.

### Tech

- Built-in developer-friendly framework for scenarii amd events
- Improved communication limits between server and clients
- Per-feature managers
- Built-in developer-friendly window drawing system (builders)
- Per-model cache system with auto-requesting on change feature
- Internationalization system for clients, server and from-server-communications
- File-system DAO layer easily replaceable to migrate onto (No)SQL Database systems

## How to install

- Install your BeamMP server ([BeamMP Server Download](https://beammp.com)) and configure it (at least your *AuthKey*)
- Launch your server once to initialize files
- Download the last version of the mod ([Mod Releases](https://github.com/my-name-is-samael/beamjoy/releases/tag/Full))
- Unzip the mod archive in your server's *Resources* folder
- Connect your game to your server
- Type in the server console `bj setgroup <your_playername> owner` to gain permissions
(*your_playername* is not case-sensitive and can be a subpart of your actual playername)

## How to add a modded map to your server

- Be sure to have the permission *SetMaps*
- Place the map archive in your server's *Resources* folder (not in *Client* nor *Server* folders)
- In game, navigate to *Config* Menu > *Server* > *Maps Labels*
- At the bottom, fill the *Tech Name* (name of the folder inside the archive), the *Map Label* (the label you want your players to see) and the *Archive Full Name* (including the extension) : ie. "ks_spa", "SPA Francorchamps", "ks_spa_v20230929.zip"
- Click on the green *Save* button
- Now your map will be present in the map switcher area and the map vote area

The purpose of the optimized map switcher is to only have the current modded map sended to joining players and not having all your idle modded maps sended.

**Caution** : When switching from or to a modded map, the server will restart itself, so please take your precautions to have an active reboot system for your server

## How to install basegame maps data

- Download the data archive (Coming Soon...)
- Extract it in the folder *Resources/Server/BeamJoyData/db/scenarii/*
- Restart the server
- Now you have all basegame maps scenarii and facilities available for your players

## How to set or add langage to your server

The mod is packed with EN, FR, DE, IT, ES, PT and RU langages.

If you want to remove some, go to the folder *Resources/Server/BeamJoyCore/lang* and remove the files you dont want.
Then update the file *Resources/Server/BeamJoyData/db/bjc.json* to remove any instance of those removed langages in:
- Server.Lang
- Server.Broadcasts
- Server.WelcomeMessage

## Video tutorials

Coming soon ..

## Participating

Feel free to create pull-requests, as long as you keep the coding scheme.

Also feel free to create issues for bugs and improvements on any feature, I will do my best to answer you in short time, but keep in mind I do not longer work full-time on this project.

## Known issues

- Welcome message not always showing, depending on the time the map took to load (in progress)

## Roadmap

- [ ] Direct messages
- [ ] Configurable Hunter respawn stuck delay
- [ ] Fork with only races features
- [ ] Toggleable automatic random weather presets (maybe with smooth transition, waiting for basegame changes on - temperature and weather)
- [ ] Synced world objects, and within scenarii (may never be possible)
- [ ] Looking for a client-side cache system (cookie-like; useful for personal records on races, for instance)

## Credits

Thanks to all BETA-testers who helped me test and debug the features:
dvergar, Trina, Baliverne0, Rodjiii, Lotax, Nath_YT, korrigan_91, and countless others.

A huge thanks to prestonelam2003 for his work on [CobaltEssentials](https://github.com/prestonelam2003/CobaltEssentials) which inspired me to create BeamJoy, even though I did'nt copy any line of his code.
Another huge thank to StanleyDudek for his work on [CobaltEssentialsInterface](https://github.com/StanleyDudek/CobaltEssentialsInterface) which taught me how to create front-end BeamMP mods, communicate with server and the basic use of imgui.
