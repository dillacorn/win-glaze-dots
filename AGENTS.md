# AGENTS.md

Guidance for AI coding agents and LLMs working in the win-glaze-dots repository.

This file describes project-specific architecture, invariants, workflows, and validation expectations. It is intentionally separate from any user's general LLM personality or custom instructions.

## Core rule

Inspect the current repository before acting.

win-glaze-dots changes over time. Current code, tests, CI, Git state, and the exact requested branch/tag/release take precedence over remembered architecture, old conversations, old documentation, or assumptions based on similar projects.

If this file conflicts with the current implementation, verify the implementation and update this file as part of the relevant work when appropriate.

## Project identity

- win-glaze-dots is a Windows 10/11 dotfiles and configuration project maintained by dillacorn.
- `wgdot` is the native Windows maintenance system for installing, reviewing, updating, resetting, and testing managed configuration. Its primary runtime is compiled locally from inspectable repository C# source by `wgdot/bootstrap.cmd`, so normal operation does not depend on `.ps1` execution being allowed.
- The project also documents manual Windows/application setup that is intentionally not fully automated.
- The repository is a local open-source utility. Do not introduce telemetry, hosted-service dependencies, or data collection without an explicit project decision.

## Source-of-truth priority

When sources disagree, use this order unless the task explicitly targets historical behavior:

1. Exact user-requested target and current Git state.
2. Current implementation on that target.
3. Tests and CI that exercise the implementation.
4. Current release/tag metadata when release behavior is involved.
5. Current repository documentation.
6. Recent relevant Git history.
7. This `AGENTS.md` file.
8. Memory, prior conversations, or older architecture knowledge.

Never let memory override inspectable repository evidence.

## System map

```text
Windows 10/11
    |
    +--> wgdot/bootstrap.cmd
    |       |
    |       +--> downloads/uses inspectable wgdot-native.cs
    |       +--> compiles locally with Windows .NET Framework csc.exe
    |       v
    |   %LOCALAPPDATA%\wgdot\bin\wgdot.exe
    |       |
    |       +--> runtime self-refresh from main
    |       +--> explicit feature-branch refresh while maintainer-testing
    |       +--> stable release resolver
    |       +--> managed config planner/executor
    |       +--> required WinGet bootstrap + software reconciliation
    |       +--> reversible application startup / uninstall manager
    |       +--> adjacent backup manager
    |       +--> Git-testing mode
    |
    +--> wgdot/manifest.json
    |       |
    |       +--> managed components
    |       +--> Normal/Work defaults
    |       +--> GlazeWM profile mapping
    |       +--> WinGet package catalog
    |       +--> explicit migrations
    |
    +--> wgdot/wgdot.ps1 + MANUAL_POWERSHELL.md
            |
            +--> compatibility/reference implementation
            +--> paste-only PowerShell fallback for restricted environments

Managed source files
    |
    +--> UserProfile/.glzr/
    +--> UserProfile/.config/
    +--> UserProfile/AppData/
    +--> UserProfile/scripts/

Validation
    |
    +--> tests/test-wgdot.ps1
    +--> .github/workflows/validate-wgdot.yml
```

## Desktop runtime independence

WGDot is a management/configuration tool, not a required desktop-session helper.

- Managed GlazeWM and YASB configuration must remain usable when copied manually without installing or running WGDot.
- Runtime ownership is hybrid and capability-driven. Ordinary actions already supported cleanly by GlazeWM, YASB, Windows, or the target application must stay native; WGDot runtime helpers are allowed only for custom behavior that genuinely requires code, cross-component state coordination, or low-level Windows APIs.
- GlazeWM owns GlazeWM keybindings and binding modes. YASB owns its native widgets, callbacks, and global widget keybindings. Installed applications should be launched directly when practical.
- YASB's `PowerMenuWidget` owns the power button and `Win+P`. Do not replace the power menu with WGDot.
- Runtime commands launched from YASB must not flash console windows. Use a windowless compiled WGDot frontend/worker path for the small set of approved runtime helpers.
- Native ownership must stay literal: launchers, screenshots, Windows Settings, EarTrumpet, YASB Quick Launch, workspace movement, GlazeWM pause/mode state, and YASB's native power menu must not be bounced through WGDot merely for convenience.
- Restricted Work-PC operation must assume `.ps1` files can be unreadable as well as unexecutable. The Work GlazeWM/YASB profiles must contain zero runtime references to `.ps1` files, and `desktop-scripts` must default off for Work. For genuine custom Work runtime behavior, prefer a narrowly scoped compiled WGDot helper over inline PowerShell. Do not use `-ExecutionPolicy Bypass`.
- WGDot runtime helpers are permitted for narrowly scoped custom primitives that native owners cannot provide cleanly, including coordinated YASB/GlazeWM auto-hide, idle inhibition through Windows execution-state APIs, live Awtarchy-style theme application/synchronization, and the low-level mouse-button hook GlazeWM cannot express. Do not turn WGDot into a general desktop broker.
- Normal-profile theme switching may remain dotfile-owned. Restricted Work may use the compiled WGDot runtime for live theme application because `.ps1` files are blocked there; theme application must not reload GlazeWM and must remain isolated from unrelated desktop actions.
- WGDot remains responsible for installation, software management, source/version selection, managed-file planning, backups, updates, resets, migrations, audits, and other explicit maintenance operations.
- Tests must enforce the hybrid boundary: reject WGDot for actions with clean native ownership, allow only explicitly approved custom runtime commands, require Work configs to be `.ps1`-free, and reject visible-console runtime dispatch.

## Runtime vs managed configuration

WGDot runtime and managed configuration intentionally have different lifecycles.

