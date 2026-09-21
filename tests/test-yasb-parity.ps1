$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

$repoRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repoRoot "UserProfile\.config\yasb\config.yaml"
$stylePath = Join-Path $repoRoot "UserProfile\.config\yasb\styles.css"
$readmePath = Join-Path $repoRoot "UserProfile\.config\yasb\README.md"
$glazeNormalPath = Join-Path $repoRoot "UserProfile\.glzr\glazewm\config.yaml"
$glazeWorkPath = Join-Path $repoRoot "UserProfile\.glzr\glazewm\custom_work_config.yaml"
$nativePath = Join-Path $repoRoot "wgdot\wgdot-native.cs"
$manifestPath = Join-Path $repoRoot "wgdot\manifest.json"

function Assert-Contains {
    param([string]$Text, [string]$Needle, [string]$Message)
    if (-not $Text.Contains($Needle)) { throw "ASSERTION FAILED: $Message" }
}

function Assert-NotContains {
    param([string]$Text, [string]$Needle, [string]$Message)
    if ($Text.Contains($Needle)) { throw "ASSERTION FAILED: $Message" }
}

foreach ($path in @($configPath, $workConfigPath, $stylePath, $readmePath, $glazeNormalPath, $glazeWorkPath, $nativePath, $manifestPath)) {
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
$clipboardBlock = [regex]::Match($config, '(?ms)^  clipboard_history:\r?\n.*?(?=^  dnd:)').Value
Assert-Contains $clockBlock '{%a %#m/%#d}' "clock alternate date matches Awtarchy's non-zero-padded M/d"
Assert-Contains $wifiBlock '"󰤯"' "Wi-Fi zero-strength glyph matches Awtarchy"
Assert-Contains $wifiBlock 'ethernet_icon: "󰈀"' "active Ethernet glyph matches Awtarchy"
Assert-Contains $bluetoothBlock 'bluetooth_on: ""' "Bluetooth enabled glyph matches Awtarchy"
Assert-Contains $bluetoothBlock 'bluetooth_off: ""' "Bluetooth disabled keeps Awtarchy's single glyph"
Assert-Contains $bluetoothBlock 'bluetooth_connected: ""' "Bluetooth connected keeps Awtarchy's single glyph"
Assert-NotContains $config '  clipboard_history:' "dedicated clipboard runtime widget is removed until it has a standalone implementation"
Assert-NotContains $config '"clipboard_history",' "clipboard runtime button is not rendered as a dead WGDot action"
Assert-Contains $config '"idle_inhibitor"' "right-side modules include the Windows idle inhibitor"
Assert-Contains $config 'brightness_icons: ["", "", "", ""]' "brightness uses a fixed sun icon"
Assert-Contains $config 'idle-inhibitor.ps1" status' "idle inhibitor polls the standalone script"
Assert-Contains $config 'label: "{data[icon]}"' "idle inhibitor renders its JSON-decoded Awtarchy eye glyph"
Assert-Contains $config 'return_format: "json"' "idle inhibitor avoids Windows console glyph encoding loss"
Assert-Contains $config 'idle-inhibitor.ps1" toggle' "idle inhibitor toggles the standalone Keep Awake script"
Assert-Contains $launcherBlock 'clipboard_history:' "Quick Launch clipboard provider remains explicitly configured"
$launcherBlock = [regex]::Match($config, '(?ms)^  launcher:\r?\n.*?(?=^  glazewm_workspaces:)').Value
Assert-Contains $launcherBlock 'yasb.quick_launch.QuickLaunchWidget' "native Quick Launch replaces the old Flow launcher surface"
Assert-Contains $launcherBlock 'clipboard_history:' "Quick Launch clipboard provider remains explicitly configured"
Assert-Contains $launcherBlock 'enabled: false' "Quick Launch does not duplicate the dedicated WGDot Clipboard History bar action"
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
Assert-Contains $powerBlock 'yasb.custom.CustomWidget' "power button uses a simple YASB callback surface"
Assert-Contains $powerBlock 'exec wgdotw power-menu' "power button opens the WGDot native overlay without a console flash"
Assert-Contains $powerBlock 'Power menu (L/H/R/S/O/Z)' "power tooltip advertises direct action keys"
Assert-NotContains $config 'yasb.power_menu.PowerMenuWidget' "stock YASB power popup is removed"
Assert-Contains $native 'if (command == "power-menu") return PowerMenu();' "native WGDot exposes the power overlay"
Assert-Contains $native '"Lock (L)"' "power overlay includes Lock L"
Assert-Contains $native '"Hibernate (H)"' "power overlay includes Hibernate H"
Assert-Contains $native '"Reboot (R)"' "power overlay includes Reboot R"
Assert-Contains $native '"Shutdown (S)"' "power overlay includes Shutdown S"
Assert-Contains $native '"Sign out (O)"' "power overlay includes Sign out O"
Assert-Contains $native '"Sleep (Z)"' "power overlay includes Sleep Z"
Assert-Contains $native 'System.Windows.Forms.Keys.Escape' "power overlay supports Escape close"
Assert-NotContains $config 'theme_picker:' "themes live in quick settings instead of a standalone bar button"
Assert-Contains $manifest '"id": "script-theme-switcher"' "theme toggle is provided by a dotfile-owned script"
Assert-Contains $glazeNormal 'window_title: { equals: "Win Glaze Themes" }' "theme selector has a stable floating title"
Assert-NotContains $glazeNormal 'wgdot' "theme hotkey does not depend on WGDot"
Assert-Contains $glazeNormal 'theme-switcher.ps1' "GlazeWM launches the standalone theme selector"
Assert-Contains $manifest 'UserProfile/.config/yasb/theme.css' "theme.css is portable with the dotfiles"
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
    Assert-Contains $glaze 'top: "35px"' "GlazeWM uses the requested 35 px top reservation"
    Assert-NotContains $glaze 'top: "8px"' "bar redesign does not require live GlazeWM gap migration"
    Assert-Contains $glaze 'shell-exec yasb' "GlazeWM starts YASB"
    Assert-Contains $glaze 'color: "#a1a1a1"' "focused GlazeWM border stays theme-neutral"
    Assert-Contains $glaze 'bindings: ["lwin+t", "rwin+t"]' "Win+T opens themes"
    Assert-Contains $glaze 'bindings: ["lwin+c", "rwin+c"]' "Super+C opens WGDot Clipboard History"
    Assert-Contains $glaze 'wgdot.exe quick-launch' "GlazeWM keeps WGDot/YASB Quick Launch available"
    Assert-Contains $glaze 'bindings: ["lwin+v", "rwin+v"]' "GlazeWM owns Super+V for the EarTrumpet mixer"
    Assert-Contains $glaze 'name: "noalt"' "noalt mode is restored"
    Assert-Contains $glaze 'commands: ["wm-toggle-pause"]' "real GlazeWM pause replaces pause/noalt emulation"
    Assert-Contains $glaze 'bindings: ["lwin+alt+p", "rwin+alt+p"]' "real pause uses Alt+Super+P"
    Assert-Contains $glaze 'theme-toggle' "GlazeWM theme hotkey uses the single-instance selector helper"
    Assert-NotContains $glaze 'shell-exec wt.exe -w new --size 72,22 nt --title "WGDot Themes"' "GlazeWM no longer spawns duplicate theme terminals directly"
    Assert-Contains $glaze 'window_title: { equals: "WGDot Themes" }' "theme selector has a dedicated GlazeWM title rule"
    Assert-Contains $glaze 'window_process: { regex: "^WindowsTerminal(\\.exe)?$" }' "theme selector floating rule is scoped to Windows Terminal"
    Assert-NotContains $glaze 'wm-reload-config wgdot theme' "theme hotkey never chains a GlazeWM reload"
    Assert-NotContains $glaze 'yasbc toggle-bar' "unsafe hard-hide command is not bound from GlazeWM"
    Assert-Contains $glaze 'bar-autohide-toggle' "GlazeWM uses WGDot's coordinated YASB/GlazeWM auto-hide helper"
    Assert-Contains $glaze 'bindings: ["alt+ctrl+b"]' "Alt+Ctrl+B toggles coordinated auto-hide"
    Assert-NotContains $glaze 'lwin+alt+ctrl+b' "unused Awtarchy Win+Alt+Ctrl+B chord is not added beside the requested Alt+Ctrl+B mapping"
    Assert-NotContains $glaze 'rwin+alt+ctrl+b' "unused Awtarchy Win+Alt+Ctrl+B chord is not added beside the requested Alt+Ctrl+B mapping"
    Assert-NotContains $glaze 'Stop-Process -Name yasb -Force' "bar visibility no longer kills the YASB process"
    Assert-NotContains $glaze 'bindings: ["lwin", "rwin"]' "GlazeWM bare-Super consumer is removed in favor of WGDot desktop worker"
    Assert-Contains $glaze 'bindings: ["lwin+1", "rwin+1"]' "Super+number workspace focus survives noalt"
    Assert-Contains $glaze 'bindings: ["lwin+shift+1", "rwin+shift+1"]' "Super+Shift+number workspace move survives noalt"
    Assert-NotContains $glaze 'bindings: ["lwin+alt+d", "rwin+alt+d"]' "GlazeWM leaves the private YASB bridge out of normal bindings"
}

