@echo off
setlocal EnableExtensions

set "WGDOT_POLICY="
for /f "usebackq delims=" %%P in (`powershell.exe -NoLogo -NoProfile -Command "[Console]::Out.Write((Get-ExecutionPolicy).ToString())"`) do set "WGDOT_POLICY=%%P"

if /I "%WGDOT_POLICY%"=="Restricted" goto policy_blocked
if /I "%WGDOT_POLICY%"=="AllSigned" goto policy_blocked

powershell.exe -NoLogo -NoProfile -File "%~dp0wgdot.ps1" %*
exit /b %ERRORLEVEL%

:policy_blocked
echo.
echo WGDot automatic mode cannot run because the current Windows PowerShell execution policy is %WGDOT_POLICY%.
echo WGDot will not change or bypass execution policy.
echo Use the paste-only manual workflow instead:
echo   https://github.com/dillacorn/win-glaze-dots/blob/main/MANUAL_POWERSHELL.md
echo.
exit /b 5