- The installed WGDot runtime may refresh from `main`.
- Normal user-facing WGDot invocations compare the recorded runtime revision with the configured runtime branch head before dispatch and run the refreshed runtime immediately when they differ.
- Every newly added direct user-facing maintenance command must be added to the runtime auto-refresh policy before dispatch. Direct subcommands must not require the user to run plain `wgdot` first to receive current runtime behavior.
- Because Windows cannot reliably overwrite the currently running executable, a refreshed staged runtime schedules its own post-exit replacement of the installed `wgdot.exe` and records the exact revision only after that swap succeeds.
- WGDot runtime replacement must tolerate ordinary transient executable locks and retry safely, but desktop-session behavior must not require long-lived WGDot workers. Do not add new runtime-swap preservation logic for bar/window-manager helpers. Internal runtime-swap commands must never recursively schedule another staged replacement.
- Normal managed-config update/reset/review operations must use an exact published stable release, never the current `main` config tree.
- A runtime refresh from `main` must not silently change the release manifest used for a stable config operation.
- The selected stable release supplies its own `wgdot/manifest.json` and managed source files.
- Development branches are accessible only through explicit Git-testing mode.
- Restricted/corporate networks may allow `raw.githubusercontent.com` while blocking `github.com` archive downloads and `api.github.com`. An explicitly bootstrapped full 40-character revision is already immutable and may be reused exactly without a branch-head API lookup. Managed source acquisition should prefer the normal GitHub archive path but fall back to downloading the revision's manifest plus all manifest-declared managed source files from `raw.githubusercontent.com`. A failed optional runtime-refresh API check must never make an already-installed exact runtime unusable. Do not weaken normal Git branch-membership validation for `git-review` / `git-update` / `git-reset`; the raw fallback is source transport, not a replacement for branch verification.
- Strict work-PC/config-only migration uses `bootstrap.cmd --dots-only --profile <normal|work>`. That bootstrap path installs/refreshes only the WGDot management runtime and then dispatches the installed runtime's `dots-only` command; it must bypass `ensure-winget`, software reconciliation/uninstall, elevated software workers, driver/install helpers, and browser setup. `dots-only` selects only file-backed managed components that default on for the requested profile, forces the matching GlazeWM/YASB profile pair, preserves any existing package/tweak/browser selection state without acting on it, and suppresses non-file/system post-actions such as Yazi package install, YAZI_FILE_ONE mutation, legacy shell-hotkey migration, and cursor registry application. The Normal profile may manage the portable desktop scripts; the Work profile must not select or deploy the `desktop-scripts` component. Tracked `theme.css` / `appearance.css` remain ordinary managed files. With an exact bootstrapped revision and `WGDOT_FORCE_RAW_SOURCE=1`, this path must not require `api.github.com` or the GitHub archive endpoint.
- Bootstrap source download prefers `curl.exe`, but managed Windows environments can expose Schannel failures even when .NET HTTPS works. If curl is unavailable or its download fails, bootstrap may fall back to in-box Windows PowerShell 5.1 `Net.WebClient` with TLS 1.2. This fallback is transport-only: do not pass execution-policy bypass flags, do not run a `.ps1`, and do not couple it to WinGet/software setup. CI may force this path with `WGDOT_FORCE_POWERSHELL_DOWNLOAD=1`.

Do not collapse runtime state, stable config state, Git-testing state, and baseline state into one version value.

## Stable release model

Normal users update managed configuration from published stable releases with semantic tags of the form `vMAJOR.MINOR.PATCH`.

A stable source must:

- be a published GitHub Release;
- not be a draft;
- not be a prerelease for normal stable mode;
- have a semantic version tag;
- resolve to an immutable commit SHA;
- contain a WGDot-compatible `wgdot/manifest.json`.

A Git branch is not a stable release.

Do not treat pre-WGDot releases as WGDot-compatible merely because they are published.

## Git-testing model

Git testing is explicit maintainer/developer behavior.

- The user selects a remote branch.
- An optional exact revision must be a full 40-character commit SHA.
- The exact commit must belong to the selected branch.
- Git-testing state remains separate from the remembered stable release.
- Stable update/reset returns to the published release stream.
- Never accept a hidden branch/commit override in normal stable update paths.

Do not merge a testing branch merely because tests pass. Merge only when explicitly authorized.

## Managed configuration boundaries

WGDot manages individual files declared in `wgdot/manifest.json`.

Important rules:

- Never recursively synchronize or delete an entire `%USERPROFILE%`, `%APPDATA%`, or `%LOCALAPPDATA%` subtree.
- Never delete a live file merely because it disappeared from the repository.
- Upstream removal of a previously managed file is preserve-by-default.
- Deletion requires an explicit migration with positive identification of the known old managed artifact.
- Before replacing an existing live managed file, create an adjacent WGDot backup unless the file is already byte-identical to the target.
- Preserve unrelated files in the same directories.
- Treat files with no trusted baseline conservatively.
- User-modified files must never be silently overwritten during a normal update.
- Reset/reconfigure may replace selected managed files, but must back up differing existing files first.

## Baseline model

WGDot compares three states:

```text
local live file
previous trusted baseline
new selected release target
```

Typical classifications include:

- `NEW`
- `CURRENT`
- `UPSTREAM`
- `USER`
- `BOTH`
- `LEGACY`
- `REMOVED-UPSTREAM`

The baseline is updated only after a successful apply.

When both local and upstream changed, use a merge only for manifest-declared merge-safe text files. A merge conflict must preserve the local file and report the conflict rather than force replacement.

## Backup model

WGDot backups are adjacent to the live file and WGDot-identifiable:

```text
config.yaml.wgdot.backup
config.yaml.wgdot.backup.YYYYMMDD-HHMMSS
```

