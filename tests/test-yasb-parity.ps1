$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$repoRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repoRoot "UserProfile\.config\yasb\config.yaml"
$workConfigPath = Join-Path $repoRoot "UserProfile\.config\yasb\custom_work_config.yaml"
$stylePath = Join-Path $repoRoot "UserProfile\.config\yasb\styles.css"
$readmePath = Join-Path $repoRoot "UserProfile\.config\yasb\README.md"
$glazeNormalPath = Join-Path $repoRoot "UserProfile\.glzr\glazewm\config.yaml"
$glazeWorkPath = Join-Path $repoRoot "UserProfile\.glzr\glazewm\custom_work_config.yaml"
$themeScriptPath = Join-Path $repoRoot "UserProfile\.config\win-glaze\scripts\theme-switcher.ps1"
$manifestPath = Join-Path $repoRoot "wgdot\manifest.json"

function Assert-Contains {
    param([string]$Text, [string]$Needle, [string]$Message)
    if (-not $Text.Contains($Needle)) { throw "ASSERTION FAILED: $Message" }
}

function Assert-NotContains {
    param([string]$Text, [string]$Needle, [string]$Message)
    if ($Text.Contains($Needle)) { throw "ASSERTION FAILED: $Message" }
}

foreach ($path in @($configPath, $workConfigPath, $stylePath, $readmePath, $glazeNormalPath, $glazeWorkPath, $themeScriptPath, $manifestPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "ASSERTION FAILED: missing YASB parity file: $path"
    }
}

$config = Get-Content -LiteralPath $configPath -Raw
$workConfig = Get-Content -LiteralPath $workConfigPath -Raw
$style = Get-Content -LiteralPath $stylePath -Raw
$readme = Get-Content -LiteralPath $readmePath -Raw
$glazeNormal = Get-Content -LiteralPath $glazeNormalPath -Raw
$glazeWork = Get-Content -LiteralPath $glazeWorkPath -Raw
$themeScript = Get-Content -LiteralPath $themeScriptPath -Raw
$manifest = Get-Content -LiteralPath $manifestPath -Raw

