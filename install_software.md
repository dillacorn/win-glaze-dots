# Package Management with Winget

---

### install all essential applications (one-liner)
```powershell
winget install SpeedCrunch.SpeedCrunch Git.Git Microsoft.WindowsTerminal AltSnap.AltSnap Microsoft.VCRedist.2015+.x64 AmN.yasb Flameshot.Flameshot Flow-Launcher.Flow-Launcher File-New-Project.EarTrumpet Notepad++.Notepad++ zyedidia.micro sxyazi.yazi qimgv.qimgv mpv.net LocalSend.LocalSend DisplayDriverUninstaller.DisplayDriverUninstaller Brave.Brave Microsoft.PowerToys Fastfetch-cli.Fastfetch 7zip.7zip Gyan.FFmpeg jqlang.jq oschwartz10612.Poppler sharkdp.fd BurntSushi.ripgrep.MSVC junegunn.fzf ajeetdsouza.zoxide ImageMagick.ImageMagick hpjansson.Chafa xiph.flac glzr-io.glazewm karlstav.cava DEVCOM.JetBrainsMonoNerdFont WinsiderSS.SystemInformer
```

### install gaming applications (one-liner)
```powershell
winget install Valve.Steam itch.itch GOG.Galaxy PrismLauncher.PrismLauncher ebkr.r2modman EpicGames.EpicGamesLauncher
```

### install optional applications (one-liner)
```powershell
winget install alexx2000.DoubleCommander RustDesk.RustDesk CPUID.HWMonitor jeffvli.Feishin Discord.Discord OBSProject.OBSStudio MullvadVPN.MullvadBrowser voidtools.Everything KDE.Okular Ultimaker.Cura OpenWhisperSystems.Signal KeePassXCTeam.KeePassXC Bitwarden.Bitwarden KDE.Krita Meltytech.Shotcut GIMP.GIMP qBittorrent.qBittorrent NickeManarin.ScreenToGif Spotify.Spotify Betaflight.Betaflight-Configurator Ventoy.Ventoy Piriform.CCleaner AntibodySoftware.WizTree CPUID.CPU-Z TechPowerUp.GPU-Z WinSCP.WinSCP TimKosse.FileZilla.Client MoonlightGameStreamingProject.Moonlight LizardByte.Sunshine TrackerSoftware.PDF-XChangeEditor Tailscale.Tailscale Open-Shell.Open-Shell-Menu RamenSoftware.Windhawk Microsoft.Sysinterals.ProcessExplorer
```

### install development tools (one-liner)
```powershell
winget install yt-dlp.yt-dlp GnuWin32.Make MSYS2.MSYS2 cURL.cURL aristocratos.btop4win
```

### Virtualization (one-liner) - https://github.com/dillacorn/win-glaze-dots/blob/main/qemu-linux-guide.md
```powershell
winget install SoftwareFreedomConservancy.QEMU SoftwareFreedomConservancy.QEMUGuestAgent
```

---

## Application List with Descriptions

### Essential Applications:
- **SpeedCrunch** - Scientific calculator
- **Git** - Version control system; also provides `file.exe` used by Yazi for MIME detection
- **Windows Terminal** - Default terminal application
- **Yazi** - Terminal file manager; configured to use Micro for text files and qimgv for images
- **Micro** - Terminal text editor
- **AltSnap** - Window management utility
- **Visual C++ Redistributable** - Runtime libraries
- **Flameshot** - Screenshot tool
- **Flow Launcher** - Application launcher
- **EarTrumpet** - Volume control utility
- **Notepad++** - Text editor
- **qimgv** - Image viewer
- **mpv** - Media player
- **LocalSend** - File sharing utility
- **Display Driver Uninstaller** - GPU driver removal tool
- **Brave** - Privacy-focused web browser
- **PowerToys** - Windows utilities
- **Fastfetch** - System information tool
- **7-Zip** - File archiver and Yazi archive helper
- **FFmpeg** - Media preview helper used by Yazi
- **jq** - JSON helper used by Yazi
- **Poppler** - PDF preview helper used by Yazi
- **fd** - Fast file search helper used by Yazi
- **ripgrep** - Text search helper used by Yazi
- **fzf** - Fuzzy finder helper used by Yazi
- **zoxide** - Directory navigation helper used by Yazi
- **ImageMagick** - Image conversion/preview helper used by Yazi
- **Chafa** - Fallback terminal image renderer used by Yazi when native graphics are unavailable
- **FLAC** - Audio codec
- **GlazeWM** - Tiling window manager
- **JetBrainsMonoNerdFont** - Font for yasb bar
- **Yasb** - System information bar
- **System Informer** - Replaces task manager (need more functionality? - install process explorer, slightly heavier alternative)

### Gaming Applications:
- **Steam** - Game distribution platform
- **itch.io** - Indie game platform
- **GOG Galaxy** - DRM-free game launcher
- **Prism Launcher** - Minecraft launcher
- **r2modman** - Risk of Rain 2 mod manager
- **Epic Games Launcher** - Epic Games store

### Optional Applications:
- **Double Commander** - File Browser
- **RustDesk** - Remote desktop software
- **HWMonitor** - Hardware monitoring
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
- **Open-Shell** - Old Style Window Pop-out Menu
- **Windhawk** - Customize Windows Internally
- **Process Explorer** - Replaces Task Manager (little heavier than System Informer)

### Development Tools:
- **yt-dlp** - Video downloader
- **Make** - Build automation tool
- **MSYS2** - Unix-like environment
- **cURL** - Data transfer tool
- **btop** - System monitor

### Virtualization: https://github.com/dillacorn/win-glaze-dots/blob/main/qemu-arch-scoop-guide.md
- **QEMU** - Virtualization platform
- **QEMU guest agent** - Virtualization Guest Agent

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
### Install DistroAV (NDI Runtime) for OBS
```powershell
winget install DistroAV.DistroAV
```

Need BLUR? -> [obs-composite-blur Plugin | Releases](https://github.com/FiniteSingularity/obs-composite-blur/releases) by [FiniteSingularity](https://github.com/FiniteSingularity)

Need CROPPING? -> [obs-advanced-masks Plugin | Releases](https://github.com/FiniteSingularity/obs-advanced-masks/releases) by [FiniteSingularity](https://github.com/FiniteSingularity)

---

# microphone suppression (requires Equalizer_APO)
https://github.com/werman/noise-suppression-for-voice/releases
