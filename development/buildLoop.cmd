@echo off
:: fix missing 7zip path link
set PATH=%PATH%;C:\Program Files\7-Zip\

:: infinite reboot and build loop
:while
cls

:: remove server mod
del /s /q ..\Resources\Server\BeamJoyCore\* >nul 2>&1
rmdir /s /q ..\Resources\Server\BeamJoyCore\
mkdir ..\Resources\Server\BeamJoyCore
del /s /q ..\Resources\Server\BeamJoyChatHandler\* >nul 2>&1
rmdir /s /q ..\Resources\Server\BeamJoyChatHandler\
mkdir ..\Resources\Server\BeamJoyChatHandler
:: copy server mod
xcopy .\BeamJoyCore\* ..\Resources\Server\BeamJoyCore\ /s /e >nul 2>&1
xcopy .\BeamJoyChatHandler\* ..\Resources\Server\BeamJoyChatHandler\ /s /e >nul 2>&1
echo [1;92mServer mods processed[0m

:: remove builded client mod
del /q .\dist\BJI.zip
:: remove cached client mod
del /q %appdata%\BeamMP-Launcher\Resources\BJI.zip
:: build client mod
7z a -y .\dist\BJI.zip .\BeamJoyInterface\* >nul 2>&1
:: remove client mod
del /q ..\Resources\Client\BJI.zip
:: copy client mods
copy /y .\dist\BJI.zip ..\Resources\Client\BJI.zip >nul 2>&1
echo [1;92mClient mods processed[0m

:: start server
cd ..\
echo [1;95mStarting server...[0m
.\BeamMP-Server.exe

:: infinite reboot and build loop
cd .\workspace
goto :while
:: Keep Ctrl+C combination after entering "exit" to stop the loop
