# Define possible installation paths for EarTrumpet
$scoopPath = "$env:USERPROFILE\scoop\apps\eartrumpet\current"
$msStorePath = "$env:LOCALAPPDATA\Packages\40459File-New-Project.EarTrumpet_*\LocalCache\Local\EarTrumpet"

# Check where EarTrumpet is installed
if (Test-Path $scoopPath) {
    $installPath = $scoopPath
} elseif (Test-Path $msStorePath) {
    $installPath = (Get-ChildItem -Path $msStorePath -Directory | Select-Object -First 1).FullName
} else {
    Write-Host "EarTrumpet is not installed in the expected locations."
    exit
}

# Define the path for the shortcut in the Startup folder
$startupFolderPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$shortcutPath = "$startupFolderPath\EarTrumpet.lnk"

# Create the shortcut
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($shortcutPath)
$Shortcut.TargetPath = "$installPath\EarTrumpet.exe"
$Shortcut.WorkingDirectory = $installPath
$Shortcut.Save()

Write-Host "Shortcut created at $shortcutPath"
