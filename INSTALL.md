# Installing win-glaze-dots / WGDot

WGDot is the native Windows maintenance system for win-glaze-dots. It installs under your user profile and manages the selected dotfiles, software, browser options, Windows tweaks, backups, and update state.

## Before installing

WGDot targets Windows 10/11.

For a fresh Windows installation:

1. Finish Windows setup.
2. Run Windows Update and reboot as needed.
3. Open **Windows PowerShell** or **Windows Terminal**.

WinGet is a WGDot requirement, but it does **not** need to be preinstalled manually. The bootstrap checks for `winget.exe`; if it is missing, WGDot automatically uses Microsoft's WinGet client/repair path and registers App Installer for the current user. This is intended to cover stripped Windows installs such as LTSC systems where App Installer/WinGet is not already available.

WGDot does not require changing PowerShell execution policy and does not use `Set-ExecutionPolicy` or `-ExecutionPolicy Bypass`.

## Install WGDot

Paste this into PowerShell:

```powershell
$b="$env:TEMP\wgdot-bootstrap.cmd"; curl.exe -fsSL https://raw.githubusercontent.com/dillacorn/win-glaze-dots/main/wgdot/bootstrap.cmd -o $b; & $b
```

The bootstrap downloads the inspectable native WGDot C# source, compiles it locally with the Windows .NET Framework compiler, self-tests it, installs the runtime, and then verifies the required WinGet/App Installer stack. Missing WinGet is repaired automatically before bootstrap completes.

The runtime is installed under:

```text
%LOCALAPPDATA%\wgdot\bin
```

Open a new terminal after the bootstrap finishes, then run:

```powershell
wgdot
```

Use the interactive menu to choose your Normal/Work profile, managed components, software, browser options, and Windows tweaks.

## Software startup and back-out

After software reconciliation, WGDot enables its own Windows-login startup entries for selected applications that are part of the desktop session: GlazeWM, AltSnap, EarTrumpet, and MicLockTray when selected. RawAccel is available as a separate optional startup entry and defaults OFF. Startup Applications also exposes supported apps that WGDot positively detects as already installed even when they are not selected for software reconciliation. YASB is not registered a second time because the managed GlazeWM configuration starts and stops YASB itself.

Run `wgdot software` to open the **Software / startup manager**. From there you can:

- enable or disable individual WGDot-managed startup entries without uninstalling anything;
- disable all WGDot-managed startup entries in one action while leaving applications installed;
- uninstall individual WGDot catalog applications after a separate removal review and confirmation;
- reconcile the desired software selection again.

WGDot startup entries are current-user Windows Run entries named `WGDot.*`. Disabling them does not touch unrelated application/vendor startup entries.

## GPU drivers

WGDot detects present AMD, NVIDIA, and Intel display adapters from their hardware IDs. When a matching vendor display driver is missing, software reconciliation launches the detected vendor's official auto-detect/driver assistant. The GPU maintenance menu can also run the official assistants on demand. Hybrid systems can run more than one vendor assistant.

DDU cleanup remains a separate guarded recovery path and is never run automatically.

## Release and runtime model

WGDot intentionally separates its maintenance runtime from managed configuration releases.

- The WGDot runtime may refresh from `main` so updater/runtime fixes can reach installed systems without replacing the currently selected configuration release.
- Normal managed-dot update/reset/review operations use the latest published stable semantic release.
- Unreleased branch testing is explicit and separate from stable state.

## Manual fallback

If a work or policy-restricted system permits pasted PowerShell commands but blocks downloaded `.ps1` execution, use [MANUAL_POWERSHELL.md](MANUAL_POWERSHELL.md). Do not change execution policy to work around local policy.

For normal updates after installation, use [UPDATE.md](UPDATE.md).
