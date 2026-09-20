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
Assert-Contains $config 'always_on_top: true' "YASB remains above normal windows without changing reservation models"
Assert-Contains $config 'windows_app_bar: false' "YASB keeps the reload-free GlazeWM gap reservation"
Assert-Contains $config 'hide_on_fullscreen: true' "YASB hides for fullscreen applications"
Assert-Contains $config 'auto_hide: false' "normal YASB AppBar mode is explicit until runtime auto-hide is supported"
Assert-Contains $config 'align: "center"' "current YASB BarAlignment field is used"
Assert-NotContains $config 'center: false' "obsolete bar alignment field is absent"
Assert-NotContains $config 'acrylic:' "removed YASB blur field is absent"
Assert-Contains $config 'enabled: false' "bar/task decorative animation has an explicit disabled state"
Assert-Contains $config 'yasb.applications.ApplicationsWidget' "native YASB Applications widget is used"
Assert-Contains $config 'yasb.custom.CustomWidget' "launcher uses native callback-capable YASB Custom widget"
Assert-Contains $config 'wgdot flow-open' "launcher reuses WGDot Flow Launcher integration"
Assert-Contains $config 'tooltip_label: "Flow Launcher"' "launcher retains an explicit Flow Launcher tooltip"
Assert-Contains $config 'glazewm.workspaces.GlazewmWorkspacesWidget' "native GlazeWM workspace widget is used"
Assert-Contains $config 'monitor_exclusive: true' "monitor-local workspace/task behavior is retained"
Assert-Contains $config 'enable_scroll_switching: true' "workspace wheel switching is enabled"
Assert-Contains $config 'yasb.grouper.GrouperWidget' "workspace mover uses native YASB Grouper"
Assert-Contains $config 'glazewm.exe command move-workspace --direction left' "workspace mover uses native GlazeWM commands"
Assert-Contains $config 'glazewm.binding_mode.GlazewmBindingModeWidget' "binding mode is used as the Windows submap equivalent"
Assert-Contains $config 'on_right: "toggle_window"' "taskbar right click uses YASB minimize/restore behavior"
Assert-Contains $config 'label: "{info[percent][total]}% <span></span>"' "CPU glyph can use Awtarchy-matched icon sizing"
Assert-Contains $config 'label: "{virtual_mem_percent}% <span></span>"' "memory glyph can use Awtarchy-matched icon sizing"
if (([regex]::Matches($config, 'icon_size:\s*14')).Count -lt 2) {
    throw "ASSERTION FAILED: taskbar and systray retain Awtarchy's current 14 px default icon size"
}
Assert-Contains $config 'label_icon: false' "active window title remains text-only"
Assert-Contains $config 'monitor_exclusive: false' "active window title follows the globally focused window like Awtarchy"
Assert-Contains $config 'ddc_poll_interval: 60' "brightness uses native YASB DDC polling"
Assert-Contains $config 'exec cmd.exe /c start ms-settings:powersleep' "battery clicks use Windows Power and battery settings"
Assert-Contains $config 'on_middle: "toggle_label"' "battery middle click retains YASB alternate battery label"
Assert-Contains $config 'use_hook: false' "systray avoids explorer DLL injection"
Assert-NotContains $config 'use_hook: true' "systray DLL injection is never enabled"
Assert-Contains $config 'yasb.quick_launch.QuickLaunchWidget' "clipboard history uses native YASB Quick Launch"
Assert-Contains $config 'search_placeholder: "Search clipboard history..."' "clipboard Quick Launch is dedicated to history"
Assert-Contains $config 'prefix: "*"' "clipboard provider handles an empty popup query directly"
Assert-Contains $config 'yasb.dnd.DndWidget' "unified notifications and Do Not Disturb control uses native YASB DND"
Assert-NotContains $config 'yasb.notifications.NotificationsWidget' "separate Notifications widget stays removed after DND unification"
Assert-Contains $config 'on_left: "exec notification_center"' "unified DND left click opens Windows Notification Center through YASB native exec mapping"
Assert-Contains $config 'on_right: "toggle_status"' "unified DND right click uses its native DND toggle callback"
Assert-Contains $config 'on_right: "exec wgdot eartrumpet-mixer"' "audio right click opens the existing EarTrumpet mixer helper"
Assert-Contains $config 'normal: ""' "unmuted microphone glyph is collapsed like Awtarchy"
Assert-Contains $style '.microphone-widget .icon.muted' "muted microphone state has dedicated styling"
Assert-Contains $style '--muted: #5c5c5c;' "fallback palette matches Awtarchy Carbon Night"
Assert-Contains $style '@import "theme.css";' "YASB imports the generated live theme palette"
Assert-Contains $config 'theme_picker:' "bar exposes a YASB theme entrypoint"
Assert-Contains $config 'tooltip_label: "Themes (Win+T)"' "theme button documents the Awtarchy-style shortcut"
Assert-Contains $config 'wt.exe -w new --size 72,22 nt --title "WGDot Themes" --suppressApplicationTitle wgdot theme' "theme button keeps WGDot errors visible in a stable titled Windows Terminal"

