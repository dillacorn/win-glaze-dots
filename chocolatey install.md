### check restrictions
`Get-ExecutionPolicy`

### unlock restrictions
`Set-ExecutionPolicy AllSigned`

### check restrictions again to make sure it's AllSigned
`Get-ExecutionPolicy`

### run provided execution script by Chocolatey
link: https://chocolatey.org/install

`Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))`

### my main chocolatey applications
`choco install steam ungoogled-chromium librewolf mullvad-app wireguard alacritty 7zip.install notepadplusplus.install malwarebytes ccleaner filezilla gimp winscp.install spotify audacity vmware-tools imagemagick.app qbittorrent bitwarden telegram obs-studio obs-ndi ddu moonlight-qt.install flameshot Shotcut itch hwmonitor vmware-workstation-player qimgv localsend micro okular git mpv foobar2000 flac altsnap flow-launcher -y`

### optional chocolatey applications
`choco install powertoys microsoft-teams-new-bootstrapper directoryopus vlc putty everything amd-ryzen-chipset amd-ryzen-master sunshine samsung-magician ventoy auto-dark-mode files winspy -y`

### Applications not provided by Chocolatey (manual install)
Discord, Vencord (mod), onboard memory manager (logitech), tinywhoopgo, 
