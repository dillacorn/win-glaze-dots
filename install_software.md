Notes From Repo: https://github.com/dillacorn/win-glaze-dots

# Install Chocolatey
https://chocolatey.org/install

---

### Install GlazeWM and Zebar (GlazeWM not up-to-date on scoop)
```choco_install
choco install glazewm zebar -y
```

---

# Install scoop
https://scoop.sh/#/

---

### Add scoop "extras" repository
```scoop_add_extras
scoop bucket add extras
```

### install essential "extra" applications
```scoop_install
scoop install extras/altsnap flow-launcher alacritty flameshot powertoys eartrumpet winspy notepadplusplus
```

### install ALL of my scoop "extra" applications
```scoop_install
scoop install extras/altsnap cura logitech-omm vesktop ungoogled-chromium librewolf flow-launcher ddu keepassxc bitwarden powertoys flameshot microsoft-teams teamviewer sunshine moonlight alacritty ventoy everything mpv vlc krita hwmonitor qimgv winspy filezilla eartrumpet winscp okular shotcut gimp qbittorrent obs-studio obs-plugin-droidcam localsend notepadplusplus ccleaner screentogif spotify betaflight-configurator virt-viewer
```

---

### Add scoop "main" repository
```scoop_add_main
scoop bucket add main
```

### install ALL of my scoop "main" applications
```scoop_install
scoop install main/git make mingw curl fastfetch micro nircmd flac 7zip qemu
```

---

### Add scoop "games" repository
```scoop_add_games
scoop bucket add games
```

### install ALL of my scoop "games" applications
```
scoop install games/steam epic-games-launcher itch
```

---

### Add scoop "nonportable" repository
```scoop_add_nonportable
scoop bucket add nonportable
```

### install ALL of my scoop "nonportable" applications
```
scoop install nonportable/wireguard-np mullvadvpn-np files-np
```

---

### butterytaskbar2 link: (used to )
https://github.com/LuisThiamNye/ButteryTaskbar2

---

### Gaming apps not avaliable in repositories
tinywhoopgo, 