Assert-Contains $config 'height: 28' "bar height stays at Awtarchy horizontal default"
Assert-Contains $config 'always_on_top: true' "YASB remains above normal windows without changing reservation models"
Assert-Contains $config 'windows_app_bar: false' "YASB keeps the reload-free GlazeWM gap reservation"
Assert-Contains $config 'hide_on_fullscreen: true' "YASB hides for fullscreen applications"
Assert-Contains $config 'auto_hide: false' "normal YASB AppBar mode is explicit until runtime auto-hide is supported"
Assert-Contains $config 'context_menu: false' "blank-bar YASB context menu is disabled; coordinated auto-hide remains on Alt+Ctrl+B"
Assert-Contains $config 'align: "center"' "current YASB BarAlignment field is used"
Assert-NotContains $config 'center: false' "obsolete bar alignment field is absent"
Assert-NotContains $config 'acrylic:' "removed YASB blur field is absent"
Assert-Contains $config 'enabled: false' "bar/task decorative animation has an explicit disabled state"
Assert-Contains $config 'yasb.applications.ApplicationsWidget' "native YASB Applications widget is used for workspace mouse controls"
Assert-Contains $config 'yasb.quick_launch.QuickLaunchWidget' "launcher uses native YASB Quick Launch"
Assert-Contains $config 'search_placeholder: "Search applications..."' "Quick Launch defaults to installed-application search"
Assert-NotContains $config 'keys: "alt+p"' "YASB does not globally capture Alt+P from VM guests"
Assert-NotContains $config 'keys: "win+d"' "YASB does not globally capture Super+D from VM guests"
Assert-Contains $config 'keys: "f24"' "YASB Quick Launch uses a private F24 bridge"
Assert-NotContains $config 'keys: "win+alt+d"' "YASB does not globally capture Win+Alt+D"
Assert-NotContains $config 'wgdot' "normal YASB has no WGDot runtime dependency"
Assert-Contains $config 'glazewm.workspaces.GlazewmWorkspacesWidget' "native GlazeWM workspace widget is used"
Assert-Contains $config 'monitor_exclusive: true' "monitor-local workspace/task behavior is retained"
Assert-Contains $config 'enable_scroll_switching: true' "workspace wheel switching is enabled"
Assert-Contains $config 'yasb.grouper.GrouperWidget' "workspace mover uses a passive Grouper hover container"
Assert-Contains $config 'class_name: "workspace-move-grouper"' "workspace mover hover container has a dedicated class"
Assert-Contains $config 'collapse_options:' "workspace mover declares Grouper collapse behavior explicitly"
Assert-Contains $config 'enabled: false' "workspace mover keeps Grouper click-collapse disabled"
Assert-Contains $config 'glazewm.exe command move-workspace --direction left' "workspace mover uses native GlazeWM commands"
Assert-NotContains $config 'workspace_mouse:' "YASB does not require the removed WGDot mouse-mode runtime"
Assert-NotContains $config 'mouse-mode-toggle' "YASB has no mouse-mode helper dependency"
Assert-Contains $config 'horizontal_label: "↔"' "tiling direction uses an unambiguous horizontal arrow"
Assert-Contains $config 'vertical_label: "↕"' "tiling direction uses an unambiguous vertical arrow"
Assert-Contains $config 'glazewm.binding_mode.GlazewmBindingModeWidget' "native YASB binding-mode visibility is retained"
Assert-Contains $config 'glazewm.tiling_direction.GlazewmTilingDirectionWidget' "native GlazeWM tiling direction state is visible and clickable"
Assert-Contains $config 'noalt: ""' "noalt mode is visible in YASB again"
Assert-Contains $config 'binding_modes_to_cycle_through: ["none", "noalt", "vm"]' "YASB exposes native noalt and VM binding modes"
Assert-NotContains $config 'glazewm_pause:' "pause is owned directly by GlazeWM instead of a helper widget"
Assert-Contains $glazeNormal 'bindings: ["lwin+alt+p", "rwin+alt+p"]' "GlazeWM owns the real Alt+Super+P pause chord"
Assert-Contains $glazeNormal 'commands: ["wm-toggle-pause"]' "pause uses GlazeWM's native command"
Assert-NotContains $config 'glazewm-pause-status' "YASB no longer polls WGDot pause state"
Assert-Contains $config 'run_interval: 250' "idle inhibitor state refreshes quickly after a click"
Assert-Contains $config 'yasb.control_center.ControlCenterWidget' "native YASB Control Center provides Awtarchy-style quick settings"
Assert-Contains $config 'keys: "win+alt+backspace"' "quick settings matches Awtarchy Super+Alt+Backspace"
Assert-NotContains $config 'wgdot_running_apps' "running applications stay on instead of being a quick-setting toggle"
Assert-NotContains $config 'wgdot_shade_apps' "broken running-app shading is removed"
Assert-Contains $config 'theme-switcher.ps1' "quick settings exposes the standalone theme switcher"
Assert-Contains $config 'bar-autohide.ps1' "quick settings exposes standalone coordinated auto-hide"
Assert-Contains $config 'command: "glazewm.exe command wm-enable-binding-mode --name noalt"' "quick settings enters NoAlt through GlazeWM directly"
Assert-Contains $config 'command: "glazewm.exe command wm-enable-binding-mode --name vm"' "quick settings enters VM through GlazeWM directly"
Assert-Contains $config 'on_right: "disable_binding_mode"' "visible binding-mode label clears modes through YASB's native GlazeWM integration"
Assert-NotContains $config 'glazewm-pause-toggle' "YASB has no WGDot pause helper"
Assert-NotContains $config 'id: "wgdot_mouse_mode"' "mouse mode is not duplicated in quick settings"
Assert-NotContains $config 'id: "screenshot"' "YASB screenshot action is removed in favor of Flameshot"
Assert-Contains $config 'on_right: "toggle_window"' "taskbar right click uses YASB minimize/restore behavior"
Assert-Contains $config 'label: "{info[percent][total]} <span></span>"' "CPU label matches Awtarchy's unitless integer plus glyph"
Assert-Contains $config 'label: "{virtual_mem_percent} <span></span>"' "memory label matches Awtarchy's unitless integer plus glyph"
Assert-NotContains $config 'label: "{info[percent][total]}% <span></span>"' "CPU bar label does not reintroduce a percent suffix"
Assert-NotContains $config 'label: "{virtual_mem_percent}% <span></span>"' "memory bar label does not reintroduce a percent suffix"
Assert-Contains $config 'icon_size: 14' "taskbar retains the 14 px Awtarchy icon size"
Assert-NotContains $config '"systray",' "systray is not rendered in the bar"
Assert-Contains $config 'label_icon: false' "active window title remains text-only"
Assert-Contains $config 'monitor_exclusive: false' "active window title follows the globally focused window like Awtarchy"
Assert-Contains $config 'label_alt: "class={win[class_name]} | exe={win[process][name]} | hwnd={win[hwnd]}"' "active window click exposes class/process/HWND details"
Assert-Contains $config 'on_left: "toggle_label"' "active window left click toggles details"
$brightnessBlock = [regex]::Match($config, '(?ms)^  brightness:\r?\n.*?(?=^  battery:)').Value
$batteryBlock = [regex]::Match($config, '(?ms)^  battery:\r?\n.*?(?=^  microphone:)').Value
Assert-Contains $brightnessBlock 'yasb.brightness.BrightnessWidget' "brightness widget block is discoverable"
Assert-Contains $brightnessBlock 'label: "<span>{icon}</span> {percent}%"' "brightness retains Awtarchy's explicit percent suffix"
if (([regex]::Matches($brightnessBlock, '')).Count -ne 4) {
    throw "ASSERTION FAILED: brightness uses the fixed sun glyph in all four native YASB slots"
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
Assert-Contains $clockBlock '{%a %#m/%#d}' "clock alternate date matches Awtarchy's non-zero-padded M/d"
Assert-Contains $wifiBlock '"󰤯"' "Wi-Fi zero-strength glyph matches Awtarchy"
Assert-Contains $wifiBlock 'ethernet_icon: "󰈀"' "active Ethernet glyph matches Awtarchy"
Assert-Contains $bluetoothBlock 'bluetooth_on: ""' "Bluetooth enabled glyph matches Awtarchy"
Assert-Contains $bluetoothBlock 'bluetooth_off: ""' "Bluetooth disabled keeps Awtarchy's single glyph"
Assert-Contains $bluetoothBlock 'bluetooth_connected: ""' "Bluetooth connected keeps Awtarchy's single glyph"
Assert-NotContains $config 'yasb.clipboard_history' "dedicated clipboard widget implementation is absent until a standalone history surface exists"
Assert-NotContains $config '"clipboard_history",' "clipboard runtime button is not rendered as a dead WGDot action"
Assert-Contains $config '"idle_inhibitor"' "right-side modules include the Windows idle inhibitor"
Assert-Contains $config 'brightness_icons: ["", "", "", ""]' "brightness uses a fixed sun icon"
Assert-Contains $config 'idle-inhibitor.ps1" status' "idle inhibitor polls the standalone script"
Assert-Contains $config 'label: "{data[icon]}"' "idle inhibitor renders its JSON-decoded Awtarchy eye glyph"
Assert-Contains $config 'return_format: "json"' "idle inhibitor avoids Windows console glyph encoding loss"
Assert-Contains $config 'idle-inhibitor.ps1" toggle' "idle inhibitor toggles the standalone Keep Awake script"
$launcherBlock = [regex]::Match($config, '(?ms)^  launcher:\r?\n.*?(?=^  glazewm_workspaces:)').Value
Assert-Contains $launcherBlock 'clipboard_history:' "Quick Launch clipboard provider remains explicitly configured"
Assert-Contains $launcherBlock 'yasb.quick_launch.QuickLaunchWidget' "native Quick Launch replaces the old Flow launcher surface"
Assert-Contains $launcherBlock 'clipboard_history:' "Quick Launch clipboard provider remains explicitly configured"
Assert-Contains $launcherBlock 'enabled: false' "Quick Launch clipboard provider remains disabled while no standalone history surface is configured"
Assert-NotContains $config 'wgdot' "YASB desktop parity does not depend on WGDot runtime commands"
Assert-NotContains $workConfig 'wgdot' "Work YASB desktop parity does not depend on WGDot runtime commands"
Assert-Contains $config 'next_binding_mode' "YASB binding-mode widget can cycle modes natively"

Assert-Contains $config 'yasb.dnd.DndWidget' "unified notifications and Do Not Disturb control uses native YASB DND"
Assert-NotContains $config 'yasb.notifications.NotificationsWidget' "separate Notifications widget stays removed after DND unification"
Assert-Contains $config 'on_left: "exec notification_center"' "unified DND left click opens Windows Notification Center through YASB native exec mapping"
Assert-Contains $config 'on_right: "toggle_status"' "unified DND right click uses its native DND toggle callback"
Assert-Contains $config "shell:AppsFolder\40459File-New-Project.EarTrumpet_725pr5jq8wr8a!EarTrumpet" "audio right click launches EarTrumpet directly"
Assert-Contains $config 'normal: ""' "unmuted microphone glyph is collapsed like Awtarchy"
$mutedMicBlock = [regex]::Match($style, '(?ms)^\.microphone-widget \.label\.muted,\r?\n\.microphone-widget \.icon\.muted \{\r?\n.*?^\}').Value
Assert-Contains $mutedMicBlock 'padding: 0 8px;' "muted microphone keeps Awtarchy's 8 px horizontal control padding"
Assert-Contains $style '.microphone-widget .icon.muted' "muted microphone state has dedicated styling"
Assert-Contains $style '--muted: #5c5c5c;' "fallback palette matches Awtarchy Carbon Night"
Assert-Contains $style '@import "theme.css";' "YASB imports the managed live theme palette"
Assert-Contains $manifest '"id": "yasb-theme"' "theme.css is a normal managed dotfile"
Assert-Contains $manifest '"id": "script-theme-switcher"' "theme switcher is a managed standalone script"
Assert-Contains $manifest 'theme-switcher.ps1' "managed theme script is deployed with the dots"
Assert-NotContains $manifest '"type": "ensure-yasb-theme"' "theme lifecycle no longer requires a WGDot post-action"
$powerBlock = [regex]::Match($config, '(?ms)^  power_menu:\r?\n.*$').Value
Assert-Contains $powerBlock 'yasb.power_menu.PowerMenuWidget' "power button uses YASB's native power menu"
Assert-Contains $powerBlock 'lock: ["", "Lock"]' "native power menu includes Lock"
Assert-Contains $powerBlock 'hibernate: ["", "Hibernate"]' "native power menu includes Hibernate"
Assert-Contains $powerBlock 'restart: ["", "Restart"]' "native power menu includes Restart"
Assert-Contains $powerBlock 'shutdown: ["", "Shut Down"]' "native power menu includes Shutdown"
Assert-Contains $powerBlock 'signout: ["󰗽", "Sign out"]' "native power menu includes Sign out"
Assert-Contains $powerBlock 'sleep: ["󰒲", "Sleep"]' "native power menu includes Sleep"
Assert-Contains $powerBlock 'keys: "win+p"' "YASB owns the Super+P power-menu hotkey"
Assert-NotContains $config 'theme_picker:' "themes live in quick settings instead of a standalone bar button"
Assert-Contains $manifest '"id": "script-theme-switcher"' "theme toggle is provided by a dotfile-owned script"
Assert-Contains $glazeNormal 'window_title: { equals: "Win Glaze Themes" }' "theme selector has a stable floating title"
Assert-NotContains $glazeNormal 'wgdot' "theme hotkey does not depend on WGDot"
Assert-Contains $glazeNormal 'theme-switcher.ps1' "GlazeWM launches the standalone theme selector"
Assert-Contains $manifest 'UserProfile/.config/yasb/theme.css' "theme.css is portable with the dotfiles"
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
    Assert-Contains -Text $themeScript -Needle $themeId -Message "standalone theme script owns expected Awtarchy palette id"
}
Assert-Contains -Text $themeScript -Needle "Background='#353535'" -Message "Carbon Night background stays aligned with Awtarchy"
Assert-Contains -Text $themeScript -Needle "Foreground='#89b4fa'" -Message "Electric Blue foreground stays aligned with Awtarchy"
Assert-Contains -Text $themeScript -Needle 'Win Glaze $($t.Label)' -Message "standalone theme script owns Windows Terminal synchronization"
Assert-NotContains -Text $themeScript -Needle "wgdot" -Message "standalone theme switching has no WGDot runtime dependency"