The backup manager must operate only on WGDot-recognizable backups associated with managed paths. Do not treat arbitrary `.backup` files as WGDot-owned.

Backup deletion must support review/dry-run behavior and explicit confirmation.

## GlazeWM profile model

- The managed GlazeWM profiles include a `noalt` binding mode toggled with `Win+Alt+N`, modeled after Awtarchy's noalt submap. Because GlazeWM binding modes replace rather than inherit global bindings, noalt must explicitly retain Super-based workspace focus/move, focus-direction, move-direction, launcher, terminal, theme, close, float, and fullscreen controls that should remain available in the mode. Do not add a WGDot runtime dependency to preserve a binding.
- The managed profiles include `noalt`, `mouse`, and `vm` binding modes whose state is owned by GlazeWM. `Win+Alt+N`, `Win+Alt+M`, and `Win+Alt+V` enter the corresponding mode; the same mode chord disables that mode, and mode-to-mode transitions explicitly disable the current mode before enabling the next one. YASB's native `GlazewmBindingModeWidget` displays the active mode. Clicking the visible active-mode text must call `disable_binding_mode` and must never cycle NoAlt -> Mouse -> VM. WGDot may supply only the low-level pointer hook while GlazeWM remains the source of truth for mouse-mode state.
- Real GlazeWM pause is independent of binding modes and uses both `LWin+Alt+P` and `RWin+Alt+P`. Duplicate that `wm-toggle-pause` binding inside modes where necessary so pause remains reachable. Do not add a WGDot pause-status helper or YASB polling path; pause remains owned directly by GlazeWM.
- WGDot's reversible, default-off `disable-windows-shell-hotkeys` management tweak uses Explorer's selective `DisabledHotkeys` value and intentionally preserves native Win+V/Win+N. The retired 2026-09-20 experiment used `HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\NoWinKeys=1`; blanket NoWinKeys breaks Windows shell shortcuts and is no longer part of the design. Managed updates must still migrate only an exact WGDot-owned legacy NoWinKeys value when the matching registry snapshot exists, restore its pre-WGDot value, retire that old snapshot, preserve any user-modified replacement value, and request UAC before opening the protected legacy policy key for write on a non-elevated process. Do not reintroduce NoWinKeys.
- `NoWinKeys` does not disable a lone Windows-key press, and runtime testing showed GlazeWM bare `lwin` / `rwin` `wm-redraw` bindings do not reliably stop Start from opening. Any future lone-Super suppression must be implemented as a portable dotfile-owned non-elevated helper, must allow normal Super chords unchanged, and must bypass suppression while VM mode is active. WGDot must not own or be required by that live keyboard filter. Until such a standalone helper is implemented and maintainer-tested, do not claim lone-Super suppression is active.
- Launcher bindings must be ordinary GlazeWM-owned bindings. Launch the target application or a documented native YASB command/interface directly from GlazeWM. Do not use `flow-launcher.ps1`, `yasb-quick-launch.ps1`, `SendKeys`, a private/synthetic `F24` relay, WGDot, or another helper solely to bridge a launcher hotkey. YASB may expose Quick Launch through its own normal native widget/callback behavior, but GlazeWM must not fake a YASB invocation by injecting a key. If current upstream YASB has no documented direct command/interface that GlazeWM can call, leave that external hotkey unsupported rather than inventing a relay. Flow Launcher remains optional/default-off unless the user explicitly chooses it.
- Target Awtarchy-style clipboard/audio bindings without making WGDot part of the live path. Native Windows Clipboard History was unreliable on maintainer testing, so YASB's clipboard-history provider remains disabled. If `Super+C` custom clipboard history is retained, implement it as a portable dotfile-owned helper with its own persistence/UI and no dependency on `wgdot.exe`/`wgdotw.exe`; until that exists, do not render a dead clipboard button or claim the shortcut works. Audio should be owned by EarTrumpet itself where its native hotkey settings support the desired chord.
- EarTrumpet should own the desired mixer hotkey directly. WGDot may configure that application setting during explicit install/configuration management, but desktop use must not route `Super+V` through a WGDot synthetic-key helper.
- Flameshot selection capture is `Win+Shift+S` in both managed profiles and launches `flameshot.exe gui` directly from GlazeWM. WGDot must not sit in the live screenshot path.
- Windows RawAccel uses only `Win+Shift+M` / `Super+Shift+M`. Do not add the Awtarchy `Alt+Shift+M` alias on Windows. The Normal profile may invoke the portable non-elevated `~/.config/win-glaze/scripts/rawaccel-toggle.ps1`. The restricted Work profile must not reference that script; if RawAccel needs a Work-profile runtime action, use a direct executable/native interface or leave the action unavailable.
- Theme switching must not reload GlazeWM. Keep the focused-window border theme-neutral at `#a1a1a1`. Normal may use `theme-switcher.ps1`; restricted Work may invoke the approved compiled WGDot theme helper because script files are blocked.
- GlazeWM 3.10.x does not expose mouse buttons through its keybinding parser. Keep `mouse` mode state native in GlazeWM, but WGDot may own a narrowly scoped windowless low-level mouse hook for actual Awtarchy-style mouse move/resize. The hook must run only while mouse mode is active, stop unconditionally when that mode exits, and must not become a general input daemon.
- `~/.config/yasb/theme.css` and `~/.config/yasb/appearance.css` are tracked managed dotfiles. Deploy them like the rest of the portable desktop config; do not regenerate them from WGDot state or require a WGDot post-action.
- Yazi launcher binding uses both `lwin+shift+e` and `rwin+shift+e`.

There are two maintained GlazeWM source profiles:

