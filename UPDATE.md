# Updating win-glaze-dots / WGDot

Use the installed `wgdot` maintenance command for normal updates. Do not reclone the repository or rerun the bootstrap for routine upgrades.

## Interactive maintenance

Run:

```powershell
wgdot
```

The maintenance menu exposes managed-dot updates, a software/startup manager, Windows tweaks, GPU maintenance, backup management, review/reset operations, audits, status, and explicit Git testing.

## Update managed dots

```powershell
wgdot update
```

Normal managed-dot updates use the latest published stable WGDot-compatible release.

WGDot creates adjacent backups when required, preserves unrelated files, and tracks a trusted baseline so local edits can be distinguished from upstream changes.

## Review before applying

```powershell
wgdot review
```

This resolves the current stable release and previews the managed-file plan without applying it.

## Reset or reconfigure managed dots

```powershell
wgdot reset
```

Use reset when you intentionally want selected WGDot-managed files returned to the selected stable release state. Differing live files are backed up before replacement.

## Software, startup, and uninstall management

```powershell
wgdot software
```

This opens the **Software / startup manager**. It provides separate actions for installing/reconciling selected software, managing Windows-login startup entries, uninstalling individual applications, and disabling every WGDot-owned startup entry while keeping the applications installed.

Direct commands are also available:

```powershell
wgdot software-reconcile
wgdot startup
wgdot software-uninstall
wgdot startup-disable-all
```

Software reconciliation installs missing approved packages and can offer explicitly approved upgrades. It does not run a blind `winget upgrade --all`. Deselecting software during reconciliation does not itself uninstall anything; removal requires the dedicated uninstall workflow and its confirmation.

WGDot requires WinGet. If WinGet/App Installer is missing, the runtime uses Microsoft's WinGet repair/bootstrap path automatically rather than requiring a separate manual setup step.

## GPU driver maintenance

```powershell
wgdot gpu-driver
```

WGDot detects present AMD, NVIDIA, and Intel display adapters and runs the matching official vendor auto-detect/driver assistant when requested. Missing matching vendor drivers are also surfaced after software reconciliation. DDU/Safe Mode cleanup remains a separate confirmation-gated recovery path.

## Check state

```powershell
wgdot status
```

Status reports the installed runtime revision separately from stable managed-config state, Git-testing state, baseline state, backups, and pending GPU maintenance state.

## Test unreleased work

Use the interactive **Advanced / Git testing** menu or the explicit direct commands:

```powershell
wgdot git-review --branch <branch> --revision <full-40-character-sha>
wgdot git-update --branch <branch> --revision <full-40-character-sha>
wgdot git-reset --branch <branch> --revision <full-40-character-sha>
```

`git-review` is non-mutating. `git-update` applies the normal managed-file update rules from that exact branch revision, including backup/baseline protection. `git-reset` is the intentional reset/reconfigure path and may replace selected managed files after backing up differences.

Git testing is explicit maintainer/developer behavior. A branch is not treated as a stable release, and normal stable operations remain a separate release stream.

## Audits

Non-installing software catalog audit:

```powershell
wgdot software-audit
```

Broader safe acceptance audit:

```powershell
wgdot acceptance-audit
```

The acceptance audit keeps mutation tests isolated and leaves interaction-dependent checks, such as real Windows hotkeys and some application approval flows, for manual testing.

## Runtime refresh behavior

Normal user-facing WGDot maintenance commands check the configured runtime branch before dispatch. If the installed runtime revision is old, WGDot stages the current runtime, runs the requested command with it, and finalizes the runtime replacement after the old executable exits.

This runtime refresh is separate from the stable managed configuration release.

For a fresh machine, use [INSTALL.md](INSTALL.md).
