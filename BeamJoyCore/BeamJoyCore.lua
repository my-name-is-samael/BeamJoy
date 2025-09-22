--[[
BeamJoy for BeamMP
Copyright (C) 2024-2025 TontonSamael

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

Contact : https://github.com/my-name-is-samael
]]

BJCVERSION = "2.0.6"

BJCPluginPath = debug.getinfo(1).source:gsub("\\", "/")
BJCPluginPath = BJCPluginPath:sub(1, (BJCPluginPath:find("BeamJoyCore.lua")) - 2)

require("utils/LUA") ---@diagnostic disable-line
require("utils/Server")
require("utils/MATH")
require("utils/String")
require("utils/Table")
SHA = require("utils/SHA")
JSON = require("utils/JSON")
TOML = require("utils/TOML")

require("utils/Constants")
require("utils/Common")

SetLogType("BJC", CONSOLE_COLORS.FOREGROUNDS.LIGHT_BLUE)

local function printLogo()
    -- https://patorjk.com/software/taag/#p=display&f=Big%20Money-se&t=BeamJoy
    print([[

 _______                                        _____
|       \                                      |     \
| $$$$$$$\  ______    ______   ______ ____      \$$$$$  ______   __    __
| $$__/ $$ /      \  |      \ |      \    \       | $$ /      \ |  \  |  \
| $$    $$|  $$$$$$\  \$$$$$$\| $$$$$$\$$$$\ __   | $$|  $$$$$$\| $$  | $$
| $$$$$$$\| $$    $$ /      $$| $$ | $$ | $$|  \  | $$| $$  | $$| $$  | $$
| $$__/ $$| $$$$$$$$|  $$$$$$$| $$ | $$ | $$| $$__| $$| $$__/ $$| $$__/ $$
| $$    $$ \$$     \ \$$    $$| $$ | $$ | $$ \$$    $$ \$$    $$ \$$    $$
 \$$$$$$$   \$$$$$$$  \$$$$$$$ \$$  \$$  \$$  \$$$$$$   \$$$$$$  _\$$$$$$$
                                                                |  \__| $$
                                                                 \$$    $$
                                                                  \$$$$$$]])
end

local function loadBeamJoy()
    Log(string.var("Loading BeamJoyCore v{1} ...", { BJCVERSION }), "BJC")
    printLogo()

    BJCEvents = require("managers/EventsManager")

    BJCAsync = require("managers/AsyncManager")
    BJCDefaults = require("managers/Defaults")
    BJCDao = require("dao/DaoFile")
    BJCCore = require("managers/CoreManager")
    BJCCache = require("managers/CacheManager")
    BJCVehicles = require("managers/VehiclesManager")
    BJCConfig = require("managers/ConfigManager")
    BJCLang = require("managers/LangManager")
    BJCGroups = require("managers/GroupsManager")
    BJCPlayers = require("managers/PlayerManager")
    BJCPerm = require("managers/PermissionsManager")
    BJCMaps = require("managers/MapsManager")
    BJCCommand = require("managers/CommandManager")
    BJCVote = require("managers/VotesManager")
    require("tx/Tx") ---[[BJCTx]]
    BJCEnvironment = require("managers/EnvironmentManager")
    BJCChatCommand = require("managers/ChatCommandManager")
    BJCChat = require("managers/ChatManager")

    BJCScenarioData = require("managers/ScenarioDataManager")
    BJCScenario = require("scenarii/ScenarioManager")
    BJCTournament = require("managers/TournamentManager")

    require("rx/Rx")

    if BJCCore.Data.Debug then
        -- TESTS
        if not pcall(function()
                for _, filename in pairs(FS.ListFiles(BJCPluginPath .. "/tests")) do
                    if filename:find(".lua") and not filename:find("CommonTests") then
                        require("tests/" .. filename:gsub(".lua", ""))
                    end
                end
            end) then
            BJCEvents.shutdown()
            return
        end
    end

    Log(string.var("BeamJoyCore v{1} loaded !", { BJCVERSION }), "BJC")
    Log(BJCLang.getConsoleMessage("common.startMessage"))
end

function _G.onInit() ---@diagnostic disable-line
    local ok, err = pcall(loadBeamJoy)
    if not ok then
        LogError(string.var("BeamJoyCore failed to load: {1}", { err }))
    end
end
