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

WGDot is primarily a management/configuration tool. Narrow, compiled desktop-session helpers are allowed only where the desired behavior cannot be reproduced cleanly by GlazeWM, YASB, Windows, or the target application.

- Managed GlazeWM and YASB configuration should remain broadly usable when copied manually without WGDot, but approved custom surfaces may degrade when the compiled helper is absent.
- Runtime ownership is hybrid and capability-driven. Ordinary actions already supported cleanly by GlazeWM, YASB, Windows, or the target application must stay native; WGDot runtime helpers are allowed only for custom behavior that genuinely requires code, cross-component state coordination, or low-level Windows APIs.
- GlazeWM owns GlazeWM keybindings and binding modes. YASB owns its native widgets and callbacks where those widgets satisfy the intended behavior. Installed applications should be launched directly when practical.
- The Awtarchy-style fullscreen power surface is an explicit compiled WGDot exception. YASB owns only the bar button; the button and `Super+P` dispatch `wgdotw.exe power-menu`. Keep the surface single-instance, theme-aware, windowless at dispatch, and animated with fade-in/fade-out so it never flashes an unstyled bright frame.
- Runtime commands launched from YASB must not flash console windows. Use a windowless compiled WGDot frontend/worker path for the small set of approved runtime helpers.
- Native ownership must stay literal for actions that have a clean native surface: screenshots, Windows Settings, workspace movement, and GlazeWM pause/mode state must not be bounced through WGDot merely for convenience. EarTrumpet remains the owner of its mixer window and Alt+V hotkey; the only approved WGDot bridge is the bar-only `eartrumpet-mixer-toggle` action because upstream YASB cannot emit the application-owned hotkey itself. The application launcher is an explicit exception because upstream YASB cannot provide the required trigger-aware placement or a native CLI/widget-action interface.
- Neither Normal nor Work desktop runtime may depend on `.ps1` files. All managed GlazeWM/YASB runtime profiles must contain zero runtime references to `.ps1` files, and `desktop-scripts` must not be a default runtime component for either profile. For genuine custom runtime behavior that native owners cannot provide cleanly, use a narrowly scoped compiled WGDot helper. Do not use `-ExecutionPolicy Bypass`.
- WGDot runtime helpers are permitted for narrowly scoped custom primitives that native owners cannot provide cleanly, including coordinated YASB/GlazeWM auto-hide, live Awtarchy-style theme application/synchronization and selector-window toggling, the Awtarchy-style power surface, the Awtarchy-style application launcher, the bar-only one-shot Clipboard History opener, the bar-only EarTrumpet mixer-hotkey trigger, and the narrow RawAccel GUI toggle. The retired idle inhibitor and mouse-mode low-level pointer hook are not approved live runtime primitives. Do not turn WGDot into a general desktop broker.
- Live Awtarchy-style theme application is an approved compiled WGDot responsibility for both Normal and Work. Theme application must not reload GlazeWM, must preserve unrelated Windows Terminal configuration, and must remain isolated from unrelated desktop actions.
- WGDot remains responsible for installation, software management, source/version selection, managed-file planning, backups, updates, resets, migrations, audits, and other explicit maintenance operations.
- Tests must enforce the hybrid boundary: reject WGDot for actions with clean native ownership, allow only explicitly approved custom runtime commands, require both Normal and Work runtime configs to be `.ps1`-free, and reject visible-console runtime dispatch.

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
- Strict work-PC/config-only migration uses `bootstrap.cmd --dots-only --profile <normal|work>`. That bootstrap path installs/refreshes only the WGDot management runtime and then dispatches the installed runtime's `dots-only` command; it must bypass `ensure-winget`, software reconciliation/uninstall, elevated software workers, driver/install helpers, and browser setup. `dots-only` selects only file-backed managed components that default on for the requested profile, forces the matching GlazeWM/YASB profile pair, preserves any existing package/tweak/browser selection state without acting on it, and suppresses non-file/system post-actions such as Yazi package install, YAZI_FILE_ONE mutation, legacy shell-hotkey migration, and cursor registry application. Neither profile may select or deploy `desktop-scripts` as a live desktop runtime component. Tracked `theme.css` / `appearance.css` remain ordinary managed files. If a managed apply writes `theme.css` or WGDot-managed Windows Terminal settings, reapply the remembered selected WGDot theme afterward so user-selected visual state survives dots-only and normal managed updates. With an exact bootstrapped revision and `WGDOT_FORCE_RAW_SOURCE=1`, this path must not require `api.github.com` or the GitHub archive endpoint.
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

