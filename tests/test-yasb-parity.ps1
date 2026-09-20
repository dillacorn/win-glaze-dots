$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$repoRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repoRoot "UserProfile\.config\yasb\config.yaml"
$stylePath = Join-Path $repoRoot "UserProfile\.config\yasb\styles.css"
$readmePath = Join-Path $repoRoot "UserProfile\.config\yasb\README.md"
$glazeNormalPath = Join-Path $repoRoot "UserProfile\.glzr\glazewm\config.yaml"
$glazeWorkPath = Join-Path $repoRoot "UserProfile\.glzr\glazewm\custom_work_config.yaml"
$nativePath = Join-Path $repoRoot "wgdot\wgdot-native.cs"

function Assert-Contains {
    param([string]$Text, [string]$Needle, [string]$Message)
    if (-not $Text.Contains($Needle)) { throw "ASSERTION FAILED: $Message" }
}

function Assert-NotContains {
    param([string]$Text, [string]$Needle, [string]$Message)
    if ($Text.Contains($Needle)) { throw "ASSERTION FAILED: $Message" }
}

foreach ($path in @($configPath, $stylePath, $readmePath, $glazeNormalPath, $glazeWorkPath, $nativePath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "ASSERTION FAILED: missing YASB parity file: $path"
    }
}

$config = Get-Content -LiteralPath $configPath -Raw
$style = Get-Content -LiteralPath $stylePath -Raw
$readme = Get-Content -LiteralPath $readmePath -Raw
$glazeNormal = Get-Content -LiteralPath $glazeNormalPath -Raw
$glazeWork = Get-Content -LiteralPath $glazeWorkPath -Raw
$native = Get-Content -LiteralPath $nativePath -Raw

