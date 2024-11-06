### check restrictions
Get-ExecutionPolicy

### unlock restrictions
Set-ExecutionPolicy AllSigned

### check restrictions again to make sure it's AllSigned
Get-ExecutionPolicy

### run provided execution script by Chocolatey
link: https://chocolatey.org/install

Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

### My chocolatey applications
choco install steam ungoogled-chromium librewolf mullvad-app wireguard alacritty 7zip.install notepadplusplus.install vlc malwarebytes ccleaner filezilla gimp winscp.install spotify putty amd-ryzen-chipset everything audacity vmware-tools imagemagick.app qbittorrent bitwarden samsung-magician telegram obs-studio obs-ndi ventoy ddu sunshine moonlight-qt.install flameshot Shotcut itch hwmonitor vmware-workstation-player qimgv localsend micro auto-dark-mode okular amd-ryzen-master git mpv files foobar2000 flac altsnap microsoft-teams.install powertoys -y

### Applications not provided by Chocolatey
Discord, Vencord (mod), onboard memory manager (logitech), tinywhoopgo, 