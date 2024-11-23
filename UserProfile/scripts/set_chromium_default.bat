@echo off
:: Check if running as administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo This script must be run as Administrator!
    pause
    exit /b
)

:: Set the path for the XML file
set ExportPath=C:\DefaultAppAssociations.xml

:: Export current default app associations
echo Exporting current default app associations...
dism /Online /Export-DefaultAppAssociations:%ExportPath%
if %errorlevel% neq 0 (
    echo Failed to export default app associations. Exiting...
    pause
    exit /b
)

:: Replace associations with Chromium in the XML file
echo Updating default app associations for Chromium...
(
    for /f "delims=" %%A in ('findstr /v "<Association Identifier=\".html\"" %ExportPath%') do (
        echo %%A
    )
    echo ^<Association Identifier=".html" ProgId="ChromiumHTM.Document" ApplicationName="Chromium" />
    echo ^<Association Identifier="http" ProgId="ChromiumHTM.Document" ApplicationName="Chromium" />
    echo ^<Association Identifier="https" ProgId="ChromiumHTM.Document" ApplicationName="Chromium" />
) > %ExportPath%.tmp
move /y %ExportPath%.tmp %ExportPath%

:: Import updated associations
echo Importing updated default app associations...
dism /Online /Import-DefaultAppAssociations:%ExportPath%
if %errorlevel% neq 0 (
    echo Failed to import default app associations. Exiting...
    pause
    exit /b
)

echo Default app associations updated successfully!
pause
