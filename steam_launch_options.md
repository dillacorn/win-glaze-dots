Notes From Repo: https://github.com/dillacorn/win-glaze-dots

### DWM on Windows 11 has been improved. Latency between fullscreen and borderless windowed is similar in most games. 

### before attempting to use a custom resolution you will need to apply the custom resolution with your GPU driver software ~ [See Guide](https://github.com/dillacorn/win-glaze-dots/blob/main/amd_software_settings.md)

For games requiring borderless windowed mode for stretched fullscreen resolutions, I use nircmd scripts to quickly switch resolutions before launching specific games. I find 1600x1024 (16:10) strikes a good balance—offering stretch without overdoing it, while still feeling natural when switching back to 16:9. While 1728x1080 (16:10) is sharper, the difference is minimal, and 1600x1024 provides better frame rate consistency. For a stronger stretch, 1440x1080 (4:3) and 1400x1050 (4:3) are excellent options, with the latter offering a slightly less intense stretch.

### To use nircmd launch it with GlazeWM shortcut `ALT+shift+m` ~ [See GlazeWM Config](https://github.com/dillacorn/win-glaze-dots/blob/d8667c1f86257113a0b3ad13b69d28e74fd226f0/UserProfile/.glzr/glazewm/config.yaml#L415)
---
### Apex Legends ~ stretched 1600x1024 and/or 1400x1050
### patch apex ["videoconfig.txt"](https://github.com/dillacorn/win-glaze-dots/blob/main/Game_Config_Files/Apex%20Legends/UserProfile/Saved%20Games/Respawn/Apex/Local/videoconfig.txt) then make read-only

File Location: `C:\Users\username\Saved Games\Respawn\Apex\local`

```
"setting.defaultres"		"1600"
"setting.defaultresheight"		"1024"
```

### Apex Steam Launch Options:
`+mat_letterbox_aspect_goal 0 +mat_letterbox_aspect_threshold 0 +building_cubemaps "1" -dev -freq 240 +fps_max 240`

---
### Marvel Rivals ~ stretched 1600x1024 (borderless windowed)
### patch marvel ["GameUserSettings.ini"](https://github.com/dillacorn/win-glaze-dots/blob/main/Game_Config_Files/Marvel%20Rivals/AppData/Local/Marvel/Saved/Config/Windows/GameUserSettings.ini) then make read-only

File Location: `C:\Users\username\AppData\Local\Marvel\Saved\Config\Windows`

```
ResolutionSizeX=1600
ResolutionSizeY=1024
```
### Overwatch 2 ~ stretched 1600x1024 (fullscreen)
---
### The Finals ~ stretched 1600x1024 and/or 1400x1050 (fullscreen)
---
### Fortnite ~ stretched 1600x1024 and/or 1400x1050 (borderless windowed)
---
### CS2 ~ stretched 1600x1024 and/or 1400x1050 (borderless windowed)
---
