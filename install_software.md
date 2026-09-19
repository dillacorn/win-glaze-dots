# Package Management with WinGet

WGDot's interactive software selector is the preferred installation path. Packages are grouped by category instead of shown as one giant list.

The default selection is intentionally conservative for public use. Only the WGDot desktop stack, broadly useful defaults, and practical dependencies are enabled by default; personal applications are opt-in.

## Default ON

- **Git** — `Git.Git`
- **Windows Terminal** — `Microsoft.WindowsTerminal`
- **AltSnap** — `AltSnap.AltSnap`
- **Visual C++ Redistributable** — `Microsoft.VCRedist.2015+.x64`
- **YASB** — `AmN.yasb`
- **Flameshot** — `Flameshot.Flameshot`
- **Flow Launcher** — `Flow-Launcher.Flow-Launcher`
- **EarTrumpet** — `File-New-Project.EarTrumpet`
- **Micro** — `zyedidia.micro`
- **Yazi** — `sxyazi.yazi`
- **qimgv** — `easymodo.qimgv`
- **mpv.net** — `mpv.net`
- **Firefox** — `Mozilla.Firefox`
- **7-Zip** — `7zip.7zip`
- **FFmpeg** — `Gyan.FFmpeg`
- **jq** — `jqlang.jq`
- **Poppler** — `oschwartz10612.Poppler`
- **fd** — `sharkdp.fd`
- **ripgrep** — `BurntSushi.ripgrep.MSVC`
- **fzf** — `junegunn.fzf`
- **zoxide** — `ajeetdsouza.zoxide`
- **ImageMagick** — `ImageMagick.ImageMagick`
- **GlazeWM** — `glzr-io.glazewm`
- **JetBrains Mono Nerd Font** — `DEVCOM.JetBrainsMonoNerdFont`
- **Open-Shell** — `Open-Shell.Open-Shell-Menu`

## Optional packages by category

### CLI / Yazi helpers

- **Fastfetch** — `Fastfetch-cli.Fastfetch`
- **Cava** — `karlstav.cava`
- **btop4win** — `aristocratos.btop4win`

### Browsers

- **Brave** — `Brave.Brave`
- **Mullvad Browser** — `MullvadVPN.MullvadBrowser`

### Editors

- **Notepad++** — `Notepad++.Notepad++`

### General utilities

- **SpeedCrunch** — `SpeedCrunch.SpeedCrunch`
- **Everything** — `voidtools.Everything`

### System / diagnostics

- **Display Driver Uninstaller** — `Wagnardsoft.DisplayDriverUninstaller`
- **PowerToys** — `Microsoft.PowerToys`
- **System Informer** — `WinsiderSS.SystemInformer`
- **HWMonitor** — `CPUID.HWMonitor`
- **Ventoy** — `Ventoy.Ventoy`
- **CCleaner** — `Piriform.CCleaner`
- **WizTree** — `AntibodySoftware.WizTree`
- **CPU-Z** — `CPUID.CPU-Z`
- **GPU-Z** — `TechPowerUp.GPU-Z`
- **Windhawk** — `RamenSoftware.Windhawk`

### Networking / remote

- **LocalSend** — `LocalSend.LocalSend`
- **RustDesk** — `RustDesk.RustDesk`
- **qBittorrent** — `qBittorrent.qBittorrent`
- **WinSCP** — `WinSCP.WinSCP`
- **FileZilla** — `TimKosse.FileZilla.Client`
- **WireGuard** — `WireGuard.WireGuard`
- **Tailscale** — `Tailscale.Tailscale`

### Communication

- **Vesktop (Vencord)** — `Vencord.Vesktop`

### Media

- **FLAC** — `Xiph.FLAC`
- **Feishin** — `jeffvli.Feishin`
- **OBS Studio** — `OBSProject.OBSStudio`
- **Okular** — `KDE.Okular`
- **yt-dlp** — `yt-dlp.yt-dlp`
- **DistroAV** — `DistroAV.DistroAV`

### Creative

- **Krita** — `KDE.Krita`
- **Shotcut** — `Meltytech.Shotcut`
- **GIMP** — `GIMP.GIMP`
- **ScreenToGif** — `NickeManarin.ScreenToGif`

### 3D printing

- **OrcaSlicer** — `SoftFever.OrcaSlicer`
- **PrusaSlicer** — `Prusa3D.PrusaSlicer`
- **Cura** — `Ultimaker.Cura`

### Gaming

- **Steam** — `Valve.Steam`
- **itch.io** — `ItchIo.Itch`
- **GOG Galaxy** — `GOG.Galaxy`
- **Prism Launcher** — `PrismLauncher.PrismLauncher`
- **r2modman** — `ebkr.r2modman`
- **Epic Games Launcher** — `EpicGames.EpicGamesLauncher`
- **Moonlight** — `MoonlightGameStreamingProject.Moonlight`
- **Sunshine** — `LizardByte.Sunshine`

### Security

- **KeePassXC** — `KeePassXCTeam.KeePassXC`

### Development

- **Make** — `GnuWin32.Make`
- **MSYS2** — `MSYS2.MSYS2`
- **cURL** — `cURL.cURL`

### Virtualization

- **QEMU** — `SoftwareFreedomConservancy.QEMU`
- **QEMU Guest Agent** — `SoftwareFreedomConservancy.QEMUGuestAgent`

### Work

- **Microsoft Teams** — `Microsoft.Teams`

## Notes

- Open-Shell is enabled by default and WGDot starts it after a successful first install.
- Micro is the preferred text editor. Notepad++ remains available only as an opt-in editor.
- qimgv and mpv.net are default media applications.
- Vesktop (`Vencord.Vesktop`) is the offered Discord-family client; Discord itself is not cataloged.
- OrcaSlicer, PrusaSlicer, and Cura are all optional and default OFF.
- WireGuard is available under Networking / remote and defaults OFF.
- Steam, itch.io, GOG Galaxy, Prism Launcher, r2modman, and Epic Games Launcher are all optional and default OFF.
- Signal, Bitwarden, Betaflight Configurator, PDF-XChange Editor, Spotify, Process Explorer, and Double Commander are intentionally not offered.
- Deselecting an installed package does not uninstall it.
- WGDot never runs `winget upgrade --all`; upgrade checks are opt-in and each selected package requires approval.
