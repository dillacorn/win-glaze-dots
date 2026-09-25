# Install WGDot

WGDot supports Windows 10/11. Open PowerShell or Windows Terminal and run:

```powershell
irm https://github.com/dillacorn/win-glaze-dots/raw/main/i.ps1 | iex
```

The tiny `i.ps1` handoff downloads and runs WGDot's native batch bootstrap. WGDot then downloads its source, compiles and self-tests locally, ensures WinGet is available, adds `%LOCALAPPDATA%\wgdot\bin` to your user `PATH`, and opens immediately.

No reboot is required. WGDot does not change PowerShell execution policy or launch PowerShell with `-ExecutionPolicy Bypass`.

New terminals can simply run:

```powershell
wgdot
```

For policy-restricted systems, use [MANUAL_POWERSHELL.md](MANUAL_POWERSHELL.md).

For later maintenance, see [UPDATE.md](UPDATE.md).
