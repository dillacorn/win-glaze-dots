Notes From Repo: https://github.com/dillacorn/win-glaze-dots

# Install Chocolatey

### check restrictions
`Get-ExecutionPolicy`

### unlock restrictions
`Set-ExecutionPolicy AllSigned`

if `RemoteSigned`

then `Set-ExecutionPolicy AllSigned -Scope CurrentUser`

### check restrictions again to make sure it's AllSigned
`Get-ExecutionPolicy`

### run provided execution script by Chocolatey
link: https://chocolatey.org/install

---

### (main) chocolatey applications
```choco_install
choco install steam ungoogled-chromium librewolf 7zip.install notepadplusplus.install ccleaner krita spotify audacity imagemagick.app qbittorrent telegram obs-studio obs-ndi ddu moonlight-qt.install flameshot screentogif Shotcut itch hwmonitor qimgv localsend okular mpv foobar2000 flac flow-launcher eartrumpet winspy -y
```

### (optional-cli) chocolatey applications
```choco_install
choco install alacritty fastfetch micro -y
```

### (optional-additional) chocolatey applications
```choco_install
choco install microsoft-teams-new-bootstrapper teamviewer directoryopus vlc gimp putty everything ventoy audiorelay filezilla winscp.install files -y
```

### (optional-powertoys) applications (powertoys only functions if explorer.exe is not killed)
```choco_install
choco install powertoys -y
```

### (optional-3D_Printing) chocolatey applications
```choco_install
choco install cura-new -y`
```

### (optional-security_VPN) chocolatey applications
```choco_install
choco install bitwarden keepassxc wireguard mullvad-app malwarebytes -y
```

### (optional-virtual_machine_tool) chocolatey applications
```choco_install
choco install vmware-tools vmware-workstation-player -y
```

### (optional-hardware_specific) chocolatey applications
```choco_install
choco install amd-ryzen-chipset amd-ryzen-master sunshine samsung-magician -y
```

### (optional-applet) chocolatey applications (if you're killing explorer.exe may not need/want these)
```choco_install
choco install auto-dark-mode -y
```

### (optional-dev_cli_tools) chocolatey applications
```choco_install
choco install git make mingw curl -y
```

---

### butterytaskbar2 link: (used to )
https://github.com/LuisThiamNye/ButteryTaskbar2

---

### Applications not provided by Chocolatey (manual install)
Discord, Vencord (mod), onboard memory manager (logitech) ~ (on scoop), AltSnap (1.64 and newer), feishin (on scoop), 

---

### Gaming apps
tinywhoopgo, 

---

### AltSnap Build From source for Linux-wm Alt resize/move behavior!

or install pre-release! -> https://github.com/RamonUnch/AltSnap/releases

(need `git`, `make` and `mingw`!)
open `powershell` or `alacritty` with elevated privledges!

```commands
cd ~/Downloads
git clone https://github.com/RamonUnch/AltSnap
cd AltSnap
```

Follow build directions for your CPU hardware ("x86_64 GCC")
https://github.com/RamonUnch/AltSnap?tab=readme-ov-file#build

```commands
make -fMakefileX64
```

AltSnap successfully built!
Now move AltSnap to correct directory

```commands
mv ~/Downloads/AltSnap C:\Program Files\AltSnap
```

Run .exe and configure AltSnap appropriatly

