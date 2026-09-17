### [clone_&_copy_dots.bat](https://github.com/dillacorn/win-glaze-dots/blob/main/scripts/clone_%26_copy_dots.bat) to automate the process

The script copies the Windows Terminal and Yazi configuration and sets `YAZI_FILE_ONE` automatically when Git for Windows is installed in its normal location.

### Navigate to user home directory
```powershell
cd ~
```

### Clone Repo
```powershell
git clone https://github.com/dillacorn/win-glaze-dots
```

### Recursive copy dotfiles

#### Copy and overwrite `.glzr` folder dots
```powershell
Copy-Item -Recurse -Path "$env:UserProfile\win-glaze-dots\UserProfile\.glzr" -Destination "$env:UserProfile" -Force
```

#### Copy and overwrite `scripts` folder
```powershell
Copy-Item -Recurse -Path "$env:UserProfile\win-glaze-dots\UserProfile\scripts" -Destination "$env:UserProfile" -Force
```

#### Copy and overwrite Windows Terminal settings
```powershell
$source = "$env:UserProfile\win-glaze-dots\UserProfile\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$target = "$env:LocalAppData\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
New-Item -ItemType Directory -Force -Path $target | Out-Null
Copy-Item -Path $source -Destination "$target\settings.json" -Force
```

#### Copy and overwrite Yazi dots
```powershell
Copy-Item -Recurse -Path "$env:UserProfile\win-glaze-dots\UserProfile\AppData\Roaming\yazi" -Destination "$env:AppData\Roaming" -Force
```

#### Configure Yazi MIME detection with Git for Windows
```powershell
$gitFile = "$env:ProgramFiles\Git\usr\bin\file.exe"
if (Test-Path $gitFile) {
    [Environment]::SetEnvironmentVariable('YAZI_FILE_ONE', $gitFile, 'User')
}
```

Restart terminals or sign out/reboot after changing user environment variables so newly launched applications inherit them.

#### Copy and overwrite `flameshot` dots
```powershell
Copy-Item -Recurse -Path "$env:UserProfile\win-glaze-dots\UserProfile\AppData\Roaming\flameshot" -Destination "$env:AppData\Roaming" -Force
```

#### Copy and overwrite `double commander` dots
```powershell
Copy-Item -Recurse -Path "$env:UserProfile\win-glaze-dots\UserProfile\AppData\Roaming\doublecmd" -Destination "$env:AppData\Roaming" -Force
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

#### Copy and overwrite `Startup Folder` dots
```powershell
Copy-Item -Path "$env:UserProfile\win-glaze-dots\UserProfile\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup" -Destination "$env:UserProfile\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup" -Force
```
