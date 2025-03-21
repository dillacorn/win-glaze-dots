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

### install apps not available (or don't work) in scoop
```powershell
sudo choco install malwarebytes speedcrunch rustdesk -y
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

### Install git (needed for adding additional repositories)
```powershell
scoop install git
```

### add scoop additional repositories
```powershell
scoop bucket add extras
```
```powershell
scoop bucket add games
```
```powershell
scoop bucket add nonportable
```

### install essential "extras" repo applications
```powershell
scoop install extras/altsnap alacritty vcredist zebar flameshot flow-launcher eartrumpet notepadplusplus qimgv mpv hwmonitor localsend ddu ungoogled-chromium cru winspy powertoys
```

### install essential "main" repo applications
```powershell
scoop install main/fastfetch micro nircmd 7zip flac
```

### install optional "games" repo applications
```powershell
scoop install games/steam itch goggalaxy prismlauncher r2modman
```
```powershell
sudo scoop install games/epic-games-launcher
```

### install optional "extras" repo applications
```powershell
scoop install extras/feishin logitech-omm vesktop obs-studio mullvad-browser git everything okular cura telegram keepassxc bitwarden krita shotcut gimp qbittorrent screentogif spotify betaflight-configurator ventoy ccleaner wiztree cpu-z gpu-z winscp filezilla moonlight sunshine pdf-xchange-editor
```
#### Some scripts require sudo.
```powershell
sudo scoop install extras/tailscale
```

### install optional "main" repo applications
```powershell
scoop install main/yt-dlp make mingw curl btop
```

### install optional "nonportable" repo applications
```powershell
sudo scoop install nonportable/virtualbox-np wireguard-np
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

### update all scoop apps
```powershell
scoop update *
```

---

### Need WinGet on LTSC?
```powershell
scoop install main/winget
```
Browse the winget repo ->
**https://winget.run/**

### Install `Teams` example (**Using WinGet**)
*(I have difficulty with choco and scoop solutions for Teams.. so winget is a must here)*
```powershell
winget install -e --id Microsoft.Teams
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
sudo scoop install nonportable/equalizer-apo-np
```

[How to install werman noise-suppression!](https://github.com/dillacorn/win-glaze-dots/blob/main/mic_suppression_apo.md)

---

# signal-cli (scoop+choco) install directions

### signal-cli uses javaruntime.
```powershell
sudo choco install javaruntime -y
```

### run my script to set JAVA_HOME environment variable for current user.
[xx]()

### install signal-cli with scoop
```powershell
scoop install main/signal-cli
```

### follow usage signal-cli guide for setup
https://github.com/AsamK/signal-cli?tab=readme-ov-file#usage

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
