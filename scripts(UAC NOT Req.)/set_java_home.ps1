# Get the installed Java path from the system environment
$javaHome = [System.Environment]::GetEnvironmentVariable("JAVA_HOME", "Machine")

if (-not $javaHome) {
    Write-Host "JAVA_HOME is not set in the system environment. Please install Java first." -ForegroundColor Red
    exit 1
}

# Set JAVA_HOME for the user environment
[System.Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHome, "User")
Write-Host "Set JAVA_HOME for user: $javaHome" -ForegroundColor Green

# Get the current user PATH and append Java's bin directory if not already included
$userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
$javaBinPath = "$javaHome\bin"

if ($userPath -notlike "*${javaBinPath}*") {
    $newUserPath = "$userPath;$javaBinPath"
    [System.Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
    Write-Host "Added Java bin directory to user PATH: $javaBinPath" -ForegroundColor Green
} else {
    Write-Host "Java bin directory is already in user PATH." -ForegroundColor Yellow
}

# Force PowerShell to reload the environment variables immediately
$env:JAVA_HOME = [System.Environment]::GetEnvironmentVariable("JAVA_HOME", "User")
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "Machine")

Write-Host "Restart your terminal or log out and back in for changes to take effect." -ForegroundColor Cyan