- Normal: `UserProfile/.glzr/glazewm/config.yaml`
- Work: `UserProfile/.glzr/glazewm/custom_work_config.yaml`

Both map to the same live destination:

`%USERPROFILE%\.glzr\glazewm\config.yaml`

The selected profile is remembered. Normal updates use the remembered profile. Reset/reconfigure may switch profiles and must back up the existing live config before replacement when it differs.

Do not deploy both source files as active configs.

## Awtarchy-to-YASB bar parity

The `feat/awtarchy-yasb-bar` work treats the current Awtarchy Quickshell bar as the visual/behavioral reference while keeping Windows behavior native to YASB, GlazeWM, or Windows.

- Verify a current upstream YASB/GlazeWM capability before translating an Awtarchy bar feature. Do not infer widget options from old YASB themes or invent unsupported config keys.
- Prefer direct native widgets and commands over helper scripts. A missing feature should remain documented as missing rather than be simulated solely for visual parity.
- Keep the Windows bar flat and compact around Awtarchy's current defaults: 28 px horizontal height, `#353535` background, `#d0d0d0` foreground, square controls, subtle hover/active fills, no decorative taskbar/bar animations.
- Preserve WGDot's existing reload-free reservation model on this branch: YASB is `always_on_top: true`, `windows_app_bar: false`, and both GlazeWM profiles use the current requested 35 px top `outer_gap`. Migrating a live session to AppBar reservation would require a GlazeWM config reload; do not force that layout-disrupting reload merely for a palette/theme change.
- Preserve JetBrainsMono NFP on Windows unless the project explicitly decides to add a different font package.
- Use YASB's native DDC/CI brightness support rather than a translated Awtarchy DDC script.
- Keep YASB systray `use_hook: false`. Upstream documents `use_hook: true` as an `explorer.exe` DLL-injection path. Do not introduce that extra hook for cosmetic parity, especially on a gaming-oriented setup.
- Do not substitute GPU temperature for Awtarchy's CPU-temperature module. Do not require Libre Hardware Monitor solely to make the bar look equivalent.
- Awtarchy's bar idle inhibitor uses `SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED)` and clears the request on exit. Normal may use `idle-inhibitor.ps1`; restricted Work may use the approved compiled WGDot idle helper. Do not alter the Windows power plan.
- Use YASB's native `QuickLaunchWidget` as the primary launcher. Installed application search is the default provider, matching Awtarchy's desktop-entry search more closely than Flow Launcher. Keep calculator/settings/file/window/terminal providers available through explicit prefixes, keep the Quick Launch clipboard provider disabled while no portable custom clipboard surface exists, and keep Flow Launcher optional/default-off rather than making it the normal default.
- Do not render the Awtarchy-style clipboard button until its portable standalone implementation exists. Keep Quick Launch's clipboard provider disabled because it depends on Windows Clipboard History. YASB callbacks must not invoke `wgdot.exe` or `wgdotw.exe`.
- Use YASB's native `ControlCenterWidget` for Awtarchy-style quick settings. Keep brightness/volume/microphone/media, DND, Windows dark mode, display/network/Bluetooth settings native. NoAlt/VM quick actions still change GlazeWM modes; if YASB cannot launch `glazewm.exe` invisibly, an approved windowless WGDot dispatch may invoke the GlazeWM CLI solely to avoid a console flash. Mouse mode is toggled by `Win+Alt+M` and the separate mouse icon. Running applications stay visible and unshaded; screenshot remains Flameshot.
- Awtarchy's single notification/mute control maps to one native YASB `DndWidget`: left click uses BaseWidget's native `exec notification_center` system-function mapping to open Windows Notification Center, middle click does nothing, and right click uses the widget's native `toggle_status` callback for Windows Do Not Disturb. Use bell/muted-bell state styling on that one control; do not reintroduce a separate Notifications widget or cross-widget hook. YASB documents its DND backend as the Windows QuietHoursSettings COM API, which is undocumented by Windows and may change.
- Match Awtarchy task controls with native YASB callbacks where possible: middle-click closes and right-click uses `toggle_window` for minimize/restore. Keep the documented left-click mismatch because YASB has no activate-only task callback.
- Awtarchy's horizontal bars show the globally focused active-window title on every monitor. Keep YASB ActiveWindow `monitor_exclusive: false` for that behavior; task icons and workspaces remain monitor-local.
- Do not use `yasbc toggle-bar` for bar hiding: it can strand an invisible bar and does not coordinate the GlazeWM top gap. Normal may use `bar-autohide.ps1`; restricted Work may use the approved compiled WGDot auto-hide helper. The helper must coordinate YASB `auto_hide` with the 35 px/5 px GlazeWM top gap and reload only the affected applications.
- Awtarchy's audio right-click should launch EarTrumpet directly; keep native YASB left-click mute and wheel volume behavior. Do not route the mixer through WGDot.
- Awtarchy's microphone indicator is muted-only. Preserve the native YASB Microphone widget but keep its normal icon empty and collapse its normal padding; rely on YASB's native `muted` class to reveal the red muted indicator rather than adding polling/helper logic.
- YASB's Battery widget has no native details popup. Map Awtarchy battery-menu clicks to Windows' own `ms-settings:powersleep` Power & battery surface on left/right click, and retain middle-click for YASB's alternate label rather than building a custom battery popup.
- YASB theme and appearance files are tracked dotfiles, not WGDot-generated runtime state. Keep the Carbon Night palette in `styles.css` as a fallback, import tracked `theme.css` for palette variables, then import tracked `appearance.css` last. `theme-switcher.ps1` keeps its own lightweight state under `~/.config/win-glaze`, updates the tracked/live `theme.css`, and synchronizes only its own Windows Terminal scheme/UI entries while preserving unrelated Terminal settings. Preserve the current Awtarchy palette names/colors unless intentionally changing the shared visual catalog. Never reload or restart GlazeWM for theme-only changes.
- In Normal, keep quick-settings theme launch and `Win+T` on the standalone selector. In restricted Work, route live Awtarchy-style theme application through the approved compiled WGDot theme helper rather than a `.ps1` file. Do not use WGDot for unrelated native actions.
- In Normal, launch the standalone selector in Windows Terminal titled `Win Glaze Themes`. Restricted Work must not require that script/title path; its compiled WGDot theme helper owns Work theme changes without reloading GlazeWM.
- YASB v2.0.7 Grouper's collapse control is click-only, so do not use Grouper collapse to implement the workspace mover. A passive Grouper with `collapse_options.enabled: false` is allowed strictly as the hover parent: keep the mouse hub in its own always-visible passive YASB widget, keep the four directional arrows in an Applications widget collapsed to zero width, and reveal that arrow child with the Grouper's native QSS `:hover` state. This preserves Awtarchy's visible mouse icon plus hover-only arrow drawer without a click-only collapse action.
- Current stable YASB bar alignment supports only `top` and `bottom`; do not expose fake left/right bar-position choices. Its native blank-bar context menu also has no position-changing action, so a right-click position picker would require an upstream change or maintained YASB fork.
- Windows reserves `Win+L` for session locking. Runtime testing confirmed it still locks under the validated NoWinKeys setup, and PowerToys documents it as non-remappable. The user explicitly requested a lower-level experiment on 2026-09-20, so `wgdot super-l-test start|stop|status` may run a manually started, test-only low-level keyboard hook that consumes the L key while Super is held and asks GlazeWM to focus right. Do not install/start that hook automatically, do not add `Super+L` back to managed GlazeWM config yet, and do not describe the chord as solved until real Windows testing proves it does not lock the session. `Super+Right` remains the supported fallback.
- The visible GlazeWM binding-mode widget must reflect native `noalt` / `mouse` / `vm` state. Left/right click should disable the current active mode rather than cycle. The separate mouse icon toggles mouse mode. Real pause stays native through `wm-toggle-pause`.
- Do not add AutoHotkey, whkd, DLL injection, or third-party general-purpose input daemons. The approved WGDot mouse hook is the only low-level pointer helper and is scoped to GlazeWM mouse mode. Other native-capable interactions must not be pulled into WGDot.

