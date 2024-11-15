@echo off
:: Define variables
set "repoURL=http://www.rw-designer.com/cursor-downloadset.php?id=oops-all-link-selects"
set "tempDir=%TEMP%\OopsAllLinkSelects"
set "zipFile=%tempDir%\OopsAllLinkSelects.zip"
set "extractDir=%tempDir%\OopsAllLinkSelectsExtracted"
set "cursorDir=C:\Windows\Cursors\OopsAllLinkSelects"

:: Step 1: Create temporary directory and clear any previous downloads
if not exist "%tempDir%" mkdir "%tempDir%"
if exist "%extractDir%" rd /s /q "%extractDir%"

:: Step 2: Download the ZIP file
echo Downloading the cursor theme...
powershell -Command "(New-Object System.Net.WebClient).DownloadFile('%repoURL%', '%zipFile%')"
if not exist "%zipFile%" (
    echo Failed to download the cursor theme.
    exit /b 1
)

:: Step 3: Extract the ZIP file
echo Extracting the cursor theme...
powershell -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('%zipFile%', '%extractDir%')"
if not exist "%extractDir%" (
    echo Failed to extract the cursor theme.
    exit /b 1
)

:: Step 4: Copy cursor files to the Windows cursor directory
echo Installing the cursor theme...
if not exist "%cursorDir%" mkdir "%cursorDir%"
xcopy "%extractDir%\*" "%cursorDir%" /E /I /Y
if errorlevel 1 (
    echo Failed to copy cursor files.
    exit /b 1
)

:: Step 5: Update the registry to apply the theme
echo Applying the cursor theme...
reg add "HKEY_CURRENT_USER\Control Panel\Cursors" /v "Arrow" /t REG_SZ /d "%cursorDir%\default.cur" /f
reg add "HKEY_CURRENT_USER\Control Panel\Cursors" /v "Help" /t REG_SZ /d "%cursorDir%\help.cur" /f
reg add "HKEY_CURRENT_USER\Control Panel\Cursors" /v "AppStarting" /t REG_SZ /d "%cursorDir%\busy.ani" /f
reg add "HKEY_CURRENT_USER\Control Panel\Cursors" /v "Wait" /t REG_SZ /d "%cursorDir%\busy.ani" /f
reg add "HKEY_CURRENT_USER\Control Panel\Cursors" /v "Crosshair" /t REG_SZ /d "%cursorDir%\precision select.cur" /f
reg add "HKEY_CURRENT_USER\Control Panel\Cursors" /v "IBeam" /t REG_SZ /d "%cursorDir%\handwrite.cur" /f
reg add "HKEY_CURRENT_USER\Control Panel\Cursors" /v "NWPen" /t REG_SZ /d "%cursorDir%\handwrite.cur" /f
reg add "HKEY_CURRENT_USER\Control Panel\Cursors" /v "No" /t REG_SZ /d "%cursorDir%\unavailable.ani" /f
reg add "HKEY_CURRENT_USER\Control Panel\Cursors" /v "SizeNS" /t REG_SZ /d "%cursorDir%\resize vertical.cur" /f
reg add "HKEY_CURRENT_USER\Control Panel\Cursors" /v "SizeWE" /t REG_SZ /d "%cursorDir%\resize horizontal.cur" /f
reg add "HKEY_CURRENT_USER\Control Panel\Cursors" /v "SizeNWSE" /t REG_SZ /d "%cursorDir%\resize backslash.cur" /f
reg add "HKEY_CURRENT_USER\Control Panel\Cursors" /v "SizeNESW" /t REG_SZ /d "%cursorDir%\resize slash.cur" /f
reg add "HKEY_CURRENT_USER\Control Panel\Cursors" /v "SizeAll" /t REG_SZ /d "%cursorDir%\move.cur" /f
reg add "HKEY_CURRENT_USER\Control Panel\Cursors" /v "UpArrow" /t REG_SZ /d "%cursorDir%\alt select.cur" /f
reg add "HKEY_CURRENT_USER\Control Panel\Cursors" /v "Hand" /t REG_SZ /d "%cursorDir%\link select.cur" /f

:: Step 6: Refresh the system to apply changes
echo Applying changes...
rundll32.exe user32.dll,UpdatePerUserSystemParameters

echo Cursor theme installed and applied successfully!
pause
