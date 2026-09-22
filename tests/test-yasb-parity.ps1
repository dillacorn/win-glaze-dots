$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$repoRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repoRoot "UserProfile\.config\yasb\config.yaml"
$workConfigPath = Join-Path $repoRoot "UserProfile\.config\yasb\custom_work_config.yaml"
$stylePath = Join-Path $repoRoot "UserProfile\.config\yasb\styles.css"
$readmePath = Join-Path $repoRoot "UserProfile\.config\yasb\README.md"
$glazeNormalPath = Join-Path $repoRoot "UserProfile\.glzr\glazewm\config.yaml"
$glazeWorkPath = Join-Path $repoRoot "UserProfile\.glzr\glazewm\custom_work_config.yaml"
$nativeSourcePath = Join-Path $repoRoot "wgdot\wgdot-native.cs"
$manifestPath = Join-Path $repoRoot "wgdot\manifest.json"

function Assert-Contains {
    param([string]$Text, [string]$Needle, [string]$Message)
    if (-not $Text.Contains($Needle)) { throw "ASSERTION FAILED: $Message" }
}

function Assert-NotContains {
    param([string]$Text, [string]$Needle, [string]$Message)
    if ($Text.Contains($Needle)) { throw "ASSERTION FAILED: $Message" }
}

foreach ($path in @($configPath, $workConfigPath, $stylePath, $readmePath, $glazeNormalPath, $glazeWorkPath, $nativeSourcePath, $manifestPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "ASSERTION FAILED: missing YASB parity file: $path"
    }
}

$config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8
$workConfig = Get-Content -LiteralPath $workConfigPath -Raw -Encoding UTF8
$style = Get-Content -LiteralPath $stylePath -Raw -Encoding UTF8
$readme = Get-Content -LiteralPath $readmePath -Raw -Encoding UTF8
$glazeNormal = Get-Content -LiteralPath $glazeNormalPath -Raw -Encoding UTF8
$glazeWork = Get-Content -LiteralPath $glazeWorkPath -Raw -Encoding UTF8
$nativeSource = Get-Content -LiteralPath $nativeSourcePath -Raw -Encoding UTF8
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8

