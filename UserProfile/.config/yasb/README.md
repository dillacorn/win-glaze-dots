# Awtarchy-inspired YASB

This YASB configuration mirrors the current Awtarchy bar where Windows, YASB, and GlazeWM have direct supported equivalents.

WGDot manages installation, updates, backups, and deployment of these files. It is not part of the running desktop. The copied GlazeWM/YASB configs and the scripts under `~/.config/win-glaze/scripts` are the runtime environment.

## Runtime ownership

- **GlazeWM** owns window-manager keybindings, binding modes, pause, workspace actions, screenshots, and direct Windows/application launches.
- **YASB** owns bar widgets, native widget callbacks, its native power menu, DND, Quick Launch, and the private Quick Launch hotkey.
- **Installed applications** own their supported native hotkeys where possible. EarTrumpet is configured to own `Super+V` directly.
- **Portable non-elevated scripts** handle only custom behavior that needs coordination across applications:
  - `theme-switcher.ps1`
  - `bar-autohide.ps1`
  - `idle-inhibitor.ps1`
  - `yasb-quick-launch.ps1`
  - `flow-launcher.ps1`
  - `rawaccel-toggle.ps1`
- **WGDot is never required when a bar button or window-manager keybinding is used.**

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

YASB Quick Launch registers only a private `F24` hotkey. It must not globally register `Alt+P` or `Super+D`, because a Windows `RegisterHotKey` registration would steal those chords even while GlazeWM is in VM mode.

GlazeWM owns the user-facing chords and invokes the portable `yasb-quick-launch.ps1` bridge:

- Normal profile: `Alt+P` and `Super+D` open YASB Quick Launch.
- Work profile: `Alt+P` opens Flow Launcher and `Super+D` opens YASB Quick Launch.
- VM mode does not define those chords, so they can pass through to the guest.

The Work split is an A/B migration choice, not the normal project default.

## Binding modes

GlazeWM owns `noalt` and `vm` modes directly with `wm-enable-binding-mode` and `wm-disable-binding-mode`.

YASB's native `GlazewmBindingModeWidget` displays and cycles those modes. No WGDot-tracked mode state is required.

Real GlazeWM pause remains `Win+Alt+P` and uses `wm-toggle-pause`.

Mouse-window mode is currently omitted. GlazeWM 3.10.x does not expose mouse buttons through its normal keybinding parser, and the previous WGDot-owned hook was removed with the runtime-decoupling work. Do not render a dead mouse-mode control.

## Themes

`theme.css` and `appearance.css` are normal tracked dotfiles.

`theme-switcher.ps1` is a non-elevated standalone script. It:

- writes the selected YASB palette to `~/.config/yasb/theme.css`
- updates the user's Windows Terminal color/UI theme when Terminal settings exist
- records its own state under `~/.config/win-glaze`
- does **not** reload GlazeWM

The selector is launched in Windows Terminal with the title `Win Glaze Themes`, and both GlazeWM profiles float/center that window.

GlazeWM focused borders stay neutral `#a1a1a1` so a theme change never requires a layout-disrupting GlazeWM reload.

## Coordinated bar auto-hide

`Alt+Ctrl+B` invokes `bar-autohide.ps1`.

The script coordinates:

- YASB `auto_hide: true/false`
- GlazeWM top gap `5px/35px`
- a YASB reload
- a GlazeWM config reload

The blank-bar context menu stays disabled so there is no second unsynchronized auto-hide control.

## Idle inhibitor

The eye control invokes `idle-inhibitor.ps1`.

The script uses Windows `SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED)` in a hidden user-session PowerShell worker. It changes no power-plan values and requires no WGDot process.

## Power controls

The bar uses YASB's native `PowerMenuWidget` with Lock, Sign out, Sleep, Hibernate, Restart, Shutdown, and Cancel.

`Super+P` is owned by the YASB power-menu keybinding. GlazeWM deliberately does not capture that chord.

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
| visible submap state | native `GlazewmBindingModeWidget` for `noalt` / `vm` |
| tiling direction | native `GlazewmTilingDirectionWidget` |
| active title | `ActiveWindowWidget` with `monitor_exclusive: false` |
| task icons | native `TaskbarWidget`, 14 px icons in Awtarchy-sized slots |
| workspace mover | passive native YASB Grouper with GlazeWM move-workspace commands |
| quick settings | native `ControlCenterWidget` plus standalone theme/auto-hide scripts |
| CPU / memory | native CPU and Memory widgets |
| DDC brightness | native Brightness widget |
| battery | native Battery widget with Awtarchy-like thresholds and glyph composition |
| microphone | native Microphone widget |
| output audio | native Volume widget + direct EarTrumpet launch |
| clock/date | native Clock widget |
| network / Bluetooth | native WiFi and Bluetooth widgets |
| notifications / mute | native `DndWidget` |
| power controls | native `PowerMenuWidget` |
| launcher | native `QuickLaunchWidget` behind the portable F24 bridge |
| theme switching | standalone non-elevated `theme-switcher.ps1` |
| bar auto-hide | standalone non-elevated `bar-autohide.ps1` |
| keep awake | standalone non-elevated `idle-inhibitor.ps1` |

## Deliberate differences and omissions

- CPU temperature is not represented because YASB's CPU widget does not expose the same CPU-temperature value.
- Hyprland special-workspace scratchpad state has no direct GlazeWM equivalent.
- Awtarchy's global "new windows float" indicator has no verified direct GlazeWM/YASB state equivalent.
- A dedicated privacy/screen-capture indicator has no verified native YASB equivalent.
- Current YASB bar placement is top/bottom; left/right vertical bars are not faked.
- Workspace urgent-state coloring and Awtarchy's static number+glyph mappings do not have exact YASB equivalents.
- Mouse-window move/resize mode is omitted until it has a portable implementation independent of WGDot.
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
- Portable helpers are narrowly scoped PowerShell scripts shipped with the dots, not WGDot background services.
