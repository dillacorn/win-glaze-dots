# Awtarchy-inspired YASB

This YASB configuration mirrors the current Awtarchy bar where Windows, YASB, and GlazeWM have direct supported equivalents.

WGDot manages installation, updates, backups, and deployment. Runtime ownership is hybrid: GlazeWM, YASB, Windows, and applications own behavior they can provide natively, while a small compiled WGDot runtime handles only custom Windows behavior that genuinely needs code or low-level APIs.

## Runtime ownership

- **GlazeWM** owns window-manager keybindings, binding modes, pause, workspace actions, screenshots, and direct Windows/application launches.
- **YASB** owns ordinary bar widgets and native callbacks; for the custom application launcher it owns only the visible bar button.
- **Installed applications** own their native hotkeys where practical. EarTrumpet owns `Alt+V` itself; YASB volume right-click uses a narrow windowless WGDot bridge only to trigger that application-owned hotkey. WGDot does not rewrite the hotkey.
- **Neither Normal nor Work has any `.ps1` runtime dependencies.** Desktop-session behavior uses native GlazeWM/YASB/Windows/application interfaces first.
- **Compiled WGDot is used at runtime only for approved custom primitives:** the application launcher, power surface, coordinated auto-hide, theme application/window toggle, invisible GlazeWM mode dispatch where a console would otherwise flash, the narrow RawAccel GUI toggle, the bar-only one-shot Clipboard History opener, and the bar-only EarTrumpet mixer-hotkey trigger.
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
- Bar click opens directly below the top bar, flush with the active display's left edge.
- Keyboard activation opens horizontally centered just below the top bar during ordinary desktop use.
- For keyboard activation only, if YASB auto-hide is enabled or the foreground window fills the active monitor, the launcher opens centered on that monitor.
- The launcher stays compact at roughly half the old search-window width while retaining normal application-name room.
- Its results scrollbar is WGDot-drawn with the active YASB theme instead of the bright native Windows scrollbar.
- It indexes Start Menu shortcuts, activates them through Windows shell semantics, and resolves ordinary `.lnk` target/icon metadata so results prefer the underlying application icon instead of shortcut-style presentation where Windows exposes that metadata.
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

The custom idle-inhibitor eye is retired. Real-Windows testing showed the cross-display refresh path visibly reloaded the whole YASB bar, and the feature was not worth keeping as another live WGDot/YASB integration. No idle widget, polling command, or keep-awake worker runs in either profile.

## RawAccel

`Super+Shift+M` uses `wgdotw.exe rawaccel-toggle` in both profiles. The helper is deliberately narrow: if the RawAccel GUI is open it closes that GUI process; otherwise it locates and launches `rawaccel.exe`. Windows does not add Awtarchy's `Alt+Shift+M` alias.

## Power controls

The bar power button is a lightweight YASB `CustomWidget` that opens the compiled `wgdotw.exe power-menu` surface.

The power surface preserves the Awtarchy-style fullscreen 3x2 tile layout for Lock, Hibernate, Reboot, Shutdown, Sign out, and Sleep. It follows the active WGDot/YASB theme and fades in/out to avoid a bright first-frame flash.

`Super+P` is owned by GlazeWM and opens the same windowless compiled power surface. No PowerShell runtime script is involved.

## Audio

The native YASB Volume widget retains Awtarchy-like mute glyphs, thresholds, and 5-point wheel changes.

EarTrumpet owns Alt+V itself through its application settings. YASB volume right-click runs `wgdotw.exe eartrumpet-mixer-toggle`. That helper verifies EarTrumpet is running, starts its Start Menu shortcut if necessary, then injects Alt+V. EarTrumpet's own hotkey handler calls `WindowHolder.OpenOrClose()`, so repeated right-clicks open and close the mixer. Direct AppsFolder activation is intentionally not used because activating the packaged app does not invoke the mixer toggle. Super+V remains native Clipboard History.

## Clipboard

The old generic WGDot clipboard-history worker/window remains removed.

Super+V stays native Windows Clipboard History. GlazeWM does not override it and the retired Super+C/clipboard-anchor handoff is gone. The dedicated bar Clipboard History button uses only `wgdotw.exe clipboard-history-open`, a one-shot helper that injects native Win+V for the mouse click and immediately exits; it does not pause GlazeWM or claim custom placement.

## Font parity

The Windows bar uses the Noto Sans Mono Nerd Font face at 14 px to match Awtarchy. On Windows, the upstream TTF exposes its embedded family as `NotoSansM NFM`, so YASB must request that exact family; `JetBrainsMono NFP` remains the fallback. WGDot manages the face from the official `ryanoasis/nerd-fonts` Noto archive. Dots-only updates intentionally do not install fonts, so a machine without Noto installed will render the JetBrains fallback. Use `wgdot bar-font-install` to install only this current-user font without reconciling unrelated software, then restart YASB with `yasbc reload`. The command is idempotent: if the managed TTF is already present and loaded, WGDot reuses it and repairs the registry family mapping instead of trying to overwrite the locked file.

The Noto face renders Nerd Font glyphs smaller than the previous JetBrains fallback at the same nominal size. Bar text therefore remains 14 px while Nerd Font glyphs use Awtarchy's tuned sizes: generic/CPU/memory/brightness/clock/network/clipboard/control-center glyphs 18 px, battery 17 px, DND 19 px, volume and power 20 px. Real task/application icons remain 14 px. Workspace-move controls use the heavier Nerd Font arrow glyphs at 18 px instead of thin Unicode arrows. The separate GlazeWM tiling-direction indicator stays compact at 14 px in a fixed centered 26 px slot. Right-side metric text uses a 1 px bottom adjustment to align visually with the enlarged glyphs.

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
| output audio | native Volume widget + bar-only EarTrumpet mixer-hotkey trigger |
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
- YASB's native Clock tooltip currently hard-codes its time line to 24-hour `%H:%M`; stock configuration exposes only the tooltip enable/disable option, so a 12-hour AM/PM hover time requires an upstream YASB change rather than a dotfile-only setting.

## Reserved-key development test

Windows still reserves `Win+L`, and the selective Explorer hotkey policy does not reclaim it. WGDot's `super-l-test` remains an explicit maintainer/development diagnostic only. It is not part of the normal desktop runtime and is not advertised as a user binding.

## Anti-cheat-sensitive choices

- YASB systray stays `use_hook: false`.
- No AutoHotkey, whkd, Explorer DLL injection, or third-party general-purpose input daemon is added.
- Runtime helpers are narrowly scoped. Normal and Work have no `.ps1` runtime dependencies; native-capable actions remain outside WGDot.


## Popup spacing

Native YASB menus that expose a vertical offset are configured with `offset_top: 0`, so CPU, memory, Control Center, brightness, microphone, volume, clock/calendar, Wi-Fi, and Bluetooth surfaces touch the bar instead of leaving the upstream 6 px gap.
