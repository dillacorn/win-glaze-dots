@echo off
:: Define variables
set repoURL=https://github.com/dillacorn/win-glaze-dots
set repoPath=%UserProfile%\win-glaze-dots
set userProfile=%UserProfile%
set appDataRoaming=%AppData%
set scoopPath=%UserProfile%\scoop\apps

:: Force clone the repository
if exist "%repoPath%" (
    echo Removing existing repository...
    rmdir /S /Q "%repoPath%"
)
echo Cloning repository from %repoURL%...
git clone %repoURL% "%repoPath%"

:: Copy .glzr folder
xcopy "%repoPath%\UserProfile\.glzr" "%userProfile%\.glzr" /E /I /Y

:: Copy scripts folder
xcopy "%repoPath%\UserProfile\scripts" "%userProfile%\scripts" /E /I /Y

:: Copy alacritty configuration
xcopy "%repoPath%\AppData\Roaming\alacritty" "%appDataRoaming%\alacritty" /E /I /Y

:: Copy flameshot configuration
xcopy "%repoPath%\AppData\Roaming\flameshot" "%appDataRoaming%\flameshot" /E /I /Y

:: Copy altsnap configuration
xcopy "%repoPath%\scoop\apps\altsnap\1.64\AltSnap.ini" "%scoopPath%\altsnap\1.64\AltSnap.ini" /Y

:: Copy btop configuration
xcopy "%repoPath%\scoop\apps\btop\1.0.4\btop.conf" "%scoopPath%\btop\1.0.4\btop.conf" /Y

:: Done
echo All files have been cloned and copied successfully!
pause
