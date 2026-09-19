@echo off
setlocal EnableExtensions

set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"

if not exist "%CSC%" (
  echo WGDot native bootstrap could not find the Windows .NET Framework C# compiler.
  echo No execution-policy changes were made.
  exit /b 2
)

set "OUT=%TEMP%\wgdot-native-%RANDOM%-%RANDOM%.exe"
"%CSC%" /nologo /optimize+ /target:exe /out:"%OUT%" /r:System.Web.Extensions.dll "%~dp0wgdot-native.cs"
if errorlevel 1 exit /b %ERRORLEVEL%

"%OUT%" self-test
if errorlevel 1 (
  del /q "%OUT%" >nul 2>&1
  exit /b 3
)

"%OUT%" install
set "RC=%ERRORLEVEL%"
del /q "%OUT%" >nul 2>&1
exit /b %RC%