## Work-PC constraints

Some Work systems can run PowerShell commands but cannot freely execute downloaded `.ps1` files.

Therefore:

- Do not use `Set-ExecutionPolicy`.
- Do not invoke PowerShell with `-ExecutionPolicy Bypass`.
- Do not require a downloaded opaque custom executable for WGDot maintenance. A native helper may be compiled locally from repository source with Windows-provided tooling, but the source must remain inspectable and the manual fallback must not depend on it.
- A native bootstrap must not invoke PowerShell to work around execution policy. It may only perform behavior implemented natively.
- Automatic WGDot and manual PowerShell behavior must derive from the same manifest/planning rules.
- Preserve a pasteable PowerShell path for important operations.
- If local policy blocks `.ps1`, do not work around policy; use the manual paste-only path.
- The restricted Work profile itself must remain usable after that paste-only deployment with no readable/executable `.ps1` files present. Tests must reject `.ps1` runtime references in `custom_work_config.yaml` files and reject `desktop-scripts.defaultWork: true`.

## Native runtime and PowerShell fallback compatibility

The primary WGDot runtime is `wgdot/wgdot-native.cs`, compiled locally with the Windows .NET Framework C# compiler. Keep it compatible with the compiler/framework available on supported Windows 10/11 systems and do not add a dependency on a separately installed .NET SDK unless explicitly approved.

The compatibility/reference PowerShell runtime and paste-only fallback target Windows PowerShell 5.1 unless the project intentionally raises that requirement.

Avoid PowerShell 7-only syntax and semantics in PowerShell fallback/runtime files, including:

- ternary expressions;
- null-coalescing operators;
- pipeline chain operators;
- PS7-only cmdlet parameters without compatibility handling.

Use `powershell.exe -NoProfile` for Windows PowerShell validation and `pwsh` as an additional compatibility check when available.

## WinGet behavior

Software management is separate from managed-dot updates.

