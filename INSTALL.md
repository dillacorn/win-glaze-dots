# Installing win-glaze-dots / WGDot

WGDot is the native Windows maintenance system for win-glaze-dots. It installs under your user profile and manages the selected dotfiles, software, browser options, Windows tweaks, backups, and update state.

## Before installing

WGDot targets Windows 10/11.

For a fresh Windows installation:

1. Finish Windows setup.
2. Run Windows Update and reboot as needed.
3. Open **Windows PowerShell** or **Windows Terminal**.
4. Confirm WinGet is available if you want WGDot to install software:

```powershell
winget --version
```

WGDot does not require changing PowerShell execution policy and does not use `Set-ExecutionPolicy` or `-ExecutionPolicy Bypass`.

## Install WGDot

Paste this into PowerShell:

```powershell
$b="$env:TEMP\wgdot-bootstrap.cmd"; curl.exe -fsSL https://raw.githubusercontent.com/dillacorn/win-glaze-dots/main/wgdot/bootstrap.cmd -o $b; & $b
```

The bootstrap downloads the inspectable native WGDot C# source, compiles it locally with the Windows .NET Framework compiler, self-tests it, and installs the runtime under:

```text
%LOCALAPPDATA%\wgdot\bin
```

Open a new terminal after the bootstrap finishes, then run:

```powershell
wgdot
```

Use the interactive menu to choose your Normal/Work profile, managed components, software, browser options, and Windows tweaks.

## Release and runtime model

WGDot intentionally separates its maintenance runtime from managed configuration releases.

- The WGDot runtime may refresh from `main` so updater/runtime fixes can reach installed systems without replacing the currently selected configuration release.
- Normal managed-dot update/reset/review operations use the latest published stable semantic release.
- Unreleased branch testing is explicit and separate from stable state.

## Manual fallback

If a work or policy-restricted system permits pasted PowerShell commands but blocks downloaded `.ps1` execution, use [MANUAL_POWERSHELL.md](MANUAL_POWERSHELL.md). Do not change execution policy to work around local policy.

For normal updates after installation, use [UPDATE.md](UPDATE.md).
