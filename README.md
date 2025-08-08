# BeamJoy
All-in-One mod for BeamMP

<p align="center">
  <img src="/assets/logo_white.png" style="width: 49%; height: auto;" />
  <a target="_blank" href="https://www.youtube.com/watch?v=l-lbXQDEz-o" alt="Trailer">
      <img src="/assets/trailer_preview.jpg" style="width: 49%; height: auto;" alt="Trailer" />
  </a>
</p>

<p align="center">
  <a href="https://discord.gg/83kF4utCV5">
    <img src="/assets/discord_icon.png" width="100" alt="Join us on Discord" />
  </a>
  <a href="https://www.patreon.com/c/BeamJoy">
    <img src="/assets/patreon_icon.png" width="100" alt="Join us on Patreon" />
  </a>
</p>

The purpose of this mod is to provide easy access to moderation tools and activities for the players on your BeamMP server.
In addition, it includes a built-in framework to make it modular, allowing developers to easily add new features.

## Summary
- [BeamJoy](#beamjoy)
  - [Summary](#summary)
  - [Features](#features)
    - [Global and Sync](#global-and-sync)
    - [QoL](#qol)
    - [Facilities](#facilities)
    - [Moderation](#moderation)
    - [Scenarios](#scenarios)
      - [Races](#races)
      - [Hunter / CarHunt](#hunter--carhunt)
      - [Deliveries](#deliveries)
      - [Bus Mission](#bus-mission)
      - [Speed Game](#speed-game)
      - [Destruction Derby](#destruction-derby)
      - [Tag Duo](#tag-duo)
      - [Infected](#infected)
    - [Tournament](#tournament)
    - [Tech (for developers)](#tech-for-developers)
  - [How To](#how-to)
    - [How to install](#how-to-install)
    - [How to add a modded map to your server](#how-to-add-a-modded-map-to-your-server)
    - [How to install basegame maps data](#how-to-install-basegame-maps-data)
    - [How to set or add a language to your server](#how-to-set-or-add-a-language-to-your-server)
  - [FAQ](#faq)
    - [I cannot spawn a vehicle even after setting myself the server owner. What did I do wrong ?](#i-cannot-spawn-a-vehicle-even-after-setting-myself-the-server-owner-what-did-i-do-wrong-)
    - [I cannot respawn my vehicle, is this broken?](#i-cannot-respawn-my-vehicle-is-this-broken)
    - [Why some players can spawn traffic and some don't ? How can I spawn traffic during a scenario ?](#why-some-players-can-spawn-traffic-and-some-dont--how-can-i-spawn-traffic-during-a-scenario-)
    - [Can I enable GPS path in races ?](#can-i-enable-gps-path-in-races-)
    - [Can I completely disable the "ghost mode" when somebody respawns ?](#can-i-completely-disable-the-ghost-mode-when-somebody-respawns-)
    - [Shadows are disappearing when I drive fast. What's going on ?](#shadows-are-disappearing-when-i-drive-fast-whats-going-on-)
  - [Compatible Mods](#compatible-mods)
  - [Participating](#participating)
  - [Known issues](#known-issues)
  - [Credits](#credits)
  - [Support](#support)

## Features
<img src="/assets/banner-features.png" style="width: 100%; height: auto;" alt="Features" />

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
- Localized and dynamic chat commands system.

### QoL

- Reworked and toggleable player nametags, showing who is spectating, who is playing, and idle vehicles. Props do not display nametags, and trailers do not if their owner is towing them. Colors are also configurable by everyone (for themselves).
- Reworked in-game chat with Rank or Reputation level indicators, as well as activities events.
- Toggleable automatic headlights based on the day-night cycle.
- Toggleable smooth free camera.
- Precise free camera FoV and speed selectors.
- Toggleable respawn protection (ghost mode) to prevent speeding players from crashing into newly spawned players.
- Toggleable broadcast for big drifts.
- Reputation rewards based on drift length.
- Almost all base game UI-Apps work for each scenario.
- BigMap missions are removed since they are unavailable on BeamMP.
- Traffic spawning is managed with a per-group VehicleCap permission to prevent game softlock when permission is missing.
- Prevent users from activating their own mods and disrupting the server experience.
- A secondary, highly responsive vehicle selector with all the base functionalities and a nema filter (works with modded vehicles).
- Complete theme editor for windows for staff.
- Vehicle model blacklist to prevent their usage on your server (only staff can see and spawn them).
- Specific permissions for spawning trailers and props. Vehicles in categories for which you lack permissions will be hidden in both vehicle selectors.
- Built-in presets for game time (dusk, noon, dawn, midnight) and weather (clear, cloudy, light rain, rainy, light snow, and snowy).
- Toggleable preservation of fuel/energy when a vehicle is reset, making gas stations and charging stations essential.
- Highly customizable emergency refuel system when players vehicles are running out of gas.
- Vehicles no longer keep pressed inputs when players switch to another.
- Working GPS to find gas stations, garages, and players (and more within scenarios).
- Working world interactive markers for gas stations, garages, races, derby arenas and bus missions.
- Working `Map` menu with points of interest and GPS features.
- Controller support to start activities and votes with interactive markers.
- Night-specific environment settings are now available to make nights clearer and finally playable.

### Facilities

- Gas Stations and Charging Stations, with independent fuel types.
- Garages to repair vehicles and refill NOS.
- Complete editors for staff and selected players.

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
- Solo races (time attack) with leaderboards and time delta.
- Race editor for admins and selected players.
- Multiplayer races can be forced by staff or voted for by players.
- Working pit stands.
- Multiple respawn strategies: All respawn types, no respawn (with a DNF counter), respawn at the last checkpoint and respawn in the last pit stand.
- Players can use any vehicle, a specific model, or a specified configuration set at race launch.
- Dynamic branching race mapping allows shortcuts or reroutes.
- Persistent race records.
- Best personal times stored on the game cache and kept between game restarts.
- Reputation rewards for participation, winning races, and breaking records, highly customizable.
- Real-time race time counter with flashing time when reaching a checkpoint (UI applications).
- Toggleable broadcasting solo race times.
- Useful tools in race editor, such as 180deg vehicle rotation and race reversal.

#### Hunter / CarHunt

- Working hunter system where the fugitive and hunters cannot see each other's nametags.
- The fugitive must pass the specified checkpoints without being taken down by hunters or crashing.
- Hunters can reset their vehicles but with a time penalty before resuming the chase.
- Waypoints and start positions editor for admins and selected players.
- The mode can be forced by staff or voted for by players.
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
- Dynamic bus routes informations.
- Bus route editor for admins and selected players.
- Reputation rewards per kilometer driven, highly customizable.

#### Speed Game

- Battle Royale-like game where players must stay above an increasing minimum speed or risk exploding.
- Can be forced by staff or voted for by players.
- Reputation rewards, highly customizable.

#### Destruction Derby

- Battle Royale-like game where the last moving vehicle wins.
- The mode can be forced by staff or voted for by players.
- Can be launched with a lives amount setting.
- Specific vehicle models can be set at launch for thematic games.
- Multiple arenas per map.
- Complete arena and starting positions editor for admins and selected players.
- Reputation rewards for participation and winning, highly customizable.

#### Tag Duo

- Duo mode where one player must tag another, then roles reverse, indefinitely.
- Server-wide visible lobbies in-real-time.
- Reputation rewards for tagging your opponent, highly customizable.

#### Infected

- Battle Royale-like game where the last survivor wins.
- Start positions editor for admins and selected players.
- The mode can be forced by staff or voted for by players.
- Can be launched with forced vehicle colors for both teams.
- Can be launched with a setting imposing the last survivor to be infected for the game to ends
- A vehicle configuration can be forced at launch.

### Tournament

- Almost all previous activities can be played in a tournament mode where points are automatically attributed.
- Since number of participants can vary from an activity to another, the best player gets 1 point, and the last gets the number of participants as points, then the participant with least points wins when the tournament is over.
- When the tournament is active, no player can start an activity or a vote on their own.
- Staff members can launch tournament activities and can edit data after the activity ends.
- When all staff members leaves, the mode disbaled itself automatically, allowing players to start activities again.
- Participants data are saved upon a disconnection or a crash (and if you change map during a tournament)
- Tournament activities are:
  - Time attack (solo race)
  - Race
  - Hunter
  - Destruction Derby
  - Infected
  - Speed Game

### Tech (for developers)

- Built-in developer-friendly framework for scenarios and events.
- Improved communication limits between server and clients.
- Per-feature managers.
- Reworked developer-friendly IMGUI drawing system.
- Per-model cache system with auto-requesting on changes.
- Internationalization system for clients, server, and server-client communications.
- File-system DAO layer easily replaceable to migrate to (No)SQL database systems.
- Global beamjoy settings cache & per-server cookies-like systems
- On events triggering system

</details>

## How To
<img src="/assets/banner-howto.png" style="width: 100%; height: auto;" alt="How To" />

### How to install

- Install your BeamMP server ([BeamMP Server Download](https://beammp.com)) and configure it (at least your *AuthKey*).
- Launch your server once to initialize files.
- Download the last version of the mod ([Mod Releases](https://github.com/my-name-is-samael/BeamJoy/releases)).
- Unzip the mod archive in your server's *Resources* folder.
- Connect your game to your server.
- Type in the server console `bj setgroup <your_playername> owner` to gain permissions

(*your_playername* is not case-sensitive and can be a subpart of your actual playername).

### How to add a modded map to your server

- Ensure to have the permission *SetMaps*.
- Place the map archive in your server's *Resources* folder (not in *Client* or *Server* folders).
- In-game, navigate to *Config* Menu > *Server* > *Maps Labels*.
- At the bottom, fill in the *Tech Name* (name of the folder inside the archive), the *Map Label* (the label you want players to see) and the *Archive Full Name* (including the extension), e.g., "ks_spa", "SPA Francorchamps", "ks_spa_v20230929.zip".
- Click the green *Save* button.
- Your map will now appear in the map switcher and map vote areas.

The optimized map switcher only sends the current modded map to joining players, not all idle map mods.

**Caution** : When switching to or from a modded map, the server will restart. Ensure you have an active reboot system for your server.

### How to install basegame maps data

- Download the data archive ([available here](https://github.com/my-name-is-samael/BeamJoy/releases/tag/datapack-2024-12-20)).
- Extract it to the *Resources/Server/BeamJoyData/db/scenarii/* folder.
- Restart the server.
- All basegame maps, scenarios, and facilities will now be available for players.

### How to set or add a language to your server

The mod is packed with EN, FR, DE, IT, ES, PT and RU languages.

To remove languages:
- Go to the folder *Resources/Server/BeamJoyCore/lang* and delete the files you dont want.
- Update the *Resources/Server/BeamJoyData/db/bjc.json* file to remove any instances of those languages in:
    - Server.Lang
    - Server.Broadcasts
    - Server.WelcomeMessage

To add new language:
- You want to add an in-game language:
- - In the BeamNG main menu, open the console and type `dump(Lua:getSelectedLanguage())`.
- - You should get a result like *"en_EN"*. Name your future JSON file using the part before the underscore, converted to lowercase (e.g., *"Tr_UI"* becomes *tr.json*).
- Or you want to add a new language:
- - Find the best code for your language (usually 2 or 3 letters). Name your future JSON file with your lowered code (e.g., *tr.json*)
- Copy *Resources/Server/BeamJoyCore/lang/en.json* and rename it with the new name from the previous step.
- Translate the newly created file, but only change the values, not the keys, and do not modify variables between braces (**{** and **}**) in values.

To update labels:
- Find your language file in *Resources/Server/BeamJoyCore/lang*.
- As mentioned earlier, do not change keys or variables between braces (**{** and **}**) in values.

## FAQ
<img src="/assets/banner-faq.png" style="width: 100%; height: auto;" alt="FAQ" />

### I cannot spawn a vehicle even after setting myself the server owner. What did I do wrong ?
You should check your `MaxVehicles` inside `ServerConfig.toml` (beammp server root folder), the value cannot be set to `-1` (I recommand you to set it between 50 and 500).

### I cannot respawn my vehicle, is this broken?
Each scenario has its own rules, and there are many different types of respawns, which we can group into three categories:
- **On-the-spot respawns:**
  - `Recover vehicle` (`Insert` / `DPad left` by default)
  - `Recover vehicle Alt` (`Ctrl+Insert` by default)
  - `Set Home` (`Ctrl+Home` by default)
- **Teleported respawns:**
  - `Recover to last road`
  - `Reset physics` (`R` / `DPad right` by default)
  - `Load Home` (`Home` by default)
  - `Reload vehicle` (`Shift+R` by default)
- **Others:**
  - `Reset all physics` (`Ctrl+R` by default)
  - `Reload all vehicles` (`Ctrl+Shift+R` by default)
  - `Drop player at camera` (`F7` by default)
  - `Drop player at camera no reset` (`Ctrl+F7` by default)

_Let’s not forget about `rewind`, available on `Recover vehicle` and `Recover vehicle Alt`._

Here’s how respawns behave depending on the scenario:
- **Freeroam**: All respawns are allowed. If the server is configured with a respawn and/or teleport delay, you’ll see a countdown in the main window before you can use it again.
- **Races (solo/multi)**: The available respawns are defined by the player who starts the race:
  - `All respawns`: All on-the-spot respawns will repair your vehicle in place, and teleported ones will bring you back to the last checkpoint. Rewind is enabled.
  - `No respawns`: Self-explanatory.
  - `Last checkpoint`: Both on-the-spot and teleported respawns will bring you back to the last checkpoint you passed. Rewind is disabled.
  - `Stand`: Both on-the-spot and teleported respawns will bring you back to the closest pit stand behind you, or to your starting position if none yet. Rewind is disabled.
- **Delivery (solo, package/vehicle)**: All respawns are disabled to keep the scenario fair (you’ll need to reach a garage to repair your vehicle, except for vehicle delivery).
- **DeliveryTogether**: Unlike the above, both on-the-spot and teleported respawns are available but will only repair you in place and will cancel your streak and reward. Rewind is limited to 5 seconds.
- **TagDuo**: Participants can use all respawns, but they will be repaired in place. Rewind is limited to 5 seconds.
- **Hunter**: The fugitive can only respawn if no hunter is nearby (distance is configurable), and hunters can respawn anytime but will be frozen for a few seconds to prevent abuse (also configurable). In both cases, respawns will only repair the vehicle in place. Rewind is limited to 5 seconds.
- **Infected**: All players can use both on-the-spot and teleported respawns, but they will be repaired in place. Rewind is limited to 5 seconds.
- **Destruction Derby**: Participants have lives, and as long as they have any left, they can use on-the-spot and teleported respawns, but they will be brought back to their starting point. (Note: if they have at least one life left and the countdown reaches zero, respawn will be triggered automatically.)
- **Speed**: In this mode, participants cannot respawn, since the goal is to stay above a certain speed limit and be the last player alive.

### Why some players can spawn traffic and some don't ? How can I spawn traffic during a scenario ?

Traffic spawning is dependant on group permissions. Players in groups having a `VehicleCap` attribute set to `-1` (_Infinite_) will automatically have access to traffic toggling, but not anytime.

Here the scenarii list players can toggle traffic in:
- Freeroam
- Vehicle Delivery
- Package Delivery
- Delivery Together
- Bus Mission

### Can I enable GPS path in races ?

The GPS route system is fully integrated into the base game, but unfortunately, it fails in one-way roads, prohibited directions, and off-road sections. This often makes the route guidance useless in many parts of a race.

If your race layout isn't intuitive, the best approach is to improve your level design. Keep in mind that at each checkpoint, racers should be able to see the next one (checkpoints are visible high in the sky when there are no buildings obstructing the view). Also, avoid placing checkpoints too far apart in classic races.

### Can I completely disable the "ghost mode" when somebody respawns ?

This is a respawn protection system enabled by default on your server, but you can configure it under `Edit` > `Freeroam Settings` (`Collisions Mode` field).

### Shadows are disappearing when I drive fast. What's going on ?

Strangely, this behavior is linked to the shadow distance setting (`Config` > `Environment` > `Sun` tab > `Shadow Distance` slider).<br/>
If you want to calibrate this setting correctly on your server, I recommend the following steps:
- Choose a fast vehicle configuration (e.g., the vanilla `Civetta Bolide Top Speed`).
- Find a location where you can reach maximum speed.
- Switch to the driver’s first-person camera.
- Increase your field of view to the maximum (holding `Num 3` by default).
- Check whether the shadow distance value works well under these conditions.

## Compatible Mods
<img src="/assets/banner-compatiblemods.png" style="width: 100%; height: auto;" alt="Compatible Mods" />

- Pretty much all modded vehicles with correctly formed data
- [Enhanced Interior Camera](https://www.beamng.com/resources/enhanced-interior-camera.24952/)
- [Agent's Simplified Realistic Traffic Mod (EU + Yakuza)](https://www.beamng.com/threads/agents-simplified-realistic-traffic-mod-eu-yakuza.102034/)
- [Discord ChatHook](https://github.com/OfficialLambdax/BeamMP-ChatHook) (all chat events are logged and translated with a configuration)

_Please contact me or open a ticket to request a mod integration_

## Participating
<img src="/assets/banner-participating.png" style="width: 100%; height: auto;" alt="Participating" />

Feel free to create pull requests, as long as you follow the coding scheme. We do not accept any more features (since specific variants are now present on [Patreon](https://www.patreon.com/c/BeamJoy)) but bugs and security fixed are appreciated.

Also if you are not a developer yourself, feel free to report bugs or suggest improvements. I'll do my best to respond quickly, but note that I no longer work full-time on this project.

You can also fix translations if they are wrong :
<p>
  <a href="https://gitlocalize.com/repo/9945/es?utm_source=badge">
    <img src="https://gitlocalize.com/repo/9945/es/badge.svg" />
  </a>
  <a href="https://gitlocalize.com/repo/9945/de?utm_source=badge">
    <img src="https://gitlocalize.com/repo/9945/de/badge.svg" />
  </a>
  <a href="https://gitlocalize.com/repo/9945/fr?utm_source=badge">
    <img src="https://gitlocalize.com/repo/9945/fr/badge.svg" />
  </a>
  <a href="https://gitlocalize.com/repo/9945/it?utm_source=badge">
    <img src="https://gitlocalize.com/repo/9945/it/badge.svg" />
  </a>
  <a href="https://gitlocalize.com/repo/9945/pt?utm_source=badge">
    <img src="https://gitlocalize.com/repo/9945/pt/badge.svg" />
  </a>
  <a href="https://gitlocalize.com/repo/9945/ru?utm_source=badge">
    <img src="https://gitlocalize.com/repo/9945/ru/badge.svg" />
  </a>
</p>

## Known issues
<img src="/assets/banner-knownissues.png" style="width: 100%; height: auto;" alt="Known Issues" />

- Windows system costs performances, this is a fact and it is unfortunate. But this is the only way BeamJoy have to not be intrusive (we do not want to force players by manually adding UI-Apps, but still give them mandatory scenario and server informations).
- When leaving a server with BeamJoy on, then going to freeroam or a non-BeamJoy server, the game will softlock during the loading screen. This is a module dependency issue and we don't have a solution for now, except than a complete remake of the mod ([Patreon](https://www.patreon.com/c/BeamJoy) versions are remakes and will fix this).

## Credits
<img src="/assets/banner-credits.png" style="width: 100%; height: auto;" alt="Credits" />

Thanks to all BETA testers who helped me test and debug the features:
dvergar, Trina, Baliverne0, Rodjiii, Lotax, Nath_YT, korrigan_91, @YannD-Deltagon and all of you giving feedback and reporting bugs.

A huge thanks to prestonelam2003 for his work on [CobaltEssentials](https://github.com/prestonelam2003/CobaltEssentials) which inspired me to create BeamJoy, although I didn't copy any lines of his code.<br/>
Another huge thank to StanleyDudek for his work on [CobaltEssentialsInterface](https://github.com/StanleyDudek/CobaltEssentialsInterface) which taught me how to create front-end BeamMP mods, communicate with the server, and the basic use of imgui.

## Support
<img src="/assets/banner-support.png" style="width: 100%; height: auto;" alt="Support" />

**BeamJoy is and will always be free.** However, if you'd like to support my work, you can [buy me a coffee](https://coff.ee/tontonsamael) or [support BeamJoy on Patreon](https://www.patreon.com/c/BeamJoy).

If you're looking for more from BeamJoy, you'll find additional variants on [Patreon](https://www.patreon.com/c/BeamJoy) — you can even get your own personalized version.

<p align="center">
  <a target="_blank" href="https://coff.ee/tontonsamael" alt="Buy me a coffee">
    <img src="/assets/buymeacoffee.png?raw=" width="250" alt="Buy me a coffee" />
  </a>
  <a target="_blank" href="https://www.patreon.com/c/BeamJoy" alt="Join us on Patreon">
      <img src="/assets/patreon.png?raw=" width="250" alt="Join us on Patreon"/>
  </a>
</p>