foreach ($glaze in @($glazeNormal, $glazeWork)) {
    Assert-Contains $glaze 'top: "35px"' "GlazeWM uses the requested 35 px top reservation"
    Assert-NotContains $glaze 'top: "8px"' "bar redesign does not require live GlazeWM gap migration"
    Assert-Contains $glaze 'shell-exec yasb' "GlazeWM starts YASB"
    Assert-Contains $glaze 'color: "#a1a1a1"' "focused GlazeWM border stays theme-neutral"
    Assert-Contains $glaze 'bindings: ["lwin+t", "rwin+t"]' "Win+T opens the standalone theme selector"
    Assert-NotContains $glaze 'bindings: ["lwin+c", "rwin+c"]' "GlazeWM does not require WGDot Clipboard History"
    Assert-NotContains $glaze 'bindings: ["lwin+v", "rwin+v"]' "GlazeWM leaves Super+V available for EarTrumpet"
    Assert-NotContains $glaze 'bindings: ["lwin+p", "rwin+p"]' "GlazeWM leaves Super+P to YASB's native power menu"
    Assert-Contains $glaze 'name: "noalt"' "noalt mode is retained"
    Assert-Contains $glaze 'name: "vm"' "VM mode is retained"
    Assert-Contains $glaze 'wm-enable-binding-mode --name noalt' "NoAlt transitions use native GlazeWM commands"
    Assert-Contains $glaze 'wm-enable-binding-mode --name vm' "VM transitions use native GlazeWM commands"
    Assert-Contains $glaze 'wm-disable-binding-mode --name' "binding modes have native GlazeWM escape commands"
    Assert-Contains $glaze 'commands: ["wm-toggle-pause"]' "real GlazeWM pause uses the native command"
    Assert-Contains $glaze 'bindings: ["lwin+alt+p", "rwin+alt+p"]' "real pause uses Alt+Super+P"
    Assert-Contains $glaze 'theme-switcher.ps1' "theme hotkey uses the standalone theme script"
    Assert-Contains $glaze 'window_title: { equals: "Win Glaze Themes" }' "theme selector has a dedicated floating title"
    Assert-Contains $glaze 'window_process: { regex: "^WindowsTerminal(\\.exe)?$" }' "theme selector floating rule is scoped to Windows Terminal"
    Assert-NotContains $glaze 'wgdot' "GlazeWM runtime is independent of WGDot"
    Assert-NotContains $glaze 'yasbc toggle-bar' "unsafe hard-hide command is not bound from GlazeWM"
    Assert-Contains $glaze 'bar-autohide.ps1' "GlazeWM uses the standalone coordinated auto-hide script"
    Assert-Contains $glaze 'bindings: ["alt+ctrl+b"]' "Alt+Ctrl+B toggles coordinated auto-hide"
    Assert-NotContains $glaze 'lwin+alt+ctrl+b' "unused Awtarchy Win+Alt+Ctrl+B chord is not added"
    Assert-NotContains $glaze 'rwin+alt+ctrl+b' "unused Awtarchy Win+Alt+Ctrl+B chord is not added"
    Assert-NotContains $glaze 'Stop-Process -Name yasb -Force' "bar visibility no longer kills the YASB process"
    Assert-NotContains $glaze 'bindings: ["lwin", "rwin"]' "GlazeWM does not rely on ineffective bare-Super bindings"
    Assert-Contains $glaze 'bindings: ["lwin+1", "rwin+1"]' "Super+number workspace focus survives noalt"
    Assert-Contains $glaze 'bindings: ["lwin+shift+1", "rwin+shift+1"]' "Super+Shift+number workspace move survives noalt"
    Assert-Contains $glaze 'yasb-quick-launch.ps1' "GlazeWM launches YASB through the portable dotfile bridge"
}