- WinGet is a WGDot prerequisite. `wgdot/bootstrap.cmd` invokes the native `ensure-winget` path after installing the runtime. If `winget.exe` is missing, WGDot automatically uses Microsoft's supported `Microsoft.WinGet.Client` / `Repair-WinGetPackageManager` bootstrap and requests current-user App Installer registration. Do not use unofficial WinGet bootstrap scripts or execution-policy bypasses.
- An already working WinGet installation must be left alone; bootstrap is missing-only.
- Package IDs live in `wgdot/manifest.json`. For WinGet-backed entries they are exact WinGet IDs; explicit non-WinGet install modes may use a stable WGDot selection identity that still follows the manifest ID shape.
- Verify every WinGet-backed package with exact-ID WinGet lookup before installation or upgrade. Do not send explicit direct-source packages through a fake WinGet probe.
- Never silently run `winget upgrade --all`.
- Updates may detect available software upgrades and ask for explicit user consent.
- Deselecting a package must not uninstall it.
- Removal is a separate, explicit `Software / startup manager -> Uninstall individual applications` operation with its own review/confirmation. Successful removals must also remove the package from WGDot's desired package selection so the next reconcile does not reinstall it.
- Generic uninstall must never guess at kernel-driver teardown. Packages using `official-github-archive-driver` remain manual/upstream uninstall unless an explicit verified uninstall implementation is added.
- WGDot-owned portable application directories may be deleted only when the manifest positively identifies the install directory/file that WGDot itself created.
- Removal/retirement of software requires explicit project behavior and ownership tracking.
- Normal software reconciliation keeps the interactive WGDot UI unelevated. After the user approves the selection, missing WinGet/installer/driver package installs, explicitly approved package upgrades, and selected administrator-only tweaks are grouped into one internal elevated WGDot worker so normal installs do not trigger one UAC prompt per package. Explicit user-level portable packages stay in the normal process and must not be launched from that elevated worker.
- The elevated software worker may consume only a WGDot-created plan under the WGDot state directory, must validate package/tweak IDs against the active manifest/source revision, and must not launch browser configuration or ordinary user-level post-install configuration while elevated.
- Protected registry-only setup may run inside that bounded elevated worker. This includes Firefox extension policy registry mutation and registry-heavy Windows tweaks; Betterfox profile work, Brave/Mullvad browser interaction, Flow Launcher/EarTrumpet app configuration, and browser/app launches stay unelevated.
- If a later standalone tweak unexpectedly gets `UnauthorizedAccessException` under the normal token, retry only that explicit tweak through the existing elevation path and label the retry. Do not let an unlabeled access-denied exception abort the whole menu.
- privacy.sexy integration must not disable antivirus, add antivirus exclusions, or fake an unsupported headless API. The privacy.sexy installer may auto-launch the desktop app; detect that process before launching another copy, and wait for the single desktop instance to close before returning to the WGDot workflow.
- Software reconciliation must preserve human-readable failure reasons from the elevated worker and print them in the main WGDot window. Never collapse package/tweak/browser-policy failures into only an anonymous numeric failure count.
- Registry mutation helpers must open existing keys with the minimum rights needed to query/set values before falling back to key creation. Do not use `CreateSubKey` unconditionally on existing Windows-owned keys; some taskbar/search keys permit value writes while denying broader key-creation rights.
- `clean-taskbar-items` treats an access-denied write to the user-level `TaskbarDa` Widgets value as a Windows-build compatibility case. Discard the un-applied TaskbarDa rollback snapshot and fall back to Microsoft's machine-level `SOFTWARE\Policies\Microsoft\Dsh\AllowNewsAndInterests=0` policy inside the already-elevated batch. Preserve/restore that policy through the normal registry snapshot model.
- `automatic-time-and-timezone` is default ON and administrator-level. Use only Windows' built-in time/location stack: keep W32Time available, enable `tzautoupdate` with `Start=3`, enable device Location through `CapabilityAccessManager\ConsentStore\location\Value=Allow`, request a bounded/best-effort `w32tm /resync /rediscover`, and report the resulting Windows time zone. Do not add an external IP-geolocation dependency. Preserve the pre-WGDot registry values for rollback; rollback must not deliberately rewind the current clock or time zone.
- Do not prepend `runas`, `sudo`, or another elevation wrapper to every individual WinGet command. Elevate the bounded WGDot batch once, then return to the normal user process.
- Software preflight must not issue a network-backed exact-ID lookup for packages already known installed. Take one bounded WinGet installed-state snapshot first, then validate only missing packages.
- Silent WinGet preflight/list/show checks must use noninteractive mode and a finite timeout. A hung WinGet query must stop or skip the affected preflight with a clear message rather than freeze WGDot indefinitely.
- Actual WinGet installs must also be bounded when a package declares `wingetInstallTimeoutSeconds`. On timeout, terminate the stuck WinGet process tree before continuing.
- A WinGet install timeout/failure may fall back only when the package manifest explicitly declares an approved official GitHub repository and a narrow asset regex. Never invent or scrape third-party mirrors.
- Flow Launcher is WinGet-first but has an approved fallback to `Flow-Launcher/Flow.Launcher` asset `Flow-Launcher-Setup.exe` because real-VM testing reproduced a WinGet download stall while the same official asset completed normally outside WinGet.

## Application startup ownership

- Startup management is separate from installation. Manifest packages may declare a narrow `startupHandler` and `startupDefault`.
- WGDot startup entries are current-user `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` values named `WGDot.<handler>`. Never overwrite, delete, or reinterpret unrelated vendor/user Run values.
- Current managed startup handlers are GlazeWM, AltSnap, EarTrumpet, and MicLockTray when those packages are selected. The startup UI labels the GlazeWM entry as `GlazeWM + YASB`: YASB is deliberately not a second Windows startup entry because the managed GlazeWM config already starts/stops YASB through `startup_commands` / `shutdown_commands`.
- GlazeWM startup must use its real executable plus `start --config=<live config>`; do not rely on an arbitrary shell working directory.
- `startup.json` under WGDot state owns user enable/disable preferences. A software reconcile applies those remembered preferences; a selected startup-capable package gets its manifest default only when no preference exists yet.
- The startup manager must expose individual enable/disable selection plus a one-action `Disable all WGDot-managed startup` path that keeps software installed.
- Uninstalling a startup-managed package must remove WGDot's startup entry and persist the disabled preference first.

