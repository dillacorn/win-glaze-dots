Notes From Repo: https://github.com/dillacorn/win-glaze-dots

# Install Chocolatey
https://chocolatey.org/install

---

### Install GlazeWM and Zebar
```choco_install
choco install vcredist140 glazewm zebar -y
```

### Install vmware-player
```choco_install
choco install vmware-workstation-player -y
```

### Install obs-studio and (ndi-plugin) DistroAV
```choco_install
choco install obs-studio obs-ndi -y
```

---

# Install scoop
https://scoop.sh/#/

---

### Install `git` to add bucket repos
```scoop_install_git
scoop install git
```

### install ALL of my scoop "main" repo applications
```scoop_install
scoop install main/git make mingw curl fastfetch micro nircmd flac 7zip
```

---

### Add scoop "extras" repository
```scoop_add_extras
scoop bucket add extras
```

### install essential "extras" repo applications
```scoop_install
scoop install extras/altsnap flow-launcher alacritty flameshot powertoys eartrumpet winspy notepadplusplus
```

### install ALL of my scoop "extras" repo applications
```scoop_install
scoop install extras/altsnap cura logitech-omm vesktop ungoogled-chromium librewolf flow-launcher ddu keepassxc bitwarden powertoys flameshot microsoft-teams teamviewer sunshine moonlight alacritty ventoy everything mpv vlc krita hwmonitor qimgv winspy filezilla eartrumpet winscp okular shotcut gimp qbittorrent localsend notepadplusplus ccleaner screentogif spotify betaflight-configurator
```

---

### Add scoop "games" repo repository
```scoop_add_games
scoop bucket add games
```

### install ALL of my scoop "games" repo applications
```
scoop install games/steam epic-games-launcher itch
```

---

### Add scoop "nonportable" repository
```scoop_add_nonportable
scoop bucket add nonportable
```

### install ALL of my scoop "nonportable" repo applications
```
scoop install nonportable/wireguard-np mullvadvpn-np files-np
```

---

### butterytaskbar2 link: (used to )
https://github.com/LuisThiamNye/ButteryTaskbar2

---

### Gaming apps not avaliable in repositories
tinywhoopgo, 