Assert-Contains $config "height: 28" "bar height stays at Awtarchy horizontal default"
Assert-Contains $config "always_on_top: true" "YASB remains above normal windows without changing reservation models"
Assert-Contains $config "windows_app_bar: false" "YASB keeps the reload-free GlazeWM gap reservation"
Assert-Contains $config "hide_on_fullscreen: true" "YASB hides for fullscreen applications"
Assert-Contains $config "auto_hide: false" "normal YASB AppBar mode is explicit until runtime auto-hide is supported"
Assert-Contains $config "context_menu: false" "blank-bar YASB context menu is disabled; coordinated auto-hide remains on Alt+Ctrl+B"
Assert-Contains $config "align: `"center`"" "current YASB BarAlignment field is used"
Assert-NotContains $config "center: false" "obsolete bar alignment field is absent"
Assert-NotContains $config "acrylic:" "removed YASB blur field is absent"
Assert-Contains $config "enabled: false" "bar/task decorative animation has an explicit disabled state"
Assert-Contains $config "yasb.applications.ApplicationsWidget" "native YASB Applications widget is used for workspace move arrows"
Assert-Contains $config "class_name: `"awtarchy-launcher`"" "launcher uses the compiled Awtarchy-style YASB button"
Assert-Contains $config "wgdotw.exe launcher bar" "launcher button opens the compiled bar-relative search surface"
Assert-NotContains $config "keys: `"alt+p`"" "YASB does not globally capture Alt+P from noalt/VM guests"
Assert-NotContains $config "keys: `"win+d`"" "YASB does not globally capture Super+D outside GlazeWM ownership"
Assert-NotContains $config "keys: `"f24`"" "launcher does not use a synthetic F24 relay"
Assert-NotContains $config "keys: `"win+alt+d`"" "YASB does not globally capture Win+Alt+D"
Assert-Contains $config "wgdotw.exe power-menu" "normal YASB uses the compiled Awtarchy-style power surface"
Assert-Contains $config "glazewm.workspaces.GlazewmWorkspacesWidget" "native GlazeWM workspace widget is used"
Assert-Contains $config 'populated_label: "{display_name}"' "YASB workspace buttons render GlazeWM display_name values"
Assert-NotContains $config 'populated_label: "{name}"' "YASB does not override GlazeWM display_name with raw workspace names"
Assert-Contains $config "monitor_exclusive: true" "monitor-local workspace/task behavior is retained"
Assert-Contains $config "enable_scroll_switching: true" "workspace wheel switching is enabled"
Assert-NotContains $config "workspace_move_hub:" "retired workspace mover hub is absent"
Assert-NotContains $config "workspace_move_group:" "workspace arrows no longer need a fake hover parent"
Assert-Contains $config "`"workspace_move`"" "workspace arrows are rendered directly in the bar"
Assert-Contains $config "glazewm.exe command move-workspace --direction left" "workspace mover uses native GlazeWM commands"
Assert-NotContains $config "wgdotw.exe mouse-mode-toggle" "retired mouse-mode helper stays out of YASB"
Assert-Contains $config "horizontal_label: `"↔`"" "tiling direction uses an unambiguous horizontal arrow"
Assert-Contains $config "vertical_label: `"↕`"" "tiling direction uses an unambiguous vertical arrow"
Assert-Contains $config "glazewm.binding_mode.GlazewmBindingModeWidget" "native YASB binding-mode visibility is retained"
Assert-Contains $config "glazewm.tiling_direction.GlazewmTilingDirectionWidget" "native GlazeWM tiling direction state is visible and clickable"
Assert-Contains $config "noalt: `"`"" "noalt mode is visible in YASB again"
Assert-Contains $config "binding_modes_to_cycle_through: [`"none`", `"noalt`", `"vm`"]" "YASB exposes only native noalt and VM binding modes"
Assert-NotContains $config "glazewm_pause:" "pause is owned directly by GlazeWM instead of a helper widget"
Assert-Contains $glazeNormal "bindings: [`"lwin+alt+p`", `"rwin+alt+p`"]" "GlazeWM owns the real Alt+Super+P pause chord"
Assert-Contains $glazeNormal "commands: [`"wm-toggle-pause`"]" "pause uses GlazeWM's native command"
Assert-NotContains $config "glazewm-pause-status" "YASB no longer polls WGDot pause state"
Assert-Contains $config "yasb.control_center.ControlCenterWidget" "native YASB Control Center provides Awtarchy-style quick settings"
foreach ($profileEntry in @(
    @{ Name = "Normal"; Text = $config },
    @{ Name = "Work"; Text = $workConfig }
)) {
    $profileName = [string]$profileEntry.Name
    $profileText = [string]$profileEntry.Text

    foreach ($menuName in @("brightness_menu", "mic_menu", "audio_menu", "calendar")) {
        $menuPattern = "(?ms)^\s{6}" + [regex]::Escape($menuName) + ":.*?^\s{8}offset_top: 0\s*$"
        if ($profileText -notmatch $menuPattern) {
            throw "ASSERTION FAILED: $profileName $menuName must touch the YASB bar vertically"
        }
    }

    foreach ($widgetName in @("cpu", "memory", "wifi", "bluetooth")) {
        $widgetPattern = "(?ms)^\s{2}" + [regex]::Escape($widgetName) + ":.*?^\s{8}offset_top: 0\s*$"
        if ($profileText -notmatch $widgetPattern) {
            throw "ASSERTION FAILED: $profileName $widgetName popup/menu must touch the YASB bar vertically"
        }
    }

    $controlCenterPattern = "(?ms)^\s{2}control_center:.*?^\s{8}offset_top: 0\s*$"
    if ($profileText -notmatch $controlCenterPattern) {
        throw "ASSERTION FAILED: $profileName Control Center popup must touch the YASB bar vertically"
    }
}

Assert-Contains $config "keys: `"win+alt+backspace`"" "quick settings matches Awtarchy Super+Alt+Backspace"
Assert-NotContains $config "wgdot_running_apps" "running applications stay on instead of being a quick-setting toggle"
Assert-NotContains $config "wgdot_shade_apps" "broken running-app shading is removed"
Assert-Contains $config "wgdotw.exe theme-window-toggle" "quick settings uses the windowless theme-window toggle"
Assert-Contains $config "wgdotw.exe bar-autohide-toggle" "quick settings exposes compiled coordinated auto-hide"
Assert-Contains $config "wgdotw.exe glazewm-binding-mode-toggle" "console-subsystem mode actions use the windowless WGDot frontend"
Assert-NotContains $config "%USERPROFILE%\.config\win-glaze\scripts" "YASB ShellExecute commands do not rely on unexpanded percent-style USERPROFILE paths"

Assert-Contains $config "wgdotw.exe glazewm-binding-mode-toggle noalt" "quick settings enters NoAlt without a visible console"
Assert-Contains $config "wgdotw.exe glazewm-binding-mode-toggle vm" "quick settings enters VM without a visible console"
Assert-Contains $config "on_right: `"disable_binding_mode`"" "visible binding-mode label clears modes through YASB's native GlazeWM integration"
Assert-NotContains $config "glazewm-pause-toggle" "YASB has no WGDot pause helper"
Assert-NotContains $config "id: `"wgdot_mouse_mode`"" "mouse mode is not duplicated in quick settings"
Assert-NotContains $config "id: `"screenshot`"" "YASB screenshot action is removed in favor of Flameshot"
Assert-Contains $config "on_right: `"toggle_window`"" "taskbar right click uses YASB minimize/restore behavior"
Assert-Contains $config "label: `"{info[percent][total]} <span></span>`"" "CPU label matches Awtarchy's unitless integer plus glyph"
Assert-Contains $config "label: `"{virtual_mem_percent} <span></span>`"" "memory label matches Awtarchy's unitless integer plus glyph"
Assert-NotContains $config "label: `"{info[percent][total]}% <span></span>`"" "CPU bar label does not reintroduce a percent suffix"
Assert-NotContains $config "label: `"{virtual_mem_percent}% <span></span>`"" "memory bar label does not reintroduce a percent suffix"
Assert-Contains $config 'border_color: "None"' "YASB popup border_color values remain strings instead of invalid YAML nulls"
Assert-NotContains $config "border_color: None" "YASB popup configs do not use null border_color values"

