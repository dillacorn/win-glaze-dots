Notes From Repo: https://github.com/dillacorn/win-glaze-dots

### Reason why I don't use winget? 

- Packages regularly outdated... 

# install Chocolatey
### https://chocolatey.org/install

---

### install GlazeWM and Zebar
```choco_install
choco install vcredist140 glazewm zebar -y
```

### install other choco applications
```choco_install
choco install vmware-workstation-player obs-studio obs-ndi malwarebytes -y
```

### install directory-opus (license required) 
```choco_install
choco install directoryopus -y
```

---

# install scoop
### https://scoop.sh/#/

---

### install `git` to add bucket repos
```scoop_install_git
scoop install git
```

### install ALL "main" repo applications
```scoop_install
scoop install main/git make mingw curl fastfetch micro nircmd flac 7zip
```

---

### add scoop "extras" repository
```scoop_add_extras
scoop bucket add extras
```

### install essential "extras" repo applications
```scoop_install
scoop install extras/altsnap flow-launcher alacritty flameshot powertoys eartrumpet winspy notepadplusplus
```

### install ALL "extras" repo applications
```scoop_install
scoop install extras/altsnap cura logitech-omm vesktop telegram ungoogled-chromium librewolf flow-launcher ddu keepassxc bitwarden powertoys flameshot microsoft-teams teamviewer sunshine moonlight alacritty ventoy everything mpv vlc feishin krita hwmonitor qimgv irfanview winspy filezilla eartrumpet winscp okular shotcut gimp qbittorrent localsend notepadplusplus ccleaner screentogif spotify betaflight-configurator
```

---

### add scoop "games" repo repository
```scoop_add_games
scoop bucket add games
```

### install ALL "games" repo applications
```
scoop install games/steam epic-games-launcher itch
```

---

### add scoop "nonportable" repository
```scoop_add_nonportable
scoop bucket add nonportable
```

### install ALL "nonportable" repo applications
```
scoop install nonportable/wireguard-np mullvadvpn-np files-np
```

---

### butterytaskbar2: https://github.com/LuisThiamNye/ButteryTaskbar2

---

### applications not avaliable in repos
tinywhoopgo, 
