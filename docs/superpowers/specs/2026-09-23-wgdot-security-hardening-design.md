# WGDot Minimal Security Hardening Design

Date: 2026-09-23

Tracking issue: https://github.com/dillacorn/win-glaze-dots/issues/61

Baseline: `4b97a4d1e7fb62bf5d71b7beba2adb9baa8c53eb`

## Purpose

Tighten the three meaningful user-to-administrator trust crossings found in the WGDot review without changing installation, application selection, menus, UAC frequency, or desktop behavior.

This is not an installer redesign. WGDot keeps one WinGet-based application flow and the existing `wgdot.exe` plus `wgdotw.exe` architecture.

## Required user experience

- Installation remains the current `wgdot/bootstrap.cmd` flow.
- Software selection and reconciliation continue using the same WinGet commands and one existing elevation handoff.
- GPU/DDU staging and resume retain the same confirmations and recovery order.
- Runtime updates continue replacing the locally compiled `wgdot.exe` through the existing self-refresh path and ensure the explicitly versioned `wgdotw.exe` frontend before recording the refreshed revision.
- Normal and Work GlazeWM/YASB callbacks remain unchanged.
- No new installed executable, service, task, dependency, setting, prompt, menu, or alternate installation method is introduced.
- `wgdot/bootstrap.cmd`, the manifest, and managed desktop configuration are not changed in this batch. After integrating v4.6.0, `wgdotw.exe` receives only exact argument-boundary forwarding plus version-aware refresh so the new Yazi drag manifest path remains one argument even when `%TEMP%` contains spaces.
- The only new visible result is a clear failure when an elevated handoff was modified or an executable resolves outside its trusted location.

## Threat model

The addressed attacker is another process already running as the current standard user. It can modify files under `%LOCALAPPDATA%`, influence the inherited environment, and wait for the user to approve a legitimate WGDot UAC prompt.

The fixes prevent that process from silently changing the software plan or GPU resume state after the user initiated an operation, substituting a different `winget.exe`, or making elevated WGDot execute a DDU path taken from writable state.

Administrator/SYSTEM compromise, repository-account compromise, upstream installer compromise, and code signing remain outside this minimal batch.

## Design

### 1. Bind elevated software plans to their exact bytes

The normal process continues writing the same bounded JSON plan under the WGDot state directory. It then calculates the plan file's SHA-256 and includes the digest in the existing `software-elevated` command line.

The elevated worker must:

1. require a 64-character hexadecimal digest;
2. read the plan file once;
3. hash those exact bytes;
4. compare the expected and actual digests before parsing;
5. parse the already verified bytes rather than reopening the path;
6. stop before any privileged action when verification fails.

The plan schema and all software behavior remain otherwise unchanged.

### 2. Run the genuine WinGet execution alias by full path

WGDot keeps its existing WinGet bootstrap and repair behavior. It does not add another package manager or installation route.

Before an elevated software operation launches WinGet, WGDot resolves `%LOCALAPPDATA%\Microsoft\WindowsApps\winget.exe`, canonicalizes it, verifies that it is an existing file inside that exact WindowsApps directory, and then reuses the full path for the existing `show`, `install`, and `upgrade` commands.

WGDot must not fall back to a bare `winget.exe` name while elevated. If the execution alias is unavailable, the existing repair/error path applies.

This change does not alter package IDs, repository selection, arguments, prompts, or application-selection logic.

### 3. Bind GPU resume state and re-resolve DDU after elevation

After WGDot writes the final Safe Mode state file, it calculates that file's SHA-256 and includes the digest in the existing HKLM RunOnce command.

`gpu-safe-resume` must preserve the digest through its existing UAC re-elevation, read the state once, verify the exact bytes, and parse only those verified bytes.

The elevated resume path must not execute the stored `dduPath`. It re-resolves DDU from its existing registered/conventional installed locations and accepts only an existing full path beneath Program Files or Program Files (x86). The stored path may remain for diagnostics but has no execution authority.

The existing ordering remains mandatory: remove forced Safe Mode successfully before launching DDU, and do not launch DDU if normal boot cannot be restored.

### 4. Preserve the current update model

All production changes remain in `wgdot/wgdot-native.cs`. Existing installations receive the hardening through WGDot's current exact-revision compile, self-test, staged execution, and post-exit replacement behavior.

The v4.6.0 Yazi outbound-drag integration introduced a path argument that can contain spaces. The generated `wgdotw.exe` therefore quotes each forwarded argument using Windows command-line rules. The frontend carries an explicit file version; runtime self-refresh invokes the new runtime's internal `ensure-hidden-launcher` step before recording the refreshed revision. An already-current frontend is left byte-for-byte untouched, avoiding unnecessary ThreatLocker hash churn.

## Failure handling

- Changed or malformed software plan: stop before any elevated software action and instruct the user to rerun the operation.
- Missing or unsafe WinGet path: use the existing repair/error behavior and never search arbitrary PATH locations while elevated.
- Changed or malformed GPU state: stop the resume operation without launching DDU.
- Missing or unsafe DDU location: preserve the existing boot-recovery safety ordering and do not launch DDU.

No new security check silently falls back to a less trusted path.

## Validation

Automated coverage must prove:

- an unchanged software plan is accepted;
- changing one plan byte after hashing is rejected;
- malformed or missing plan digests are rejected;
- elevated WinGet launches receive an absolute path inside the current user's WindowsApps directory and never a bare name;
- unchanged GPU state is accepted and changed state is rejected;
- the GPU resume digest survives the non-admin-to-admin handoff;
- the elevated GPU resume path ignores stored `dduPath` as execution authority;
- DDU candidates outside Program Files roots are rejected;
- `wgdotw.exe` preserves spaces, quotes, empty arguments, and trailing backslashes without interpreting them through a shell;
- runtime self-refresh ensures an outdated frontend before recording its revision and does not rebuild an already-current frontend;
- existing repository, desktop, stable/Git separation, and runtime-refresh tests continue passing.

CI remains the authoritative automated Windows compile and native self-test environment. Interactive UAC, ThreatLocker, and Safe Mode behavior still require real-Windows confirmation before merge or release.

## Explicitly deferred

The following issue #61 items are not part of this batch:

- elevated manifest re-download or ProgramData staging;
- bootstrap selector changes;
- broad replacement of every Windows system utility path;
- code signing or publisher-rule deployment;
- runtime update-channel changes;
- mandatory Authenticode/hash validation for upstream installers;
- moving WGDot to a machine-wide protected directory;
- general reparse-point hardening.

These may be evaluated separately. They are intentionally excluded here to keep WGDot installation and operation unchanged.

## Rejected alternatives

### Add a second installer, package manager, or software method

Rejected. The security fix only changes how the existing WinGet executable is located; application installation remains one existing flow.

### Add a service or privileged helper executable

Rejected. Either would increase installation complexity, application-control approvals, persistence, and attack surface.

### Rebuild the windowless wrapper on every update

Rejected. The frontend is rebuilt only when its explicit version changes. This delivers the v4.6.0 argument-boundary fix without unnecessary application-control hash churn.
