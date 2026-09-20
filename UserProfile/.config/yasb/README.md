# Awtarchy-inspired YASB

This YASB configuration intentionally mirrors the current Awtarchy Quickshell bar where Windows, YASB, and GlazeWM have direct supported equivalents. It does not add helper scripts to imitate compositor-only features.

## Bar layout

Left:

- Flow Launcher button using the existing WGDot `flow-open` helper
- GlazeWM workspaces
- collapsible workspace-move controls using GlazeWM's native `move-workspace --direction` command
- running-window task icons
- active GlazeWM binding mode

Center:

- globally focused active-window title, matching Awtarchy across monitor bars

Right:

- CPU usage
- memory usage
- brightness
- battery when supported
- microphone status/control
- output volume
- clock/date toggle
- network
- Bluetooth
- system tray
- Windows Clipboard History
- Windows notifications
- Windows Do Not Disturb state/control
- power menu

The bar uses Awtarchy's current flat palette: `#353535` background, `#d0d0d0` foreground, subtle active/hover fills, square controls, and a 28 px horizontal bar. JetBrainsMono NFP remains the Windows font because WGDot already installs it; this branch does not add another font dependency solely for visual parity.

Because YASB now reserves its own 28 px Windows AppBar area, the managed GlazeWM profiles use the normal 8 px top outer gap. The previous 38 px top gap was a manual allowance for the old non-AppBar YASB setup and would create a double gap with this configuration.

## Evidence-backed mappings

These translations use documented upstream YASB or GlazeWM behavior rather than custom emulation:

| Awtarchy behavior | Windows mapping | Evidence |
| --- | --- | --- |
| monitor-local workspaces + wheel switching | `GlazewmWorkspacesWidget` | YASB `docs/widgets/(Widget)-GlazeWM-Workspaces.md` |
| visible Hyprland submap | `GlazewmBindingModeWidget` for WGDot's `noalt` / `vm` modes | YASB `docs/widgets/(Widget)-GlazeWM-Binding-Mode.md` |
| centered active title | `ActiveWindowWidget` with `monitor_exclusive: false`, so every bar follows the globally focused window like Awtarchy | YASB Active Window source filters per monitor only when `monitor_exclusive` is true |
| task icons | `TaskbarWidget`; middle-click closes and right-click uses YASB's native minimize/restore toggle | YASB taskbar supports monitor filtering plus registered `toggle_window` / `close_app` callbacks |
| workspace move drawer | collapsed `GrouperWidget` containing `ApplicationsWidget` buttons that call GlazeWM's native directional workspace move command | YASB Grouper/Applications docs + existing WGDot GlazeWM `move-workspace --direction` bindings |
| CPU / memory | native CPU and Memory widgets | YASB CPU/Memory docs |
| DDC brightness | native Brightness widget | YASB brightness docs explicitly support external DDC/CI monitors and background DDC polling |
| battery | native Battery widget with `hide_unsupported` | YASB Battery docs |
| microphone | native Microphone widget with an empty normal glyph and YASB's native `muted` class styling, so the bar indicator collapses while unmuted and appears red while muted | YASB Microphone source applies `muted` / `no-device` classes dynamically |
| output audio | native Volume widget for mute/scroll volume; right-click opens the existing WGDot EarTrumpet mixer helper, paralleling Awtarchy's Wiremix action | YASB Volume callbacks + existing WGDot `eartrumpet-mixer` integration |
| clock/date | Clock widget primary/alternate labels | YASB Clock docs |
| network / Bluetooth | native WiFi and Bluetooth menus; both left and right click open the native menu, matching Awtarchy's bar behavior | YASB WiFi/Bluetooth docs and registered `toggle_menu` callbacks |
| inline tray | native Systray widget | YASB Systray docs |
| clipboard history | a dedicated `QuickLaunchWidget` instance with only YASB's native Windows Clipboard History provider enabled; it opens directly to history and supports text/images, restore, delete, clear, and previews | YASB Quick Launch and Clipboard History provider docs/source |
| notifications | native Notifications widget opens Windows Action Center; adjacent `DndWidget` exposes Windows Do Not Disturb as the supported Windows-side approximation of Awtarchy's notification-popup mute state | YASB Notifications + DND docs/source |
| power controls | native compact Power Menu popup; both left and right click use YASB's supported menu toggle | YASB Power Menu docs and registered `toggle_power_menu` callback |
| exclusive bar area + fullscreen hiding | `windows_app_bar: true` + `hide_on_fullscreen: true`; GlazeWM keeps its ordinary 8 px outer gap instead of the old 38 px manual bar allowance | YASB bar configuration; current GlazeWM uses the Windows monitor working area (excluding taskbars/reserved space) and listens for `SPI_SETWORKAREA`; Awtarchy `Bar.qml` uses `exclusiveZone: barSize` while Hyprland keeps normal `gaps_out` |
| Flow Launcher button | a static native `CustomWidget` calling the existing WGDot `flow-open` helper on both left and right click, matching Awtarchy's launcher mouse behavior | YASB Custom widget uses normal registered mouse callbacks and the existing WGDot helper |
| bar visibility hotkey | YASB's supported `yasbc toggle-bar`; WGDot keeps the old `Alt+Ctrl+B` convenience and also exposes Awtarchy's `Win+Alt+Ctrl+B` chord, including inside `noalt` and `vm` binding modes | YASB CLI `toggle-bar` + managed GlazeWM bindings |

## Deliberate differences and omissions

The following Awtarchy features are not translated because a direct supported equivalent was not verified:

- CPU temperature: YASB's CPU widget does not expose CPU temperature. GPU temperature or an external Libre Hardware Monitor service would not be the same feature.
- idle inhibitor: no native YASB idle-inhibitor equivalent was verified.
- Hyprland special-workspace scratchpad count: GlazeWM does not expose the same special-workspace model.
- Awtarchy's global "new windows float" indicator: no direct GlazeWM/YASB state equivalent was verified.
- privacy / screen-capture indicator: no native YASB equivalent was verified.
- vertical left/right bar layouts: current YASB bar positioning supports top/bottom, not Awtarchy's vertical edge layouts.
- workspace urgent-state coloring and Awtarchy's static number+glyph workspace labels: the YASB GlazeWM workspace widget does not expose those exact Hyprland states/mappings.
- Awtarchy's workspace mover expands on hover and includes a mouse submap toggle. YASB's native Grouper expands by click, and WGDot has no equivalent mouse binding mode.
- task-icon left click is still not identical: YASB's native `toggle_window` minimizes an already-active window; Awtarchy's left click simply activates it. Right-click now uses the same native YASB minimize/restore action because that is a closer match to Awtarchy.
- Awtarchy's notification icon owns both open and popup-mute behavior. YASB does not expose a cross-widget callback for that composition, so Windows Action Center and Windows Do Not Disturb are adjacent controls instead. YASB's DND implementation uses the Windows QuietHoursSettings COM API documented by YASB as an undocumented Windows API, so Windows updates can change that behavior.
- Awtarchy toggles auto-hide for the focused monitor. YASB exposes a supported CLI visibility toggle, but a monitor-specific toggle requires a concrete screen name; the managed GlazeWM hotkey therefore toggles all YASB bars rather than guessing a monitor name.

## Anti-cheat-sensitive choices

The YASB systray stays on `use_hook: false`. Upstream documents `use_hook: true` as an `explorer.exe` DLL-injection method that may interact badly with Defender or other security software. WGDot does not need that extra hook merely to imitate the Awtarchy tray.

No AutoHotkey, whkd, keyboard hook, DLL injection, or custom background input daemon is added by this bar translation.
