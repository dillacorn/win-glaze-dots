@echo off
setlocal enableextensions

:: ====== Find NirCmd ======
set "NIRCMD="

:: First try standard locations
where nircmd.exe >nul 2>&1 && set "NIRCMD=nircmd.exe"
where nircmdc.exe >nul 2>&1 && set "NIRCMD=nircmdc.exe"

:: Fallback to checking common install folders
if not defined NIRCMD (
    for %%D in (
        "%ProgramFiles%\NirSoft\nircmd.exe"
        "%ProgramFiles%\NirSoft\nircmdc.exe"
        "%ProgramFiles(x86)%\NirSoft\nircmd.exe"
        "%ProgramFiles(x86)%\NirSoft\nircmdc.exe"
    ) do if not defined NIRCMD if exist "%%~D" set "NIRCMD=%%~D"
)

:: ====== Error if missing ======
if not defined NIRCMD (
    echo NirCmd not found. You need to:
    echo 1. Download from https://www.nirsoft.net/utils/nircmd.html
    echo 2. Extract to C:\Program Files\NirSoft\
    pause
    exit /b 1
)

:: ====== Single Instance Check ======
tasklist /fi "windowtitle eq MicVol100*" 2>nul | find /i "cmd.exe" >nul && exit /b 0

:: ====== Main Volume Loop ======
start "MicVol100" /min cmd /c "title MicVol100 & echo [Running] Mic volume locked at 100%% & for /l %%i in () do ("%NIRCMD%" setsysvolume 65535 default_record & ping -n 10 127.0.0.1 >nul)"