### Stable release notes

Inspect the latest published stable release for release-specific context, but do not blindly copy its structure or repeat setup instructions that already belong in the canonical guides. `INSTALL.md` and `UPDATE.md` are the canonical user instructions for installation and maintenance; release notes should link to them instead of duplicating them.

A normal WGDot stable release body must include:

- the release title and a short overview of the release;
- an **Install and update** section near the top linking to the canonical `main` versions of `INSTALL.md` and `UPDATE.md`;
- the **Install** link before the **Update** link;
- concise feature/change bullets appropriate to the release;
- validation claims only when grounded in tests, CI, or runtime checks that actually passed for the release target.

Release notes should remain proportionate to the release. Keep routine patch/minor releases concise and user-facing. Debugging chronology, temporary implementation details, and internal test-by-test narration belong in issues, PRs, or commit history instead.

Installation and update procedures belong in `INSTALL.md` and `UPDATE.md`. Repeat procedural detail in release notes only when that release itself changes the procedure and users need migration-specific instructions.

A GitHub release, Git tag, branch, release body, and repository documentation are different targets. When working on a release:

- identify the exact release/tag first;
- inspect the published target and current body before writing;
- edit only the requested release artifact;
- do not move, recreate, or delete a tag merely to change release notes;
- do not substitute `README.md`, `INSTALL.md`, `UPDATE.md`, another branch, or another release for the requested release body;
- do not increment the version unless explicitly requested;
- after a write, re-read the complete published release body and verify the release name, draft/prerelease state, target commit, and tag SHA are unchanged unless the task explicitly changes them.

### Editing or creating releases when the connected GitHub tool lacks release-write actions

If the exact GitHub release must be created or edited but the connected GitHub tool does not expose the required Release mutation, do not declare the release inaccessible and do not substitute another repository target. Use the proven one-use GitHub Actions release bridge when the repository permits it.

- Start from the exact current `main` commit on an isolated temporary helper branch. Do not merge the helper branch merely to create or edit release metadata.
- Add a narrowly guarded one-use job to an existing PR-triggered workflow on that helper branch, then open a specifically named temporary PR to trigger it.
- Guard the job on the exact PR title, head branch, base branch, and `pull_request` event.
- Use YAML-safe folded expressions for guards when strings contain characters such as `:`; invalid workflow YAML will prevent Actions from registering the run.
- Give only the one-use release job `permissions: contents: write`; keep repository-wide workflow permissions unchanged.
- For an existing release edit, use `gh release view` first and derive the new body from the currently published body so unrelated sections are preserved.
- Update only the existing release body with `gh release edit <tag> --notes-file <file>`. Never recreate, delete, or move the tag/release just to change notes.
- For release creation, verify the intended target commit and tag do not already exist before `gh release create`; refuse to replace an existing release/tag unless explicitly requested.
- Immediately re-read the release with `gh release view`, compare the complete published body to the intended body, and verify the tag SHA plus release metadata.
- Close the temporary PR without merging and delete the helper branch/workflow machinery after successful verification.
- If a direct authenticated Release create/update action is available in the current tool surface, prefer it over the temporary bridge.

## Git-testing model

Git testing is explicit maintainer/developer behavior.

