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

### (main) chocolatey applications
`choco install steam ungoogled-chromium librewolf alacritty 7zip.install notepadplusplus.install ccleaner krita spotify audacity imagemagick.app qbittorrent telegram obs-studio obs-ndi ddu moonlight-qt.install flameshot Shotcut itch hwmonitor qimgv localsend micro okular mpv foobar2000 flac flow-launcher eartrumpet -y`

### (optional-additional) chocolatey applications
`choco install microsoft-teams-new-bootstrapper teamviewer directoryopus vlc gimp putty everything ventoy audiorelay filezilla winscp.install files winspy -y`

### (optional-powertoys) applications (powertoys only functions if explorer.exe is not killed)
`choco install powertoys -y`

### (optional-3D_Printing) chocolatey applications
`choco install cura-new -y`

### (optional-security_VPN) chocolatey applications
`choco install bitwarden wireguard mullvad-app malwarebytes -y`

### (optional-virtual_machine_tool) chocolatey applications
`choco install vmware-tools vmware-workstation-player -y`

### (optional-hardware_specific) chocolatey applications
`choco install amd-ryzen-chipset amd-ryzen-master sunshine samsung-magician -y`

### (optional-applet) chocolatey applications (if you're killing explorer.exe may not need/want these)
`choco install auto-dark-mode -y`

### (optional-dev_tools) chocolatey applications
`choco install git make mingw -y`

### butterytaskbar2 link: (used to )
https://github.com/LuisThiamNye/ButteryTaskbar2

### Applications not provided by Chocolatey (manual install)
Discord, Vencord (mod), onboard memory manager (logitech), AltSnap (no maintaner on choco..+Build from Source), 

### Gaming apps
tinywhoopgo, 

### AltSnap Build From source for Linux-wm Alt resize/move behavior!
(need git, make and mingw!)
open powershell or alacritty with elevated privledges!

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

