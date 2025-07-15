# BeamJoy
All-in-One mod for BeamMP

<p align="center">
  <img src="https://raw.githubusercontent.com/my-name-is-samael/BeamJoy/refs/heads/main/assets/logo_white.png" style="width: 49%; height: auto;" />
  <a target="_blank" href="https://www.youtube.com/watch?v=l-lbXQDEz-o" alt="Trailer">
      <img src="https://raw.githubusercontent.com/my-name-is-samael/BeamJoy/refs/heads/main/assets/trailer_preview.jpg" style="width: 49%; height: auto;" />
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
    - [Tech (for developers)](#tech-for-developers)
  - [How To](#how-to)
    - [How to install](#how-to-install)
    - [How to add a modded map to your server](#how-to-add-a-modded-map-to-your-server)
    - [How to install basegame maps data](#how-to-install-basegame-maps-data)
    - [How to set or add a language to your server](#how-to-set-or-add-a-language-to-your-server)
  - [FAQ](#faq)
    - [I cannot spawn a vehicle even after setting myself the server owner. What did I do wrong ?](#i-cannot-spawn-a-vehicle-even-after-setting-myself-the-server-owner-what-did-i-do-wrong-)
    - [I cannot respawn my vehicle, it this broken ?](#i-cannot-respawn-my-vehicle-it-this-broken-)
    - [Why some players can spawn traffic and some don't ? How can I spawn traffic during a scenario ?](#why-some-players-can-spawn-traffic-and-some-dont--how-can-i-spawn-traffic-during-a-scenario-)
    - [My game crashes during the join process or randomly with the following error](#my-game-crashes-during-the-join-process-or-randomly-with-the-following-error)
    - [Can I enable GPS path in races ?](#can-i-enable-gps-path-in-races-)
    - [Can I completely disable the "ghost mode" when somebody respawns ?](#can-i-completely-disable-the-ghost-mode-when-somebody-respawns-)
    - [Shadows are disappearing when I drive fast. What's going on ?](#shadows-are-disappearing-when-i-drive-fast-whats-going-on-)
  - [Compatible Mods](#compatible-mods)
  - [Video tutorials](#video-tutorials)
  - [Participating](#participating)
  - [Bucket list](#bucket-list)
  - [Known issues](#known-issues)
  - [Credits](#credits)

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
- Localized and dynamic chat commands system.

### QoL

- Reworked and toggleable player nametags, showing who is spectating, who is playing, and idle vehicles. Props do not display nametags, and trailers do not if their owner is towing them.
- Reworked in-game chat with Rank or Reputation level indicators.
- Toggleable automatic headlights based on the day-night cycle.
- Toggleable smooth free camera.
- Precise free camera FoV selector.
- Ghost mode to prevent speeding players from crashing into newly spawned players.
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
- Vehicles no longer keep pressed inputs when players switch to another

### Facilities

- Gas Stations and Charging Stations, with independent fuel types.
- Complete station editor for staff.
- Garages to repair vehicles and refill NOS.
- Complete garage editor for staff.
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
- Multiple respawn strategies: All respawn types, no respawn (with a DNF counter), respawn at the last checkpoint and respawn in the pit stand.
- Working pit stands.
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
- Can be launched with a lives amount setting.
- Specific vehicle models can be set at launch for thematic games.
- Multiple arenas per map.
- Complete arena and starting positions editor for admins and selected players.
- Reputation rewards for participation and winning, highly customizable.

#### Tag Duo

- Duo gamemode with public visible lobbies
- Reputation rewards for tagging your opponent, highly customizable.

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

### I cannot spawn a vehicle even after setting myself the server owner. What did I do wrong ?
You should check your `MaxVehicles` inside `ServerConfig.toml` (beammp server root folder), the value cannot be set to `-1` (I recommand you to set it between 50 and 500).

### I cannot respawn my vehicle, it this broken ?
Scenarios have their own rules, here is the complete respawns guide by scenario :
  - `Freeroam` : All respawn are allowed. If the server is configured to have a respawn delay and/or teleport delay, you will have a countdown visible in the main window, before you can do it again.
  - `Races (solo/multi)` : the allowed respawns mode is defined by the player who launched the race. There are multiple mode:
    - All respawns : __RecoverVehicle__, __RecoverVehicleAlt__, __SaveHome__ and __LoadHome__ are allowed, the 3 firsts will respawn you in-place and the last will bring you back to the last checkpoint. Other respawns are teleporting or reloading game physic (provokes a stutter) and are then disabled.
    - No respawns : self explanatory
    - Last checkpoint / Stand : __SaveHome__ and __LoadHome__ respawns wil be enabled and will bring you back to the last checkpoint/stand.
  - `Delivery (solo, package/vehicle)` : All respawn are disabled to keep the scenario fair (you will need to reach a garage to repair your vehicle).
  - `DeliveryTogether` : As opposed to other delivery modes, __RecoverVehicle__ and __RecoverVehicleAlt__ respawns are allowed, but it will cancel your next delivery reward, as mentionned in the main window (you should get to a garage or driving more carefully to keep your streak).
  - `Hunter` : The fugitive cannot respawn if close to any hunter by a customizable distance, 50 meters by default (skills are valued in this mode). Hunters can use __RecoverVehicle__ and __RecoverVehicleAlt__ respawns but will then have a customizable freeze countdown before they can drive again.
  - `Destruction Derby` : Participants have lives, and until they have, thay can use __SaveHome__ and __LoadHome__ respawns (note that if they still have lives and the takedown countdown reached 0, they will automatically get respawned).
  - `Speed` : In this mode, participants cannot respawn, since the mode goal is to stay over a speed limit and to remain the last player alive.

For reference, here is the BeamJoy handled respawns list with default bindings:
- __RecoverVehicle__ (and rewind) : Keyboard `Insert` by default | Controller `Dpad left` by default
- __RecoverVehicleAlt__ : Keyboard `Ctrl + Insert` by default | not assigned by default on Controller
- __LoadHome__ : Keyboard `Home` by default | not assigned by default on Controller

If you are mainly `playing with a controller`, it is recommended to assign these bindings:
- __Recover Vehicle__ : `DPad left`
- __Save Home__ : `DPad left`
- __Load Home__ : `DPad Right`

### Why some players can spawn traffic and some don't ? How can I spawn traffic during a scenario ?

Traffic spawning is dependant on group permissions. Players in groups having a `VehicleCap` attribute set to `-1` (_Infinite_) will automatically have access to traffic toggling, but not anytime.

Here the scenarii list players can toggle traffic in:
- Freeroam
- Vehicle Delivery
- Package Delivery
- Delivery Together
- Bus Mission

### My game crashes during the join process or randomly with the following error

![Image](https://github.com/user-attachments/assets/fc667d0e-45e4-4ee4-ac9e-ec9c7d364c84)

Unfortunately, I have done all I can to address and fix all potential causes of this issue. Some users fixed it by removing their BeamNG version folder in LocalAppData (`%localappdata%\BeamNG.drive\->your_version<-`). If you still experience this issue, please see and join [this ticket](https://github.com/my-name-is-samael/BeamJoy/issues/100).

### Can I enable GPS path in races ?

The GPS route system is fully integrated into the base game, but unfortunately, it fails in one-way roads, prohibited directions, and off-road sections. This often makes the route guidance useless in many parts of a race.

If your race layout isn't intuitive, the best approach is to improve your level design. Keep in mind that at each checkpoint, racers should be able to see the next one (checkpoints are visible high in the sky when there are no buildings obstructing the view). Also, avoid placing checkpoints too far apart in classic races.

### Can I completely disable the "ghost mode" when somebody respawns ?

This is a respawn protection system, and it is a key component of the mod. You can implement it yourself by following the instructions in [this ticket](https://github.com/my-name-is-samael/BeamJoy/issues/58), but please note that I cannot be held responsible if other parts of the mod no longer function as intended.

### Shadows are disappearing when I drive fast. What's going on ?

Strangely, this behavior is linked to the shadow distance setting (`Config` > `Environment` > `Sun` tab > `Shadow Distance` slider).<br/>
If you want to calibrate this setting correctly on your server, I recommend the following steps:
- Choose a fast vehicle configuration (e.g., the vanilla `Civetta Bolide Top Speed`).
- Find a location where you can reach maximum speed.
- Switch to the driver’s first-person camera.
- Increase your field of view to the maximum (holding `Num 3` by default).
- Check whether the shadow distance value works well under these conditions.

## Compatible Mods
- Pretty much all modded vehicles with correctly formed data
- [Enhanced Interior Camera](https://www.beamng.com/resources/enhanced-interior-camera.24952/)
- [Agent's Simplified Realistic Traffic Mod (EU + Yakuza)](https://www.beamng.com/threads/agents-simplified-realistic-traffic-mod-eu-yakuza.102034/)
- [Discord ChatHook](https://github.com/OfficialLambdax/BeamMP-ChatHook) (all BeamJoy events are logged and translated with a configuration)

_Please contact me or open a ticket to request a mod integration_

## Video tutorials

Coming soon (maybe) ...

## Participating

Feel free to create pull requests, as long as you follow the coding scheme.

Also, feel free to report bugs or suggest improvements. I'll do my best to respond quickly, but note that I no longer work full-time on this project.

You can also fix translations if they are wrong :
<ul>
    <li>
        <a href="https://gitlocalize.com/repo/9945/fr?utm_source=badge"> <img src="https://gitlocalize.com/repo/9945/fr/badge.svg" /> </a>
    </li>
    <li>
        <a href="https://gitlocalize.com/repo/9945/de?utm_source=badge"> <img src="https://gitlocalize.com/repo/9945/de/badge.svg" /> </a>
    </li>
    <li>
        <a href="https://gitlocalize.com/repo/9945/it?utm_source=badge"> <img src="https://gitlocalize.com/repo/9945/it/badge.svg" /> </a>
    </li>
    <li>
        <a href="https://gitlocalize.com/repo/9945/es?utm_source=badge"> <img src="https://gitlocalize.com/repo/9945/es/badge.svg" /> </a>
    </li>
    <li>
        <a href="https://gitlocalize.com/repo/9945/pt?utm_source=badge"> <img src="https://gitlocalize.com/repo/9945/pt/badge.svg" /> </a>
    </li>
    <li>
        <a href="https://gitlocalize.com/repo/9945/ru?utm_source=badge"> <img src="https://gitlocalize.com/repo/9945/ru/badge.svg" /> </a>
    </li>
</ul>

## Bucket list

- Race fork (only when the mod will be done and polished)
- Toggleable automatic random weather presets (maybe with smooth transitions, waiting for BeamNG changes about temperature and weather)
- Implementing BeamMP v3.5+ features when it will come out:
  - Add Core configs for AllowGuests ([#335](https://github.com/BeamMP/BeamMP-Server/pull/335))
  - Player limit join bypass by staff ([#372](https://github.com/BeamMP/BeamMP-Server/pull/372))

## Known issues

- Windows system costs performances, this is a fact. Unfortunately, this is the only way BeamJoy have to not be intrusive (we do not want to force players by adding UI-Apps, but still give them mandatory scenario and server informations).
- Having vehicle config with modded parts (which belong to a mod that is not present on the server) is causing impossibility to spawn a vehicle in a scenario with imposed config. We do not have a way to detect this particular case for now.

## Credits

Thanks to all BETA testers who helped me test and debug the features:
dvergar, Trina, Baliverne0, Rodjiii, Lotax, Nath_YT, korrigan_91, and countless others.

A huge thanks to prestonelam2003 for his work on [CobaltEssentials](https://github.com/prestonelam2003/CobaltEssentials) which inspired me to create BeamJoy, although I didn't copy any lines of his code.

Another huge thank to StanleyDudek for his work on [CobaltEssentialsInterface](https://github.com/StanleyDudek/CobaltEssentialsInterface) which taught me how to create front-end BeamMP mods, communicate with the server, and the basic use of imgui.