Assert-Contains $glazeNormal 'bindings: ["alt+p", "lwin+d", "rwin+d"]' "Normal GlazeWM owns Alt+P/Super+D for YASB Quick Launch"
Assert-NotContains $glazeNormal 'flow-launcher.ps1' "Normal GlazeWM does not make Flow Launcher the default"

Assert-Contains $glazeWork 'flow-launcher.ps1' "Work GlazeWM exposes Flow Launcher for the migration A/B test"
Assert-Contains $glazeWork 'bindings: ["alt+p"]' "Work GlazeWM maps Alt+P to Flow Launcher"
Assert-Contains $glazeWork 'bindings: ["lwin+d", "rwin+d"]' "Work GlazeWM maps Super+D to the YASB bridge"
Assert-NotContains $glazeWork 'bindings: ["alt+p", "lwin+d", "rwin+d"]' "Work GlazeWM keeps Flow and YASB launcher chords separate"

Assert-NotContains $config 'komorebi' "abandoned Komorebi integration is absent"
Assert-NotContains $config 'whkd' "whkd is not introduced"

foreach ($widgetType in @(
    'yasb.cpu.CpuWidget',
    'yasb.memory.MemoryWidget',
    'yasb.control_center.ControlCenterWidget',
    'yasb.quick_launch.QuickLaunchWidget',
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
Assert-Contains -Text $style -Needle "JetBrainsMono NFP" -Message "managed Nerd Font is retained"
$taskContainerBlock = [regex]::Match($style, "(?ms)^\.taskbar-widget \.app-container \{\r?\n.*?^\}").Value
Assert-Contains -Text $taskContainerBlock -Needle "min-width: 14px;" -Message "task content width matches its 14 px icon"
Assert-Contains -Text $taskContainerBlock -Needle "max-width: 14px;" -Message "task content width remains fixed"
Assert-Contains -Text $taskContainerBlock -Needle "padding: 0 6px;" -Message "task slot keeps 26 px total width"
Assert-Contains -Text $style -Needle ".workspace-move-buttons .widget-container" -Message "workspace arrow container collapses at rest"
Assert-Contains -Text $style -Needle ".workspace-move-buttons .label" -Message "workspace arrows collapse at rest"
Assert-Contains -Text $style -Needle ".workspace-move-grouper:hover .workspace-move-buttons .label" -Message "parent hover restores workspace arrows"
Assert-Contains -Text $style -Needle "max-width: 112px;" -Message "workspace arrow strip has bounded hover width"
Assert-Contains -Text $style -Needle ".workspace-move-grouper:hover .workspace-move-buttons" -Message "workspace mover hover reveals arrows"
Assert-Contains -Text $style -Needle ".quick-launch-widget .icon" -Message "native Quick Launch icon is styled"
Assert-Contains -Text $style -Needle ".quick-launch-widget:hover" -Message "Quick Launch has strong hover treatment"
Assert-Contains -Text $style -Needle ".quick-launch-popup .container" -Message "Quick Launch popup uses shared theme styling"
Assert-Contains -Text $style -Needle ".awtarchy-control-center:hover" -Message "quick settings has strong hover treatment"
Assert-Contains -Text $style -Needle ".control-center-menu" -Message "Control Center popup uses shared theme styling"
Assert-Contains -Text $style -Needle '@import "appearance.css";' -Message "styles import portable appearance overrides"
Assert-Contains -Text $style -Needle ".dnd-widget:hover" -Message "DND action has strong hover treatment"
Assert-Contains -Text $style -Needle "font-size: 14px;" -Message "bar icon scale is normalized"
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
Assert-Contains -Text $readme -Needle "WGDot is never required when a bar button or window-manager keybinding is used." -Message "desktop runtime independence is explicit"
Assert-Contains -Text $readme -Needle "yasb-quick-launch.ps1" -Message "portable Quick Launch bridge is documented"
Assert-Contains -Text $readme -Needle "Flow Launcher" -Message "Work launcher A/B split is documented"
Assert-Contains -Text $readme -Needle "theme-switcher.ps1" -Message "standalone theme switching is documented"
Assert-Contains -Text $readme -Needle "bar-autohide.ps1" -Message "standalone coordinated auto-hide is documented"
Assert-Contains -Text $readme -Needle "idle-inhibitor.ps1" -Message "standalone idle inhibitor is documented"
Assert-Contains -Text $readme -Needle "PowerMenuWidget" -Message "native YASB power ownership is documented"
Assert-Contains -Text $readme -Needle "EarTrumpet owns the chord itself" -Message "EarTrumpet direct Super+V ownership is documented"
Assert-Contains -Text $readme -Needle "no managed `Super+C` custom history shortcut" -Message "clipboard omission is explicit instead of claiming a dead helper"
Assert-Contains -Text $readme -Needle "Mouse-window mode is currently omitted" -Message "mouse-mode omission is explicit"
Assert-Contains -Text $readme -Needle "CPU temperature" -Message "CPU temperature is not silently substituted with another metric"
Assert-Contains -Text $readme -Needle "Do Not Disturb" -Message "notification/DND mapping is documented"
Assert-Contains -Text $readme -Needle "theme.css" -Message "live YASB theme mapping is documented"
Assert-Contains -Text $readme -Needle "exactly 15%" -Message "shared YASB battery threshold edge is documented"
Assert-Contains -Text $readme -Needle "plugged-in-but-not-charging" -Message "YASB AC-only battery color limitation is documented"
Assert-Contains -Text $readme -Needle "trailing `%`" -Message "native YASB volume percent limitation is documented"
Assert-Contains -Text $readme -Needle "conditional primary-label expression" -Message "Bluetooth connected-name/count limitation is documented"
Assert-Contains -Text $readme -Needle "no bar-label connectivity CSS class" -Message "network disconnected-color limitation is documented"
Assert-Contains -Text $readme -Needle "#a1a1a1" -Message "neutral GlazeWM border rationale is documented"
Assert-Contains -Text $readme -Needle "does **not** reload GlazeWM" -Message "theme changes remain reload-free"

Write-Host "YASB parity checks passed." -ForegroundColor Green
