$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$repoRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repoRoot "UserProfile\.config\yasb\config.yaml"
$stylePath = Join-Path $repoRoot "UserProfile\.config\yasb\styles.css"
$readmePath = Join-Path $repoRoot "UserProfile\.config\yasb\README.md"
$glazeNormalPath = Join-Path $repoRoot "UserProfile\.glzr\glazewm\config.yaml"
$glazeWorkPath = Join-Path $repoRoot "UserProfile\.glzr\glazewm\custom_work_config.yaml"

function Assert-Contains {
    param([string]$Text, [string]$Needle, [string]$Message)
    if (-not $Text.Contains($Needle)) { throw "ASSERTION FAILED: $Message" }
}

function Assert-NotContains {
    param([string]$Text, [string]$Needle, [string]$Message)
    if ($Text.Contains($Needle)) { throw "ASSERTION FAILED: $Message" }
}

foreach ($path in @($configPath, $stylePath, $readmePath, $glazeNormalPath, $glazeWorkPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "ASSERTION FAILED: missing YASB parity file: $path"
    }
}

$config = Get-Content -LiteralPath $configPath -Raw
$style = Get-Content -LiteralPath $stylePath -Raw
$readme = Get-Content -LiteralPath $readmePath -Raw
$glazeNormal = Get-Content -LiteralPath $glazeNormalPath -Raw
$glazeWork = Get-Content -LiteralPath $glazeWorkPath -Raw

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
Assert-Contains $config 'on_right: "toggle_window"' "taskbar right click uses YASB minimize/restore behavior"
Assert-Contains $config 'label_icon: false' "active window title remains text-only"
Assert-Contains $config 'ddc_poll_interval: 60' "brightness uses native YASB DDC polling"
Assert-Contains $config 'use_hook: false' "systray avoids explorer DLL injection"
Assert-NotContains $config 'use_hook: true' "systray DLL injection is never enabled"
Assert-Contains $config 'yasb.quick_launch.QuickLaunchWidget' "clipboard history uses native YASB Quick Launch"
Assert-Contains $config 'search_placeholder: "Search clipboard history..."' "clipboard Quick Launch is dedicated to history"
Assert-Contains $config 'prefix: "*"' "clipboard provider handles an empty popup query directly"
Assert-Contains $config 'yasb.dnd.DndWidget' "Windows Do Not Disturb uses native YASB DND"
Assert-Contains $config 'on_left: "toggle_status"' "DND uses its native toggle callback"
Assert-Contains $config 'on_right: "exec wgdot eartrumpet-mixer"' "audio right click opens the existing EarTrumpet mixer helper"
Assert-Contains $config 'normal: ""' "unmuted microphone glyph is collapsed like Awtarchy"
Assert-Contains $style '.microphone-widget .icon.muted' "muted microphone state has dedicated styling"

foreach ($glaze in @($glazeNormal, $glazeWork)) {
    Assert-Contains $glaze 'top: "8px"' "GlazeWM keeps a normal top outer gap when YASB reserves the AppBar area"
    Assert-NotContains $glaze 'top: "38px"' "legacy manual YASB top allowance is removed"
    Assert-Contains $glaze 'shell-exec yasb' "GlazeWM starts YASB"
    Assert-Contains $glaze 'yasbc toggle-bar' "bar visibility uses YASB's supported CLI"
    Assert-Contains $glaze 'lwin+alt+ctrl+b' "Awtarchy-style left-Win bar chord is preserved"
    Assert-Contains $glaze 'rwin+alt+ctrl+b' "Awtarchy-style right-Win bar chord is preserved"
    Assert-NotContains $glaze 'Stop-Process -Name yasb -Force' "bar visibility no longer kills the YASB process"
}
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
    'yasb.quick_launch.QuickLaunchWidget',
    'yasb.dnd.DndWidget',
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
Assert-Contains $readme 'Clipboard History' "native clipboard-history mapping is documented"
Assert-Contains $readme 'Do Not Disturb' "notification-mute approximation is documented"
Assert-Contains $readme 'toggle-bar' "native YASB bar visibility mapping is documented"
Assert-Contains $readme 'double gap' "AppBar transition avoids double-reserving the top edge"

Write-Host "YASB parity checks passed." -ForegroundColor Green
