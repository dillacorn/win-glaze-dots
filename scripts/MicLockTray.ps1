# MicLockTray.ps1
# Self-installing tray app. Locks default recording device to 100% using NirCmd every 10s.
# Double-click to install/uninstall (no admin). When installed, it runs at user logon.
# Manual run: powershell -NoProfile -ExecutionPolicy Bypass -File "MicLockTray.ps1" -hidden
# Requires: NirCmd (nircmd.exe or nircmdc.exe) in PATH or in C:\Program Files\NirSoft\

param(
  [switch]$hidden,
  [switch]$install,
  [switch]$uninstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------- Install locations (per-user, no admin) ----------
$AppName    = 'MicLockTray'
$InstallDir = Join-Path $env:LocalAppData $AppName
$InstalledScriptPath = Join-Path $InstallDir "$AppName.ps1"
$StartupDir = [Environment]::GetFolderPath('Startup') # %APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup
$ShortcutPath = Join-Path $StartupDir "$AppName.lnk"
$PsExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

function Test-Installation {
  Test-Path -LiteralPath $ShortcutPath
}

function New-Shortcut {
  param(
    [Parameter(Mandatory)] [string]$LinkPath,
    [Parameter(Mandatory)] [string]$TargetPath,
    [Parameter(Mandatory)] [string]$Arguments,
    [string]$WorkingDir = ''
  )
  $ws = New-Object -ComObject WScript.Shell
  $sc = $ws.CreateShortcut($LinkPath)
  $sc.TargetPath       = $TargetPath
  $sc.Arguments        = $Arguments
  $sc.WorkingDirectory = $WorkingDir
  try { $sc.IconLocation = "$env:SystemRoot\System32\shell32.dll,220" } catch {}
  $sc.Save()
}

function Stop-RunningInstances {
  try {
    $procs = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'"
    $mine  = $procs | Where-Object { $_.CommandLine -match [regex]::Escape("$AppName.ps1") }
    foreach ($p in $mine) { try { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue } catch {} }
  } catch {}
}

function Install-App {
  if (Test-Installation) {
    Write-Host 'miclockvol already installed' -ForegroundColor Yellow
    return
  }
  New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
  if (-not (Test-Path -LiteralPath $InstalledScriptPath) -or ($PSCommandPath -ne $InstalledScriptPath)) {
    Copy-Item -LiteralPath $PSCommandPath -Destination $InstalledScriptPath -Force
  }
  $args = "-WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$InstalledScriptPath`" -hidden"
  New-Shortcut -LinkPath $ShortcutPath -TargetPath $PsExe -Arguments $args -WorkingDir $InstallDir
  Start-Process -FilePath $PsExe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$InstalledScriptPath`"","-hidden") -WindowStyle Hidden | Out-Null
  Write-Host 'miclockvol installed' -ForegroundColor Green
}

function Uninstall-App {
  if (-not (Test-Installation)) {
    Write-Host 'miclockvol not installed' -ForegroundColor Yellow
  } else {
    try { Remove-Item -LiteralPath $ShortcutPath -Force -ErrorAction Stop } catch {}
    Write-Host 'miclockvol uninstalled' -ForegroundColor Green
  }
  Stop-RunningInstances
  try { Remove-Item -LiteralPath $InstalledScriptPath -Force -ErrorAction SilentlyContinue } catch {}
  try {
    if ((Get-ChildItem -LiteralPath $InstallDir -Force -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0) {
      Remove-Item -LiteralPath $InstallDir -Force
    }
  } catch {}
}

# ---------- CLI entry: install/uninstall/toggle ----------
if (-not $hidden) {
  if ($install)   { Install-App;   return }
  if ($uninstall) { Uninstall-App; return }
  if (Test-Installation) { Uninstall-App } else { Install-App }
  return
}

# ---------- Tray app logic (hidden mode) ----------
if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
  Start-Process -FilePath $PsExe -WindowStyle Hidden -ArgumentList @(
    '-NoProfile','-ExecutionPolicy','Bypass','-STA','-File',"`"$PSCommandPath`"","-hidden"
  ) | Out-Null
  return
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Get-NirCmdPath {
  $names = @('nircmdc.exe','nircmd.exe')
  foreach ($n in $names) {
    $c = Get-Command $n -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
  }
  $candidates = @(
    "$env:ProgramFiles\NirSoft\nircmdc.exe",
    "$env:ProgramFiles\NirSoft\nircmd.exe",
    "$env:ProgramFiles(x86)\NirSoft\nircmdc.exe",
    "$env:ProgramFiles(x86)\NirSoft\nircmd.exe"
  )
  foreach ($p in $candidates) { if (Test-Path -LiteralPath $p) { return $p } }
  return $null
}

$script:Nir   = Get-NirCmdPath
$script:Timer = New-Object System.Windows.Forms.Timer
$script:Icon  = New-Object System.Windows.Forms.NotifyIcon
$script:Menu  = New-Object System.Windows.Forms.ContextMenuStrip

function Set-Mic100 {
  if (-not $script:Nir) {
    $script:Nir = Get-NirCmdPath
    if (-not $script:Nir) {
      $script:Icon.ShowBalloonTip(2500,'MicLockTray','NirCmd not found. Install NirCmd to C:\Program Files\NirSoft\ or add it to PATH.',[System.Windows.Forms.ToolTipIcon]::Warning)
      return
    }
  }
  try {
    & $script:Nir setsysvolume 65535 default_record | Out-Null
  } catch {
    $script:Icon.ShowBalloonTip(2500,'MicLockTray',"Error: $($_.Exception.Message)",[System.Windows.Forms.ToolTipIcon]::Error)
  }
}

# Tray UI
$script:Icon.Icon    = [System.Drawing.SystemIcons]::Application
$script:Icon.Text    = 'MicLockTray: locks mic at 100%'
$script:Icon.Visible = $true

$miForce     = $script:Menu.Items.Add('Force 100% now')
$miToggle    = $script:Menu.Items.Add('Pause enforcement')
$script:Menu.Items.Add('-') | Out-Null
$miUninstall = $script:Menu.Items.Add('Uninstall MicLockTray')
$script:Menu.Items.Add('-') | Out-Null
$miExit      = $script:Menu.Items.Add('Exit')
$script:Icon.ContextMenuStrip = $script:Menu

# Actions
$miForce.Add_Click({ Set-Mic100 })
$miToggle.Add_Click({
  if ($script:Timer.Enabled) {
    $script:Timer.Stop()
    $miToggle.Text = 'Resume enforcement'
    $script:Icon.ShowBalloonTip(1500,'MicLockTray','Paused.',[System.Windows.Forms.ToolTipIcon]::None)
  } else {
    $script:Timer.Start()
    $miToggle.Text = 'Pause enforcement'
    $script:Icon.ShowBalloonTip(1500,'MicLockTray','Resumed. Mic will be forced to 100% every 10s.',[System.Windows.Forms.ToolTipIcon]::Info)
  }
})
$miUninstall.Add_Click({
  try {
    # Spawn uninstaller FIRST to avoid being killed before launch
    Start-Process -FilePath $PsExe `
      -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$InstalledScriptPath`"","-uninstall") `
      -WindowStyle Hidden
  } catch {}
  try { $script:Timer.Stop() } catch {}
  $script:Icon.Visible = $false
  try { $script:Icon.Dispose() } catch {}
  [System.Windows.Forms.Application]::Exit()
})
$miExit.Add_Click({
  try { $script:Timer.Stop() } catch {}
  $script:Icon.Visible = $false
  try { $script:Icon.Dispose() } catch {}
  [System.Windows.Forms.Application]::Exit()
})

# Timer
$script:Timer.Interval = 10000
$script:Timer.Add_Tick({ Set-Mic100 })
$script:Timer.Start()

# Kick + tip
Set-Mic100
$script:Icon.ShowBalloonTip(1500,'MicLockTray','Microphone volume locked to 100%.',[System.Windows.Forms.ToolTipIcon]::Info)

[System.Windows.Forms.Application]::Run()
