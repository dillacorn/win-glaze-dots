@echo off
setlocal EnableExtensions

set "SOURCE_REF=main"
set "SOURCE_REVISION="
set "REMOTE_REQUESTED=0"
set "SOURCE_EXPLICIT=0"
set "DOTS_ONLY=0"
set "DOTS_PROFILE="

:parse_args
if "%~1"=="" goto args_done
if /I "%~1"=="--ref" (
  if "%~2"=="" (
    echo Missing value for --ref.
    exit /b 2
  )
  set "SOURCE_REF=%~2"
  set "REMOTE_REQUESTED=1"
  set "SOURCE_EXPLICIT=1"
  shift
  shift
  goto parse_args
)
if /I "%~1"=="--revision" (
  if "%~2"=="" (
    echo Missing value for --revision.
    exit /b 2
  )
  set "SOURCE_REVISION=%~2"
  set "REMOTE_REQUESTED=1"
  set "SOURCE_EXPLICIT=1"
  shift
  shift
  goto parse_args
)
if /I "%~1"=="--dots-only" (
  set "DOTS_ONLY=1"
  shift
  goto parse_args
)
if /I "%~1"=="--profile" (
  if "%~2"=="" (
    echo Missing value for --profile.
    exit /b 2
  )
  set "DOTS_PROFILE=%~2"
  shift
  shift
  goto parse_args
)
echo Unknown bootstrap argument: %~1
exit /b 2

:args_done
if "%DOTS_ONLY%"=="1" (
  if not defined DOTS_PROFILE (
    echo --dots-only requires --profile normal or --profile work.
    exit /b 2
  )
)

set "FETCH_REF=%SOURCE_REF%"
if defined SOURCE_REVISION set "FETCH_REF=%SOURCE_REVISION%"

set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"

if not exist "%CSC%" (
  echo WGDot native bootstrap could not find the Windows .NET Framework C# compiler.
  echo No execution-policy changes were made.
  exit /b 2
)

set "SOURCE_FILE=%~dp0wgdot-native.cs"
set "DOWNLOADED_SOURCE=0"

if "%REMOTE_REQUESTED%"=="1" goto download_source
if exist "%SOURCE_FILE%" goto source_ready

:download_source
where curl.exe >nul 2>&1
if errorlevel 1 (
  echo WGDot native bootstrap requires curl.exe to acquire its source.
  echo No execution-policy changes were made.
  exit /b 2
)

set "SOURCE_FILE=%TEMP%\wgdot-native-source-%RANDOM%-%RANDOM%.cs"
set "SOURCE_URL=https://raw.githubusercontent.com/dillacorn/win-glaze-dots/%FETCH_REF%/wgdot/wgdot-native.cs"
echo Fetching WGDot native source from %FETCH_REF%...
curl.exe -fL --retry 2 --connect-timeout 15 "%SOURCE_URL%" -o "%SOURCE_FILE%"
if errorlevel 1 (
  echo Failed to download WGDot native source.
  del /q "%SOURCE_FILE%" >nul 2>&1
  exit /b 3
)
set "DOWNLOADED_SOURCE=1"

:source_ready
set "OUT=%TEMP%\wgdot-native-%RANDOM%-%RANDOM%.exe"
set "WGDOT_SOURCE_REF=%SOURCE_REF%"
set "WGDOT_SOURCE_REVISION=%SOURCE_REVISION%"
set "WGDOT_SOURCE_EXPLICIT=%SOURCE_EXPLICIT%"
if "%DOWNLOADED_SOURCE%"=="0" set "WGDOT_SOURCE_ROOT=%~dp0.."
if "%DOWNLOADED_SOURCE%"=="1" set "WGDOT_SOURCE_ROOT="

"%CSC%" /nologo /optimize+ /target:exe /out:"%OUT%" /r:System.Web.Extensions.dll /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll /r:System.Xml.dll /r:System.Windows.Forms.dll /r:System.Drawing.dll "%SOURCE_FILE%"
if errorlevel 1 (
  if "%DOWNLOADED_SOURCE%"=="1" del /q "%SOURCE_FILE%" >nul 2>&1
  exit /b %ERRORLEVEL%
)

"%OUT%" self-test
if errorlevel 1 (
  del /q "%OUT%" >nul 2>&1
  if "%DOWNLOADED_SOURCE%"=="1" del /q "%SOURCE_FILE%" >nul 2>&1
  exit /b 4
)

"%OUT%" install
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" goto cleanup

if "%DOTS_ONLY%"=="1" goto apply_dots_only

"%OUT%" ensure-winget
set "RC=%ERRORLEVEL%"
goto cleanup

:apply_dots_only
set "INSTALLED_WGDOT=%LOCALAPPDATA%\wgdot\bin\wgdot.exe"
if defined WGDOT_TEST_ROOT set "INSTALLED_WGDOT=%WGDOT_TEST_ROOT%\wgdot\bin\wgdot.exe"
if not exist "%INSTALLED_WGDOT%" (
  echo Installed WGDot runtime was not found after bootstrap.
  set "RC=5"
  goto cleanup
)
set "WGDOT_SKIP_RUNTIME_REFRESH=1"
"%INSTALLED_WGDOT%" dots-only --profile "%DOTS_PROFILE%" --yes
set "RC=%ERRORLEVEL%"

:cleanup
del /q "%OUT%" >nul 2>&1
if "%DOWNLOADED_SOURCE%"=="1" del /q "%SOURCE_FILE%" >nul 2>&1
exit /b %RC%
