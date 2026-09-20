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
| visible mode state | `GlazewmBindingModeWidget` is retained only for the real `vm` binding mode. The broken `noalt` emulation is removed; GlazeWM's real `wm-toggle-pause` is exposed separately as a `PAUSED` bar indicator | current GlazeWM filters all normal keybindings while paused except bindings containing `wm-toggle-pause`; WGDot queries `glazewm query paused` once per second for the bar state |
| centered active title | `ActiveWindowWidget` with `monitor_exclusive: false`, so every bar follows the globally focused window like Awtarchy | YASB Active Window source filters per monitor only when `monitor_exclusive` is true |
| task icons | `TaskbarWidget` with 14 px icons in 26 px total task slots; middle-click closes and right-click uses YASB's native minimize/restore toggle | current Awtarchy `smallIconSize` is 14 px and each horizontal task is `max(26, smallIconSize + 12)` = 26 px. Qt QSS sizes `min-width` / `max-width` against the content rect, so WGDot uses 14 px content plus 6 px horizontal padding per side |
| workspace move drawer | collapsed `GrouperWidget` containing 14 px symbol-sized `ApplicationsWidget` buttons with Awtarchy's 8 px side padding; the arrows call GlazeWM's native directional workspace move command | current Awtarchy renders the hub/arrows at 14 px with `BarControl`'s default 8 px horizontal padding; YASB Grouper/Applications provide content-sized native controls |
| CPU / memory | native CPU and Memory widgets, using the same unitless integer bar labels as current Awtarchy (`42 `, `63 `); left click opens YASB's native detail popup as a Windows-native enhancement | current Awtarchy `SystemState.cpuUsage` / `memoryUsage` are integers; YASB exposes the same values plus supported native stat popups |
| DDC brightness | native Brightness widget with Awtarchy's fixed `` glyph and explicit `%` suffix at every level | YASB brightness supports a configurable four-entry icon list, external DDC/CI monitors, and background DDC polling; using the same glyph in all four slots preserves Awtarchy's fixed icon |
| battery | native Battery widget with `hide_unsupported`; the compact label matches Awtarchy's unitless percentage, battery bands, normal charging foreground, and battery-glyph-plus-bolt form. Critical color begins at 15%. Left/right open Windows' own Power & battery settings, while middle-click toggles the alternate label | current Awtarchy bands are `<15`, `15-39`, `40-64`, `65-89`, `90+` with red foreground at `<=15` when unplugged; YASB exposes configurable status thresholds plus `{icon}` / `{charging_icon}` composition. YASB v2.0.7 also has a native `PowerPlanWidget`, but it is a separate standalone control and cannot be composed into Battery's click surface, so WGDot does not add another permanent bar widget merely to imitate Awtarchy's integrated battery/power-mode flyout |
| microphone | native Microphone widget with an empty normal glyph and YASB's native `muted` class styling, so the bar indicator collapses while unmuted and appears red with Awtarchy's 8 px side padding while muted; YASB's native menu/mute actions remain available as a Windows-native enhancement | YASB Microphone source applies `muted` / `no-device` classes dynamically; current Awtarchy uses default 8 px `BarControl` horizontal padding |
| output audio | native Volume widget with Awtarchy's `` muted glyph, matching low/medium/high icon cutoffs (`0-24`, `25-59`, `60-100`), and the same 5-point wheel step; right-click opens the existing WGDot EarTrumpet mixer helper, paralleling Awtarchy's Wiremix action | YASB v2.0.7 accepts numeric threshold keys and configurable `scroll_step`; current Awtarchy `quickshell_volume.sh` changes volume by 5% per wheel action |
| clock/date | Clock widget primary/alternate labels; the alternate uses Windows `strftime` `%#m/%#d` so `Sun 9/20` matches Awtarchy's non-zero-padded `ddd M/d`; left/right toggle time/date and middle opens YASB's native calendar | YASB v2.0.7 delegates `{%...}` formatting to Python `strftime`; YASB itself uses the Windows `%#d` form elsewhere, while Microsoft CRT documents `#` as removing leading zeroes. Clock registers left/middle/right callbacks but no wheel callback |
| network / Bluetooth | native WiFi and Bluetooth menus; Wi-Fi uses Awtarchy's five signal glyphs including `󰤯` at zero strength, active Ethernet uses `󰈀`, and Bluetooth uses the same `` glyph in all states with disabled state muted by YASB's native `bt-off` class. Left/right click open the native menus | YASB v2.0.7 exposes five Wi-Fi icon slots, an Ethernet icon, configurable Bluetooth state icons, and `bt-off`/`bt-on`/`bt-connected` CSS classes |
| system tray | not rendered in the WGDot YASB bar; Windows taskbar remains the place for applet/tray interaction | the dormant YASB Systray definition stays `use_hook: false`, but `systray` is removed from the bar's right-side widget list |
| clipboard history | the `` bar button opens Windows' built-in Clipboard History. Windows keeps native `Win+V`; WGDot adds `Super+C` as the GlazeWM alias | WGDot synthesizes the native Win+V chord and managed GlazeWM configs no longer intercept Win+V for EarTrumpet |
| notifications / mute | one native `DndWidget`: left click uses YASB's built-in `exec notification_center` mapping to open Windows Notification Center; right click uses the widget's native `toggle_status` callback for Windows Do Not Disturb; the icon changes from bell to muted bell with DND state | YASB v2.0.7 `BaseWidget`, Windows `function_map`, and DND source |
| power controls | WGDot-native themed full-screen overlay modeled after Awtarchy's Quickshell menu: Lock (L), Hibernate (H), Reboot (R), Shutdown (S), Sign out (O), Sleep (Z), plus Escape/click-background close | YASB's stock PowerMenu does not support Awtarchy's direct letter shortcuts, so the bar uses a simple native callback surface while WGDot implements Windows-native system actions and the themed overlay |
| bar reservation + fullscreen hiding | keep WGDot's existing 38 px GlazeWM top gap, with YASB `always_on_top: true`, `windows_app_bar: false`, and `hide_on_fullscreen: true` | YASB supports non-AppBar always-on-top/fullscreen behavior; this avoids forcing a GlazeWM reload solely to migrate reservation models |
| blank bar right-click | disabled with `context_menu: false` so only actual bar controls own mouse actions | YASB enables its own bar context menu by default; current Awtarchy has no equivalent blank-bar menu |
| Flow Launcher button | a static native `CustomWidget` calling the existing WGDot `flow-open` helper on both left and right click, matching Awtarchy's launcher mouse behavior | YASB Custom widget uses normal registered mouse callbacks and the existing WGDot helper |
| legacy bar visibility hotkey | WGDot keeps its existing `Alt+Ctrl+B` convenience but implements it with supported `yasbc toggle-bar` instead of killing/restarting YASB | YASB CLI `toggle-bar` + managed GlazeWM binding |
| theme switching | WGDot `theme` writes only `~/.config/yasb/theme.css`; YASB's watched `@import` applies the palette live. The YASB managed component also runs an `ensure-yasb-theme` post-action after apply, regenerating the remembered palette or Carbon Night on a fresh install so `styles.css` never starts with a missing imported theme file. The bar palette button and `Win+T` call one WGDot `theme-toggle` path. A visible selector on the focused monitor closes; a selector on another monitor or a cloaked GlazeWM workspace is closed and recreated in the current context, preventing duplicate theme windows while keeping apply/runtime errors visible. The terminal is given the stable title `WGDot Themes`, and the managed GlazeWM profiles float/center that title so opening the selector does not intentionally disturb the tiling tree. The palette set mirrors Awtarchy's current themes. | YASB v2.0.7 watches imported stylesheets through its stylesheet watcher; no YASB restart or GlazeWM reload is required |

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
- Awtarchy can optionally retint task and tray icons per monitor. Current YASB v2.0.7 taskbar and systray schemas expose icon sizing/filtering but no native image-tint option, so WGDot leaves application and tray icons in their native colors rather than adding a custom image-processing path.
- Awtarchy uses the low-battery glyph `` at exactly 15% while also coloring that value critical red. YASB v2.0.7 uses one shared status threshold to choose both glyph and CSS state, so preserving the more important `<=15%` critical-color boundary means exactly 15% uses YASB's critical `` glyph; the surrounding ranges and colors match.
- Awtarchy suppresses critical battery color whenever AC is plugged in. YASB v2.0.7 includes `power_plugged` when composing the bolt icon, but emits the `status-charging` CSS state only while the battery is actively charging. A plugged-in-but-not-charging battery at or below 15% can therefore retain YASB's critical color even though the bolt is present; there is no native bar CSS class for the broader AC-only state.
- Awtarchy's unmuted volume text is a bare integer. YASB v2.0.7's native Volume widget formats its only numeric `{level}` placeholder with a trailing `%`; there is no separate raw numeric placeholder, so WGDot keeps the native value instead of replacing the Volume widget with a polling helper.
- Awtarchy's Bluetooth bar label conditionally shows one connected device's shortened name or a device count when several are connected. YASB exposes device names and count placeholders but no conditional label expression that can switch among empty/name/count in one primary label, so WGDot keeps the primary Bluetooth control icon-only and leaves device names to its native menu/tooltip.
- Awtarchy mutes the network bar foreground whenever neither Wi-Fi nor Ethernet is connected. YASB v2.0.7's WiFi widget exposes the correct state glyph/value but no connectivity CSS class on the bar label, so WGDot matches the glyphs and leaves the native YASB foreground rather than polling network state just to recolor it.

