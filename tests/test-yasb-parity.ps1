$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$repoRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repoRoot "UserProfile\.config\yasb\config.yaml"
$stylePath = Join-Path $repoRoot "UserProfile\.config\yasb\styles.css"
$readmePath = Join-Path $repoRoot "UserProfile\.config\yasb\README.md"

function Assert-Contains {
    param([string]$Text, [string]$Needle, [string]$Message)
    if (-not $Text.Contains($Needle)) { throw "ASSERTION FAILED: $Message" }
}

function Assert-NotContains {
    param([string]$Text, [string]$Needle, [string]$Message)
    if ($Text.Contains($Needle)) { throw "ASSERTION FAILED: $Message" }
}

foreach ($path in @($configPath, $stylePath, $readmePath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "ASSERTION FAILED: missing YASB parity file: $path"
    }
}

$config = Get-Content -LiteralPath $configPath -Raw
$style = Get-Content -LiteralPath $stylePath -Raw
$readme = Get-Content -LiteralPath $readmePath -Raw

Assert-Contains $config 'height: 28' "bar height stays at Awtarchy horizontal default"
Assert-Contains $config 'windows_app_bar: true' "YASB reserves the Windows work area"
Assert-Contains $config 'hide_on_fullscreen: true' "YASB hides for fullscreen applications"
Assert-Contains $config 'align: "center"' "current YASB BarAlignment field is used"
Assert-NotContains $config 'center: false' "obsolete bar alignment field is absent"
Assert-NotContains $config 'acrylic:' "removed YASB blur field is absent"
Assert-Contains $config 'enabled: false' "bar/task decorative animation has an explicit disabled state"
Assert-Contains $config 'yasb.applications.ApplicationsWidget' "native YASB Applications widget is used"
Assert-Contains $config 'wgdot flow-open' "launcher reuses WGDot Flow Launcher integration"
Assert-Contains $config 'glazewm.workspaces.GlazewmWorkspacesWidget' "native GlazeWM workspace widget is used"
Assert-Contains $config 'monitor_exclusive: true' "monitor-local workspace/task behavior is retained"
Assert-Contains $config 'enable_scroll_switching: true' "workspace wheel switching is enabled"
Assert-Contains $config 'yasb.grouper.GrouperWidget' "workspace mover uses native YASB Grouper"
Assert-Contains $config 'glazewm.exe command move-workspace --direction left' "workspace mover uses native GlazeWM commands"
Assert-Contains $config 'glazewm.binding_mode.GlazewmBindingModeWidget' "binding mode is used as the Windows submap equivalent"
Assert-Contains $config 'on_right: "context_menu"' "taskbar right click uses the Windows-native YASB context menu"
Assert-Contains $config 'label_icon: false' "active window title remains text-only"
Assert-Contains $config 'ddc_poll_interval: 60' "brightness uses native YASB DDC polling"
Assert-Contains $config 'use_hook: false' "systray avoids explorer DLL injection"
Assert-NotContains $config 'use_hook: true' "systray DLL injection is never enabled"
Assert-NotContains $config 'komorebi' "abandoned Komorebi integration is absent"
Assert-NotContains $config 'whkd' "whkd is not introduced"

foreach ($widgetType in @(
    'yasb.cpu.CpuWidget',
    'yasb.memory.MemoryWidget',
    'yasb.brightness.BrightnessWidget',
    'yasb.battery.BatteryWidget',
    'yasb.microphone.MicrophoneWidget',
    'yasb.volume.VolumeWidget',
    'yasb.clock.ClockWidget',
    'yasb.wifi.WifiWidget',
    'yasb.bluetooth.BluetoothWidget',
    'yasb.systray.SystrayWidget',
    'yasb.notifications.NotificationsWidget',
    'yasb.power_menu.PowerMenuWidget'
)) {
    Assert-Contains $config $widgetType "supported YASB widget is present: $widgetType"
}

Assert-Contains $style '#353535' "Awtarchy background color is retained"
Assert-Contains $style '#d0d0d0' "Awtarchy foreground color is retained"
Assert-Contains $style '#ff5555' "Awtarchy critical color is retained"
Assert-Contains $style 'JetBrainsMono NFP' "existing WGDot-managed Nerd Font is retained"
Assert-Contains $style '.workspace-move-grouper' "workspace mover has dedicated flat styling"

Assert-Contains $readme 'Evidence-backed mappings' "feature mappings document their evidence boundary"
Assert-Contains $readme 'Deliberate differences and omissions' "unsupported translations are documented"
Assert-Contains $readme 'CPU temperature' "CPU temperature is not silently substituted with another metric"
Assert-Contains $readme 'context menu' "Windows-native taskbar right-click difference is documented"

Write-Host "YASB parity checks passed." -ForegroundColor Green
