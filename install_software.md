Notes From Repo: https://github.com/dillacorn/win-glaze-dots

### Reason why I don't use winget? 

- Packages regularly outdated...

---

### Reason why I don't primarily use scoop anymore?

- Chocolatey is a safer due to applications needing to be ran in a test environment and manually/automatically tested before distribution.
- With scoop you're essentially putting your full trust that the latest update of a piece of software may not contain a virus or malicious code either intentional or unintentional... with scoop you're downloading directly from the repo with no middle-man protection.
- If you want to be absolutley certain the application is safe Chocolatey is undoubtedly the better option.
- Packages are pretty up-to-date on Chocolatey as well so it's not much of any issue using it over scoop.

---

# install Chocolatey
### https://chocolatey.org/install
### UAC required

---

### install GlazeWM & Zebar
```powershell
choco install vcredist140 git glazewm zebar flow-launcher gsudo alacritty flameshot powertoys eartrumpet winspy wingetui -y
```

### install other choco applications
```powershell
choco install vmware-workstation-player malwarebytes okular make mingw curl fastfetch micro nircmd flac 7zip notepadplusplus cura-new telegram dorion ungoogled-chromium librewolf ddu keepassxc bitwarden teamviewer sunshine moonlight ventoy everything mpv vlc krita hwmonitor qimgv filezilla winscp shotcut gimp qbittorrent localsend ccleaner screentogif spotify betaflight-configurator obs-studio obs-ndi steam epicgameslauncher itch wireguard mullvad-app files -y
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
### UAC not required

---

### add scoop "extras" repository
```powershell
scoop bucket add extras
```

### install essential "extras" repo applications
```powershell
scoop install extras/altsnap
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
[butterytaskbar2](https://github.com/LuisThiamNye/ButteryTaskbar2), [AutoDesk Software](https://manage.autodesk.com/login?t=/products), [tinywhoopgo](https://tinywhoopgo.com/),