foreach ($glaze in @($glazeNormal, $glazeWork)) {
    Assert-Contains $glaze 'top: "38px"' "GlazeWM keeps the existing reload-free top reservation"
    Assert-NotContains $glaze 'top: "8px"' "bar redesign does not require live GlazeWM gap migration"
    Assert-Contains $glaze 'shell-exec yasb' "GlazeWM starts YASB"
    Assert-Contains $glaze 'color: "#a1a1a1"' "focused GlazeWM border stays theme-neutral"
    Assert-Contains $glaze 'bindings: ["lwin+t", "rwin+t"]' "Win+T opens themes in normal/noalt contexts"
    Assert-Contains $glaze 'shell-exec wt.exe -w new --size 72,22 nt --title "WGDot Themes" --suppressApplicationTitle wgdot theme' "GlazeWM theme hotkey opens the stable WGDot terminal selector"
    Assert-Contains $glaze 'window_title: { equals: "WGDot Themes" }' "theme selector has a dedicated GlazeWM title rule"
    Assert-Contains $glaze 'window_process: { regex: "^WindowsTerminal(\\.exe)?$" }' "theme selector floating rule is scoped to Windows Terminal"
    Assert-NotContains $glaze 'wm-reload-config wgdot theme' "theme hotkey never chains a GlazeWM reload"
    Assert-Contains $glaze 'yasbc toggle-bar' "legacy hard visibility uses YASB's supported CLI"
    Assert-Contains $glaze 'bindings: ["alt+ctrl+b"]' "legacy WGDot hard-visibility hotkey is preserved"
    Assert-NotContains $glaze 'lwin+alt+ctrl+b' "Awtarchy auto-hide chord is not falsely mapped to YASB hard-hide"
    Assert-NotContains $glaze 'rwin+alt+ctrl+b' "Awtarchy auto-hide chord is not falsely mapped to YASB hard-hide"
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
Assert-Contains $style '.awtarchy-launcher .icon' "launcher span is styled through YASB's native icon class"
Assert-Contains $style '.awtarchy-launcher:hover' "launcher uses Awtarchy's strong hover treatment"
Assert-Contains $style '.dnd-widget:hover' "notification/DND action uses Awtarchy's strong hover treatment"
Assert-Contains $style 'font-size: 19px;' "notification/DND icon keeps Awtarchy's tuned icon scale"
Assert-Contains $style 'padding: 0 8px;' "fixed 8 px horizontal action padding is retained"

Assert-Contains $readme 'Evidence-backed mappings' "feature mappings document their evidence boundary"
Assert-Contains $readme 'Deliberate differences and omissions' "unsupported translations are documented"
Assert-Contains $readme 'CPU temperature' "CPU temperature is not silently substituted with another metric"
Assert-Contains $readme 'Clipboard History' "native clipboard-history mapping is documented"
Assert-Contains $readme 'Do Not Disturb' "notification-mute approximation is documented"
Assert-Contains $readme 'toggle-bar' "native YASB bar visibility mapping is documented"
Assert-Contains $readme 'theme.css' "live YASB theme mapping is documented"
Assert-Contains $readme 'Power & battery' "Windows-native battery details mapping is documented"
Assert-Contains $readme 'PowerPlanWidget' "native Windows power-plan option was evaluated instead of blindly scripted"
Assert-Contains $readme 'no wheel callback' "clock wheel limitation is documented from current YASB source"
Assert-Contains $readme 'one native tray monitor service' "multi-monitor systray behavior is documented from current YASB source"
Assert-Contains $readme 'no native image-tint option' "Awtarchy task/tray recoloring limitation is documented instead of faked"
Assert-Contains $readme 'visual preview cards' "theme-selector limitation versus Awtarchy is documented"
Assert-Contains $readme 'output discarded' "direct YASB theme-command diagnostic limitation is documented"
Assert-Contains $readme '#a1a1a1' "neutral GlazeWM border rationale is documented"
Assert-Contains $readme 'reload-free reservation model' "bar transition rationale avoids forced GlazeWM reload"

Write-Host "YASB parity checks passed." -ForegroundColor Green
