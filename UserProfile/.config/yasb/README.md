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
- unified Windows notifications / Do Not Disturb control
- live YASB theme picker
- power menu

The default bar uses Awtarchy's Carbon Night palette: `#353535` background, `#d0d0d0` foreground, subtle active/hover fills, square controls, and a 28 px horizontal bar. WGDot also exposes the current Awtarchy palette set through a live YASB theme selector. JetBrainsMono NFP remains the Windows font because WGDot already installs it; this branch does not add another font dependency solely for visual parity.

WGDot deliberately keeps the existing GlazeWM 38 px top outer gap and runs YASB as an always-on-top, non-AppBar bar. Moving an already-running setup to Windows AppBar reservation would require GlazeWM to reload the new smaller gap to avoid double spacing. Since GlazeWM reloads can disturb the current tiling tree, this branch keeps the reload-free reservation model for an easy live transition.

The YASB redesign itself can therefore be tested by restarting YASB only. New GlazeWM-only conveniences on this branch, such as `Win+T` and the `WGDot Themes` floating-window rule, naturally become active the next time GlazeWM starts; WGDot does not force a live GlazeWM reload just to activate them.

## Evidence-backed mappings

These translations use documented upstream YASB or GlazeWM behavior rather than custom emulation:

| Awtarchy behavior | Windows mapping | Evidence |
| --- | --- | --- |
| monitor-local workspaces + wheel switching | `GlazewmWorkspacesWidget` | YASB `docs/widgets/(Widget)-GlazeWM-Workspaces.md` |
| visible Hyprland submap | `GlazewmBindingModeWidget` for WGDot's `noalt` / `vm` modes | YASB `docs/widgets/(Widget)-GlazeWM-Binding-Mode.md` |
| centered active title | `ActiveWindowWidget` with `monitor_exclusive: false`, so every bar follows the globally focused window like Awtarchy | YASB Active Window source filters per monitor only when `monitor_exclusive` is true |
| task icons | `TaskbarWidget` with 14 px icons to match Awtarchy's current default; middle-click closes and right-click uses YASB's native minimize/restore toggle | current Awtarchy `smallIconSize` is 14 px; YASB taskbar supports monitor filtering plus native activate/minimize/close behavior |
| workspace move drawer | collapsed `GrouperWidget` containing `ApplicationsWidget` buttons that call GlazeWM's native directional workspace move command | YASB Grouper/Applications docs + existing WGDot GlazeWM `move-workspace --direction` bindings |
| CPU / memory | native CPU and Memory widgets | YASB CPU/Memory docs |
| DDC brightness | native Brightness widget | YASB brightness docs explicitly support external DDC/CI monitors and background DDC polling |
| battery | native Battery widget with `hide_unsupported`; left/right open Windows' own Power & battery settings because YASB has no battery-details popup, while middle-click toggles the alternate label | YASB Battery exposes no details menu. YASB v2.0.7 also has a native `PowerPlanWidget`, but it is a separate standalone widget and cannot be composed into Battery's click surface, so WGDot does not add another bar control just to mimic Awtarchy's integrated battery/power-mode flyout |
| microphone | native Microphone widget with an empty normal glyph and YASB's native `muted` class styling, so the bar indicator collapses while unmuted and appears red while muted | YASB Microphone source applies `muted` / `no-device` classes dynamically |
| output audio | native Volume widget for mute/scroll volume; right-click opens the existing WGDot EarTrumpet mixer helper, paralleling Awtarchy's Wiremix action | YASB Volume callbacks + existing WGDot `eartrumpet-mixer` integration |
| clock/date | Clock widget primary/alternate labels; left/right toggle time/date and middle opens YASB's native calendar | YASB v2.0.7 Clock registers left/middle/right callbacks but no wheel callback, so Awtarchy's wheel-to-toggle behavior is deliberately not scripted |
| network / Bluetooth | native WiFi and Bluetooth menus; both left and right click open the native menu, matching Awtarchy's bar behavior | YASB WiFi/Bluetooth docs and registered `toggle_menu` callbacks |
| inline tray | native Systray widget with 14 px icons and `use_hook: false` | YASB v2.0.7 shares one native tray monitor service across all Systray widget instances while each instance keeps screen-specific state; this supports the multi-monitor bar design without enabling the Explorer DLL hook |
| clipboard history | a dedicated `QuickLaunchWidget` instance with only YASB's native Windows Clipboard History provider enabled; it opens directly to history and supports text/images, restore, delete, clear, and previews | YASB Quick Launch and Clipboard History provider docs/source |
| notifications / mute | one native `DndWidget`: left click uses YASB's built-in `exec notification_center` mapping to open Windows Notification Center; right click uses the widget's native `toggle_status` callback for Windows Do Not Disturb; the icon changes from bell to muted bell with DND state | YASB v2.0.7 `BaseWidget`, Windows `function_map`, and DND source |
| power controls | native compact Power Menu popup; both left and right click use YASB's supported menu toggle | YASB Power Menu docs and registered `toggle_power_menu` callback |
| bar reservation + fullscreen hiding | keep WGDot's existing 38 px GlazeWM top gap, with YASB `always_on_top: true`, `windows_app_bar: false`, and `hide_on_fullscreen: true` | YASB supports non-AppBar always-on-top/fullscreen behavior; this avoids forcing a GlazeWM reload solely to migrate reservation models |
| Flow Launcher button | a static native `CustomWidget` calling the existing WGDot `flow-open` helper on both left and right click, matching Awtarchy's launcher mouse behavior | YASB Custom widget uses normal registered mouse callbacks and the existing WGDot helper |
| legacy bar visibility hotkey | WGDot keeps its existing `Alt+Ctrl+B` convenience but implements it with supported `yasbc toggle-bar` instead of killing/restarting YASB | YASB CLI `toggle-bar` + managed GlazeWM binding |
| theme switching | WGDot `theme` writes only `~/.config/yasb/theme.css`; YASB's watched `@import` applies the palette live. The bar palette button and `Win+T` open the same compact Windows Terminal selector so apply/runtime errors stay visible. The terminal is given the stable title `WGDot Themes`, and the managed GlazeWM profiles float/center that title so opening the selector does not intentionally disturb the tiling tree. The palette set mirrors Awtarchy's current themes. | YASB v2.0.7 watches imported stylesheets through its stylesheet watcher; no YASB restart or GlazeWM reload is required |

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
- Awtarchy's single notification icon maps to one YASB `DndWidget`: left click opens Windows Notification Center through YASB's native system-function mapping, while right click toggles Windows Do Not Disturb. This is still an approximation because Windows Notification Center and DND are separate Windows facilities, and YASB's DND implementation uses the Windows QuietHoursSettings COM API documented by YASB as an undocumented Windows API, so Windows updates can change that behavior.
- Awtarchy's `Win+Alt+Ctrl+B` changes focused-monitor auto-hide and releases the exclusive zone. YASB v2.0.7 has native auto-hide, but no supported runtime CLI toggle for that configuration flag. WGDot's `yasbc toggle-bar` hard-hide also cannot reclaim the separate 38 px GlazeWM reservation. WGDot therefore does **not** bind the Awtarchy auto-hide chord to `toggle-bar`; the older `Alt+Ctrl+B` hard-visibility convenience remains separate.
- Awtarchy themes also retint Hyprland borders. WGDot deliberately does not retint GlazeWM on theme changes because GlazeWM requires a config reload and reloads can disturb the current tiling layout. Both managed GlazeWM profiles therefore keep the focused border at neutral `#a1a1a1`, while YASB changes live.
- Awtarchy's theme picker provides large visual preview cards and marks the active theme. The Windows translation keeps a simpler WGDot terminal selector that marks the current palette with `*` but does not fake graphical preview cards. YASB's Applications widget launches arbitrary app entries through a shell with output discarded, so using it as a direct palette drawer would hide WGDot errors and can introduce console-launch behavior rather than giving a true native theme-state UI. The selector window is intentionally floated by its fixed Windows Terminal title instead of forcing a GlazeWM config reload when a palette changes.

## Anti-cheat-sensitive choices

The YASB systray stays on `use_hook: false`. Upstream documents `use_hook: true` as an `explorer.exe` DLL-injection method that may interact badly with Defender or other security software. WGDot does not need that extra hook merely to imitate the Awtarchy tray.

No AutoHotkey, whkd, keyboard hook, DLL injection, or custom background input daemon is added by this bar translation.