- The user selects a remote branch.
- An optional exact revision must be a full 40-character commit SHA.
- The exact commit must belong to the selected branch.
- Git-testing state remains separate from the remembered stable release.
- Git-testing Update/Reset must keep the installed native WGDot runtime aligned with the exact selected branch revision. Compile and self-test that revision's `wgdot/wgdot-native.cs` before applying managed changes, then schedule the installed runtime swap only after the managed apply succeeds. Git-testing Review must remain non-mutating and must not retarget runtime.
- Do not record the selected Git-testing revision as the installed runtime revision until the post-exit swap succeeds. A failed swap must leave the previous installed revision visible so normal runtime refresh can retry.
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

- The managed GlazeWM profiles include a `noalt` binding mode toggled with `Win+Alt+N`, modeled after Awtarchy's noalt submap. Because GlazeWM binding modes replace rather than inherit global bindings, noalt must explicitly retain Super-based workspace focus/move, focus-direction, move-direction, launcher, terminal, theme, tiling, close, float, and fullscreen controls that should remain available in the mode. Do not add a WGDot runtime dependency to preserve a binding.
- The managed profiles include only `noalt` and `vm` desktop binding modes. `Win+Alt+N` and `Win+Alt+V` enter the corresponding mode; the same mode chord disables that mode, and mode-to-mode transitions explicitly disable the current mode before enabling the next one. YASB's native `GlazewmBindingModeWidget` displays the active mode. Clicking the visible active-mode text must call `disable_binding_mode` and must never cycle between modes.
- Real GlazeWM pause is independent of binding modes and uses both `LWin+Alt+P` and `RWin+Alt+P`. Duplicate that `wm-toggle-pause` binding inside modes where necessary so pause remains reachable. Do not add a WGDot pause-status helper or YASB polling path; pause remains owned directly by GlazeWM.
- WGDot's reversible, default-off `disable-windows-shell-hotkeys` management tweak uses Explorer's selective `DisabledHotkeys` value and intentionally preserves native Win+V/Win+N. The retired 2026-09-20 experiment used `HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\NoWinKeys=1`; blanket NoWinKeys breaks Windows shell shortcuts and is no longer part of the design. Managed updates must still migrate only an exact WGDot-owned legacy NoWinKeys value when the matching registry snapshot exists, restore its pre-WGDot value, retire that old snapshot, preserve any user-modified replacement value, and request UAC before opening the protected legacy policy key for write on a non-elevated process. Do not reintroduce NoWinKeys.
- `NoWinKeys` does not disable a lone Windows-key press, and runtime testing showed GlazeWM bare `lwin` / `rwin` `wm-redraw` bindings do not reliably stop Start from opening. Any future lone-Super suppression must be implemented as a portable dotfile-owned non-elevated helper, must allow normal Super chords unchanged, and must bypass suppression while VM mode is active. WGDot must not own or be required by that live keyboard filter. Until such a standalone helper is implemented and maintainer-tested, do not claim lone-Super suppression is active.
- Launcher hotkeys are GlazeWM-owned but dispatch the approved compiled `wgdotw.exe launcher hotkey` surface because current upstream YASB Quick Launch cannot distinguish bar-click placement from keyboard placement and `yasbc` exposes no widget-action command. In managed GlazeWM config, invoke the helper through its deterministic `%LOCALAPPDATA%\wgdot\bin\wgdotw.exe` path so a long-running GlazeWM process does not depend on a stale inherited PATH. Do not restore `flow-launcher.ps1`, `yasb-quick-launch.ps1`, SendKeys, a private/synthetic F24 relay, or any fake YASB key injection. `launcher bar` must stay flush with the active display's left edge below the top bar; `launcher hotkey` must remain horizontally centered, including the existing fullscreen/auto-hide centering behavior. Global `Alt+P` and `Super+D` open the compiled launcher; `noalt` keeps `Super+D` but deliberately leaves plain `Alt+P` uncaptured. Flow Launcher is retired from the WGDot software catalog; preserve only narrow legacy-state cleanup for old selections and never reintroduce it as a launcher dependency.
- Clipboard/audio ownership is intentionally simple after real-Windows failures. `Super+V` stays the native Windows Clipboard History shortcut and GlazeWM must not capture it. The YASB clipboard button may use only the one-shot `wgdotw.exe clipboard-history-open` helper to inject native `Win+V`; it must not pause GlazeWM, create an anchor window, claim bar-relative placement, or own a keyboard shortcut. Do not revive `Super+C`, `clipboard-anchor`, or the retired generic clipboard worker/window.
- EarTrumpet owns `Alt+V` through its own application hotkey setting. GlazeWM must not capture `Alt+V` or `Super+V`, and WGDot must not rewrite EarTrumpet's mixer hotkey during software reconciliation. YASB volume right-click uses only `wgdotw.exe eartrumpet-mixer-toggle`, which verifies/starts EarTrumpet from its Start Menu shortcut and injects the application-owned Alt+V chord so EarTrumpet itself executes `OpenOrClose()`. Do not revive direct AppsFolder activation for mixer toggling. Native Windows `Super+V` stays free for Clipboard History.
- Flameshot owns its own `Win+Shift+X` capture hotkey. GlazeWM must not launch Flameshot or bind `Win+Shift+X`, `Win+Alt+S`, or `Win+Shift+S`; the latter stays available to the standard Windows Snipping Tool. WGDot must not sit in the live screenshot path. The tracked Flameshot INI must contain no user-specific absolute profile paths or obsolete shortcut entries current Flameshot rejects, and it is intentionally non-merge-managed so dots-only/reset replaces stale invalid keys instead of preserving them.
- Windows RawAccel uses only `Win+Shift+M` / `Super+Shift+M`. Do not add the Awtarchy `Alt+Shift+M` alias on Windows. Prefer a direct RawAccel executable/native interface when it can provide the required toggle semantics exactly; otherwise use only the narrowly scoped compiled WGDot RawAccel helper. Neither profile may reference `rawaccel-toggle.ps1` at runtime.
- Theme switching must not reload GlazeWM. Keep the focused-window border theme-neutral at `#a1a1a1`. Both profiles use the approved compiled WGDot theme helper for the custom theme workflow; neither profile may invoke `theme-switcher.ps1` at runtime.
- The experimental GlazeWM/WGDot mouse binding mode was retired after real-Windows testing showed pointer lag and unreliable tiled-window dragging. Do not reintroduce a low-level WGDot mouse hook or `Win+Alt+M` mouse mode. Preserve the native workspace mover arrows independently of that retired mode.
- `~/.config/yasb/theme.css` and `~/.config/yasb/appearance.css` are tracked managed dotfiles. Deploy them like the rest of the portable desktop config. After a managed apply that writes `theme.css` or WGDot-managed Windows Terminal settings, reapply the remembered selected theme through the existing compiled theme manager; this preserves user state without removing the files from management. `appearance.css` remains a normal tracked file.
- Windows Terminal ANSI colors are semantic terminal foreground colors, not raw YASB surface colors. Theme generation must enforce readable contrast for ANSI slots and preserve recognizable hues where possible. In particular, Yazi uses ANSI `blue` for directory names and ANSI `cyan` for PDF/document names, so dark YASB focus/hover colors must not be copied directly into those slots.
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
- Match Awtarchy's Noto Sans Mono Nerd Font typography at 14 px. The upstream `NotoSansMNerdFontMono-Regular.ttf` exposes the embedded Windows family name `NotoSansM NFM`; YASB CSS and WGDot font registration must use that exact Windows family name rather than the upstream long face label. WGDot manages the font from the official `ryanoasis/nerd-fonts` `Noto.zip` release as a current-user font; YASB keeps `JetBrainsMono NFP` as a fallback because dots-only updates intentionally perform no software/font installation. `wgdot bar-font-install` is the approved narrow management action for installing only this font without reconciling unrelated software, and dots-only should warn when the font is absent. Keep the action idempotent: if the managed TTF already exists and may be loaded by YASB, reuse it and repair the registry mapping rather than overwriting the locked file. A newly installed Noto font requires YASB restart before assuming Qt has picked it up. Keep JetBrains Mono Nerd Font managed as well because Windows Terminal still uses it. Keep bar text and real task/application icons at 14 px, but preserve Awtarchy's Nerd Font glyph tuning: generic/CPU/memory/brightness/clock/network/clipboard/control-center glyphs 18 px, battery 17 px, DND 19 px, and volume/power 20 px. The launcher glyph is 18 px. On Windows/Noto, use the heavier Nerd Font workspace-move arrows at 18 px rather than thin Unicode arrows. Keep the separate GlazeWM tiling-direction indicator compact at 14 px in a fixed 26 px centered slot with its 1 px baseline correction. Preserve the confirmed 1 px bottom adjustment on right-side metric text so it aligns visually with the enlarged glyphs.
- Keep the Caps Lock warning native to YASB using `yasb.language.LanguageWidget`: place the conditional `⇪` indicator immediately left of CPU in both profiles, poll at YASB’s 1-second minimum, collapse it to zero width while Caps Lock is off, and show it in the normal bar foreground color only while `.caps-lock-on` is active. Do not add a WGDot/session helper for keyboard lock state.
- Normal/personal GlazeWM defaults to `focus_follows_cursor: true`; Work intentionally remains `false`. Keep that profile difference explicit and covered by tests.
- Both GlazeWM profiles keep `cursor_jump.enabled: true` with `cursor_jump.trigger: "monitor_focus"` so cursor warping occurs when focus crosses monitors without forcing same-monitor window/workspace focus to recenter the pointer.
- Use YASB's native DDC/CI brightness support rather than a translated Awtarchy DDC script.
- Keep YASB systray `use_hook: false`. Upstream documents `use_hook: true` as an `explorer.exe` DLL-injection path. Do not introduce that extra hook for cosmetic parity, especially on a gaming-oriented setup.
- Do not substitute GPU temperature for Awtarchy's CPU-temperature module. Do not require Libre Hardware Monitor solely to make the bar look equivalent.
- The bar idle inhibitor was retired after real-Windows testing because its custom-widget state refresh was not worth the complexity and full YASB reload caused visible bar disappearance/reappearance. Do not render an idle eye, poll idle state, start a keep-awake worker, or reload YASB for idle state. Retain only legacy runtime stop cleanup so an older WGDot idle worker can be terminated during upgrade.
- Use the approved compiled Awtarchy-style application launcher as the primary launcher surface. YASB owns only the bar button and dispatches `wgdotw.exe launcher bar`; GlazeWM dispatches `wgdotw.exe launcher hotkey`. The launcher searches installed Start Menu applications, stays theme-aware, and does not grow Flow Launcher-style provider/scaling complexity unless explicitly requested.
- Launcher placement is trigger/context aware: with the 28 px visible top bar, both ordinary placements sit essentially flush below it with only a 1 px gap; a bar click stays top-left on the active display while keyboard activation stays horizontally centered. YASB auto-hide or a fullscreen/borderless foreground window forces center-screen placement on the relevant monitor. Keep the launcher single-instance, compact at roughly half the original 720 px width, windowless at dispatch, and immediate with no spawn fade. Keep the search field vertically compact. Start Menu shortcut activation must use Windows shell execution. For ordinary `.lnk` results, resolve the underlying target/icon metadata where Windows exposes it so the launcher prefers clean application icons rather than shortcut-style presentation; retain shortcut-icon fallback for packaged/special entries that do not expose a normal executable target.
- Clipboard History is separate from the launcher. Do not revive the old Quick Launch clipboard provider merely to expose history; the dedicated native Clipboard History/button experiment is tracked separately.
- Use YASB's native `ControlCenterWidget` for Awtarchy-style quick settings. Keep brightness/volume/microphone/media, DND, Windows dark mode, display/network/Bluetooth behavior native. The bar Wi-Fi/Ethernet control opens Windows' native `ms-settings:network-status` surface and the Bluetooth control opens Windows' native `ms-settings:bluetooth` surface; do not restore the rejected YASB `toggle_menu` mini flyouts merely for toggle-close behavior. NoAlt/VM quick actions still change GlazeWM modes; if YASB cannot launch `glazewm.exe` invisibly, an approved windowless WGDot dispatch may invoke the GlazeWM CLI solely to avoid a console flash. Running applications stay visible and unshaded; screenshot remains Flameshot.
- Awtarchy's single notification/mute control maps to one native YASB `DndWidget`: left click uses BaseWidget's native `exec notification_center` system-function mapping to open Windows Notification Center, middle click does nothing, and right click uses the widget's native `toggle_status` callback for Windows Do Not Disturb. Use bell/muted-bell state styling on that one control; do not reintroduce a separate Notifications widget or cross-widget hook. YASB documents its DND backend as the Windows QuietHoursSettings COM API, which is undocumented by Windows and may change.
- Match Awtarchy task controls with native YASB callbacks where possible: middle-click closes and right-click uses `toggle_window` for minimize/restore. Keep the documented left-click mismatch because YASB has no activate-only task callback.
- Awtarchy's horizontal bars show the globally focused active-window title on every monitor. Keep YASB ActiveWindow `monitor_exclusive: false` for that behavior; task icons and workspaces remain monitor-local.
- YASB workspace labels must render GlazeWM `display_name`, not raw workspace `name`. Keep all GlazewmWorkspaces populated/empty/active/focused label templates on `{display_name}` so names such as `1: Flame` and the Work profile labels actually appear in the bar.
- Do not use `yasbc toggle-bar` for bar hiding: it can strand an invisible bar and does not coordinate the GlazeWM top gap. Both profiles use the approved compiled WGDot auto-hide helper. The helper must coordinate YASB `auto_hide` with the 35 px/5 px GlazeWM top gap and reload only the affected applications; neither profile may invoke `bar-autohide.ps1` at runtime.
- Keep native YASB volume left-click mute, middle alternate-label behavior, and wheel volume changes. Volume right-click must call only the narrow windowless `wgdotw.exe eartrumpet-mixer-toggle` bridge; direct AppsFolder activation does not toggle EarTrumpet's mixer and must not return.
- Awtarchy's microphone indicator is muted-only. Preserve the native YASB Microphone widget but keep its normal icon empty and collapse its normal padding; rely on YASB's native `muted` class to reveal the red muted indicator rather than adding polling/helper logic.
- YASB's Battery widget has no native details popup. Map Awtarchy battery-menu clicks to Windows' own `ms-settings:powersleep` Power & battery surface on left/right click, and retain middle-click for YASB's alternate label rather than building a custom battery popup.
- YASB theme and appearance files are tracked dotfiles, not disposable generated state. Keep the Carbon Night palette in `styles.css` as a fallback, import tracked `theme.css` for palette variables, then import tracked `appearance.css` last. The compiled WGDot theme manager keeps lightweight selected-theme state under `~/.config/win-glaze`, updates the live `theme.css`, and synchronizes only its own Windows Terminal scheme/UI entries while preserving unrelated Terminal settings. Any managed update/reset that writes `theme.css` or WGDot-managed Terminal settings must reapply the remembered selected theme after file application. Preserve the current Awtarchy palette names/colors unless intentionally changing the shared visual catalog. Never reload or restart GlazeWM for theme-only changes.
- Route quick-settings theme launch and `Super+Alt+T` through `wgdotw.exe theme-window-toggle`, which owns only single-instance selector-window toggle/relocation. If the existing `Win Glaze Themes` window is visible on the currently focused monitor/workspace, the next invocation closes it; if it is on another monitor or a cloaked workspace, close/recreate exactly one selector in the current focused context. The interactive selector itself remains `wgdot.exe theme` inside Windows Terminal and theme application still must not reload GlazeWM.
- In Normal, launch the standalone selector in Windows Terminal titled `Win Glaze Themes`. Restricted Work must not require that script/title path; its compiled WGDot theme helper owns Work theme changes without reloading GlazeWM.
- Keep the four native workspace-move arrows directly visible and usable through the YASB Applications widget. The retired mouse-mode slot must disappear completely: no neutral hub glyph, no placeholder widget, and no fake Grouper hover parent. If upstream YASB later gains a clean reveal mechanism that does not require a visible placeholder, it can be reconsidered separately.
- Current stable YASB bar alignment supports only `top` and `bottom`; do not expose fake left/right bar-position choices. Its native blank-bar context menu also has no position-changing action, so a right-click position picker would require an upstream change or maintained YASB fork.
- Windows reserves `Win+L` for session locking. Runtime testing confirmed it still locks under the validated NoWinKeys setup, and PowerToys documents it as non-remappable. The user explicitly requested a lower-level experiment on 2026-09-20, so `wgdot super-l-test start|stop|status` may run a manually started, test-only low-level keyboard hook that consumes the L key while Super is held and asks GlazeWM to focus right. Do not install/start that hook automatically, do not add `Super+L` back to managed GlazeWM config yet, and do not describe the chord as solved until real Windows testing proves it does not lock the session. `Super+Right` remains the supported fallback.
- The visible GlazeWM binding-mode widget must reflect native `noalt` / `vm` state. Left/right click should disable the current active mode rather than cycle. Real pause stays native through `wm-toggle-pause`.
- Do not add AutoHotkey, whkd, DLL injection, third-party general-purpose input daemons, or another WGDot low-level pointer hook. Other native-capable interactions must not be pulled into WGDot.

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
- Both Normal and Work profiles must remain usable with no desktop/session `.ps1` runtime dependency. Tests must reject `.ps1` runtime references in all four managed GlazeWM/YASB runtime configs and reject `desktop-scripts` being default-enabled for either profile.

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
- Protected registry-only setup may run inside that bounded elevated worker. This includes Firefox extension policy registry mutation and registry-heavy Windows tweaks; Betterfox profile work, Brave/Mullvad browser interaction, EarTrumpet app configuration, and browser/app launches stay unelevated.
- If a later standalone tweak unexpectedly gets `UnauthorizedAccessException` under the normal token, retry only that explicit tweak through the existing elevation path and label the retry. Do not let an unlabeled access-denied exception abort the whole menu.
- privacy.sexy integration must not disable antivirus, add antivirus exclusions, or fake an unsupported headless API. The optional recommendation-level selector uses `Skip`, not `Cancel`; Skip bypasses only privacy.sexy and continues/finishes WGDot without implying that already-completed software work was cancelled. The privacy.sexy installer may auto-launch the desktop app; detect that process before launching another copy, and wait for the single desktop instance to close before returning to the WGDot workflow.
- Keep the privacy.sexy Clipboard History recovery as an action-only Windows tweak, not a persistent selection. It may restore `HKCU\\Software\\Microsoft\\Clipboard\\EnableClipboardHistory`, remove `HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows\\System\\AllowClipboardHistory` only when that policy is the disabled value `0`, and restore `cbdhsvc` startup only when privacy.sexy left it Disabled. Do not enable cross-device clipboard sync or broadly revert unrelated privacy.sexy settings.
- Software reconciliation must preserve human-readable failure reasons from the elevated worker and print them in the main WGDot window. Never collapse package/tweak/browser-policy failures into only an anonymous numeric failure count.
- Registry mutation helpers must open existing keys with the minimum rights needed to query/set values before falling back to key creation. Do not use `CreateSubKey` unconditionally on existing Windows-owned keys; some taskbar/search keys permit value writes while denying broader key-creation rights.
- `clean-taskbar-items` treats an access-denied write to the user-level `TaskbarDa` Widgets value as a Windows-build compatibility case. Discard the un-applied TaskbarDa rollback snapshot and fall back to Microsoft's machine-level `SOFTWARE\Policies\Microsoft\Dsh\AllowNewsAndInterests=0` policy inside the already-elevated batch. Preserve/restore that policy through the normal registry snapshot model.
- `automatic-time-and-timezone` is default ON and administrator-level. Use only Windows' built-in time/location stack: keep W32Time available, enable `tzautoupdate` with `Start=3`, enable device Location through `CapabilityAccessManager\ConsentStore\location\Value=Allow`, request a bounded/best-effort `w32tm /resync /rediscover`, and report the resulting Windows time zone. Do not add an external IP-geolocation dependency. Preserve the pre-WGDot registry values for rollback; rollback must not deliberately rewind the current clock or time zone.
- Do not prepend `runas`, `sudo`, or another elevation wrapper to every individual WinGet command. Elevate the bounded WGDot batch once, then return to the normal user process.
- Software preflight must not issue a network-backed exact-ID lookup for packages already known installed. Take one bounded WinGet installed-state snapshot first, then validate only missing packages.
- Silent WinGet preflight/list/show checks must use noninteractive mode and a finite timeout. A hung WinGet query must stop or skip the affected preflight with a clear message rather than freeze WGDot indefinitely.
- Actual WinGet installs must also be bounded when a package declares `wingetInstallTimeoutSeconds`. On timeout, terminate the stuck WinGet process tree before continuing.
- A WinGet install timeout/failure may fall back only when the package manifest explicitly declares an approved official GitHub repository and a narrow asset regex. Never invent or scrape third-party mirrors.
- Flow Launcher is retired from the software catalog. Loading older installation state may discard its retired package/tweak selections, but WGDot must not silently uninstall an already-installed copy solely because catalog support was removed.
- Double Commander is retired from the software catalog. Yazi + Explorer are the preferred file-manager path. Loading older installation state must discard the retired `Alexx2000.DoubleCommander` selection without uninstalling an existing Double Commander installation.
- Open-Shell remains selectable but defaults OFF for both Normal and Work on a fresh selection. Existing remembered package selections remain authoritative, and changing the default must never be treated as permission to uninstall an existing Open-Shell installation. Run its post-install setup only when the package was explicitly selected for installation.

