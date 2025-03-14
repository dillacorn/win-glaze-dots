# Define possible installation paths
$scoopPath = "$env:USERPROFILE\scoop\apps\glazewm\current"
$programFilesPath = "C:\Program Files\glzr.io\GlazeWM"

# Check where GlazeWM is installed
if (Test-Path $scoopPath) {
    $installPath = $scoopPath
} elseif (Test-Path $programFilesPath) {
    $installPath = $programFilesPath
} else {
    Write-Host "GlazeWM is not installed in the expected locations."
    exit
}

# Define the path for the shortcut in the Startup folder
$startupFolderPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$shortcutPath = "$startupFolderPath\GlazeWM.lnk"

# Create the shortcut
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($shortcutPath)
$Shortcut.TargetPath = "$installPath\glazewm.exe"
$Shortcut.WorkingDirectory = $installPath
$Shortcut.Save()

Write-Host "Shortcut created at $shortcutPath"