Assert-Contains $config 'height: 28' "bar height stays at Awtarchy horizontal default"
Assert-Contains $config 'always_on_top: true' "YASB remains above normal windows without changing reservation models"
Assert-Contains $config 'windows_app_bar: false' "YASB keeps the reload-free GlazeWM gap reservation"
Assert-Contains $config 'hide_on_fullscreen: true' "YASB hides for fullscreen applications"
Assert-Contains $config 'auto_hide: false' "normal YASB AppBar mode is explicit until runtime auto-hide is supported"
Assert-Contains $config 'context_menu: false' "blank-bar YASB context menu is disabled like Awtarchy"
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
Assert-Contains $config 'label: "{info[percent][total]} <span></span>"' "CPU label matches Awtarchy's unitless integer plus glyph"
Assert-Contains $config 'label: "{virtual_mem_percent} <span></span>"' "memory label matches Awtarchy's unitless integer plus glyph"
Assert-NotContains $config 'label: "{info[percent][total]}% <span></span>"' "CPU bar label does not reintroduce a percent suffix"
Assert-NotContains $config 'label: "{virtual_mem_percent}% <span></span>"' "memory bar label does not reintroduce a percent suffix"
if (([regex]::Matches($config, 'icon_size:\s*14')).Count -lt 2) {
    throw "ASSERTION FAILED: taskbar and systray retain Awtarchy's current 14 px default icon size"
}
Assert-Contains $config 'label_icon: false' "active window title remains text-only"
Assert-Contains $config 'monitor_exclusive: false' "active window title follows the globally focused window like Awtarchy"
$brightnessBlock = [regex]::Match($config, '(?ms)^  brightness:\r?\n.*?(?=^  battery:)').Value
$batteryBlock = [regex]::Match($config, '(?ms)^  battery:\r?\n.*?(?=^  microphone:)').Value
Assert-Contains $brightnessBlock 'yasb.brightness.BrightnessWidget' "brightness widget block is discoverable"
Assert-Contains $brightnessBlock 'label: "<span>{icon}</span> {percent}%"' "brightness retains Awtarchy's explicit percent suffix"
if (([regex]::Matches($brightnessBlock, '')).Count -ne 4) {
    throw "ASSERTION FAILED: brightness uses Awtarchy's fixed gear glyph in all four native YASB slots"
}
Assert-Contains $brightnessBlock 'ddc_poll_interval: 60' "brightness uses native YASB DDC polling"
Assert-Contains $batteryBlock 'yasb.battery.BatteryWidget' "battery widget block is discoverable"
Assert-Contains $batteryBlock 'exec cmd.exe /c start ms-settings:powersleep' "battery clicks use Windows Power and battery settings"
Assert-Contains $batteryBlock 'label: "<span>{icon}</span> {percent}"' "battery bar label matches Awtarchy's unitless integer"
Assert-NotContains $batteryBlock 'label: "<span>{icon}</span> {percent}%"' "battery bar label does not reintroduce a percent suffix"
Assert-Contains $batteryBlock 'icon_format: "{icon} {charging_icon}"' "plugged-in battery retains the battery glyph and adds the charging bolt"
Assert-Contains $batteryBlock 'critical: 15' "battery critical color begins at Awtarchy's 15 percent boundary"
Assert-Contains $batteryBlock 'low: 39' "battery low band ends at 39 like Awtarchy"
Assert-Contains $batteryBlock 'medium: 64' "battery medium band ends at 64 like Awtarchy"
Assert-Contains $batteryBlock 'high: 89' "battery high band ends at 89 like Awtarchy"
Assert-Contains $batteryBlock 'on_middle: "toggle_label"' "battery middle click retains YASB alternate battery label"
$volumeBlock = [regex]::Match($config, '(?ms)^  volume:\r?\n.*?(?=^  clock:)').Value
Assert-Contains $volumeBlock 'scroll_step: 5' "volume wheel changes by the same five points as current Awtarchy"
Assert-Contains $volumeBlock 'muted: ""' "volume muted glyph matches current Awtarchy"
Assert-Contains $volumeBlock '"24": ""' "volume low icon ends at 24 like Awtarchy's <25 threshold"
Assert-Contains $volumeBlock '"59": ""' "volume medium icon ends at 59 like Awtarchy's <60 threshold"
Assert-Contains $volumeBlock '"100": ""' "volume high icon covers the remaining range"
Assert-NotContains $volumeBlock '"10": ""' "old YASB default low-volume cutoff is removed"
Assert-NotContains $volumeBlock '"30": ""' "old YASB default medium-volume cutoff is removed"
Assert-Contains $config 'use_hook: false' "systray avoids explorer DLL injection"
Assert-NotContains $config 'use_hook: true' "systray DLL injection is never enabled"
$clockBlock = [regex]::Match($config, '(?ms)^  clock:\r?\n.*?(?=^  wifi:)').Value
$wifiBlock = [regex]::Match($config, '(?ms)^  wifi:\r?\n.*?(?=^  bluetooth:)').Value
$bluetoothBlock = [regex]::Match($config, '(?ms)^  bluetooth:\r?\n.*?(?=^  systray:)').Value
$clipboardBlock = [regex]::Match($config, '(?ms)^  clipboard_history:\r?\n.*?(?=^  dnd:)').Value
Assert-Contains $clockBlock '{%a %#m/%#d}' "clock alternate date matches Awtarchy's non-zero-padded M/d"
Assert-Contains $wifiBlock '"󰤯"' "Wi-Fi zero-strength glyph matches Awtarchy"
Assert-Contains $wifiBlock 'ethernet_icon: "󰈀"' "active Ethernet glyph matches Awtarchy"
Assert-Contains $bluetoothBlock 'bluetooth_on: ""' "Bluetooth enabled glyph matches Awtarchy"
Assert-Contains $bluetoothBlock 'bluetooth_off: ""' "Bluetooth disabled keeps Awtarchy's single glyph"
Assert-Contains $bluetoothBlock 'bluetooth_connected: ""' "Bluetooth connected keeps Awtarchy's single glyph"
Assert-Contains $clipboardBlock 'label: "<span></span>"' "clipboard glyph matches current Awtarchy"
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
Assert-Contains $native 'new YasbTheme("carbon-night", "Carbon Night", "#353535", "#d0d0d0", "#404040", "#4a4a4a", "#2b2b2b", "#ff5555", "#1a1a1a", "#6a9955", "#ff5555", "#5c5c5c")' "Carbon Night YASB palette matches current Awtarchy"
Assert-Contains $native 'new YasbTheme("catppuccin-frappe", "Catppuccin Frappe", "#303446", "#c6d0f5", "#414559", "#535970", "#383c4d", "#e78284", "#232634", "#a6d189", "#ef9f76", "#a5adce")' "Catppuccin Frappe YASB palette matches current Awtarchy"
Assert-Contains $native 'new YasbTheme("crimson-red", "Crimson Red", "#1e1e2e", "#f38ba8", "#352630", "#5a3442", "#292330", "#f38ba8", "#1e1e2e", "#fab387", "#f38ba8", "#9f8994")' "Crimson Red YASB palette matches current Awtarchy"
Assert-Contains $native 'new YasbTheme("electric-blue", "Electric Blue", "#1e1e2e", "#89b4fa", "#293448", "#34445e", "#252938", "#f38ba8", "#1e1e2e", "#a6e3a1", "#fab387", "#8993a8")' "Electric Blue YASB palette matches current Awtarchy"
Assert-Contains $native 'new YasbTheme("gruvbox", "Gruvbox", "#282828", "#ebdbb2", "#4a423c", "#665c4e", "#3c3836", "#b16286", "#fbf1c7", "#98971a", "#cc241d", "#a89984")' "Gruvbox YASB palette matches current Awtarchy"
Assert-Contains $native 'new YasbTheme("iron-forge", "Iron Forge", "#0f1113", "#bcd2d2", "#1f2328", "#242a32", "#0d0f12", "#a31717", "#ffffff", "#1f6f6f", "#a31717", "#6a7b86")' "Iron Forge YASB palette matches current Awtarchy"
Assert-Contains $native 'new YasbTheme("obsidian-night", "Obsidian Night", "#0f0f0f", "#cdd6f4", "#1e1e2e", "#313244", "#1a1a1a", "#ff5555", "#1e1e2e", "#6a9955", "#ff5555", "#4b4b4b")' "Obsidian Night YASB palette matches current Awtarchy"
Assert-Contains $native 'new YasbTheme("pink", "Pink", "#D297A1", "#2E2E2E", "#B77F91", "#C0AFC0", "#C0AFC0", "#B04155", "#FFFFFF", "#D3D3D3", "#B04155", "#7A7A7A")' "Pink YASB palette matches current Awtarchy"
Assert-Contains $native 'new YasbTheme("pipboy", "Pip-Boy", "#050805", "#a4ff47", "#1f301f", "#1b281b", "#101810", "#263826", "#050805", "#a4ff47", "#3c1b1b", "#2a3d2a")' "Pip-Boy YASB palette matches current Awtarchy"

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
$taskContainerBlock = [regex]::Match($style, '(?ms)^\.taskbar-widget \.app-container \{\r?\n.*?^\}').Value
Assert-Contains $taskContainerBlock 'min-width: 14px;' "task content width matches its 14 px Awtarchy icon"
Assert-Contains $taskContainerBlock 'max-width: 14px;' "task content width is fixed so the padded slot remains 26 px"
Assert-Contains $taskContainerBlock 'padding: 0 6px;' "task slot totals Awtarchy's 26 px width"
Assert-Contains $style '.workspace-move-grouper' "workspace mover has dedicated flat styling"
Assert-Contains $style '.awtarchy-launcher .icon' "launcher span is styled through YASB's native icon class"
Assert-Contains $style '.awtarchy-launcher:hover' "launcher uses Awtarchy's strong hover treatment"
Assert-Contains $style '.dnd-widget:hover' "notification/DND action uses Awtarchy's strong hover treatment"
Assert-Contains $style 'font-size: 19px;' "notification/DND icon keeps Awtarchy's tuned icon scale"
Assert-Contains $style 'padding: 0 8px;' "fixed 8 px horizontal action padding is retained"