- The native software catalog audit is strictly non-mutating: no installer downloads, installs, upgrades, app launches, registry writes, or elevation. It checks every manifest package with exact-ID `winget show`, validates known post-install action names, and resolves declared official GitHub fallback assets using the same resolver as real fallback installs.
- Treat catalog audit success as metadata/source coverage only. It does not prove an installer can execute successfully or that application-specific runtime configuration works after installation.
- `acceptance-audit` is the preferred broad maintainer smoke test. It must stay safe against the live system: actual mutation/rollback tests run only in an isolated `WGDOT_TEST_ROOT`; live checks are read-only planner/state/source/GPU inspections plus the no-install software audit.
- The acceptance audit must explicitly name what remains inherently interactive: OS hotkey behavior, browser extension consumption/approval, at least one real managed-dots apply/rollback cycle, and any intentionally exercised DDU reboot flow.
- Packages intentionally unavailable from WinGet may declare `installMode: official-page` with an HTTPS publisher download page and installed display name. The audit validates the official page without downloading an installer. Reconcile may offer to open that publisher page, but must not invent a third-party mirror or silently scrape/execute an unverified changing binary.
- FileZilla Client is an `official-page` package because Microsoft's WinGet repository flags FileZilla Client/Server as blocked from the community repository for redistribution/licensing reasons. Keep its historical ID only as WGDot selection identity; do not attempt `winget install` for it.
- RustDesk is an `official-github` package backed by `rustdesk/rustdesk`. Current WinGet community data does not expose the historical `RustDesk.RustDesk` package, so audit/reconcile must not report or probe that dead WinGet path as its primary source. Use the verified publisher GitHub release asset resolver directly.
- `official-github-portable` is for a publisher-owned standalone executable that WGDot copies into the current user's LocalAppData Programs tree and launches only from the normal process. Validate downloaded executable payloads before use.
- `official-github-archive-driver` is for a publisher-owned ZIP that contains a driver installer. Extract through path-traversal-safe logic, run the upstream installer from its extracted release directory inside the bounded elevated worker, and verify concrete driver/service markers because an upstream installer exit code alone may be unreliable.
- Raw Accel uses `RawAccelOfficial/rawaccel` and verifies the `rawaccel` kernel-driver service plus driver/application files after installation. It requires a Windows restart but WGDot must not reboot automatically.
- MicLockTray uses the publisher-owned `dillacorn/MicLockTray` standalone release executable and remains a user-level portable install.
- Do not invent WinGet package IDs. Verify changed or questionable WinGet IDs against current WinGet data before committing them. Stable direct-source selection identities must map to an explicit verified source mode.

## Cursor themes

- The default WGDot cursor is Awtarchy's Bibata Modern Ice equivalent. Cursor selection is independent runtime state under `%LOCALAPPDATA%\wgdot\state\cursor.json`.
- Keep all 12 Awtarchy Bibata combinations: Ice/Classic/Amber, Modern rounded/Original sharp, and normal/right-handed variants. Resolve Windows ZIP assets only from the official `ful1e5/Bibata_Cursor` GitHub release and use its regular-size Windows cursor directory.
- Keep Oops-all-links available as a legacy alternative. Switching between Bibata, Oops, and Windows-default must restore the other WGDot cursor snapshot first so rollback returns to the pre-WGDot registry values rather than another WGDot theme.
- Use the existing safe ZIP extractor for all cursor archives. Do not require administrator rights merely to apply Bibata; the files may live under WGDot's user-local install root and HKCU may point to them.

## Development menu

- Keep maintainer diagnostics separate from normal maintenance. `Audit all software (no install)`, `Automated acceptance audit (safe)`, and `Advanced / Git testing` belong under the clearly labeled `Development / testing` menu.

## Browser configuration

- Browser-specific option metadata lives in the top-level `browserOptions` section of `wgdot/manifest.json`, keyed by WinGet package ID.
- Persist user browser selections in `installation.json` under `browserOptions`. Keep operational ownership/rollback metadata separate in `browser-management.json`.
- Existing installation state that predates `browserOptions` must be preserved. Do not silently apply new browser defaults during a plain reconcile until the user has entered/reviewed browser options.
- Firefox extension automation may use only Mozilla-supported signed add-on deployment. WGDot uses the current-user `Extensions.Install` Windows policy, preserves unrelated policy URLs, and removes only install requests that WGDot previously owned.
- Firefox defaults DuckDuckGo No-AI Search ON through DuckDuckGo's publisher-owned signed AMO extension (`duckduckgo-no-ai-search`). Prefer that supported extension over editing Firefox search databases or inventing a custom search-engine policy; the extension owns the AI-free DuckDuckGo default-search behavior and can be deselected like other Firefox options.
- Firefox Betterfox uses a dedicated `Profiles/wgdot.betterfox` profile. Back up affected Firefox metadata and `user.js`, change the default profile only after explicit user approval, and restore the prior default only when WGDot still owns that default choice.
- Deselecting Betterfox must preserve the dedicated Firefox profile. Removing `user.js` alone is not a full preference rollback after Firefox has applied it, so isolation is the rollback boundary.
- Brave on unmanaged Windows uses guided official Chrome Web Store pages and normal browser approval. Full uBlock Origin is the exception: expose Brave's own supported `brave://settings/extensions/v2` Manifest V2 path, default OFF, instead of pretending the Chrome Web Store still provides full uBO. Do not introduce silent sideloading, developer-mode loading, fake enterprise enrollment, or unsigned extensions.
- Mullvad Browser must remain upstream-as-shipped: no WGDot extensions, Betterfox/user.js, preference changes, or hardening overlays. Its anti-fingerprinting consistency takes precedence over sharing the Firefox configuration.

## Yazi migration safety

The current Windows Yazi clipboard helper is:

`UserProfile/AppData/Roaming/yazi/config/plugins/system-clipboard.yazi/main.lua`

The current keymap invokes `plugin system-clipboard`.

The obsolete `%APPDATA%\yazi\config\plugins\clipboard.yazi` directory may be removed only when positively identified as the known old managed XYenon plugin. A same-named user/custom directory must be preserved with a warning.

Do not reintroduce Linux `wl-copy`/`wl-paste` assumptions into the Windows helper.

