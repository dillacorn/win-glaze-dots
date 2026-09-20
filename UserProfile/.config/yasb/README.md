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

- active window title

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
- Windows notifications
- power menu

The bar uses Awtarchy's current flat palette: `#353535` background, `#d0d0d0` foreground, subtle active/hover fills, square controls, and a 28 px horizontal bar. JetBrainsMono NFP remains the Windows font because WGDot already installs it; this branch does not add another font dependency solely for visual parity.

Because YASB now reserves its own 28 px Windows AppBar area, the managed GlazeWM profiles use the normal 8 px top outer gap. The previous 38 px top gap was a manual allowance for the old non-AppBar YASB setup and would create a double gap with this configuration.

## Evidence-backed mappings

These translations use documented upstream YASB or GlazeWM behavior rather than custom emulation:

| Awtarchy behavior | Windows mapping | Evidence |
| --- | --- | --- |
| monitor-local workspaces + wheel switching | `GlazewmWorkspacesWidget` | YASB `docs/widgets/(Widget)-GlazeWM-Workspaces.md` |
| visible Hyprland submap | `GlazewmBindingModeWidget` for WGDot's `noalt` / `vm` modes | YASB `docs/widgets/(Widget)-GlazeWM-Binding-Mode.md` |
| task icons | `TaskbarWidget` | YASB taskbar supports monitor filtering, close callbacks, minimize/restore focus behavior, and disabled animation |
| workspace move drawer | collapsed `GrouperWidget` containing `ApplicationsWidget` buttons that call GlazeWM's native directional workspace move command | YASB Grouper/Applications docs + existing WGDot GlazeWM `move-workspace --direction` bindings |
| CPU / memory | native CPU and Memory widgets | YASB CPU/Memory docs |
| DDC brightness | native Brightness widget | YASB brightness docs explicitly support external DDC/CI monitors and background DDC polling |
| battery | native Battery widget with `hide_unsupported` | YASB Battery docs |
| microphone | native Microphone widget | YASB Microphone docs |
| output audio | native Volume widget | YASB Volume docs |
| clock/date | Clock widget primary/alternate labels | YASB Clock docs |
| network / Bluetooth | native WiFi and Bluetooth menus | YASB WiFi/Bluetooth docs |
| inline tray | native Systray widget | YASB Systray docs |
| notifications | native Notifications widget opening Windows Action Center | YASB Notifications docs |
| power controls | native compact Power Menu popup | YASB Power Menu docs |
| exclusive bar area + fullscreen hiding | `windows_app_bar: true` + `hide_on_fullscreen: true`; GlazeWM keeps its ordinary 8 px outer gap instead of the old 38 px manual bar allowance | YASB bar configuration + Awtarchy `Bar.qml` uses `exclusiveZone: barSize` while Hyprland keeps normal `gaps_out` |
| Flow Launcher button | `ApplicationsWidget` launching the existing WGDot helper | YASB Applications widget supports arbitrary commands |

## Deliberate differences and omissions

The following Awtarchy features are not translated because a direct supported equivalent was not verified:

- CPU temperature: YASB's CPU widget does not expose CPU temperature. GPU temperature or an external Libre Hardware Monitor service would not be the same feature.
- idle inhibitor: no native YASB idle-inhibitor equivalent was verified.
- Hyprland special-workspace scratchpad count: GlazeWM does not expose the same special-workspace model.
- Awtarchy's global "new windows float" indicator: no direct GlazeWM/YASB state equivalent was verified.
- privacy / screen-capture indicator: no native YASB equivalent was verified.
- one-click Awtarchy clipboard popup: YASB has Windows clipboard history inside Quick Launch, but not the same dedicated bar surface.
- vertical left/right bar layouts: current YASB bar positioning supports top/bottom, not Awtarchy's vertical edge layouts.
- workspace urgent-state coloring and Awtarchy's static number+glyph workspace labels: the YASB GlazeWM workspace widget does not expose those exact Hyprland states/mappings.
- Awtarchy's workspace mover expands on hover and includes a mouse submap toggle. YASB's native Grouper expands by click, and WGDot has no equivalent mouse binding mode.
- Awtarchy only shows its microphone indicator while muted. YASB's native microphone widget remains visible and applies a muted CSS state instead.
- task-icon left click is not identical: YASB's native `toggle_window` minimizes an already-active window; Awtarchy's left click simply activates it.
- task-icon right click intentionally uses YASB's native Windows context menu. Awtarchy uses right click to minimize/restore; YASB exposes `toggle_window`, `close_app`, and `context_menu`, so keeping the Windows context menu avoids inventing another input layer.

## Anti-cheat-sensitive choices

The YASB systray stays on `use_hook: false`. Upstream documents `use_hook: true` as an `explorer.exe` DLL-injection method that may interact badly with Defender or other security software. WGDot does not need that extra hook merely to imitate the Awtarchy tray.

No AutoHotkey, whkd, keyboard hook, DLL injection, or custom background input daemon is added by this bar translation.
