# Package Management with Winget

---

### install all essential applications (one-liner)
```powershell
winget install SpeedCrunch.SpeedCrunch RustDesk.RustDesk Git.Git Microsoft.WindowsTerminal AltSnap.AltSnap Alacritty.Alacritty Microsoft.VCRedist.2015+.x64 AmN.yasb Flameshot.Flameshot Flow-Launcher.Flow-Launcher File-New-Project.EarTrumpet Notepad++.Notepad++ qimgv.qimgv clsid2.mpc-hc CPUID.HWMonitor LocalSend.LocalSend DisplayDriverUninstaller.DisplayDriverUninstaller Brave.Brave Microsoft.PowerToys Fastfetch-cli.Fastfetch 7zip.7zip xiph.flac glzr-io.glazewm karlstav.cava 
```

### install gaming applications (one-liner)
```powershell
winget install Valve.Steam itch.itch GOG.Galaxy PrismLauncher.PrismLauncher ebkr.r2modman EpicGames.EpicGamesLauncher
```

### install optional applications (one-liner)
```powershell
winget install jeffvli.Feishin Discord.Discord OBSProject.OBSStudio MullvadVPN.MullvadBrowser voidtools.Everything KDE.Okular Ultimaker.Cura OpenWhisperSystems.Signal KeePassXCTeam.KeePassXC Bitwarden.Bitwarden KDE.Krita Meltytech.Shotcut GIMP.GIMP qBittorrent.qBittorrent NickeManarin.ScreenToGif Spotify.Spotify Betaflight.Betaflight-Configurator Ventoy.Ventoy Piriform.CCleaner AntibodySoftware.WizTree CPUID.CPU-Z TechPowerUp.GPU-Z WinSCP.WinSCP TimKosse.FileZilla.Client MoonlightGameStreamingProject.Moonlight LizardByte.Sunshine TrackerSoftware.PDF-XChangeEditor Tailscale.Tailscale
```

### install development tools (one-liner)
```powershell
winget install yt-dlp.yt-dlp GnuWin32.Make MSYS2.MSYS2 cURL.cURL aristocratos.btop4win
```

### install optional system tools (one-liner)
```powershell
winget install Oracle.VirtualBox WireGuard.WireGuard
```

---

# install scoop (only for NirCmd)
### https://scoop.sh/#/
### **Admin not Req.**

### Install NirCmd via scoop (command line utility for Windows)
```powershell
scoop install main/nircmd
```

---

## Application List with Descriptions

### Essential Applications:
- **SpeedCrunch** - Scientific calculator
- **RustDesk** - Remote desktop software
- **Git** - Version control system
- **Windows Terminal** - Modern terminal application
- **AltSnap** - Window management utility
- **Alacritty** - GPU-accelerated terminal emulator
- **Visual C++ Redistributable** - Runtime libraries
- **Yasb** - System information bar
- **Flameshot** - Screenshot tool
- **Flow Launcher** - Application launcher
- **EarTrumpet** - Volume control utility
- **Notepad++** - Text editor
- **qimgv** - Image viewer
- **MPC-HC** - Media player
- **HWMonitor** - Hardware monitoring
- **LocalSend** - File sharing utility
- **Display Driver Uninstaller** - GPU driver removal tool
- **Brave** - Privacy-focused web browser
- **PowerToys** - Windows utilities
- **Fastfetch** - System information tool
- **7-Zip** - File archiver
- **FLAC** - Audio codec
- **GlazeWM** - Tiling window manager

### Gaming Applications:
- **Steam** - Game distribution platform
- **itch.io** - Indie game platform
- **GOG Galaxy** - DRM-free game launcher
- **Prism Launcher** - Minecraft launcher
- **r2modman** - Risk of Rain 2 mod manager
- **Epic Games Launcher** - Epic Games store

### Optional Applications:
- **Feishin** - Music streaming client
- **Discord** - Communication platform
- **OBS Studio** - Streaming/recording software
- **Mullvad Browser** - Privacy-focused browser
- **Everything** - File search utility
- **Okular** - Document viewer
- **Cura** - 3D printing slicer
- **Signal** - Encrypted messaging
- **KeePassXC** - Password manager
- **Bitwarden** - Password manager
- **Krita** - Digital painting software
- **Shotcut** - Video editor
- **GIMP** - Image editor
- **qBittorrent** - BitTorrent client
- **ScreenToGif** - Screen recorder to GIF
- **Spotify** - Music streaming
- **Betaflight Configurator** - Drone firmware tool
- **Ventoy** - Bootable USB creator
- **CCleaner** - System cleaner
- **WizTree** - Disk space analyzer
- **CPU-Z** - CPU information tool
- **GPU-Z** - GPU information tool
- **WinSCP** - SFTP/SCP client
- **FileZilla** - FTP client
- **Moonlight** - Game streaming client
- **Sunshine** - Game streaming server
- **PDF-XChange Editor** - PDF editor
- **Tailscale** - VPN mesh network

### Development Tools:
- **yt-dlp** - Video downloader
- **Make** - Build automation tool
- **MSYS2** - Unix-like environment
- **cURL** - Data transfer tool
- **btop** - System monitor

### Optional System Tools:
- **VirtualBox** - Virtualization platform
- **WireGuard** - VPN software

### update all winget apps
```powershell
winget upgrade --all
```

---

### Install `Teams` example (**Using WinGet**)
```powershell
winget install Microsoft.Teams
```

---
### Install OBS DistroAV (OBS NDI)

DistroAV Plugin | Releases -> [Link](https://github.com/DistroAV/DistroAV/releases)

### Install NDI Runtime for OBS
```powershell
winget install --exact --id NDI.NDIRuntime
```

Need BLUR? -> [obs-composite-blur Plugin | Releases](https://github.com/FiniteSingularity/obs-composite-blur/releases) by [FiniteSingularity](https://github.com/FiniteSingularity)

Need CROPPING? -> [obs-advanced-masks Plugin | Releases](https://github.com/FiniteSingularity/obs-advanced-masks/releases) by [FiniteSingularity](https://github.com/FiniteSingularity)

---

# microphone suppression (requires Equalizer_APO)
https://github.com/werman/noise-suppression-for-voice/releases

### Install APO
```powershell
winget install EqualizerAPO.EqualizerAPO
```

[How to install werman noise-suppression!](https://github.com/dillacorn/win-glaze-dots/blob/main/mic_suppression_apo.md)

---

# applications not available in official repos
- [DistroAV | aka OBS-NDI](https://github.com/DistroAV/DistroAV)
- [AutoDesk Software](https://manage.autodesk.com/login?t=/products)
- [tinywhoopgo](https://tinywhoopgo.com/)

---

# Graphics Card Drivers
- [Advanced Micro Devices (AMD GPU) Drivers](https://www.amd.com/en/support/download/drivers.html)
- [Nvidia GPU Drivers](https://www.nvidia.com/en-us/drivers/)

- [Intel ARC GPU Drivers](https://www.intel.com/content/www/us/en/download/785597/intel-arc-iris-xe-graphics-windows.html)

