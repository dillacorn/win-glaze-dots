@echo off
setlocal EnableExtensions

:: =========================
:: Settings
:: =========================
set "repoURL=https://github.com/dillacorn/win-glaze-dots"
set "repoPath=%UserProfile%\win-glaze-dots"
set "userProfile=%UserProfile%"
set "appDataRoaming=%AppData%"

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
:: Copy: %APPDATA%\alacritty
:: =========================
echo Copying alacritty config...
if not exist "%appDataRoaming%\alacritty" mkdir "%appDataRoaming%\alacritty"
xcopy "%repoPath%\UserProfile\AppData\Roaming\alacritty" "%appDataRoaming%\alacritty" /E /I /Y

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
pause
