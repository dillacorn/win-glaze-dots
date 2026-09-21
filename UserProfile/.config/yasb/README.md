# Awtarchy-inspired YASB

This YASB configuration mirrors the current Awtarchy bar where Windows, YASB, and GlazeWM have direct supported equivalents.

WGDot manages installation, updates, backups, and deployment. Runtime ownership is hybrid: GlazeWM, YASB, Windows, and applications own behavior they can provide natively, while a small compiled WGDot runtime handles only custom Windows behavior that genuinely needs code or low-level APIs.

## Runtime ownership

- **GlazeWM** owns window-manager keybindings, binding modes, pause, workspace actions, screenshots, and direct Windows/application launches.
- **YASB** owns bar widgets, native widget callbacks, its native power menu, DND, and Quick Launch.
- **Installed applications** own their supported native hotkeys where possible. EarTrumpet is configured to own `Super+V` directly.
- **Neither Normal nor Work has any `.ps1` runtime dependencies.** Desktop-session behavior uses native GlazeWM/YASB/Windows/application interfaces first.
- **Compiled WGDot is used at runtime only for approved custom primitives:** the mouse hook, idle inhibition, coordinated auto-hide, theme application, invisible GlazeWM mode dispatch where a console would otherwise flash, and the narrow RawAccel GUI toggle.
- Runtime actions that must stay invisible use the windowless `wgdotw.exe` frontend; the interactive theme selector uses `wgdot.exe theme` inside Windows Terminal.

## Bar layout

Left:

- YASB Quick Launch
- GlazeWM workspaces
- hover-revealed workspace-move controls
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
- unified Windows notifications / Do Not Disturb
- native YASB power menu

The system tray definition remains available but is not rendered in the bar. `use_hook: false` is retained so YASB does not inject into Explorer.

## Launcher ownership

YASB Quick Launch is opened from its native bar widget. It does not register a private synthetic hotkey and GlazeWM does not inject a key to open it.

- Normal profile: no external Quick Launch chord is advertised until YASB exposes a documented direct command/interface that GlazeWM can invoke.
- Work profile: `Alt+P` launches Flow Launcher directly from GlazeWM for the current work-PC test.
- `Super+D` is not faked through YASB, PowerShell, SendKeys, or WGDot.
- VM mode therefore has no launcher relay that can steal guest shortcuts.

## Binding modes

GlazeWM owns `noalt`, `mouse`, and `vm` modes directly with `wm-enable-binding-mode` and `wm-disable-binding-mode`.

`Win+Alt+N`, `Win+Alt+M`, and `Win+Alt+V` enter the corresponding mode. The same mode chord exits that mode, and mode-to-mode transitions explicitly disable the current mode first.

YASB's native `GlazewmBindingModeWidget` displays those modes. Clicking the visible active mode disables that mode; it does not cycle to another mode. GlazeWM remains the source of truth for mode state.

Real GlazeWM pause remains `Win+Alt+P` and uses `wm-toggle-pause`.

GlazeWM 3.10.x still does not expose mouse buttons through its keybinding parser. GlazeWM owns `mouse` mode state, while the scoped compiled WGDot mouse hook supplies the actual left-drag move, right-drag resize, and middle-click floating behavior and exits automatically when mouse mode ends.

## Themes

`theme.css` and `appearance.css` are normal tracked dotfiles.

The compiled WGDot theme manager is launched as `wgdot.exe theme` inside Windows Terminal. It:

- writes the selected YASB palette to `~/.config/yasb/theme.css`
- updates only WGDot-owned Windows Terminal theme entries/settings when Terminal settings exist, preserving unrelated Terminal configuration
- records its own lightweight theme state under `~/.config/win-glaze`
- does **not** reload GlazeWM

The selector uses the title `Win Glaze Themes`, and both GlazeWM profiles float/center that window.

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

The helper uses Windows `SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED)` in a scoped hidden user-session worker. It changes no power-plan values.

## RawAccel

`Super+Shift+M` uses `wgdotw.exe rawaccel-toggle` in both profiles. The helper is deliberately narrow: if the RawAccel GUI is open it closes that GUI process; otherwise it locates and launches `rawaccel.exe`. Windows does not add Awtarchy's `Alt+Shift+M` alias.

## Power controls

The bar power button is a lightweight YASB `CustomWidget` that opens the compiled `wgdotw.exe power-menu` surface.

The power surface preserves the Awtarchy-style fullscreen 3x2 tile layout for Lock, Hibernate, Reboot, Shutdown, Sign out, and Sleep. It follows the active WGDot/YASB theme and fades in/out to avoid a bright first-frame flash.

`Super+P` is owned by GlazeWM and opens the same windowless compiled power surface. No PowerShell runtime script is involved.

## Audio

The native YASB Volume widget retains Awtarchy-like mute glyphs, thresholds, and 5-point wheel changes.

Right-click launches EarTrumpet directly through its packaged AppsFolder identity.

WGDot may configure EarTrumpet's own mixer hotkey to `Super+V` during explicit environment management. After configuration, EarTrumpet owns the chord itself; no WGDot helper or synthetic Alt+V bridge is used.

## Clipboard

The previous WGDot-owned clipboard-history worker/window has been removed from the desktop runtime.

YASB's Quick Launch clipboard-history provider remains disabled because it depends on Windows Clipboard History, which was unreliable in maintainer testing.

There is currently no rendered clipboard-history bar button and no managed `Super+C` custom history shortcut. If custom history returns, it must be implemented as a portable dotfile-owned helper that works without WGDot.

## Evidence-backed mappings

| Awtarchy behavior | Windows mapping |
| --- | --- |
| monitor-local workspaces + wheel switching | native `GlazewmWorkspacesWidget` |
| visible submap state | native `GlazewmBindingModeWidget` for `noalt` / `mouse` / `vm`; click disables active mode |
| tiling direction | native `GlazewmTilingDirectionWidget` |
| active title | `ActiveWindowWidget` with `monitor_exclusive: false` |
| task icons | native `TaskbarWidget`, 14 px icons in Awtarchy-sized slots |
| workspace mover | passive native YASB Grouper with GlazeWM move-workspace commands |
| quick settings | native `ControlCenterWidget` plus narrowly scoped compiled WGDot theme/auto-hide/mode actions |
| CPU / memory | native CPU and Memory widgets |
| DDC brightness | native Brightness widget |
| battery | native Battery widget with Awtarchy-like thresholds and glyph composition |
| microphone | native Microphone widget |
| output audio | native Volume widget + direct EarTrumpet launch |
| clock/date | native Clock widget |
| network / Bluetooth | native WiFi and Bluetooth widgets |
| notifications / mute | native `DndWidget` |
| power controls | compiled Awtarchy-style `wgdotw.exe power-menu` surface |
| launcher | native `QuickLaunchWidget`; Work `Alt+P` launches Flow directly during testing |
| theme switching | compiled `wgdot.exe theme` manager in both profiles |
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
- The native `mouse` binding mode exists and toggles with `Win+Alt+M`; the scoped WGDot hook supplies mouse-button move/resize because GlazeWM 3.10.x does not expose mouse buttons.
- Custom clipboard history is omitted until it has a portable implementation independent of WGDot.
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
