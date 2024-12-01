# How to build the mod
## Manual Steps
To compile the mod:
- Zip the contents of the `BeamJoyInterface` folder.
- Move the created archive to the `Resources/Client/` folder on your server.
- Copy the BeamJoyCore folder to the `Resources/Server/` folder.

Notes:
- I recommend using 7-Zip for archiving, as the default Windows zipping command can cause issues with the archive, potentially breaking the mod.

## Automatic builder
You can use my personal builder script, `buildLoop.cmd`. This script is designed for use with *Windows 11* and *PowerShell* but can be adapted for your preferred OS or shell environment.

### What it does:
Continuously builds the mod and starts the server in a loop until manually stopped.

### How to stop:
Enter the `exit` command in the terminal and then hold *Ctrl+C* to break the loop.

### Example Folder Structure
If you want to use my builder, your folder structure should look something like this:
```
┌─ Resources
│  ├─ Client
│  │  └─ ...
│  ├─ Server
│  │  └─ ...
│  └─ my_modded_map.zip
├─ workspace // actual parent folder of the repo
│  ├─ BeamJoyCore
│  │  └─ ...
│  ├─ BeamJoyInterface
│  │  └─ ...
│  └─ buildLoop.cmd
├─ BeamMP-Server.exe
└─ ServerConfig.toml
```