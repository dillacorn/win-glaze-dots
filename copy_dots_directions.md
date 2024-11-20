### Clone Repo (Using Alacritty)
```powershell
git clone https://github.com/dillacorn/win-glaze-dots
```
### Recursive copy directories
#### Copy `.glazr` folder to the home directory
```powershell
Copy-Item -Recurse -Path "$env:UserProfile\win-glaze-dots\UserProfile\.glzr" -Destination "$env:UserProfile" -Force
```
#### Copy `scripts` folder to the home directory
```powershell
Copy-Item -Recurse -Path "$env:UserProfile\win-glaze-dots\UserProfile\scripts" -Destination "$env:UserProfile" -Force
```
#### Copy `alacritty` folder to the home directory
```powershell
Copy-Item -Recurse -Path "$env:UserProfile\win-glaze-dots\AppData\Roaming\alacritty" -Destination "$env:AppData\Roaming" -Force
```
#### Copy `flameshot` folder to the home directory
```powershell
Copy-Item -Recurse -Path "$env:UserProfile\win-glaze-dots\AppData\Roaming\flameshot" -Destination "$env:AppData\Roaming" -Force
```