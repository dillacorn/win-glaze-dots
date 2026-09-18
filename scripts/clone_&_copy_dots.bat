@echo off
setlocal EnableExtensions

:: =========================
:: Settings
:: =========================
set "repoURL=https://github.com/dillacorn/win-glaze-dots"
set "repoPath=%UserProfile%\win-glaze-dots"
set "userProfile=%UserProfile%"
set "appDataRoaming=%AppData%"
set "localAppData=%LocalAppData%"

:: =========================
:: Fresh clone of the repo
:: =========================
if exist "%repoPath%" (
    echo Removing existing repository...
    rmdir /S /Q "%repoPath%"
)
echo Cloning repository from %repoURL%...
git clone "%repoURL%" "%repoPath%" || (
    echo ERROR: git clone failed.
    exit /b 1
)

:: =========================
:: Copy: ~/.glzr
:: =========================
echo Copying .glzr...
if not exist "%userProfile%\.glzr" mkdir "%userProfile%\.glzr"
xcopy "%repoPath%\UserProfile\.glzr" "%userProfile%\.glzr" /E /I /Y

:: =========================
:: Copy: ~/scripts
:: =========================
echo Copying scripts...
if not exist "%userProfile%\scripts" mkdir "%userProfile%\scripts"
xcopy "%repoPath%\UserProfile\scripts" "%userProfile%\scripts" /E /I /Y

:: =========================
:: Copy: Windows Terminal settings
:: =========================
echo Copying Windows Terminal settings...
set "terminalSource=%repoPath%\UserProfile\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
set "terminalTarget=%localAppData%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
if not exist "%terminalTarget%" mkdir "%terminalTarget%"
if exist "%terminalSource%" (
    copy /Y "%terminalSource%" "%terminalTarget%\settings.json" >nul
) else (
    echo WARNING: Windows Terminal settings.json not found in repo.
)

:: =========================
:: Copy: %APPDATA%\yazi
:: =========================
echo Copying Yazi config...
if not exist "%appDataRoaming%\yazi" mkdir "%appDataRoaming%\yazi"
xcopy "%repoPath%\UserProfile\AppData\Roaming\yazi" "%appDataRoaming%\yazi" /E /I /Y

where ya >nul 2>&1
if errorlevel 1 (
    echo WARNING: Yazi package helper ya was not found. Run "ya pkg install" after installing Yazi.
) else (
    echo Installing Yazi plugins...
    ya pkg install || echo WARNING: Could not install Yazi plugins automatically. Run "ya pkg install" manually.
)

:: Yazi uses Git for Windows' file.exe for MIME detection.
set "gitFile=%ProgramFiles%\Git\usr\bin\file.exe"
if exist "%gitFile%" (
    echo Setting YAZI_FILE_ONE=%gitFile%
    setx YAZI_FILE_ONE "%gitFile%" >nul
) else if exist "%userProfile%\scoop\apps\git\current\usr\bin\file.exe" (
    echo Setting YAZI_FILE_ONE=%userProfile%\scoop\apps\git\current\usr\bin\file.exe
    setx YAZI_FILE_ONE "%userProfile%\scoop\apps\git\current\usr\bin\file.exe" >nul
) else (
    echo WARNING: Git file.exe not found. Yazi MIME detection may be incomplete.
)

:: =========================
:: Copy: %APPDATA%\flameshot
:: =========================
echo Copying flameshot config...
if not exist "%appDataRoaming%\flameshot" mkdir "%appDataRoaming%\flameshot"
xcopy "%repoPath%\UserProfile\AppData\Roaming\flameshot" "%appDataRoaming%\flameshot" /E /I /Y

:: =========================
:: Copy: AltSnap.ini -> %APPDATA%\AltSnap
:: =========================
echo Copying AltSnap.ini...
if not exist "%appDataRoaming%\AltSnap" mkdir "%appDataRoaming%\AltSnap"
if exist "%repoPath%\UserProfile\AppData\Roaming\AltSnap\AltSnap.ini" (
    xcopy "%repoPath%\UserProfile\AppData\Roaming\AltSnap\AltSnap.ini" "%appDataRoaming%\AltSnap\AltSnap.ini" /Y
) else (
    echo WARNING: Source AltSnap.ini not found in repo.
)

:: =========================
:: Ensure ~/.config exists
:: =========================
if not exist "%userProfile%\.config" mkdir "%userProfile%\.config"

:: =========================
:: Copy: btop -> %USERPROFILE%\.config\btop
:: =========================
echo Copying btop config...
if not exist "%userProfile%\.config\btop" mkdir "%userProfile%\.config\btop"
xcopy "%repoPath%\UserProfile\.config\btop" "%userProfile%\.config\btop" /E /I /Y

:: =========================
:: Copy: yasb -> %USERPROFILE%\.config\yasb
:: Includes: config.yaml and styles.css
:: =========================
echo Copying yasb config...
if not exist "%userProfile%\.config\yasb" mkdir "%userProfile%\.config\yasb"
xcopy "%repoPath%\UserProfile\.config\yasb" "%userProfile%\.config\yasb" /E /I /Y

:: =========================
:: Done
:: =========================
echo All files have been cloned and copied successfully!
echo Restart terminals or sign out/reboot so new user environment variables are inherited.
pause
