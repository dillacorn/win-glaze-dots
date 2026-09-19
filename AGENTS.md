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
    |       +--> WinGet software reconciliation
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

## Runtime vs managed configuration

WGDot runtime and managed configuration intentionally have different lifecycles.

- The installed WGDot runtime may refresh from `main`.
- Normal user-facing WGDot invocations compare the recorded runtime revision with the configured runtime branch head before dispatch and run the refreshed runtime immediately when they differ.
- Because Windows cannot reliably overwrite the currently running executable, a refreshed staged runtime schedules its own post-exit replacement of the installed `wgdot.exe` and records the exact revision only after that swap succeeds.
- Normal managed-config update/reset/review operations must use an exact published stable release, never the current `main` config tree.
- A runtime refresh from `main` must not silently change the release manifest used for a stable config operation.
- The selected stable release supplies its own `wgdot/manifest.json` and managed source files.
- Development branches are accessible only through explicit Git-testing mode.

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

- The managed GlazeWM profiles include a `noalt` binding mode toggled with `Win+Alt+N`, modeled after Awtarchy's noalt submap. It suppresses the normal Alt-heavy GlazeWM bindings while preserving Windows-key app/screenshot alternatives.
- The managed GlazeWM profiles include a `vm` binding mode toggled with `Win+Alt+V`, modeled after Awtarchy's VM submap. While active, ordinary global host bindings are replaced so the guest receives normal Alt/Windows shortcuts; required host controls live on `Win+Alt` combinations.
- VM mode host controls include close (`Win+Alt+Q`), float (`Win+Alt+F`), Flow Launcher (`Win+Alt+P`), Calculator (`Win+Alt+C`), EarTrumpet (`Win+Alt+Ctrl+V`), Flameshot (`Win+Alt+S`), Terminal (`Win+Alt+Enter`), workspace focus (`Win+Alt+0..9`), and move-to-workspace (`Win+Alt+Shift+0..9`).
- `Win+Alt+N` switches from VM mode to noalt; `Win+Alt+V` switches from noalt to VM mode. GlazeWM replaces the active binding mode when another mode is enabled.
- Flow Launcher keeps native `Alt+P`; GlazeWM maps `Win+D` to WGDot's `flow-open` helper.
- EarTrumpet keeps native mixer `Alt+V`; GlazeWM maps `Win+V` to WGDot's `eartrumpet-mixer` helper so both reach the same mixer action.
- Flameshot selection capture is `Win+Shift+S` in both managed GlazeWM profiles; do not restore the old `Win+Shift+F` binding.

- Yazi launcher binding uses both `lwin+shift+e` and `rwin+shift+e`. Keep both Windows-key variants together and do not restore the old `alt+shift+e` launcher bind.

There are two maintained GlazeWM source profiles:

- Normal: `UserProfile/.glzr/glazewm/config.yaml`
- Work: `UserProfile/.glzr/glazewm/custom_work_config.yaml`

Both map to the same live destination:

`%USERPROFILE%\.glzr\glazewm\config.yaml`

The selected profile is remembered. Normal updates use the remembered profile. Reset/reconfigure may switch profiles and must back up the existing live config before replacement when it differs.

Do not deploy both source files as active configs.

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

- Package IDs live in `wgdot/manifest.json`.
- Verify a package with exact-ID WinGet lookup before installation or upgrade.
- Never silently run `winget upgrade --all`.
- Updates may detect available software upgrades and ask for explicit user consent.
- Deselecting a package must not uninstall it.
- Removal/retirement of software requires explicit project behavior and ownership tracking.
- Do not invent package IDs. Verify changed or questionable IDs against current WinGet data before committing them.

## Yazi migration safety

The current Windows Yazi clipboard helper is:

`UserProfile/AppData/Roaming/yazi/config/plugins/system-clipboard.yazi/main.lua`

The current keymap invokes `plugin system-clipboard`.

The obsolete `%APPDATA%\yazi\config\plugins\clipboard.yazi` directory may be removed only when positively identified as the known old managed XYenon plugin. A same-named user/custom directory must be preserved with a warning.

Do not reintroduce Linux `wl-copy`/`wl-paste` assumptions into the Windows helper.

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
