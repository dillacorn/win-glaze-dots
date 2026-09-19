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

When the **Browsers** category is open, highlight Firefox, Brave, or Mullvad Browser and press **E** to review that browser's extensions/options. Browser-option choices are remembered separately from the package checkboxes.

Firefox is the managed path. Fresh WGDot selections default to Betterfox plus CanvasBlocker, ClearURLs, Ctrl+Number to switch tabs, LocalCDN, Return YouTube Dislike, SponsorBlock, and full uBlock Origin. Dark Reader and ScrollAnywhere are optional and default OFF. Signed Firefox add-ons are requested through Mozilla's supported Windows policy mechanism.

Betterfox is installed only into a dedicated `Profiles/wgdot.betterfox` Firefox profile. Existing profiles are preserved and relevant Firefox metadata is backed up. WGDot asks before changing the Firefox default profile.

Brave uses its built-in Shields privacy/blocking features, so WGDot does not stack extra privacy blockers by default. Return YouTube Dislike and SponsorBlock default ON; Dark Reader and ScrollAnywhere default OFF and use their official Chrome Web Store pages with normal **Add to Brave** approval. Full uBlock Origin is still supported by Brave through `brave://settings/extensions/v2`; WGDot exposes that as an optional default-OFF Brave setting because Shields already covers the normal blocking role. ClearURLs is omitted because Brave disables the current Manifest V2 build, CanvasBlocker has no official Chromium build, LocalCDN's Chromium store publication is not the upstream-supported path, and Ctrl+1..9 tab switching is already native.

Mullvad Browser is intentionally left untouched. WGDot does not install extensions, Betterfox, `user.js`, or preference tweaks into it. Use it as shipped to preserve its anti-fingerprinting profile, preferably with a VPN.

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


## GPU drivers

WGDot has a separate GPU driver maintenance workflow in the main menu.

- Detects present AMD, NVIDIA, and Intel display adapters from PCI hardware IDs.
- Reports the active display-driver provider/version and recommends the matching vendor tooling when a vendor driver is missing.
- Supports AMD Auto-Detect, NVIDIA App, and Intel Driver & Support Assistant from vendor-owned download endpoints.
- Detects possible stale/mismatched display-driver vendors without treating legitimate hybrid Intel+NVIDIA / Intel+AMD systems as errors.
- Offers a guarded DDU clean reinstall/refresh path that stages Safe Mode only after explicit confirmation.
- DDU cleanup state survives the reboot. WGDot removes forced Safe Mode before DDU launches and remembers which vendor driver must be reinstalled afterward.
- DDU remains available as `Wagnardsoft.DisplayDriverUninstaller`, but WGDot does not run it automatically.
