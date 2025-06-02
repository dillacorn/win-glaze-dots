@echo off
setlocal enabledelayedexpansion

:: =============================================
:: Configuration - Easy to modify settings
:: =============================================
set "LOOP_INTERVAL_MS=100"          :: Check interval (100-5000 ms recommended)
set "MAX_RUNTIME_HOURS=24"          :: 0 = infinite runtime
set "TARGET_VOLUME=65535"           :: 65535 = 100% volume (0-65535 range)
set "WINDOW_TITLE=MicVolKeeper"     :: Window title for identification
set "SHOW_STATUS_UPDATES=true"      :: false to suppress routine status messages

:: =============================================
:: Initialization
:: =============================================
title %WINDOW_TITLE%
set "RESTARTED_WITH_RBTRAY=false"
set "VERSION=2.1"
set "LAST_ERROR="

:: Check admin privileges (NirCmd often needs them)
NET SESSION >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo WARNING: Not running as administrator. Volume control may fail.
    set "ADMIN_MODE=false"
) else (
    set "ADMIN_MODE=true"
)

:: Improved RBTray detection
for /f "tokens=2 delims=()" %%A in ('tasklist /v /fi "imagename eq RBTray.exe" /fo list ^| find "Window Title:"') do (
    if "%%A"=="%~nx0" set "RESTARTED_WITH_RBTRAY=true"
)

:: Attempt RBTray relaunch if not already under it
if not "%RESTARTED_WITH_RBTRAY%"=="true" (
    :: Check multiple possible RBTray locations
    for %%I in (
        "%USERPROFILE%\scoop\apps\rbtray\current\RBTray.exe",
        "%ProgramFiles%\RBTray\RBTray.exe",
        "%ProgramFiles(x86)%\RBTray\RBTray.exe",
        "%LOCALAPPDATA%\Programs\RBTray\RBTray.exe"
    ) do if not defined RBTRAY if exist "%%I" set "RBTRAY=%%I"

    if defined RBTRAY (
        echo [%TIME%] Launching with RBTray...
        start "" "%RBTRAY%" "%~f0"
        exit /b
    )
)

:: =============================================
:: NirCmd Location Detection
:: =============================================
set "NIRCMD="

:: Search order: PATH, Scoop, Program Files, Downloads
for %%P in (nircmdc.exe) do set "NIRCMD=%%~$PATH:P"
if not defined NIRCMD (
    for %%I in (
        "%USERPROFILE%\scoop\apps\nircmd\current\nircmdc.exe",
        "%ProgramFiles%\NirSoft\nircmdc.exe",
        "%ProgramFiles(x86)%\NirSoft\nircmdc.exe",
        "%USERPROFILE%\Downloads\nircmd\nircmdc.exe"
    ) do if not defined NIRCMD if exist "%%I" set "NIRCMD=%%I"
)

if not defined NIRCMD (
    echo ERROR: NirCmd not found in any standard locations.
    echo.
    echo Please install NirCmd from:
    echo   https://www.nirsoft.net/utils/nircmd.html
    echo.
    echo Recommended installation options:
    echo 1. Extract to "%%ProgramFiles%%\NirSoft"
    echo 2. OR install via Scoop: "scoop install nircmd"
    echo 3. Add installation directory to your PATH
    echo.
    pause
    exit /b 1
)

:: Verify NirCmd works
"%NIRCMD%" setsysvolume 65535 default_record >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: NirCmd failed to execute properly.
    if "%ADMIN_MODE%"=="false" (
        echo This may require administrator privileges.
    )
    echo.
    pause
    exit /b 1
)

:: =============================================
:: Main Execution
:: =============================================
cls
echo ===============================================
echo  Mic Volume Keeper v%VERSION% - Target: %TARGET_VOLUME%
echo ===============================================
echo.
echo Configuration:
echo   Check Interval : %LOOP_INTERVAL_MS% ms
echo   Max Runtime    : %MAX_RUNTIME_HOURS% hours
echo   Admin Mode     : %ADMIN_MODE%
echo   NirCmd Path    : %NIRCMD%
echo.
echo Press Ctrl+C to exit at any time
echo.

:: Calculate max runtime in seconds
set /a "MAX_RUNTIME_SEC=%MAX_RUNTIME_HOURS% * 3600"
if %MAX_RUNTIME_SEC% equ 0 set "MAX_RUNTIME_SEC=2147483647" :: Max 32-bit signed int

