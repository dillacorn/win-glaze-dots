@echo off
:: Check for admin privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo This script needs to be run as an administrator. Please re-run with elevated privileges.
    pause
    exit /b
)

:: Disable Fullscreen Optimizations Globally
reg add "HKCU\System\GameConfigStore" /v GameDVR_FSEBehaviorMode /t REG_DWORD /d 2 /f
reg add "HKCU\System\GameConfigStore" /v GameDVR_HonorUserFSEBehaviorMode /t REG_DWORD /d 1 /f

:: Notify the user
echo Fullscreen optimizations disabled globally. Please restart your PC for the changes to take effect.
pause
