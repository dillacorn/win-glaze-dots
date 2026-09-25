# Install WGDot

WGDot supports Windows 10/11. Open PowerShell or Windows Terminal and run:

```powershell
curl.exe -fsSL https://github.com/dillacorn/win-glaze-dots/raw/main/wgdot/bootstrap.cmd -o "$env:TEMP\wgdot.cmd"; & "$env:TEMP\wgdot.cmd"
```

The installer downloads the WGDot source, compiles and self-tests it locally, ensures WinGet is available, adds `%LOCALAPPDATA%\wgdot\bin` to your user `PATH`, then opens WGDot immediately.

No reboot is required. WGDot does not change or bypass PowerShell execution policy.

An already-open PowerShell process cannot inherit a user `PATH` change made by a child installer, so the installer launches WGDot directly on first run. New terminals can simply run:

```powershell
wgdot
```

For policy-restricted systems, use [MANUAL_POWERSHELL.md](MANUAL_POWERSHELL.md).

For later maintenance, see [UPDATE.md](UPDATE.md).