- Awtarchy's single notification icon maps to one YASB `DndWidget`: left click opens Windows Notification Center through YASB's native system-function mapping, while right click toggles Windows Do Not Disturb. This is still an approximation because Windows Notification Center and DND are separate Windows facilities, and YASB's DND implementation uses the Windows QuietHoursSettings COM API documented by YASB as an undocumented Windows API, so Windows updates can change that behavior.
- Awtarchy's `Win+Alt+Ctrl+B` changes focused-monitor auto-hide and releases the exclusive zone. YASB v2.0.7 has native auto-hide, but no supported runtime CLI toggle for that configuration flag. WGDot's `yasbc toggle-bar` hard-hide also cannot reclaim the separate 38 px GlazeWM reservation. WGDot therefore does **not** bind the Awtarchy auto-hide chord to `toggle-bar`; the older `Alt+Ctrl+B` hard-visibility convenience remains separate.
- Awtarchy themes also retint Hyprland borders. WGDot deliberately does not retint GlazeWM on theme changes because GlazeWM requires a config reload and reloads can disturb the current tiling layout. Both managed GlazeWM profiles therefore keep the focused border at neutral `#a1a1a1`, while YASB changes live.
- Awtarchy's theme picker provides large visual preview cards and marks the active theme. The Windows translation keeps a simpler WGDot terminal selector that marks the current palette with `*` but does not fake graphical preview cards. YASB's Applications widget launches arbitrary app entries through a shell with output discarded, so using it as a direct palette drawer would hide WGDot errors and can introduce console-launch behavior rather than giving a true native theme-state UI. The selector window is intentionally floated by its fixed Windows Terminal title instead of forcing a GlazeWM config reload when a palette changes.

## Anti-cheat-sensitive choices

The YASB systray stays on `use_hook: false`. Upstream documents `use_hook: true` as an `explorer.exe` DLL-injection method that may interact badly with Defender or other security software. WGDot does not need that extra hook merely to imitate the Awtarchy tray.

No AutoHotkey, whkd, keyboard hook, DLL injection, or custom background input daemon is added by this bar translation.
