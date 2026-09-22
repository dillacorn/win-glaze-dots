# Awtarchy-inspired YASB

This YASB configuration mirrors the current Awtarchy bar where Windows, YASB, and GlazeWM have direct supported equivalents.

WGDot manages installation, updates, backups, and deployment. Runtime ownership is hybrid: GlazeWM, YASB, Windows, and applications own behavior they can provide natively, while a small compiled WGDot runtime handles only custom Windows behavior that genuinely needs code or low-level APIs.

## Runtime ownership

- **GlazeWM** owns window-manager keybindings, binding modes, pause, workspace actions, screenshots, and direct Windows/application launches.
- **YASB** owns ordinary bar widgets and native callbacks; for the custom application launcher it owns only the visible bar button.
- **Installed applications** are launched directly where practical. GlazeWM opens EarTrumpet directly on `Super+V` / global `Alt+V`; WGDot's EarTrumpet packaged-hotkey configuration remains only a management-time fallback.
- **Neither Normal nor Work has any `.ps1` runtime dependencies.** Desktop-session behavior uses native GlazeWM/YASB/Windows/application interfaces first.
- **Compiled WGDot is used at runtime only for approved custom primitives:** the application launcher, power surface, idle inhibition, coordinated auto-hide, theme application/window toggle, invisible GlazeWM mode dispatch where a console would otherwise flash, the narrow RawAccel GUI toggle, and the experimental native Clipboard History handoff.
- Runtime actions that must stay invisible use the windowless `wgdotw.exe` frontend; the interactive theme selector uses `wgdot.exe theme` inside Windows Terminal.

## Bar layout

Left:

- Awtarchy-style application launcher
- GlazeWM workspaces
- direct workspace-move arrows
- running-window task icons
- active GlazeWM binding mode
- GlazeWM tiling direction

Center:

- globally focused active-window title

Right:

- Windows Keep Awake / idle inhibitor
- CPU usage
- memory usage
- YASB Control Center / quick settings
- brightness
- battery when supported
- microphone
- output volume
- clock/date
- Wi-Fi
- Bluetooth
- Windows Clipboard History
- unified Windows notifications / Do Not Disturb
- native YASB power menu

The system tray definition remains available but is not rendered in the bar. `use_hook: false` is retained so YASB does not inject into Explorer.

## Launcher ownership

The application button is a lightweight YASB `CustomWidget` that opens `wgdotw.exe launcher bar`. GlazeWM opens the same single-purpose compiled surface with `wgdotw.exe launcher hotkey`.

- Global `Alt+P` and `Super+D` open the launcher.
- `noalt` retains `Super+D` but intentionally leaves plain `Alt+P` uncaptured.
- Bar click opens directly below the top bar at the top-left of the active display while the bar is visible.
- Keyboard activation opens horizontally centered just below the top bar during ordinary desktop use.
- If YASB auto-hide is enabled, or the foreground window fills the active monitor, the launcher opens centered on that monitor.
- The first implementation is intentionally application-focused: it indexes Start Menu shortcuts and avoids Flow Launcher-style provider/scaling complexity.
- Flow Launcher remains optional and is not the default hotkey surface.
- VM mode has no ordinary launcher binding that steals guest shortcuts.

## Binding modes

GlazeWM owns `noalt` and `vm` modes directly with `wm-enable-binding-mode` and `wm-disable-binding-mode`.

`Win+Alt+N` and `Win+Alt+V` enter the corresponding mode. The same mode chord exits that mode, and mode-to-mode transitions explicitly disable the current mode first.

YASB's native `GlazewmBindingModeWidget` displays those modes. Clicking the visible active mode disables that mode; it does not cycle to another mode. GlazeWM remains the source of truth for mode state.

Real GlazeWM pause remains `Win+Alt+P` and uses `wm-toggle-pause`.

The experimental mouse binding mode and low-level WGDot pointer hook were removed after real-Windows testing showed pointer lag and unreliable tiled-window dragging. Its old bar slot is gone completely. The four native GlazeWM workspace arrows remain directly visible and usable without a placeholder hub.

## Themes

`theme.css` and `appearance.css` are normal tracked dotfiles.

