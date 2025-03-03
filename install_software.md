Notes From Repo: https://github.com/dillacorn/win-glaze-dots

---

# Package Management with Scoop & Chocolatey

## Overview of My Preferences

I now primarily use Scoop, but here are some points to keep in mind regarding different package managers:

### Safety
- **Chocolatey** is safer because applications are tested in a virtual environment and undergo manual and automated checks before distribution.

### Trust
- **Scoop** downloads directly from the repo without middleman protection, meaning you need to fully trust that updates are free of intentional or unintentional malicious code.

### Balance
- **Scoop** is the most up-to-date, while **Chocolatey** balances timely updates with robust security checks.

### Philosophy
- I don’t use WinGet because I prefer my package manager to have full control over what version of the software is installed and managed. WinGet often installs older versions of software, and, more importantly, it allows applications to update themselves automatically after installation via their internal update mechanisms. This can lead to inconsistent versions or unwanted updates, which I want to avoid. I prefer using a package manager like Scoop or Chocolatey, where the package manager controls updates, ensuring more predictable and consistent version management.

### Conclusion on using scoop over chocolatey and WinGet primarily
That being said, I now prefer Scoop over Chocolatey and will continue to use it. The Scoop community thoroughly reviews each script, and every package undergoes a manual review before being approved for release. Additionally, I appreciate how Scoop installs software in %USERPROFILE% folders, which avoids UAC by nature for applications that don't inherently need it. For applications that require elevated permissions, they can either be installed in ProgramFiles or prompted for elevation as needed.

---

# install Chocolatey
### https://chocolatey.org/install
### **Run as Admin** ~ **Use "sudo" before command**

---

### install apps not available in scoop
```powershell
sudo choco install malwarebytes -y
```

### AMD Ryzen Chipset Drivers
```powershell
sudo choco install amd-ryzen-chipset -y
```

### install directory-opus (license required) 
```powershell
sudo choco install directoryopus -y
```

### update all chocolatey apps
```powershell
sudo choco upgrade all -y
```

---

# install scoop
### https://scoop.sh/#/
### **Admin not Req.**

---

### add scoop "extras" repository
```powershell
scoop bucket add extras
```

### install essential "extras" repo applications
```powershell
scoop install extras/altsnap alacritty vcredist zebar flameshot flow-launcher eartrumpet notepadplusplus qimgv mpv hwmonitor localsend ddu ungoogled-chromium cru winspy
```

### install essential "nonportable" repo applications
```powershell
scoop install extras/powertoys-np
```

### install essential "main" repo applications
```powershell
scoop install main/fastfetch micro nircmd 7zip flac
```

### install optional "games" repo applications
```powershell
scoop install games/steam epic-games-launcher itch goggalaxy prismlauncher
```

### install optional "extras" repo applications
```powershell
scoop install extras/feishin logitech-omm msiafterburner rtss vesktop obs-studio rustdesk mullvad-browser git everything speedcrunch okular cura telegram keepassxc bitwarden krita shotcut gimp qbittorrent screentogif spotify betaflight-configurator ventoy tailscale ccleaner wiztree cpu-z gpu-z winscp filezilla moonlight sunshine pdf-xchange-editor
```

### install optional "nonportable" repo applications
```powershell
scoop install nonportable/vmware-workstation-player-np files-np mullvadvpn-np wireguard-np
```

### install optional "main" repo applications
```powershell
scoop install main/yt-dlp make mingw curl
```

### add my unofficial scoop bucket -> I recommend `glazewm-np` install for `UIAccess`
```powershell
scoop bucket add dillacorn https://github.com/dillacorn/win-glaze-dots
```

### install glazewm-np using scoop `Recommended`
#### `installed in %ProgramFiles% so UIAccess is available!`
```powershell
scoop install dillacorn/glazewm-np
```

### install glazewm using scoop
#### `not installed in %ProgramFiles% so UIAccess is unavailable`
```powershell
scoop install dillacorn/glazewm
```

### install btop
```powershell
scoop install main/btop
```

### add optional scoop "games" repository
```powershell
scoop bucket add games
```

### install r2modman
```powershell
scoop install games/r2modman
```

### update all scoop apps
```powershell
scoop update *
```

---

# microphone suppression (requires Equalizer_APO)
https://github.com/werman/noise-suppression-for-voice/releases

### Install APO
```powershell
scoop install nonportable/equalizer-apo-np
```

[How to install werman noise-suppression!](https://github.com/dillacorn/win-glaze-dots/blob/main/mic_suppression_apo.md)

---

# applications not available in official repos
- [DistroAV | aka OBS-NDI](https://github.com/DistroAV/DistroAV)
- [AutoDesk Software](https://manage.autodesk.com/login?t=/products)
- [tinywhoopgo](https://tinywhoopgo.com/),

---

# Graphics Card Drivers
- [Advanced Micro Devices (AMD GPU) Drivers](https://www.amd.com/en/support/download/drivers.html)
- [Nvidia GPU Drivers](https://www.nvidia.com/en-us/drivers/) or ```choco install geforce-game-ready-driver -y``` (For gaming GPU) or ```choco install nvidia-display-driver -y``` (For Standard GPU)
- [Intel ARC GPU Drivers](https://www.intel.com/content/www/us/en/download/785597/intel-arc-iris-xe-graphics-windows.html)
