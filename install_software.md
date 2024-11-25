Notes From Repo: https://github.com/dillacorn/win-glaze-dots

---

### Reason why I don't primarily use scoop?

**Safety:** Chocolatey is safer as applications are tested in a virtual environment and undergo manual and automated checks before distribution.

**Trust:** Scoop downloads directly from the repo without middleman protection, requiring full trust that updates are free of intentional or unintentional malicious code.

**Balance:** Scoop is the most up-to-date, Winget is often outdated, but Chocolatey balances timely updates with robust security checks.

---

# install Chocolatey
### https://chocolatey.org/install
### **Run as Admin**

---

### install GlazeWM & Zebar + Essentials
```powershell
choco install vcredist140 git glazewm zebar flow-launcher gsudo flameshot powertoys eartrumpet winspy wingetui fastfetch micro nircmd 7zip notepadplusplus everything qimgv mpv -y
```

### install additional applications
```powershell
choco install vmware-workstation-player malwarebytes okular cura-new telegram dorion ungoogled-chromium librewolf keepassxc bitwarden teamviewer krita shotcut gimp qbittorrent screentogif spotify betaflight-configurator obs-studio files flac -y
```

### install development tools
```powershell
choco install make mingw curl steam -y
```

### install troubleshooting tools and optimization utilities
```powershell
choco install ddu ventoy hwmonitor ccleaner wiztree cpu-z gpu-z msiafterburner -y
```

### install networking utilities
```powershell
choco install mullvad-app wireguard winscp filezilla localsend moonlight sunshine obs-ndi -y
```

### install game launchers
```powershell
choco install steam epicgameslauncher itch goggalaxy prismlauncher -y
```

### AMD Ryzen Chipset Drivers
```powershell
choco install amd-ryzen-chipset -y
```

### install directory-opus (license required) 
```powershell
choco install directoryopus -y
```

### install PDF-XChange Editor (alternativley use "okular"[**I use**] or "PDFGear")
```powershell
choco install pdfxchangeeditor -y
```

### update all chocolatey apps
```powershell
choco upgrade all -y
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
scoop install extras/altsnap alacritty
```

### install ALL "extras" repo applications
```powershell
scoop install extras/feishin logitech-omm
```

### update all scoop apps
```powershell
scoop update *
```

---

# applications not avaliable in official repos
[AutoDesk Software](https://manage.autodesk.com/login?t=/products), [tinywhoopgo](https://tinywhoopgo.com/),