WGDot also remembers the selected theme separately. If a managed dots update replaces `theme.css` or WGDot-managed Windows Terminal settings, WGDot reapplies that remembered theme after the update so the active palette is preserved.

The compiled WGDot theme manager is launched as `wgdot.exe theme` inside Windows Terminal. It:

- writes the selected YASB palette to `~/.config/yasb/theme.css`
- updates only WGDot-owned Windows Terminal theme entries/settings when Terminal settings exist, preserving unrelated Terminal configuration
- records its own lightweight theme state under `~/.config/win-glaze`
- does **not** reload GlazeWM

The selector uses the title `Win Glaze Themes`, and both GlazeWM profiles float/center that window.

`Super+Alt+T` toggles the single `Win Glaze Themes` window. Pressing it again in the same visible monitor/workspace closes it; invoking it from another monitor or a cloaked workspace closes the old instance and reopens exactly one selector in the currently focused context. `Super+T` toggles tiling, as does global `Alt+T`; `noalt` intentionally leaves plain `Alt+T` unbound while retaining `Super+T`.

GlazeWM focused borders stay neutral `#a1a1a1` so a theme change never requires a layout-disrupting GlazeWM reload.

## Coordinated bar auto-hide

`Alt+Ctrl+B` invokes `wgdotw.exe bar-autohide-toggle` in both profiles.

The compiled helper coordinates:

- YASB `auto_hide: true/false`
- GlazeWM top gap `5px/35px`
- a YASB reload
- a GlazeWM config reload

The blank-bar context menu stays disabled so there is no second unsynchronized auto-hide control.

## Idle inhibitor

The eye control uses `wgdot.exe idle-inhibitor-status` for status and `wgdotw.exe idle-inhibitor-toggle` for changes in both profiles.

The helper uses Windows `SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED)` in a scoped hidden user-session worker. It changes no power-plan values. The normal status poll is a 30-second fallback; a user toggle requests one silent public `yasbc reload -s` so every monitor/bar immediately re-queries the shared state instead of waiting on a tight poll.

## RawAccel

`Super+Shift+M` uses `wgdotw.exe rawaccel-toggle` in both profiles. The helper is deliberately narrow: if the RawAccel GUI is open it closes that GUI process; otherwise it locates and launches `rawaccel.exe`. Windows does not add Awtarchy's `Alt+Shift+M` alias.

## Power controls

The bar power button is a lightweight YASB `CustomWidget` that opens the compiled `wgdotw.exe power-menu` surface.

The power surface preserves the Awtarchy-style fullscreen 3x2 tile layout for Lock, Hibernate, Reboot, Shutdown, Sign out, and Sleep. It follows the active WGDot/YASB theme and fades in/out to avoid a bright first-frame flash.

`Super+P` is owned by GlazeWM and opens the same windowless compiled power surface. No PowerShell runtime script is involved.

## Audio

The native YASB Volume widget retains Awtarchy-like mute glyphs, thresholds, and 5-point wheel changes.

Right-click launches EarTrumpet directly through its packaged AppsFolder identity.

GlazeWM also launches EarTrumpet directly on `Super+V` and global `Alt+V`. In `noalt`, `Super+V` remains available while plain `Alt+V` is intentionally left uncaptured.

WGDot may configure EarTrumpet's own mixer hotkey to `Super+V` during explicit environment management. After configuration, EarTrumpet owns the chord itself; no WGDot helper or synthetic Alt+V bridge is used.

## Clipboard

The old generic WGDot clipboard-history worker/window remains removed.

YASB's Quick Launch clipboard provider stays disabled. Instead, the bar restores a dedicated Clipboard History button and GlazeWM binds `Super+C` to the narrow `wgdotw.exe clipboard-anchor` handoff. Reliability is prioritized over fake placement: the helper leaves the user's foreground window in place, waits for the Windows modifier to be released, preserves and verifies GlazeWM's pause state around native `Win+V`, restores that state, then exits. It currently makes no bar-relative positioning claim; that behavior stays out until real-Windows evidence proves a reliable Windows-supported path.

## Font parity

