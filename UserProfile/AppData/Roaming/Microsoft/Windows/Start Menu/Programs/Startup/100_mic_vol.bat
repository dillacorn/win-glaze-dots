@echo off
setlocal enabledelayedexpansion

:: Try finding NirCmd in PATH
for %%P in (nircmdc.exe) do set "NIRCMD=%%~$PATH:P"

:: If not found, check common Scoop install path
if not defined NIRCMD if exist "%USERPROFILE%\scoop\apps\nircmd\current\nircmdc.exe" set "NIRCMD=%USERPROFILE%\scoop\apps\nircmd\current\nircmdc.exe"

:: If still not found, check common manual install locations
if not defined NIRCMD if exist "%ProgramFiles%\NirSoft\nircmdc.exe" set "NIRCMD=%ProgramFiles%\NirSoft\nircmdc.exe"
if not defined NIRCMD if exist "%ProgramFiles(x86)%\NirSoft\nircmdc.exe" set "NIRCMD=%ProgramFiles(x86)%\NirSoft\nircmdc.exe"

:: If NirCmd is still not found, exit with error
if not defined NIRCMD (
    echo Error: Could not find nircmdc.exe. Please install NirCmd and add it to your PATH.
    exit /b 1
)

:: Start loop to force 100% mic volume
start /min "" cmd /c "title Force 100%% Mic Vol && %NIRCMD% loop 172800 100 setsysvolume 65535 default_record && exit"
