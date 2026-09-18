@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "DIR=%~1"
set "STEP=2"

if /I not "%DIR%"=="left" if /I not "%DIR%"=="right" if /I not "%DIR%"=="up" if /I not "%DIR%"=="down" exit /b 2

where glazewm.exe >nul 2>&1 || exit /b 1
where jq.exe >nul 2>&1 || exit /b 1

for /f "tokens=1-6" %%A in ('glazewm.exe query focused 2^>nul ^| jq.exe -r ".data.focused ^| [.id,.x,.y,.width,.height,.state.type] ^| @tsv"') do (
    set "FID=%%A"
    set "FX=%%B"
    set "FY=%%C"
    set "FW=%%D"
    set "FH=%%E"
    set "FSTATE=%%F"
)

if not defined FID exit /b 0

if /I not "%FSTATE%"=="tiling" goto :simple

set /a FR=FX+FW
set /a FB=FY+FH

set "WINDOW_TYPE=window"
set "TILING_TYPE=tiling"

set "HAS_NEIGHBOR=0"

if /I "%DIR%"=="left" (
    glazewm.exe query workspaces 2>nul | jq.exe -e "any(.data.workspaces[] ^| select(.hasFocus == true) ^| .. ^| objects ^| select(.type? == env.WINDOW_TYPE and .id != env.FID and .state.type == env.TILING_TYPE); ((.x + .width) <= (env.FX ^| tonumber)) and (.y < (env.FB ^| tonumber)) and ((.y + .height) > (env.FY ^| tonumber)))" >nul
    if not errorlevel 1 set "HAS_NEIGHBOR=1"
)

if /I "%DIR%"=="right" (
    glazewm.exe query workspaces 2>nul | jq.exe -e "any(.data.workspaces[] ^| select(.hasFocus == true) ^| .. ^| objects ^| select(.type? == env.WINDOW_TYPE and .id != env.FID and .state.type == env.TILING_TYPE); (.x >= (env.FR ^| tonumber)) and (.y < (env.FB ^| tonumber)) and ((.y + .height) > (env.FY ^| tonumber)))" >nul
    if not errorlevel 1 set "HAS_NEIGHBOR=1"
)

if /I "%DIR%"=="up" (
    glazewm.exe query workspaces 2>nul | jq.exe -e "any(.data.workspaces[] ^| select(.hasFocus == true) ^| .. ^| objects ^| select(.type? == env.WINDOW_TYPE and .id != env.FID and .state.type == env.TILING_TYPE); ((.y + .height) <= (env.FY ^| tonumber)) and (.x < (env.FR ^| tonumber)) and ((.x + .width) > (env.FX ^| tonumber)))" >nul
    if not errorlevel 1 set "HAS_NEIGHBOR=1"
)

if /I "%DIR%"=="down" (
    glazewm.exe query workspaces 2>nul | jq.exe -e "any(.data.workspaces[] ^| select(.hasFocus == true) ^| .. ^| objects ^| select(.type? == env.WINDOW_TYPE and .id != env.FID and .state.type == env.TILING_TYPE); (.y >= (env.FB ^| tonumber)) and (.x < (env.FR ^| tonumber)) and ((.x + .width) > (env.FX ^| tonumber)))" >nul
    if not errorlevel 1 set "HAS_NEIGHBOR=1"
)

if "%HAS_NEIGHBOR%"=="1" (
    set "DELTA=+%STEP%%%"
) else (
    set "DELTA=-%STEP%%%"
)

if /I "%DIR%"=="left"  glazewm.exe command resize --width  "%DELTA%" >nul 2>&1
if /I "%DIR%"=="right" glazewm.exe command resize --width  "%DELTA%" >nul 2>&1
if /I "%DIR%"=="up"    glazewm.exe command resize --height "%DELTA%" >nul 2>&1
if /I "%DIR%"=="down"  glazewm.exe command resize --height "%DELTA%" >nul 2>&1
exit /b 0

:simple
if /I "%DIR%"=="left"  glazewm.exe command resize --width  -%STEP%%% >nul 2>&1
if /I "%DIR%"=="right" glazewm.exe command resize --width  +%STEP%%% >nul 2>&1
if /I "%DIR%"=="up"    glazewm.exe command resize --height -%STEP%%% >nul 2>&1
if /I "%DIR%"=="down"  glazewm.exe command resize --height +%STEP%%% >nul 2>&1
exit /b 0
