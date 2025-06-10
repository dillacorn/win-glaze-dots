@echo off
setlocal enableextensions

:: ====== Find NirCmd ======
set "NIRCMD="
where nircmdc.exe >nul 2>&1 && set "NIRCMD=nircmdc.exe"
if not defined NIRCMD (
    for %%D in (
        "%USERPROFILE%\scoop\apps\nircmd\current\nircmdc.exe"
        "%ProgramFiles%\NirSoft\nircmdc.exe"
        "%ProgramFiles(x86)%\NirSoft\nircmdc.exe"
    ) do if not defined NIRCMD if exist "%%~D" set "NIRCMD=%%~D"
)

:: ====== Error if NirCmd missing ======
if not defined NIRCMD (
    echo NirCmd not found. Install it from https://www.nirsoft.net/utils/nircmd.html
    pause
    exit /b 1
)

:: ====== Only allow one instance ======
tasklist /fi "windowtitle eq MicVol100" | find "cmd.exe" >nul && exit /b 0

:: ====== Main Loop (Persistent) ======
start "MicVol100" /min cmd /k "title MicVol100 & echo [Running] Mic volume locked at 100%% & for /l %%i in () do ("%NIRCMD%" setsysvolume 65535 default_record & ping -n 10 127.0.0.1 >nul)"
