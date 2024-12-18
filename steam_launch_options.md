Notes From Repo: https://github.com/dillacorn/win-glaze-dots

### before attempting to use a custom resolution you will need to apply the custom resolution with your GPU driver software ~ [See Guide](https://github.com/dillacorn/win-glaze-dots/blob/main/amd_software_settings.md)

Change res to 1728x1080 or 1440x1080 (for example) for games that only work in borderless windowed for fullscreen stretched resolutions. I'm using `nircmd` scripts to quickly change resolutions before launching specific games. ~ [View scripts](https://github.com/dillacorn/win-glaze-dots/blob/main/UserProfile/scripts)

### To use nircmd launch it with GlazeWM shortcut `ALT+shift+m` ~ [See GlazeWM Config](https://github.com/dillacorn/win-glaze-dots/blob/d8667c1f86257113a0b3ad13b69d28e74fd226f0/UserProfile/.glzr/glazewm/config.yaml#L415)
---
### Apex Legends ~ stretched 1440x1080
### patch apex ["videoconfig.txt"](https://github.com/dillacorn/win-glaze-dots/blob/main/Game_Config_Files/Apex%20Legends/UserProfile/Saved%20Games/Respawn/Apex/Local/videoconfig.txt) then make read-only

File Location: `C:\Users\username\Saved Games\Respawn\Apex\local`

```
"setting.defaultres"		"1440"
"setting.defaultresheight"		"1080"
```

### Apex Steam Launch Options:
`+mat_letterbox_aspect_goal 0 +mat_letterbox_aspect_threshold 0 +building_cubemaps "1" -dev -freq 240 +fps_max 240`
---
### Marvel Rivals ~ stretched 1728x1080 (fullscreen)
### patch marvel ["GameUserSettings.ini"](https://github.com/dillacorn/win-glaze-dots/blob/main/Game_Config_Files/Marvel%20Rivals/AppData/Local/Marvel/Saved/Config/Windows/GameUserSettings.ini) then make read-only

File Location: `C:\Users\username\AppData\Local\Marvel\Saved\Config\Windows`

```
ResolutionSizeX=1728
ResolutionSizeY=1080
```

### Marvel Steam Launch Options:
`+fps_max 0 +r_drawparticles 0 +mat_disable_fancy_blending 1 -forcenovsync`
---
### Overwatch 2 ~ stretched 1728x1080 (borderless windowed)
---
## The Finals ~ stretched 1440x1080 (fullscreen)
---
## Fortnite ~ stretched 1440x1080 (borderless windowed)