Assert-Contains $config "icon_size: 14" "taskbar retains the 14 px Awtarchy icon size"
Assert-NotContains $config "`"systray`"," "systray is not rendered in the bar"
Assert-Contains $config "label_icon: false" "active window title remains text-only"
Assert-Contains $config "monitor_exclusive: false" "active window title follows the globally focused window like Awtarchy"
Assert-Contains $config "label_alt: `"class={win[class_name]} | exe={win[process][name]} | hwnd={win[hwnd]}`"" "active window click exposes class/process/HWND details"
Assert-Contains $config "on_left: `"toggle_label`"" "active window left click toggles details"
$brightnessBlock = [regex]::Match($config, '(?ms)^  brightness:\r?\n.*?(?=^  battery:)').Value
$batteryBlock = [regex]::Match($config, '(?ms)^  battery:\r?\n.*?(?=^  microphone:)').Value
Assert-Contains $brightnessBlock "yasb.brightness.BrightnessWidget" "brightness widget block is discoverable"
Assert-Contains $brightnessBlock "label: `"<span>{icon}</span> {percent}%`"" "brightness retains Awtarchy's explicit percent suffix"
if (([regex]::Matches($brightnessBlock, '')).Count -ne 4) {
    throw "ASSERTION FAILED: brightness uses the fixed sun glyph in all four native YASB slots"
}
Assert-Contains $brightnessBlock "ddc_poll_interval: 60" "brightness uses native YASB DDC polling"
Assert-Contains $batteryBlock "yasb.battery.BatteryWidget" "battery widget block is discoverable"
Assert-Contains $batteryBlock "exec explorer.exe ms-settings:powersleep" "battery clicks open Windows Power and battery settings without cmd.exe"
Assert-Contains $batteryBlock "label: `"<span>{icon}</span> {percent}`"" "battery bar label matches Awtarchy's unitless integer"
Assert-NotContains $batteryBlock "label: `"<span>{icon}</span> {percent}%`"" "battery bar label does not reintroduce a percent suffix"
Assert-Contains $batteryBlock "icon_format: `"{icon} {charging_icon}`"" "plugged-in battery retains the battery glyph and adds the charging bolt"
Assert-Contains $batteryBlock "critical: 15" "battery critical color begins at Awtarchy's 15 percent boundary"
Assert-Contains $batteryBlock "low: 39" "battery low band ends at 39 like Awtarchy"
Assert-Contains $batteryBlock "medium: 64" "battery medium band ends at 64 like Awtarchy"
Assert-Contains $batteryBlock "high: 89" "battery high band ends at 89 like Awtarchy"
Assert-Contains $batteryBlock "on_middle: `"toggle_label`"" "battery middle click retains YASB alternate battery label"
$volumeBlock = [regex]::Match($config, '(?ms)^  volume:\r?\n.*?(?=^  clock:)').Value
Assert-Contains $volumeBlock "scroll_step: 5" "volume wheel changes by the same five points as current Awtarchy"
Assert-Contains $volumeBlock "muted: `"`"" "volume muted glyph matches current Awtarchy"
Assert-Contains $volumeBlock "`"24`": `"`"" "volume low icon ends at 24 like Awtarchy's <25 threshold"
Assert-Contains $volumeBlock "`"59`": `"`"" "volume medium icon ends at 59 like Awtarchy's <60 threshold"
Assert-Contains $volumeBlock "`"100`": `"`"" "volume high icon covers the remaining range"
Assert-NotContains $volumeBlock "`"10`": `"`"" "old YASB default low-volume cutoff is removed"
Assert-NotContains $volumeBlock "`"30`": `"`"" "old YASB default medium-volume cutoff is removed"
Assert-Contains $config "use_hook: false" "systray avoids explorer DLL injection"
Assert-NotContains $config "use_hook: true" "systray DLL injection is never enabled"
$clockBlock = [regex]::Match($config, '(?ms)^  clock:\r?\n.*?(?=^  wifi:)').Value
$wifiBlock = [regex]::Match($config, '(?ms)^  wifi:\r?\n.*?(?=^  bluetooth:)').Value
$bluetoothBlock = [regex]::Match($config, '(?ms)^  bluetooth:\r?\n.*?(?=^  systray:)').Value
Assert-Contains $clockBlock "{%a %#m/%#d}" "clock alternate date matches Awtarchy's non-zero-padded M/d"
Assert-Contains $wifiBlock "`"󰤯`"" "Wi-Fi zero-strength glyph matches Awtarchy"
Assert-Contains $wifiBlock "ethernet_icon: `"󰈀`"" "active Ethernet glyph matches Awtarchy"
Assert-Contains $bluetoothBlock "bluetooth_on: `"`"" "Bluetooth enabled glyph matches Awtarchy"
Assert-Contains $bluetoothBlock "bluetooth_off: `"`"" "Bluetooth disabled keeps Awtarchy's single glyph"
Assert-Contains $bluetoothBlock "bluetooth_connected: `"`"" "Bluetooth connected keeps Awtarchy's single glyph"
Assert-Contains $wifiBlock "on_left: `"exec explorer.exe ms-settings:network-status`"" "Wi-Fi/Ethernet opens native Windows Network settings"
Assert-NotContains $wifiBlock "on_left: `"toggle_menu`"" "Wi-Fi/Ethernet YASB mini menu is retired"
Assert-Contains $bluetoothBlock "on_left: `"exec explorer.exe ms-settings:bluetooth`"" "Bluetooth opens native Windows Bluetooth settings"
Assert-NotContains $bluetoothBlock "on_left: `"toggle_menu`"" "Bluetooth YASB mini menu is retired"

$clipboardBlock = [regex]::Match($config, '(?ms)^  clipboard_history:\r?\n.*?(?=^  dnd:)').Value
Assert-Contains $clipboardBlock "yasb.custom.CustomWidget" "clipboard history uses a dedicated lightweight bar control"
Assert-Contains $clipboardBlock "wgdotw.exe clipboard-history-open" "clipboard button opens native Clipboard History without owning a keyboard shortcut"
Assert-Contains $config "`"clipboard_history`"" "clipboard history button is rendered on the bar"
Assert-NotContains $config "`"idle_inhibitor`"" "retired idle inhibitor is not rendered"
Assert-Contains $config "brightness_icons: [`"`", `"`", `"`", `"`"]" "brightness uses a fixed sun icon"
$launcherBlock = [regex]::Match($config, '(?ms)^  launcher:\r?\n.*?(?=^  glazewm_workspaces:)').Value
Assert-Contains $launcherBlock "yasb.custom.CustomWidget" "launcher bar button stays a lightweight YASB custom widget"
Assert-Contains $launcherBlock "class_name: `"awtarchy-launcher`"" "launcher bar button has dedicated styling"
Assert-Contains $launcherBlock "wgdotw.exe launcher bar" "launcher bar button opens the context-aware compiled surface"
Assert-Contains $config "wgdotw.exe power-menu" "normal YASB power uses the compiled surface"
Assert-Contains $workConfig "wgdotw.exe power-menu" "Work YASB power uses the compiled surface"
Assert-NotContains $config ".ps1" "Normal YASB has no script-file runtime dependency"
Assert-NotContains $workConfig ".ps1" "Work YASB has no script-file runtime dependency"
Assert-Contains $config 'on_left: "disable_binding_mode"' "binding-mode label disables the active mode instead of cycling"
Assert-NotContains $config "next_binding_mode" "binding-mode label does not cycle NoAlt to Mouse to VM"

Assert-Contains $config "yasb.dnd.DndWidget" "unified notifications and Do Not Disturb control uses native YASB DND"
Assert-NotContains $config "yasb.notifications.NotificationsWidget" "separate Notifications widget stays removed after DND unification"
Assert-Contains $config "on_left: `"exec notification_center`"" "unified DND left click opens Windows Notification Center through YASB native exec mapping"
Assert-Contains $config "on_right: `"toggle_status`"" "unified DND right click uses its native DND toggle callback"
Assert-Contains $config 'on_right: "exec wgdotw.exe eartrumpet-mixer-toggle"' "volume right click triggers EarTrumpet's application-owned mixer hotkey"
Assert-NotContains $config "shell:AppsFolder" "YASB no longer uses direct AppsFolder activation for EarTrumpet mixer toggling"
Assert-Contains $config "normal: `"`"" "unmuted microphone glyph is collapsed like Awtarchy"
$mutedMicBlock = [regex]::Match($style, '(?ms)^\.microphone-widget \.label\.muted,\r?\n\.microphone-widget \.icon\.muted \{\r?\n.*?^\}').Value
Assert-Contains $mutedMicBlock "padding: 0 8px;" "muted microphone keeps Awtarchy's 8 px horizontal control padding"
Assert-Contains $style ".microphone-widget .icon.muted" "muted microphone state has dedicated styling"
Assert-Contains $style "--muted: #5c5c5c;" "fallback palette matches Awtarchy Carbon Night"
Assert-Contains $style "@import `"theme.css`";" "YASB imports the managed live theme palette"
Assert-Contains $manifest "`"id`": `"yasb-theme`"" "theme.css is a normal managed dotfile"
Assert-NotContains $manifest "`"id`": `"desktop-scripts`"" "obsolete desktop script component is not deployed"
Assert-NotContains $manifest "theme-switcher.ps1" "manifest does not deploy the retired theme script"
Assert-NotContains $manifest "bar-autohide.ps1" "manifest does not deploy the retired auto-hide script"
Assert-NotContains $manifest "idle-inhibitor.ps1" "manifest does not deploy the retired idle script"
Assert-NotContains $manifest "rawaccel-toggle.ps1" "manifest does not deploy the retired RawAccel script"
Assert-NotContains $manifest "`"type`": `"ensure-yasb-theme`"" "theme lifecycle no longer requires a WGDot post-action"
$powerBlock = [regex]::Match($config, '(?ms)^  power_menu:\r?\n.*$').Value
Assert-Contains $powerBlock "yasb.custom.CustomWidget" "power button stays a lightweight YASB custom control"
Assert-Contains $powerBlock "wgdotw.exe power-menu" "power button opens the compiled Awtarchy-style surface"
Assert-Contains $powerBlock 'tooltip_label: "Power menu (L/H/R/S/O/Z)"' "power button documents the keyboard action keys"
Assert-NotContains $config "theme_picker:" "themes live in quick settings instead of a standalone bar button"
Assert-NotContains $manifest "`"id`": `"script-theme-switcher`"" "theme toggle is no longer provided by a runtime script"
Assert-Contains $glazeNormal "window_title: { equals: `"Win Glaze Themes`" }" "theme selector has a stable floating title"
Assert-Contains $glazeNormal "wgdotw.exe theme-window-toggle" "Normal GlazeWM uses the windowless theme-window toggle"
Assert-Contains $glazeNormal "wgdotw.exe power-menu" "GlazeWM Super+P opens the compiled power surface"
Assert-Contains $manifest "UserProfile/.config/yasb/theme.css" "theme.css is portable with the dotfiles"
foreach ($themeId in @(
    'carbon-night',
    'catppuccin-frappe',
    'crimson-red',
    'electric-blue',
    'gruvbox',
    'iron-forge',
    'obsidian-night',
    'pink',
    'pipboy'
)) {
    Assert-Contains -Text $nativeSource -Needle $themeId -Message "compiled WGDot owns expected Awtarchy palette id"
}
Assert-Contains -Text $nativeSource -Needle '"#353535", "#d0d0d0"' -Message "Carbon Night palette stays aligned with Awtarchy"
Assert-Contains -Text $nativeSource -Needle '"#1e1e2e", "#89b4fa"' -Message "Electric Blue palette stays aligned with Awtarchy"
Assert-Contains -Text $nativeSource -Needle "ApplyWindowsTerminalTheme" -Message "compiled theme manager owns Windows Terminal synchronization"
Assert-Contains -Text $nativeSource -Needle "GlazeWM was not reloaded" -Message "compiled theme manager explicitly avoids GlazeWM reload"

foreach ($glaze in @($glazeNormal, $glazeWork)) {
    Assert-Contains $glaze "top: `"35px`"" "GlazeWM uses the requested 35 px top reservation"
    Assert-NotContains $glaze "top: `"8px`"" "bar redesign does not require live GlazeWM gap migration"
    Assert-Contains $glaze "shell-exec yasb" "GlazeWM starts YASB"
    Assert-Contains $glaze "color: `"#a1a1a1`"" "focused GlazeWM border stays theme-neutral"
    Assert-Contains $glaze "bindings: [`"lwin+alt+t`", `"rwin+alt+t`"]" "Super+Alt+T opens the compiled theme selector"
    Assert-NotContains $glaze "bindings: [`"lwin+c`", `"rwin+c`"]" "retired Super+C Clipboard History override stays absent"
    Assert-NotContains $glaze "clipboard-anchor" "retired Clipboard History hotkey handoff stays absent"
    Assert-NotContains $glaze "EarTrumpet_1sdd7yawvg6ne!EarTrumpet" "GlazeWM leaves EarTrumpet activation to the app's own Alt+V hotkey"
    Assert-NotContains $glaze "bindings: [`"alt+v`", `"lwin+v`", `"rwin+v`"]" "native Super+V Clipboard History and EarTrumpet Alt+V are not captured by GlazeWM"
    Assert-NotContains $glaze "bindings: [`"lwin+shift+x`", `"rwin+shift+x`"]" "GlazeWM leaves Super+Shift+X to Flameshot's own hotkey"
    Assert-NotContains $glaze "bindings: [`"lwin+alt+s`", `"rwin+alt+s`"]" "retired GlazeWM Super+Alt+S Flameshot binding stays absent"
    Assert-NotContains $glaze "bindings: [`"lwin+shift+s`", `"rwin+shift+s`"]" "Super+Shift+S remains native Windows Snipping Tool"
    Assert-NotContains $glaze "Flameshot\\bin\\flameshot.exe" "GlazeWM does not launch Flameshot directly"
    Assert-Contains $glaze "bindings: [`"lwin+p`", `"rwin+p`"]" "GlazeWM owns Super+P for the compiled power surface"
    Assert-Contains $glaze "name: `"noalt`"" "noalt mode is retained"
    Assert-NotContains $glaze "name: `"mouse`"" "retired mouse binding mode stays removed"
    Assert-NotContains $glaze "bindings: [`"lwin+alt+m`", `"rwin+alt+m`"]" "retired Super+Alt+M mouse binding stays removed"
    Assert-Contains $glaze "name: `"vm`"" "VM mode is retained"
    Assert-Contains $glaze "wm-enable-binding-mode --name noalt" "NoAlt transitions use native GlazeWM commands"
    Assert-Contains $glaze "wm-enable-binding-mode --name vm" "VM transitions use native GlazeWM commands"
    Assert-Contains $glaze "wm-disable-binding-mode --name" "binding modes have native GlazeWM escape commands"
    Assert-Contains $glaze "commands: [`"wm-toggle-pause`"]" "real GlazeWM pause uses the native command"
    Assert-Contains $glaze "bindings: [`"lwin+alt+p`", `"rwin+alt+p`"]" "real pause uses Alt+Super+P"
    Assert-Contains $glaze "bindings: [`"alt+t`", `"lwin+t`", `"rwin+t`"]" "global Alt+T and Super+T toggle tiling"
    Assert-Contains $glaze "bindings: [`"lwin+alt+t`", `"rwin+alt+t`"]" "theme hotkey remains available"
    Assert-Contains $glaze "window_title: { equals: `"Win Glaze Themes`" }" "theme selector has a dedicated floating title"
    Assert-Contains $glaze "window_process: { regex: `"^WindowsTerminal(\\.exe)?`$`" }" "theme selector floating rule is scoped to Windows Terminal"
    Assert-Contains $glaze "wgdotw.exe power-menu" "GlazeWM routes Super+P through the approved compiled power surface"
    Assert-Contains $glaze "wgdotw.exe launcher hotkey" "GlazeWM routes launcher hotkeys through the approved compiled surface"
    Assert-NotContains $glaze "yasbc toggle-bar" "unsafe hard-hide command is not bound from GlazeWM"
    Assert-Contains $glaze "bindings: [`"alt+ctrl+b`"]" "GlazeWM retains coordinated auto-hide binding"
    Assert-Contains $glaze "bindings: [`"alt+ctrl+b`"]" "Alt+Ctrl+B toggles coordinated auto-hide"
    Assert-NotContains $glaze "lwin+alt+ctrl+b" "unused Awtarchy Win+Alt+Ctrl+B chord is not added"
    Assert-NotContains $glaze "rwin+alt+ctrl+b" "unused Awtarchy Win+Alt+Ctrl+B chord is not added"
    Assert-NotContains $glaze "Stop-Process -Name yasb -Force" "bar visibility no longer kills the YASB process"
    Assert-NotContains $glaze "bindings: [`"lwin`", `"rwin`"]" "GlazeWM does not rely on ineffective bare-Super bindings"
    Assert-Contains $glaze "bindings: [`"lwin+1`", `"rwin+1`"]" "Super+number workspace focus survives noalt"
    Assert-Contains $glaze "bindings: [`"lwin+shift+1`", `"rwin+shift+1`"]" "Super+Shift+number workspace move survives noalt"
    Assert-NotContains $glaze "yasb-quick-launch.ps1" "GlazeWM has no YASB synthetic-key launcher bridge"
    Assert-NotContains $glaze "flow-launcher.ps1" "GlazeWM has no Flow launcher helper bridge"
}

