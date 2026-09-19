@echo off
setlocal EnableExtensions

set "SOURCE_REF=main"
set "SOURCE_REVISION="
set "REMOTE_REQUESTED=0"

:parse_args
if "%~1"=="" goto args_done
if /I "%~1"=="--ref" (
  if "%~2"=="" (
    echo Missing value for --ref.
    exit /b 2
  )
  set "SOURCE_REF=%~2"
  set "REMOTE_REQUESTED=1"
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
  shift
  shift
  goto parse_args
)
echo Unknown bootstrap argument: %~1
exit /b 2

:args_done
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
if "%DOWNLOADED_SOURCE%"=="0" set "WGDOT_SOURCE_ROOT=%~dp0.."
if "%DOWNLOADED_SOURCE%"=="1" set "WGDOT_SOURCE_ROOT="

"%CSC%" /nologo /optimize+ /target:exe /out:"%OUT%" /r:System.Web.Extensions.dll "%SOURCE_FILE%"
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

del /q "%OUT%" >nul 2>&1
if "%DOWNLOADED_SOURCE%"=="1" del /q "%SOURCE_FILE%" >nul 2>&1
exit /b %RC%
