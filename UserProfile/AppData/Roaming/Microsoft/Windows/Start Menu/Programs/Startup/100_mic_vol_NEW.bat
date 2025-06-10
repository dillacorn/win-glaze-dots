@echo off
setlocal enabledelayedexpansion

:: === Locate NirCmd ===
for %%P in (nircmdc.exe) do set "NIRCMD=%%~$PATH:P"

if not defined NIRCMD if exist "%USERPROFILE%\scoop\apps\nircmd\current\nircmdc.exe" (
    set "NIRCMD=%USERPROFILE%\scoop\apps\nircmd\current\nircmdc.exe"
)

if not defined NIRCMD if exist "%ProgramFiles%\NirSoft\nircmdc.exe" (
    set "NIRCMD=%ProgramFiles%\NirSoft\nircmdc.exe"
)

if not defined NIRCMD if exist "%ProgramFiles(x86)%\NirSoft\nircmdc.exe" (
    set "NIRCMD=%ProgramFiles(x86)%\NirSoft\nircmdc.exe"
)

if not defined NIRCMD (
    echo Error: NirCmd not found. Please install NirCmd.
    pause
    exit /b 1
)

:: === Start minimized loop to keep mic at 100% ===
start /min "" cmd /c ^
    "title Force 100%% Mic Volume & ^
    :loop & ^
    %NIRCMD% setsysvolume 65535 default_record & ^
    timeout /t 2 /nobreak >nul & ^
    goto loop"