## Application startup ownership

- Startup management is separate from installation. Manifest packages may declare a narrow `startupHandler` and `startupDefault`.
- WGDot startup entries are current-user `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` values named `WGDot.<handler>`. Never overwrite, delete, or reinterpret unrelated vendor/user Run values.
- Current managed startup handlers are GlazeWM, AltSnap, EarTrumpet, MicLockTray, and RawAccel when those packages are selected. RawAccel startup is independently remembered in `startup.json` and defaults OFF; enabling its WGDot-owned login entry must not alter the RawAccel acceleration configuration/profile. The startup UI labels the GlazeWM entry as `GlazeWM + YASB`: YASB is deliberately not a second Windows startup entry because the managed GlazeWM config already starts/stops YASB through `startup_commands` / `shutdown_commands`.
- The managed AltSnap defaults intentionally set `AutoFocus=1` and `Hotkeys=A4 A5 5B 5C`: dragging focuses the target window, and both left/right Alt plus left/right Windows keys activate AltSnap. Preserve these defaults unless explicitly changed.
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

Use Yazi's native wraparound movement actions for list navigation: Up/`k` use `arrow prev` and Down/`j` use `arrow next`. This intentionally wraps from the first item to the last and from the last item to the first. Preserve native `g` Go To prefix behavior, `gg` top, and `G` bottom.

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
- The paste-only restricted-network manual workflow must not require `api.github.com`, `github.com` archive/clone access, or execution of downloaded scripts. Pin its documented stable tag to the exact immutable release commit and update that tag/SHA pair whenever a new stable release becomes the supported manual source.
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


- `Super+Alt+T` opens the theme selector. `Super+T` and normal global `Alt+T` toggle tiling. The `noalt` mode must retain `Super+T` tiling and `Super+Alt+T` themes but must not capture plain `Alt+T`.

- All supported native YASB popup/menu offsets on the managed bar must use `offset_top: 0` so their surfaces touch the top bar. Keep the compiled launcher scrollbar theme-aware; do not restore the bright native Windows ListBox scrollbar.