Assert-NotContains $glazeNormal "yasb-quick-launch.ps1" "Normal GlazeWM has no YASB launcher relay"
Assert-Contains $glazeNormal "bindings: [`"alt+p`", `"lwin+d`", `"rwin+d`"]" "Normal GlazeWM maps Alt+P and Super+D to the compiled launcher"
Assert-Contains $glazeWork "bindings: [`"alt+p`", `"lwin+d`", `"rwin+d`"]" "Work GlazeWM maps Alt+P and Super+D to the compiled launcher"
Assert-NotContains $glazeWork "FlowLauncher/Flow.Launcher.exe" "Work launcher hotkeys no longer default to Flow Launcher"
Assert-NotContains $glazeNormal ".ps1" "Normal GlazeWM has no script-file runtime dependency"
Assert-NotContains $glazeWork ".ps1" "Work GlazeWM has no script-file runtime dependency"
Assert-Contains $glazeNormal "wgdotw.exe rawaccel-toggle" "Normal RawAccel uses the scoped compiled helper"
Assert-Contains $glazeWork "wgdotw.exe rawaccel-toggle" "Work RawAccel uses the scoped compiled helper"
Assert-NotContains $glazeNormal "wgdotw.exe mouse-mode-toggle" "Normal profile has no retired mouse helper"
Assert-NotContains $glazeWork "wgdotw.exe mouse-mode-toggle" "Work profile has no retired mouse helper"
Assert-Contains $glazeNormal "focus_follows_cursor: true" "Normal profile follows cursor focus by default"
Assert-Contains $glazeWork "focus_follows_cursor: false" "Work profile keeps click-focused behavior"
Assert-Contains $glazeWork "wgdotw.exe bar-autohide-toggle" "Work auto-hide uses the compiled helper"
Assert-Contains $glazeWork "wgdotw.exe theme-window-toggle" "Work theme selection uses the windowless theme-window toggle"
Assert-Contains $glazeWork "wgdotw.exe launcher hotkey" "Work GlazeWM uses the compiled launcher surface"

