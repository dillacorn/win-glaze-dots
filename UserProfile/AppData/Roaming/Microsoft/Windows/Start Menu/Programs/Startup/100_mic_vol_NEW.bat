@echo off
setlocal enableextensions

:: ====== Efficient NirCmd Detection ======
set "NIRCMD="
where nircmdc.exe >nul 2>&1 && set "NIRCMD=nircmdc.exe"
if not defined NIRCMD (
    for %%D in (
        "%USERPROFILE%\scoop\apps\nircmd\current\nircmdc.exe"
        "%ProgramFiles%\NirSoft\nircmdc.exe"
        "%ProgramFiles(x86)%\NirSoft\nircmdc.exe"
    ) do if not defined NIRCMD if exist "%%~D" set "NIRCMD=%%~D"
)

:: ====== Silent Error Handling ======
if not defined NIRCMD (
    echo NirCmd not found >con:
    pause >nul
    exit /b 1
)

:: ====== Single Instance Check ======
2>nul tasklist /fi "windowtitle eq MicVol100" | find "cmd.exe" >nul && exit /b 0

:: ====== Lightweight Main Process ======
start "MicVol100" /min cmd /c ^
"title MicVol100 && :loop && %NIRCMD% setsysvolume 65535 default_record >nul && ping -n 3 127.0.0.1 >nul && goto loop"