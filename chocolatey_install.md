### check restrictions
`Get-ExecutionPolicy`

### unlock restrictions
`Set-ExecutionPolicy AllSigned`

### check restrictions again to make sure it's AllSigned
`Get-ExecutionPolicy`

### run provided execution script by Chocolatey
link: https://chocolatey.org/install

`Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))`

### (main) chocolatey applications
`choco install steam ungoogled-chromium librewolf alacritty 7zip.install notepadplusplus.install ccleaner krita spotify audacity imagemagick.app qbittorrent telegram obs-studio obs-ndi ddu moonlight-qt.install flameshot Shotcut itch hwmonitor qimgv localsend micro okular git mpv foobar2000 flac flow-launcher eartrumpet -y`

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

### Applications not provided by Chocolatey (manual install)
Discord, Vencord (mod), onboard memory manager (logitech), AltSnap (no maintaner on choco), 

### Gaming apps
tinywhoopgo, 