:: Get precise start time
for /f "tokens=2 delims==" %%A in ('wmic os get localdatetime /value') do (
    set "START_TIME=%%A"
    set "START_TIME=!START_TIME:~0,14!"
)

:: Create unique session ID
set "SESSION_ID=%DATE:~-4%%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%-%RANDOM%"
set "SESSION_ID=%SESSION_ID: =0%"

echo [%TIME%] Session Started (ID: %SESSION_ID%)
if "%ADMIN_MODE%"=="false" (
    echo [%TIME%] WARNING: Running without admin privileges - volume control may fail
)
echo.

set /a "ITERATIONS=0, FAILURES=0, CONSECUTIVE_FAILURES=0"
set "LAST_STATUS="
set "EXIT_REQUESTED=false"

:: Main control loop
:LOOP
    :: Check for exit conditions
    if %CONSECUTIVE_FAILURES% geq 10 (
        echo [%TIME%] ERROR: 10 consecutive failures - exiting
        set "EXIT_REQUESTED=true"
    )
    
    :: Calculate elapsed time
    for /f "tokens=2 delims==" %%A in ('wmic os get localdatetime /value') do (
        set "CURRENT_TIME=%%A"
        set "CURRENT_TIME=!CURRENT_TIME:~0,14!"
    )
    call :ELAPSED %START_TIME% %CURRENT_TIME% ELAPSED_SEC
    
    if %ELAPSED_SEC% geq %MAX_RUNTIME_SEC% (
        echo [%TIME%] Maximum runtime reached - exiting
        set "EXIT_REQUESTED=true"
    )
    
    if "%EXIT_REQUESTED%"=="true" goto :EXIT

    :: Set volume and check result
    "%NIRCMD%" setsysvolume %TARGET_VOLUME% default_record >nul 2>&1
    if !ERRORLEVEL! equ 0 (
        set "STATUS=OK"
        set /a "ITERATIONS+=1, CONSECUTIVE_FAILURES=0"
    ) else (
        set "STATUS=FAIL"
        set /a "FAILURES+=1, CONSECUTIVE_FAILURES+=1"
        set "LAST_ERROR=!TIME!"
    )

    :: Display status changes if enabled
    if "%SHOW_STATUS_UPDATES%"=="true" if not "!STATUS!"=="!LAST_STATUS!" (
        if "!STATUS!"=="FAIL" (
            echo [%TIME%] WARNING: Failed to set volume (Total: !FAILURES!)
        ) else (
            echo [%TIME%] Volume maintained (Iteration: !ITERATIONS!)
        )
    )
    set "LAST_STATUS=!STATUS!"

    :: Efficient sleep using ping
    ping -n 1 -w %LOOP_INTERVAL_MS% 127.0.0.1 >nul
goto LOOP

:EXIT
echo.
echo [%TIME%] Session Complete
echo   Runtime      : %ELAPSED_SEC% seconds
echo   Iterations   : %ITERATIONS%
echo   Failures     : %FAILURES%
if defined LAST_ERROR echo   Last Error   : %LAST_ERROR%
echo.
pause
exit /b %ERRORLEVEL%

:: =============================================
:: Helper Functions
:: =============================================
:ELAPSED <Start> <End> <ResultVar>
setlocal
set "start=%~1"
set "end=%~2"

:: Extract date/time components
set /a "sy=!start:~0,4!, sm=1!start:~4,2!-100, sd=1!start:~6,2!-100"
set /a "sh=1!start:~8,2!-100, si=1!start:~10,2!-100, ss=1!start:~12,2!-100"

set /a "ey=!end:~0,4!, em=1!end:~4,2!-100, ed=1!end:~6,2!-100"
set /a "eh=1!end:~8,2!-100, ei=1!end:~10,2!-100, es=1!end:~12,2!-100"

:: Julian date calculation (more accurate than previous version)
set /a "a1=(14-sm)/12, y1=sy+4800-a1, m1=sm+12*a1-3"
set /a "jd1=sd+(153*m1+2)/5+365*y1+y1/4-y1/100+y1/400-32045"

set /a "a2=(14-em)/12, y2=ey+4800-a2, m2=em+12*a2-3"
set /a "jd2=ed+(153*m2+2)/5+365*y2+y2/4-y2/100+y2/400-32045"

:: Calculate total seconds difference
set /a "days=jd2-jd1"
set /a "secs=(eh-sh)*3600 + (ei-si)*60 + (es-ss)"
set /a "total=days*86400 + secs"

endlocal & set "%~3=%total%"
goto :EOF
