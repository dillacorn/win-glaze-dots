@echo off
setlocal enableextensions

:: ====== Find NirCmd (supports both nircmd.exe and nircmdc.exe) ======
set "NIRCMD="
where nircmd.exe >nul 2>&1 && set "NIRCMD=nircmd.exe"
where nircmdc.exe >nul 2>&1 && set "NIRCMD=nircmdc.exe"
if not defined NIRCMD (
    for %%D in (
        "%ProgramFiles%\NirSoft\nircmd.exe"
        "%ProgramFiles%\NirSoft\nircmdc.exe"
        "%ProgramFiles(x86)%\NirSoft\nircmd.exe"
        "%ProgramFiles(x86)%\NirSoft\nircmdc.exe"
        "%USERPROFILE%\scoop\apps\nircmd\current\nircmd.exe"
        "%USERPROFILE%\scoop\apps\nircmd\current\nircmdc.exe"
    ) do if not defined NIRCMD if exist "%%~D" set "NIRCMD=%%~D"
)

:: ====== Error if NirCmd missing ======
if not defined NIRCMD (
    echo NirCmd not found. Install it from https://www.nirsoft.net/utils/nircmd.html
    echo.
    echo You can install it automatically via:
    echo scoop install nircmd
    pause
    exit /b 1
)

:: Check for existing instance by window title (more reliable)
tasklist /fi "windowtitle eq MicVol100*" 2>nul | find /i "cmd.exe" >nul && exit /b 0

:: Main loop with proper escaping
start "MicVol100" /min cmd /c "title MicVol100 & echo [Running] Mic volume locked at 100%% & for /l %%i in () do (call "%NIRCMD%" setsysvolume 65535 default_record & ping -n 10 127.0.0.1 >nul)"
