Notes From Repo: https://github.com/dillacorn/win-glaze-dots

---

### Reason why I don't primarily use scoop?

**Safety:** Chocolatey is safer as applications are tested in a virtual environment and undergo manual and automated checks before distribution.

**Trust:** Scoop downloads directly from the repo without middleman protection, requiring full trust that updates are free of intentional or unintentional malicious code.

**Balance:** Scoop is the most up-to-date, Winget is often outdated, but Chocolatey balances timely updates with robust security checks.

---

# install Chocolatey
### https://chocolatey.org/install
### **Run as Admin** ~ **Use "sudo" before command**

---

### install GlazeWM & Zebar
```powershell
sudo choco install vcredist140 glazewm zebar -y
```

### install Essentials
```powershell
sudo choco install git flow-launcher flameshot powertoys eartrumpet winspy wingetui fastfetch micro nircmd 7zip notepadplusplus everything qimgv mpv -y
```

### install additional applications
```powershell
sudo choco install vmware-workstation-player malwarebytes okular cura-new telegram ungoogled-chromium librewolf keepassxc bitwarden teamviewer krita shotcut gimp qbittorrent screentogif spotify betaflight-configurator obs-studio files flac yt-dlp -y
```

### install development tools
```powershell
sudo choco install make mingw curl steam -y
```

### install troubleshooting tools and optimization utilities
```powershell
sudo choco install ddu ventoy hwmonitor ccleaner wiztree cpu-z gpu-z -y
```

### install networking utilities
```powershell
sudo choco install mullvad-app wireguard winscp filezilla localsend moonlight sunshine obs-ndi -y
```

### install game launchers
```powershell
sudo choco install steam epicgameslauncher itch goggalaxy prismlauncher -y
```

### AMD Ryzen Chipset Drivers
```powershell
sudo choco install amd-ryzen-chipset -y
```

### install directory-opus (license required) 
```powershell
sudo choco install directoryopus -y
```

### install PDF-XChange Editor (alternativley use "okular"[**I use**] or "PDFGear")
```powershell
sudo choco install pdfxchangeeditor -y
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
scoop install extras/altsnap alacritty vcredist zebar
```

### install optional "extras" repo applications
```powershell
scoop install extras/feishin logitech-omm msiafterburner rtss vesktop
```

### add my unofficial scoop "glazewm.json" bucket
```powershell
scoop bucket add dillacorn https://github.com/dillacorn/win-glaze-dots
```

### install glazewm-np using scoop
#### `installed in %ProgramFiles% so uiACCESS is avaliable!`
```powershell
scoop install dillacorn/glazewm-np
```

### install glazewm using scoop
#### `not installed in %ProgramFiles% so uiACCESS is unavaliable`
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

# applications not avaliable in official repos
- [AutoDesk Software](https://manage.autodesk.com/login?t=/products)
- [tinywhoopgo](https://tinywhoopgo.com/),

# Graphics Card Drivers
- [Advanced Micro Devices (AMD GPU) Drivers](https://www.amd.com/en/support/download/drivers.html)
- [Nvidia GPU Drivers](https://www.nvidia.com/en-us/drivers/) or ```choco install geforce-game-ready-driver -y``` (For gaming GPU) or ```choco install nvidia-display-driver -y``` (For Standard GPU)
- [Intel ARC GPU Drivers](https://www.intel.com/content/www/us/en/download/785597/intel-arc-iris-xe-graphics-windows.html)
