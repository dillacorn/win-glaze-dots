# MicLockTray.ps1
# Tray-only app. Keeps default recording device at 100% using NirCmd every 10s.
# Launch spawns a hidden STA child that shows only a tray icon with a menu.
# Run:
#   powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Path\MicLockTray.ps1"
# Adjust Volume: # Line 54 - 85% -> 65535 × 85 ÷ 100 = 55705 (example)

param([switch]$hidden)

$ErrorActionPreference = 'Stop'

# Relaunch hidden in STA (no console window)
if (-not $hidden) {
  Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @(
    '-NoProfile','-ExecutionPolicy','Bypass','-STA','-File',"`"$PSCommandPath`"",' -hidden'
  ) | Out-Null
  exit
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
  foreach ($p in $candidates) { if (Test-Path $p) { return $p } }
  return $null
}

# Persistent state
$script:Nir = Get-NirCmdPath
$script:Timer = New-Object System.Windows.Forms.Timer
$script:Icon  = New-Object System.Windows.Forms.NotifyIcon
$script:Menu  = New-Object System.Windows.Forms.ContextMenuStrip

function Set-Mic100 {
  if (-not $script:Nir) {
    $script:Nir = Get-NirCmdPath
    if (-not $script:Nir) {
      $script:Icon.ShowBalloonTip(2000,'MicVolTray','NirCmd not found. Install to C:\Program Files\NirSoft\ and try again.',[System.Windows.Forms.ToolTipIcon]::Warning)
      return
    }
  }
  try {
    & $script:Nir setsysvolume 65535 default_record | Out-Null
  } catch {
    $script:Icon.ShowBalloonTip(2000,'MicVolTray',"Error: $($_.Exception.Message)",[System.Windows.Forms.ToolTipIcon]::Error)
  }
}

# Build tray icon
$script:Icon.Icon  = [System.Drawing.SystemIcons]::Application
$script:Icon.Text  = 'MicVolTray — locks mic at 100%'
$script:Icon.Visible = $true

# Menu: Force, Toggle (pause/resume), Exit
$miForce  = $script:Menu.Items.Add('Force 100% now')
$miToggle = $script:Menu.Items.Add('Pause enforcement')
$script:Menu.Items.Add('-') | Out-Null
$miExit   = $script:Menu.Items.Add('Exit')

$script:Icon.ContextMenuStrip = $script:Menu

# Wire actions
$miForce.Add_Click({ Set-Mic100 })
$miToggle.Add_Click({
  if ($script:Timer.Enabled) {
    $script:Timer.Stop()
    $miToggle.Text = 'Resume enforcement'
    $script:Icon.ShowBalloonTip(1500,'MicVolTray','Paused.',[System.Windows.Forms.ToolTipIcon]::None)
  } else {
    $script:Timer.Start()
    $miToggle.Text = 'Pause enforcement'
    $script:Icon.ShowBalloonTip(1500,'MicVolTray','Resumed. Mic will be forced to 100% every 10s.',[System.Windows.Forms.ToolTipIcon]::Info)
  }
})
$miExit.Add_Click({
  try { $script:Timer.Stop() } catch {}
  $script:Icon.Visible = $false
  $script:Icon.Dispose()
  [System.Windows.Forms.Application]::ExitThread()
})

# Timer
$script:Timer.Interval = 10000
$script:Timer.Add_Tick({ Set-Mic100 })
$script:Timer.Start()

# Kick once and show tip
Set-Mic100
$script:Icon.ShowBalloonTip(1500,'MicVolTray','Microphone volume locked to 100%.',[System.Windows.Forms.ToolTipIcon]::Info)

# Message loop without a form (tray-only)
[System.Windows.Forms.Application]::Run()