The Windows bar stays on `JetBrainsMono NFP` at 14 px. WGDot already manages that Nerd Font and it preserves the icon coverage the bar needs. Awtarchy currently uses `NotoSansM Nerd Font Mono` at 14 px, but WGDot does not reference that exact Windows family until it has a verified managed installation path for it.

## Evidence-backed mappings

| Awtarchy behavior | Windows mapping |
| --- | --- |
| monitor-local workspaces + wheel switching | native `GlazewmWorkspacesWidget` |
| visible submap state | native `GlazewmBindingModeWidget` for `noalt` / `vm`; click disables active mode |
| tiling direction | native `GlazewmTilingDirectionWidget` |
| active title | `ActiveWindowWidget` with `monitor_exclusive: false` |
| task icons | native `TaskbarWidget`, 14 px icons in Awtarchy-sized slots |
| workspace mover | direct YASB Applications widget with native GlazeWM move-workspace commands |
| quick settings | native `ControlCenterWidget` plus narrowly scoped compiled WGDot theme/auto-hide/mode actions |
| CPU / memory | native CPU and Memory widgets |
| DDC brightness | native Brightness widget |
| battery | native Battery widget with Awtarchy-like thresholds and glyph composition |
| microphone | native Microphone widget |
| output audio | native Volume widget + direct EarTrumpet launch |
| clock/date | native Clock widget |
| network / Bluetooth | native WiFi/Bluetooth indicators opening Windows Network/Bluetooth Settings surfaces |
| notifications / mute | native `DndWidget` |
| power controls | compiled Awtarchy-style `wgdotw.exe power-menu` surface |
| launcher | compiled context-aware `wgdotw.exe launcher` application search surface |
| theme switching | compiled `wgdot.exe theme` manager with `wgdotw.exe theme-window-toggle` dispatch |
| bar auto-hide | compiled `wgdotw.exe bar-autohide-toggle` coordinator in both profiles |
| keep awake | compiled WGDot execution-state helper in both profiles |
| RawAccel GUI toggle | compiled `wgdotw.exe rawaccel-toggle` in both profiles |

## Deliberate differences and omissions

- CPU temperature is not represented because YASB's CPU widget does not expose the same CPU-temperature value.
- Hyprland special-workspace scratchpad state has no direct GlazeWM equivalent.
- Awtarchy's global "new windows float" indicator has no verified direct GlazeWM/YASB state equivalent.
- A dedicated privacy/screen-capture indicator has no verified native YASB equivalent.
- Current YASB bar placement is top/bottom; left/right vertical bars are not faked.
- Workspace urgent-state coloring and Awtarchy's static number+glyph mappings do not have exact YASB equivalents.
- The experimental mouse binding mode is intentionally omitted. Its placeholder/hub is also removed; the four directional workspace arrows remain directly available.
- Awtarchy can retint task/tray image pixels; stock YASB does not expose an equivalent image-tint option.
- At exactly 15% battery, YASB's shared threshold controls both critical styling and glyph selection, so the exact Awtarchy glyph boundary cannot be reproduced independently.
- A plugged-in-but-not-charging battery may retain YASB's critical state at low charge because YASB exposes a charging class rather than a broader AC-present class.
- YASB Volume exposes its numeric `{level}` with a trailing `%`; there is no raw integer placeholder.
- YASB Bluetooth has no conditional primary-label expression for empty/single-device/device-count states.
- YASB Wi-Fi has no bar-label connectivity CSS class equivalent to Awtarchy's disconnected foreground behavior.
- YASB Clock exposes left/middle/right callbacks but no wheel callback.

## Reserved-key development test

Windows still reserves `Win+L`, and the selective Explorer hotkey policy does not reclaim it. WGDot's `super-l-test` remains an explicit maintainer/development diagnostic only. It is not part of the normal desktop runtime and is not advertised as a user binding.

## Anti-cheat-sensitive choices

- YASB systray stays `use_hook: false`.
- No AutoHotkey, whkd, Explorer DLL injection, or third-party general-purpose input daemon is added.
- Runtime helpers are narrowly scoped. Normal and Work have no `.ps1` runtime dependencies; native-capable actions remain outside WGDot.
