### Navigate to user home directory
```powershell
cd ~
```

### Clone Repo (Using Alacritty)
```powershell
git clone https://github.com/dillacorn/win-glaze-dots
```
### Recursive copy directories
#### Copy and overwrite `.glazr` folder dots
```powershell
Copy-Item -Recurse -Path "$env:UserProfile\win-glaze-dots\%UserProfile%\.glzr" -Destination "$env:UserProfile" -Force
```
#### Copy and overwrite `scripts` folder
```powershell
Copy-Item -Recurse -Path "$env:UserProfile\win-glaze-dots\%UserProfile%\scripts" -Destination "$env:UserProfile" -Force
```
#### Copy and overwrite `alacritty` dots
```powershell
Copy-Item -Recurse -Path "$env:UserProfile\win-glaze-dots\%AppData%\Roaming\alacritty" -Destination "$env:AppData\Roaming" -Force
```
#### Copy and overwrite `flameshot` dots
```powershell
Copy-Item -Recurse -Path "$env:UserProfile\win-glaze-dots\%AppData%\Roaming\flameshot" -Destination "$env:AppData\Roaming" -Force
```