# BeamJoy
All-in-One mod for BeamMP

The purpose of this mod is to provide easy access to moderation tools and activities for the players on your BeamMP server.
In addition, it includes a built-in framework to make it modular, allowing developers to easily add new features.

## Summary
1. [Features](#features)
2. [How to Install](#how-to-install)
3. [How to Add a Modded Map](#how-to-add-a-modded-map-to-your-server)
4. [How to Install Basegame Data (Gas Stations, Garages, Delivery points, Races, ...)](#how-to-install-basegame-maps-data)
5. [How to Set Or Add a Language](#how-to-set-or-add-a-language-to-your-server)
6. [Video Tutorials](#video-tutorials)
7. [Participating](#participating)
8. [Known Issues](#known-issues)
9. [Roadmap](#roadmap)
10. [Credits](#credits)

## Features

<details>
  <summary>Show</summary>
    
### Global and Sync

- Toggle sync for Sun, Weather, Gravity, Simulation speed, and Atmosphere temperature per hour.
- Configure settings for Sun, Weather, Gravity, Simulation speed, and Atmosphere temperature per hour.
- Play time can be synced between all players.
- Prevent players from pausing the simulation.
- Optimized map switcher (none of your modded maps need to be sent to joining players, avoiding delays before they can play).
- Players can vote to switch maps.
- Reputation Level system (XP-like). Players gain points for driving and completing activities. This is highly customizable and serves as a ranking system.
- Complete internationalization (validated only for EN and FR; feel free to submit modifications for other languages).
- Modular permission system allowing you to create groups and adjust permissions.
- Customizable welcome messages per language.
- Chat entries for player joins and leaves.
- A broadcast system for customizable messages sent at specified intervals, by language.
- All server configurations can be changed in-game with sufficient permissions; no need for file-based configuration changes.
- Toggleable Console, WorldEditor, and NodeGrabber for your players (some scenarios disable these to prevent cheating).

### QoL

- Reworked and toggleable player nametags, showing who is spectating, who is playing, and idle vehicles. Props do not display nametags, and trailers do not if their owner is towing them.
- Reworked in-game chat with Rank or Reputation level indicators.
- Toggleable automatic headlights based on the day-night cycle.
- Toggleable smooth free camera.
- Precise FoV selector.
- Ghost mode to prevent speeding players from crashing into newly spawned players.
- Toggleable on-screen drift indicator.
- Toggleable broadcast for big drifts.
- Reputation rewards based on drift length.
- Almost all base game UI applications work for each scenario.
- BigMap missions are removed since they are unavailable on BeamMP.
- Traffic spawning is managed with a per-group VehicleCap permission to prevent game softlock when permission is missing.
- Prevent users from activating their own mods and disrupting the server experience.
- A secondary, highly responsive vehicle selector with all the base functionalities but without preview images (works with modded vehicles).
- Complete theme editor for windows for admins and selected players.
- Vehicle model blacklist to prevent their usage on your server (only staff can see and spawn them).
- Specific permissions for spawning trailers and props. Vehicles in categories for which you lack permissions will be hidden in both vehicle selectors.
- Built-in presets for game time (dusk, noon, dawn, midnight) and weather (clear, cloudy, light rain, rainy, light snow, and snowy).
- Toggleable preservation of fuel/energy when a vehicle is reset, making gas stations and charging stations essential.

### Facilities

- Gas Stations and Charging Stations, with independent fuel types.
- Complete station editor for admins and selected players.
- Garages to repair vehicles and refill NOS.
- Complete garage editor for admins and selected players.
- Working GPS to find gas stations, garages, and players (and more within scenarios).

### Moderation

- Mute players.
- Kick players.
- TempBan players.
- Ban players.
- Players can vote to kick griefers.
- Freeze specific player vehicles (all or specific ones).
- Turn specific player engines on or off (all or specific vehicles).
- Explode specific player vehicles.
- Teleport vehicles.
- Toggleable nametags.
- Toggleable quick travel points in BigMap.
- Toggleable player unicycles (walking mode).
- Toggleable whitelist (overridable by staff).
- By default, players in the "none" group do not have permission to spawn vehicles, allowing moderators to promote them easily (to change this, adjust the VehicleCap of the none group).
- Anti-idle unicycle and anti-unicycle spam systems.

### Scenarios

#### Races

- Multiplayer races with leaderboards and time delta.
- Solo races with leaderboards and time delta.
- Race editor for admins and selected players.
- Multiplayer races can be forced by staff or voted for by players.
- Multiple respawn strategies: All respawn types, no respawn (with a DNF counter), respawn at the last checkpoint.
- Working pit stands.
- Players can use any vehicle, a specific model, or a specified configuration set at race launch.
- Dynamic branching race mapping allows shortcuts or reroutes.
- Persistent race records.
- Reputation rewards for participation, winning races, and breaking records, highly customizable.
- Real-time race time counter with flashing time when reaching a checkpoint (UI applications).

#### Hunter / CarHunt

- Working hunter system where the fugitive and hunters cannot see each other's nametags.
- The fugitive must pass the specified checkpoints without being taken down by hunters or crashing.
- Hunters can reset their vehicles but with a 10-second penalty before resuming the chase.
- Vehicle configurations can be forced at launch.
- Complete editor for starting positions (Hunters and Fugitive) and checkpoints for admins and selected players.
- Reputation rewards for participation and winning, highly customizable.

#### Deliveries

- Vehicle deliveries (as in the single-player game).
- Package deliveries.
- Package deliveries together (all participants deliver to the same destination simultaneously).
- Delivery points editor for admins and selected players.
- Reputation rewards, highly customizable.
- Customizable vehicle blacklist for vehicle deliveries (by default *atv* and *citybus*).

#### Bus Mission

- Bus routes (as in the single-player game).
- Working UI applications.
- Dynamic bus information.
- Bus route editor for admins and selected players.
- Reputation rewards per kilometer driven, highly customizable.

#### Speed Game

- Battle Royale-like game where players must stay above an increasing minimum speed or risk exploding.
- Can be forced by staff or voted for by players.
- Reputation rewards, highly customizable.

#### Destruction Derby

- Battle Royale-like game where the last moving vehicle wins.
- Can be launched with a lives amount setting.
- Specific vehicle models can be set at launch for thematic games.
- Multiple arenas per map.
- Complete arena and starting positions editor for admins and selected players.
- Reputation rewards for participation and winning, highly customizable.

### Tech

- Built-in developer-friendly framework for scenarios and events.
- Improved communication limits between server and clients.
- Per-feature managers.
- Built-in developer-friendly window drawing system (builders).
- Per-model cache system with auto-requesting on changes.
- Internationalization system for clients, server, and server-client communications.
- File-system DAO layer easily replaceable to migrate to (No)SQL database systems.

</details>

## How to install

- Install your BeamMP server ([BeamMP Server Download](https://beammp.com)) and configure it (at least your *AuthKey*).
- Launch your server once to initialize files.
- Download the last version of the mod ([Mod Releases](https://github.com/my-name-is-samael/beamjoy/releases/tag/Full)).
- Unzip the mod archive in your server's *Resources* folder.
- Connect your game to your server.
- Type in the server console `bj setgroup <your_playername> owner` to gain permissions

(*your_playername* is not case-sensitive and can be a subpart of your actual playername).

## How to add a modded map to your server

- Ensure to have the permission *SetMaps*.
- Place the map archive in your server's *Resources* folder (not in *Client* or *Server* folders).
- In-game, navigate to *Config* Menu > *Server* > *Maps Labels*.
- At the bottom, fill in the *Tech Name* (name of the folder inside the archive), the *Map Label* (the label you want players to see) and the *Archive Full Name* (including the extension), e.g., "ks_spa", "SPA Francorchamps", "ks_spa_v20230929.zip".
- Click the green *Save* button.
- Your map will no appear in the map switcher and map vote areas.

The optimized map switcher only sends the current modded map to joining players, not all idle modded maps.

**Caution** : When switching to or from a modded map, the server will restart. Ensure you have an active reboot system for your server.

## How to install basegame maps data

- Download the data archive (Coming Soon...).
- Extract it to the *Resources/Server/BeamJoyData/db/scenarii/* folder.
- Restart the server.
- All basegame maps, scenarios, and facilities will now be available for players.

## How to set or add a language to your server

The mod is packed with EN, FR, DE, IT, ES, PT and RU languages.

To remove languages:
- Go to the folder *Resources/Server/BeamJoyCore/lang* and delete the files you dont want.
- Update the *Resources/Server/BeamJoyData/db/bjc.json* file to remove any instances of those languages in:
    - Server.Lang
    - Server.Broadcasts
    - Server.WelcomeMessage

To add new language:
- In the BeamNG main menu, open the console and type `dump(Lua:getSelectedLanguage())`.
- You should get a result like *"en_EN"*. Name your future JSON file using the part before the underscore, converted to lowercase (e.g., *"Tr_UI"* becomes *tr.json*).
- Copy *Resources/Server/BeamJoyCore/lang/en.json* and rename it with the new name from the previous step.
- Translate the newly created file, but only change the values, not the keys, and do not modify variables between braces (**{** and **}**) in values.

To update labels:
- Find your language file in *Resources/Server/BeamJoyCore/lang*.
- As mentioned earlier, do not change keys or variables between braces (**{** and **}**) in values.

## Video tutorials

Coming soon ..

## Participating

Feel free to create pull requests, as long as you follow the coding scheme.

Also, feel free to report bugs or suggest improvements. I'll do my best to respond quickly, but note that I no longer work full-time on this project.

## Known issues

- Welcome message not always showing, depending on the time the map took to load (in progress)

## Roadmap

- [ ] Direct messages
- [ ] Configurable Hunter respawn stuck delay
- [ ] Fork with only race features
- [ ] Toggleable automatic random weather presets (maybe with smooth transitions, waiting for base game changes for temperature and weather)
- [ ] Synced world objects, including in scenarios (may not be possible)
- [ ] Client-side cache system (cookie-like; useful for personal records in races, for example).

## Credits

Thanks to all BETA testers who helped me test and debug the features:
dvergar, Trina, Baliverne0, Rodjiii, Lotax, Nath_YT, korrigan_91, and countless others.

A huge thanks to prestonelam2003 for his work on [CobaltEssentials](https://github.com/prestonelam2003/CobaltEssentials) which inspired me to create BeamJoy, although I didn't copy any lines of his code.

Another huge thank to StanleyDudek for his work on [CobaltEssentialsInterface](https://github.com/StanleyDudek/CobaltEssentialsInterface) which taught me how to create front-end BeamMP mods, communicate with the server, and the basic use of imgui.
