@echo off
setlocal enabledelayedexpansion

:: -----------------------------
:: Check for RBTray executable
:: -----------------------------
set "RBTRAY="

:: Check Scoop install location
if exist "%USERPROFILE%\scoop\apps\rbtray\current\RBTray.exe" (
    set "RBTRAY=%USERPROFILE%\scoop\apps\rbtray\current\RBTray.exe"
)

:: Check common manual install paths
if not defined RBTRAY if exist "%ProgramFiles%\RBTray\RBTray.exe" (
    set "RBTRAY=%ProgramFiles%\RBTray\RBTray.exe"
)
if not defined RBTRAY if exist "%ProgramFiles(x86)%\RBTray\RBTray.exe" (
    set "RBTRAY=%ProgramFiles(x86)%\RBTray\RBTray.exe"
)

:: If RBTray is found, relaunch this script minimized via RBTray
if defined RBTRAY (
    echo Launching with RBTray...
    start "" "%RBTRAY%" "%~f0"
    exit /b
)

:: -----------------------------
:: NirCmd resolution
:: -----------------------------
:: Try finding NirCmd in PATH
for %%P in (nircmdc.exe) do set "NIRCMD=%%~$PATH:P"

:: If not found, check common Scoop install path
if not defined NIRCMD if exist "%USERPROFILE%\scoop\apps\nircmd\current\nircmdc.exe" (
    set "NIRCMD=%USERPROFILE%\scoop\apps\nircmd\current\nircmdc.exe"
)

:: If still not found, check common manual install locations
if not defined NIRCMD if exist "%ProgramFiles%\NirSoft\nircmdc.exe" (
    set "NIRCMD=%ProgramFiles%\NirSoft\nircmdc.exe"
)
if not defined NIRCMD if exist "%ProgramFiles(x86)%\NirSoft\nircmdc.exe" (
    set "NIRCMD=%ProgramFiles(x86)%\NirSoft\nircmdc.exe"
)

:: -----------------------------
:: NirCmd not found — notify user
:: -----------------------------
if not defined NIRCMD (
    echo Error: Could not find nircmdc.exe. Please install NirCmd.
    if exist "%ProgramFiles%\NirSoft\nircmdc.exe" (
        "%ProgramFiles%\NirSoft\nircmdc.exe" infobox "NirCmd is not installed. Please install NirCmd and add it to your PATH." "Error" 0x10
    )
    pause
    exit /b 1
)

:: -----------------------------
:: Launch volume loop silently
:: -----------------------------
start /min "" cmd /c "title Force 100%% Mic Vol && %NIRCMD% loop 172800 100 setsysvolume 65535 default_record && exit"