Assert-Contains $glazeNormal 'bindings: ["alt+p", "lwin+d", "rwin+d"]' "Normal GlazeWM keeps Alt+P/Super+D on WGDot/YASB Quick Launch"
Assert-NotContains $glazeNormal 'wgdot.exe flow-open' "Normal GlazeWM does not make Flow Launcher the default"

Assert-Contains $glazeWork 'wgdot.exe flow-open' "Work GlazeWM exposes Flow Launcher for the migration A/B test"
Assert-Contains $glazeWork 'bindings: ["alt+p"]' "Work GlazeWM maps Alt+P to Flow Launcher"
Assert-Contains $glazeWork 'bindings: ["lwin+d", "rwin+d"]' "Work GlazeWM maps Super+D to WGDot/YASB Quick Launch"
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

Assert-Contains $style '.glazewm-workspaces .ws-btn.empty' "inactive empty workspace buttons collapse"
Assert-Contains $style 'min-height: 28px;' "workspace shading spans the full 28 px bar height"
Assert-Contains $style 'margin-left: 2px;' "CPU and memory icons have a tiny separation from their values"
Assert-Contains $style '.tooltip,' "YASB custom rich tooltips receive an opaque themed background"
Assert-Contains $style '#353535' "Awtarchy background color is retained"
Assert-Contains $style '#d0d0d0' "Awtarchy foreground color is retained"
Assert-Contains $style '#ff5555' "Awtarchy critical color is retained"
Assert-Contains $style 'JetBrainsMono NFP' "existing WGDot-managed Nerd Font is retained"
$taskContainerBlock = [regex]::Match($style, '(?ms)^\.taskbar-widget \.app-container \{\r?\n.*?^\}').Value
Assert-Contains $taskContainerBlock 'min-width: 14px;' "task content width matches its 14 px Awtarchy icon"
Assert-Contains $taskContainerBlock 'max-width: 14px;' "task content width is fixed so the padded slot remains 26 px"
Assert-Contains $taskContainerBlock 'padding: 0 6px;' "task slot totals Awtarchy's 26 px width"
$mouseHubBlock = [regex]::Match($style, '(?ms)^\.workspace-mouse-hub \{\r?\n.*?^\}').Value
Assert-Contains $mouseHubBlock 'max-width: 28px;' "mouse hub remains a fixed visible Awtarchy-sized slot"
Assert-Contains $style '.workspace-move-buttons .widget-container' "workspace arrow container is explicitly collapsed at rest"
Assert-Contains $style '.workspace-move-buttons .label' "individual workspace arrows are explicitly collapsed at rest"
Assert-Contains $style '.workspace-move-grouper:hover .workspace-move-buttons .label' "parent hover restores arrow width and padding"
Assert-Contains $style 'max-width: 112px;' "workspace arrow strip expands only while hovered"
Assert-Contains $style '.workspace-move-grouper:hover .workspace-move-buttons' "hovering the mouse hub group reveals workspace arrows"
Assert-Contains $style '.workspace-mouse-hub' "mouse hub remains independently visible while arrows are collapsed"
Assert-Contains $style '.quick-launch-widget .icon' "native Quick Launch icon is styled like Awtarchy's launcher"
Assert-Contains $style '.quick-launch-widget:hover' "Quick Launch uses Awtarchy's strong hover treatment"
Assert-Contains $style '.quick-launch-popup .container' "Quick Launch popup has WGDot theme styling"
Assert-Contains $style '.awtarchy-control-center:hover' "quick settings button uses Awtarchy's strong hover treatment"
Assert-Contains $style '.control-center-menu' "Control Center popup has WGDot theme styling"
Assert-Contains $style '@import "appearance.css";' "styles import WGDot live appearance overrides"
Assert-Contains $style '.dnd-widget:hover' "notification/DND action uses Awtarchy's strong hover treatment"
Assert-Contains $style 'font-size: 14px;' "bar icon scale is normalized to the adjacent 14 px text"
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
Assert-Contains $readme 'auto-hide' "native YASB auto-hide limitation and recovery path are documented"
Assert-Contains $readme 'theme.css' "live YASB theme mapping is documented"
Assert-Contains $readme 'Power & battery' "Windows-native battery details mapping is documented"
Assert-Contains $readme 'PowerPlanWidget' "native Windows power-plan option was evaluated instead of blindly scripted"
Assert-Contains $readme 'no wheel callback' "clock wheel limitation is documented from current YASB source"
Assert-Contains $readme 'exactly 15%' "shared YASB battery threshold edge is documented"
Assert-Contains $readme 'plugged-in-but-not-charging' "YASB AC-only battery color limitation is documented"
Assert-Contains $readme 'trailing `%`' "native YASB volume percent limitation is documented"
Assert-Contains $readme 'conditional label expression' "Bluetooth connected-name/count limitation is documented"
Assert-Contains $readme 'no connectivity CSS class' "network disconnected-color limitation is documented"
Assert-Contains $readme 'WGDot-native themed full-screen overlay' "Awtarchy-style native power overlay is documented"
Assert-Contains $readme 'not rendered in the WGDot YASB bar' "system tray omission is documented"
Assert-Contains $readme 'no native image-tint option' "Awtarchy task/tray recoloring limitation is documented instead of faked"
Assert-Contains $readme 'visual preview cards' "theme-selector limitation versus Awtarchy is documented"
Assert-Contains $readme 'output discarded' "direct YASB theme-command diagnostic limitation is documented"
Assert-Contains $readme '#a1a1a1' "neutral GlazeWM border rationale is documented"
Assert-Contains $readme 'theme changes still never reload GlazeWM' "theme changes remain reload-free while geometry changes require one config reload"

Write-Host "YASB parity checks passed." -ForegroundColor Green
