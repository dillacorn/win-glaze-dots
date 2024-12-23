### [clone_&_copy_dots.bat](https://github.com/dillacorn/win-glaze-dots/tree/main/scripts(UAC%20Req.)/clone_&_copy_dots.bat) to automate the process ~ (UAC Req.)

### Navigate to user home directory
```powershell
cd ~
```
### Clone Repo
```powershell
git clone https://github.com/dillacorn/win-glaze-dots
```
### Recursive copy dotfiles
#### Copy and overwrite `.glazr` folder dots
```powershell
Copy-Item -Recurse -Path "$env:UserProfile\win-glaze-dots\UserProfile\.glzr" -Destination "$env:UserProfile" -Force
```
#### Copy and overwrite `scripts` folder
```powershell
Copy-Item -Recurse -Path "$env:UserProfile\win-glaze-dots\UserProfile\scripts" -Destination "$env:UserProfile" -Force
```
#### Copy and overwrite `alacritty` dots
```powershell
Copy-Item -Recurse -Path "$env:UserProfile\win-glaze-dots\AppData\Roaming\alacritty" -Destination "$env:AppData\Roaming" -Force
```
#### Copy and overwrite `flameshot` dots
```powershell
Copy-Item -Recurse -Path "$env:UserProfile\win-glaze-dots\AppData\Roaming\flameshot" -Destination "$env:AppData\Roaming" -Force
```
### Copy scoop dotfiles
#### Copy and overwrite `altsnap` dots
```powershell
Copy-Item -Path "$env:UserProfile\win-glaze-dots\UserProfile\scoop\apps\altsnap\1.64\AltSnap.ini" -Destination "$env:UserProfile\scoop\apps\altsnap\1.64\AltSnap.ini" -Force
```
#### Copy and overwrite `btop` dots
```powershell
Copy-Item -Path "$env:UserProfile\win-glaze-dots\UserProfile\scoop\apps\btop\1.0.4\btop.conf" -Destination "$env:UserProfile\scoop\apps\btop\1.0.4\btop.conf" -Force
```