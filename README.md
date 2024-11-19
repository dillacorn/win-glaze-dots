# `windows dilla.glaze.files`

- glazewm and zebar dots

- application configurations and guides

---
## Guides in Specific Order
- [windows_settings](https://github.com/dillacorn/win-glaze-dots/blob/main/Windows_Settings.md)
- [install_software](https://github.com/dillacorn/win-glaze-dots/blob/main/install_software.md)

### Clone Repo (Using Alacritty)
```powershell
cd .\Downloads\
git clone https://github.com/dillacorn/win-glaze-dots
```

### Recursive copy directories
#### Navigate to the directory
```powershell
cd .\Downloads\win-glaze-dots\%UserProfile%\
```
#### Copy `.glazr` to the user's home directory
```powershell
Copy-Item -Recurse -Path .\.glzr -Destination ~\ -Force
```
#### Copy `scripts` to the user's home directory
```powershell
Copy-Item -Recurse -Path .\scripts -Destination ~\ -Force
```
#### Navigate to the %AppData%\Roaming directory
```powershell
cd ..
cd .\%AppData%\Roaming\
```

#### Copy alacritty folder to the home directory
```powershell
Copy-Item -Recurse -Path .\alacritty -Destination "~\AppData\Roaming" -Force
```

#### Copy flameshot folder to the home directory
```powershell
Copy-Item -Recurse -Path .\flameshot -Destination "~\AppData\Roaming" -Force
```

- [privacy.sexy](https://github.com/dillacorn/win-glaze-dots/blob/main/privacy.sexy.md)
- [flow-launcher_bind](https://github.com/dillacorn/win-glaze-dots/blob/main/flow-launcher_bind.png)
- [altsnap_settings](https://github.com/dillacorn/win-glaze-dots/blob/main/altsnap_settings.md)
- [eartrumpet_bind](https://github.com/dillacorn/win-glaze-dots/blob/main/eartrumpet_bind.png)
- [powertoys_flameshot_win+shift+f](https://github.com/dillacorn/win-glaze-dots/blob/main/powertoys_flameshot_win%2Bshift%2Bf.md)
- [theme_scriptsUAC Req.](https://github.com/dillacorn/win-glaze-dots/tree/main/theme_scripts(UAC%20Req.))
- [butterytaskbar2](https://github.com/dillacorn/win-glaze-dots/blob/main/butterytaskbar2.png)
- [low_latency_gaming_guide](https://github.com/dillacorn/win-glaze-dots/blob/main/low_latency_gaming_guide.md)
- [browser_notes](https://github.com/dillacorn/win-glaze-dots/tree/main/browser_notes)
- [terminal_navigation](https://github.com/dillacorn/win-glaze-dots/blob/main/terminal_navigation.md)

---

## Wallpapers
- [Gruvbox Wallpapers](https://github.com/AngelJumbo/gruvbox-wallpapers) by [AngelJumbo](https://github.com/AngelJumbo)
- [Aesthetic Wallpapers](https://github.com/D3Ext/aesthetic-wallpapers) by [D3Ext](https://github.com/D3Ext)
- [Wallpapers](https://github.com/michaelScopic/Wallpapers) by [michaelScopic](https://github.com/michaelScopic)

---

### License
All code and notes are not under any formal license. If you find any of the scripts helpful, feel free to use, modify, publish, and distribute them to your heart's content. See https://unlicense.org/repo