Assert-Contains $readme 'Evidence-backed mappings' "feature mappings document their evidence boundary"
Assert-Contains $readme 'Deliberate differences and omissions' "unsupported translations are documented"
Assert-Contains $style '.battery-widget .label.status-critical' "battery critical state has dedicated styling"
Assert-NotContains $style '.battery-widget .label.status-low' "battery low range is not incorrectly colored critical"
Assert-Contains $style '.battery-widget .label.status-charging' "battery charging selector matches YASB's native status-charging class"
Assert-NotContains $style '.battery-widget .label.charging' "dead non-native battery charging selector is not reintroduced"
Assert-Contains $style 'Awtarchy indicates charging with the bolt, not a separate color.' "charging battery keeps Awtarchy's normal foreground"
Assert-Contains $style '.bluetooth-menu .bluetooth-item' "Bluetooth popup rows use YASB's current bluetooth-item class"
Assert-Contains $style '.bluetooth-menu .bluetooth-item:hover' "Bluetooth popup hover styling targets YASB's current class"
Assert-NotContains $style '.bluetooth-menu .device' "stale Bluetooth popup device selector is not reintroduced"
Assert-Contains $style '.bluetooth-widget .icon.bt-off' "Bluetooth disabled state has explicit native-state styling"
Assert-Contains $style 'color: var(--muted);' "disabled Bluetooth uses Awtarchy's muted foreground"
$systrayBlocks = [regex]::Matches($style, '(?ms)^\.systray \{\r?\n.*?^\}')
if ($systrayBlocks.Count -lt 1) {
    throw "ASSERTION FAILED: dedicated systray styling block is missing"
}
$systrayBlock = $systrayBlocks[$systrayBlocks.Count - 1].Value
Assert-Contains $systrayBlock 'padding: 0;' "Awtarchy-style tray outer padding is removed"
Assert-Contains $style 'margin: 0 5px;' "tray buttons preserve 10 px inter-icon spacing"