## Installation navigation safety

- Installation/reconfiguration is a staged wizard. `Q`/Esc from nested selectors backs up one wizard stage instead of immediately cancelling the whole installer.
- Backing out past the first installation-profile screen must show an explicit quit confirmation. Quitting requires an explicit `Y`; repeated `Q`/Esc input must never count as confirmation.
- `N`, Enter, Up/Down, PgUp/PgDn, Home, or End at the quit confirmation means the user wants to keep configuring and returns to the current installation menu.
- Preserve in-progress selections while navigating backward/forward. If a fresh install changes Normal/Work scope, rebuild downstream scope-dependent defaults rather than mixing defaults from the previous scope.

## Investigation vs modification

Treat review, investigation, diagnosis, explanation, comparison, research, and planning requests as read-only unless the user explicitly asks for changes.

When the user clearly requests a fix, implementation, update, or creation, perform the scoped change and validation without unnecessary reconfirmation.

Do not turn a focused implementation into unrelated cleanup.

## Git workflow

Before Git writes, verify the repository, branch/ref, remote state, and requested destination.

- Use a feature/testing branch for substantial WGDot work unless the user explicitly requests direct `main` changes.
- Keep `main` untouched while Windows runtime behavior still needs maintainer testing.
- Use concise, human-readable commit messages.
- Do not force-push, rewrite history, delete branches/tags/releases, or recreate published artifacts unless explicitly requested.
- Preserve unrelated repository changes.
- After a write, re-read or otherwise verify the exact target.

## Validation strategy

Static validation does not prove Windows runtime behavior.

For WGDot changes, use the relevant combination of:

```text
powershell -NoProfile -File tests\test-wgdot.ps1
pwsh -NoProfile -File tests/test-wgdot.ps1
wgdot\bootstrap.cmd
%LOCALAPPDATA%\wgdot\bin\wgdot.exe self-test
```

The GitHub Actions native-bootstrap job is the authoritative automated Windows compile/install test and also runs the isolated native maintenance self-test.

Also inspect the final diff and require CI success on the feature branch/PR.

CI must validate at minimum:

- `wgdot/manifest.json` parses;
- the native runtime compiles and self-tests with the Windows-provided .NET Framework compiler;
- isolated native maintenance tests exercise apply/backup/baseline/merge/migration behavior;
- the compatibility PowerShell runtime can be parsed/dot-sourced on Windows PowerShell 5.1;
- no WGDot runtime/bootstrap/manual path contains execution-policy bypasses;
- stable and Git-testing paths remain separated;
- managed destinations stay within approved user-local roots;
- GlazeWM Normal/Work variants target the same live config path;
- destructive recursive profile/AppData deletion is not introduced;
- `winget upgrade --all` is not introduced into WGDot runtime behavior.

Do not claim interactive Windows behavior is confirmed from CI alone. Real menu interaction, application reload behavior, and Work-policy behavior require runtime testing on an actual Windows machine.

## Documentation discipline

Documentation must match the current implementation.

- Distinguish stable-release instructions from unreleased branch testing.
- Do not claim WGDot is released merely because it exists on a feature branch or `main`.
- Keep manual PowerShell instructions aligned with the same manifest and safety rules used by automatic WGDot behavior.
- Prefer updating stale existing setup docs over creating redundant competing guides.

## Maintaining this file

Update `AGENTS.md` when architecture, state ownership, updater/release behavior, Git-testing behavior, managed-file boundaries, security rules, or required validation materially change.

Do not turn this file into a changelog or duplicate the package manifest.


## GPU driver maintenance

- GPU detection is native and hardware-based: enumerate present Display-class devices with SetupAPI and classify PCI vendor IDs (AMD `1002`, NVIDIA `10DE`, Intel `8086`). Do not infer GPU vendor solely from installed apps.
- Hybrid GPU systems are valid. Intel+NVIDIA and Intel+AMD must not be treated as mismatches when both physical adapters are present.
- A stale/mismatched vendor candidate is a display-driver vendor with no corresponding present GPU, or an active vendor provider that does not match the present adapter's PCI vendor.
- DDU is recovery/refresh tooling, not a routine updater. Never launch DDU, change BCD, or reboot without explicit user confirmation.
- Before DDU Safe Mode: ensure DDU is installed locally, persist the target vendor, register `*WGDotGpuSafeModeResume` under HKLM RunOnce, then set `{current}` safeboot minimal.
- On Safe Mode resume: remove the safeboot BCD value successfully before launching DDU. If normal boot cannot be restored, do not launch DDU.
- Persist `driver-needed` state before DDU launches so a DDU-triggered reboot cannot lose the reinstall reminder.
- Vendor driver tooling must come from vendor-owned HTTPS endpoints: AMD Auto-Detect from `drivers.amd.com`, NVIDIA App from `us.download.nvidia.com`, Intel Driver & Support Assistant from `dsadata.intel.com`.
- Normal driver install/repair uses hardware autodetection first, then launches the vendor's own auto-detect/assistant for every detected AMD/NVIDIA/Intel GPU vendor. Hybrid systems may therefore launch more than one vendor assistant.
- After software reconciliation, a detected GPU whose matching vendor display driver is not active launches its official vendor assistant automatically; do not ask a redundant second yes/no question after the user already approved software reconciliation.
- AMD resolver logic must tolerate AMD support-page markup changes while remaining pinned to `drivers.amd.com`: try the current generic support page and a current official Radeon family page, and accept only the Auto-Detect web-installer URL shape. Installer download may use Windows curl with the vendor page as referrer, with WebClient as a fallback. Invalid/non-PE payloads fail closed; never fall back to a third-party driver source.