Assert-NotContains $config "komorebi" "abandoned Komorebi integration is absent"
Assert-NotContains $config "whkd" "whkd is not introduced"

foreach ($widgetType in @(
    'yasb.cpu.CpuWidget',
    'yasb.memory.MemoryWidget',
    'yasb.control_center.ControlCenterWidget',
    'yasb.brightness.BrightnessWidget',
    'yasb.battery.BatteryWidget',
    'yasb.microphone.MicrophoneWidget',
    'yasb.volume.VolumeWidget',
    'yasb.clock.ClockWidget',
    'yasb.wifi.WifiWidget',
    'yasb.bluetooth.BluetoothWidget',
    'yasb.systray.SystrayWidget',
    'yasb.dnd.DndWidget'
)) {
    Assert-Contains $config $widgetType "supported YASB widget is present: $widgetType"
}

Assert-Contains -Text $style -Needle ".glazewm-workspaces .ws-btn.empty" -Message "inactive empty workspace buttons collapse"
Assert-Contains -Text $style -Needle "min-height: 28px;" -Message "workspace shading spans the full 28 px bar height"
Assert-Contains -Text $style -Needle "margin-left: 2px;" -Message "CPU and memory icons have a tiny separation from their values"
Assert-Contains -Text $style -Needle ".tooltip," -Message "YASB custom rich tooltips receive an opaque themed background"
Assert-Contains -Text $style -Needle "#353535" -Message "Awtarchy background color is retained"
Assert-Contains -Text $style -Needle "#d0d0d0" -Message "Awtarchy foreground color is retained"
Assert-Contains -Text $style -Needle "#ff5555" -Message "Awtarchy critical color is retained"
Assert-Contains -Text $style -Needle "NotoSansM NFM" -Message "Awtarchy Noto Nerd Font uses its embedded Windows family in YASB"
Assert-NotContains -Text $style -Needle "\"NotoSansM Nerd Font Mono\"" -Message "YASB does not request the non-existent verbose Windows Noto family"
Assert-Contains -Text $style -Needle "JetBrainsMono NFP" -Message "JetBrains Mono Nerd Font remains the fallback glyph family"
$taskContainerBlock = [regex]::Match($style, "(?ms)^\.taskbar-widget \.app-container \{\r?\n.*?^\}").Value
Assert-Contains -Text $taskContainerBlock -Needle "min-width: 14px;" -Message "task content width matches its 14 px icon"
Assert-Contains -Text $taskContainerBlock -Needle "max-width: 14px;" -Message "task content width remains fixed"
Assert-Contains -Text $taskContainerBlock -Needle "padding: 0 6px;" -Message "task slot keeps 26 px total width"
Assert-NotContains -Text $style -Needle ".workspace-move-hub" -Message "retired workspace hub styling is absent"
Assert-NotContains -Text $style -Needle ".workspace-move-grouper" -Message "workspace arrows no longer depend on a fake hover parent"
Assert-Contains -Text $style -Needle ".workspace-move-buttons .widget-container" -Message "workspace arrow container remains styled"
Assert-Contains -Text $style -Needle ".workspace-move-buttons .label" -Message "workspace arrows remain directly visible"
Assert-Contains -Text $style -Needle "padding: 0 7px;" -Message "workspace arrows keep compact button spacing"
Assert-Contains -Text $style -Needle ".awtarchy-launcher .icon" -Message "compiled launcher button icon is styled"
Assert-Contains -Text $style -Needle ".awtarchy-launcher .widget-container" -Message "compiled launcher gets a stable button-width contract"
Assert-Contains -Text $style -Needle ".awtarchy-launcher .label" -Message "compiled launcher glyph gets horizontal breathing room"
Assert-Contains -Text $style -Needle ".awtarchy-launcher:hover" -Message "compiled launcher button has strong hover treatment"
Assert-Contains -Text $style -Needle ".awtarchy-control-center:hover" -Message "quick settings has strong hover treatment"
Assert-Contains -Text $style -Needle ".control-center-menu" -Message "Control Center popup uses shared theme styling"
Assert-Contains -Text $style -Needle "@import `"appearance.css`";" -Message "styles import portable appearance overrides"
Assert-Contains -Text $style -Needle ".dnd-widget:hover" -Message "DND action has strong hover treatment"
$iconScaleBlock = [regex]::Match(
    $style,
    "(?ms)/\* Match Awtarchy's tuned Nerd Font glyph sizes.*?^\.awtarchy-power \.icon \{\r?\n    font-size: 20px;\r?\n\}"
).Value
Assert-Contains -Text $iconScaleBlock -Needle ".cpu-widget .icon" -Message "CPU glyph participates in Awtarchy icon scaling"
Assert-Contains -Text $iconScaleBlock -Needle ".brightness-widget .icon" -Message "brightness glyph participates in Awtarchy icon scaling"
Assert-Contains -Text $iconScaleBlock -Needle "font-size: 18px;" -Message "generic Awtarchy bar glyphs use 18 px"
Assert-Contains -Text $iconScaleBlock -Needle ".battery-widget .icon" -Message "battery glyph has dedicated scaling"
Assert-Contains -Text $iconScaleBlock -Needle "font-size: 17px;" -Message "battery glyph matches Awtarchy's 17 px tuning"
Assert-Contains -Text $iconScaleBlock -Needle ".volume-widget .icon" -Message "volume glyph has dedicated scaling"
Assert-Contains -Text $iconScaleBlock -Needle ".dnd-widget .icon" -Message "DND glyph has dedicated scaling"
Assert-Contains -Text $iconScaleBlock -Needle "font-size: 19px;" -Message "DND glyph matches Awtarchy's 19 px tuning"
Assert-Contains -Text $iconScaleBlock -Needle ".awtarchy-power .icon" -Message "power glyph has dedicated scaling"
Assert-Contains -Text $style -Needle ".awtarchy-launcher .label" -Message "launcher glyph keeps a dedicated size contract"
Assert-Contains -Text $style -Needle "font-size: 18px;" -Message "launcher/generic glyph sizing is present"
Assert-Contains -Text $style -Needle "padding: 0 8px;" -Message "fixed action padding is retained"

Assert-Contains -Text $readme -Needle "Evidence-backed mappings" -Message "feature mappings document their evidence boundary"
Assert-Contains -Text $readme -Needle "Deliberate differences and omissions" -Message "unsupported translations are documented"
Assert-Contains -Text $style -Needle ".battery-widget .label.status-critical" -Message "battery critical state has dedicated styling"
Assert-NotContains -Text $style -Needle ".battery-widget .label.status-low" -Message "battery low range is not colored critical"
Assert-Contains -Text $style -Needle ".battery-widget .label.status-charging" -Message "battery charging selector matches native class"
Assert-NotContains -Text $style -Needle ".battery-widget .label.charging" -Message "dead battery charging selector is absent"
Assert-Contains -Text $style -Needle "Awtarchy indicates charging with the bolt, not a separate color." -Message "charging battery keeps normal foreground"
Assert-Contains -Text $style -Needle ".bluetooth-menu .bluetooth-item" -Message "Bluetooth popup rows use current class"
Assert-Contains -Text $style -Needle ".bluetooth-menu .bluetooth-item:hover" -Message "Bluetooth popup hover uses current class"
Assert-NotContains -Text $style -Needle ".bluetooth-menu .device" -Message "stale Bluetooth selector is absent"
Assert-Contains -Text $style -Needle ".bluetooth-widget .icon.bt-off" -Message "Bluetooth disabled state has explicit styling"
Assert-Contains -Text $style -Needle "color: var(--muted);" -Message "disabled Bluetooth uses muted foreground"
$systrayBlocks = [regex]::Matches($style, "(?ms)^\.systray \{\r?\n.*?^\}")
if ($systrayBlocks.Count -lt 1) {
    throw "ASSERTION FAILED: dedicated systray styling block is missing"
}
$systrayBlock = $systrayBlocks[$systrayBlocks.Count - 1].Value
Assert-Contains -Text $systrayBlock -Needle "padding: 0;" -Message "tray outer padding is removed"
Assert-Contains -Text $style -Needle "margin: 0 5px;" -Message "tray buttons preserve inter-icon spacing"

Assert-Contains -Text $readme -Needle "WGDot manages installation, updates, backups, and deployment" -Message "management/runtime boundary is documented"
Assert-Contains -Text $readme -Needle "hybrid" -Message "hybrid runtime ownership is documented"
Assert-Contains -Text $readme -Needle "wgdotw.exe launcher bar" -Message "compiled launcher bar ownership is documented"
Assert-Contains -Text $readme -Needle "Alt+P" -Message "compiled launcher hotkeys are documented"
Assert-NotContains -Text $readme -Needle "Flow Launcher remains optional" -Message "retired Flow Launcher is no longer advertised by YASB docs"
Assert-Contains -Text $readme -Needle 'no `.ps1` runtime dependencies' -Message "script-free Normal and Work runtime is documented"
Assert-Contains -Text $readme -Needle "wgdot.exe theme" -Message "compiled theme selector is documented"
Assert-Contains -Text $readme -Needle "wgdotw.exe bar-autohide-toggle" -Message "compiled coordinated auto-hide is documented"
Assert-Contains -Text $readme -Needle "wgdotw.exe rawaccel-toggle" -Message "compiled RawAccel toggle is documented"
Assert-Contains -Text $readme -Needle "wgdotw.exe power-menu" -Message "compiled Awtarchy-style power ownership is documented"
Assert-Contains -Text $readme -Needle "EarTrumpet owns Alt+V itself" -Message "EarTrumpet native Alt+V ownership is documented"
Assert-Contains -Text $readme -Needle "Super+V stays native Windows Clipboard History" -Message "native Super+V Clipboard History ownership is documented"
Assert-Contains -Text $readme -Needle "clipboard-history-open" -Message "bar-only Clipboard History helper is documented"
Assert-Contains -Text $readme -Needle "experimental mouse binding mode" -Message "retired mouse binding mode is documented"
Assert-Contains -Text $readme -Needle "CPU temperature" -Message "CPU temperature is not silently substituted with another metric"
Assert-Contains -Text $readme -Needle "Do Not Disturb" -Message "notification/DND mapping is documented"
Assert-Contains -Text $readme -Needle "theme.css" -Message "live YASB theme mapping is documented"
Assert-Contains -Text $readme -Needle "exactly 15%" -Message "shared YASB battery threshold edge is documented"
Assert-Contains -Text $readme -Needle "plugged-in-but-not-charging" -Message "YASB AC-only battery color limitation is documented"
Assert-Contains -Text $readme -Needle "trailing ``%``" -Message "native YASB volume percent limitation is documented"
Assert-Contains -Text $readme -Needle "conditional primary-label expression" -Message "Bluetooth connected-name/count limitation is documented"
Assert-Contains -Text $readme -Needle "no bar-label connectivity CSS class" -Message "network disconnected-color limitation is documented"
Assert-Contains -Text $readme -Needle "#a1a1a1" -Message "neutral GlazeWM border rationale is documented"
Assert-Contains -Text $readme -Needle "does **not** reload GlazeWM" -Message "theme changes remain reload-free"

Write-Host "YASB parity checks passed." -ForegroundColor Green