Assert-Contains $readme 'CPU temperature' "CPU temperature is not silently substituted with another metric"
Assert-Contains $readme 'Clipboard History' "native clipboard-history mapping is documented"
Assert-Contains $readme 'Do Not Disturb' "notification-mute approximation is documented"
Assert-Contains $readme 'toggle-bar' "native YASB bar visibility mapping is documented"
Assert-Contains $readme 'theme.css' "live YASB theme mapping is documented"
Assert-Contains $readme 'Power & battery' "Windows-native battery details mapping is documented"
Assert-Contains $readme 'PowerPlanWidget' "native Windows power-plan option was evaluated instead of blindly scripted"
Assert-Contains $readme 'no wheel callback' "clock wheel limitation is documented from current YASB source"
Assert-Contains $readme 'exactly 15%' "shared YASB battery threshold edge is documented"
Assert-Contains $readme 'trailing `%`' "native YASB volume percent limitation is documented"
Assert-Contains $readme 'conditional label expression' "Bluetooth connected-name/count limitation is documented"
Assert-Contains $readme 'no connectivity CSS class' "network disconnected-color limitation is documented"
Assert-Contains $readme 'no separate open-only PowerMenu callback' "power-menu right-click limitation is documented"
Assert-Contains $readme 'one native tray monitor service' "multi-monitor systray behavior is documented from current YASB source"
Assert-Contains $readme 'no native image-tint option' "Awtarchy task/tray recoloring limitation is documented instead of faked"
Assert-Contains $readme 'visual preview cards' "theme-selector limitation versus Awtarchy is documented"
Assert-Contains $readme 'output discarded' "direct YASB theme-command diagnostic limitation is documented"
Assert-Contains $readme '#a1a1a1' "neutral GlazeWM border rationale is documented"
Assert-Contains $readme 'reload-free reservation model' "bar transition rationale avoids forced GlazeWM reload"

Write-Host "YASB parity checks passed." -ForegroundColor Green
