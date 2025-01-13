Notes From Repo: https://github.com/dillacorn/win-glaze-dots

### before attempting to use a custom resolution you will need to apply the custom resolution with your GPU driver software ~ [See Guide](https://github.com/dillacorn/win-glaze-dots/blob/main/amd_software_settings.md)

Change res to 1600x1024(16:10) or 1728x1080(16:10) or 1440x1080(4:3) (for example) for games that only work in borderless windowed for fullscreen stretched resolutions. I'm using `nircmd` scripts to quickly change resolutions before launching specific games. ~ [View scripts](https://github.com/dillacorn/win-glaze-dots/blob/main/UserProfile/scripts)

Based on my understanding on aspect ratios 1600x1024(16:10) strikes a good balance of adding stretch without overstretching for 16:9 aspect ratio displays such as 4:3. That way you can easily switch to 16:9 and still feel comfortable when you switch to 16:10 and vis-versa.. 1728x1080 is technically sharper than 1600x1024 but I can't tell much of a difference so using a lower res is better for more consistant frame rate.

### To use nircmd launch it with GlazeWM shortcut `ALT+shift+m` ~ [See GlazeWM Config](https://github.com/dillacorn/win-glaze-dots/blob/d8667c1f86257113a0b3ad13b69d28e74fd226f0/UserProfile/.glzr/glazewm/config.yaml#L415)
---
### Apex Legends ~ stretched 1600x1024
### patch apex ["videoconfig.txt"](https://github.com/dillacorn/win-glaze-dots/blob/main/Game_Config_Files/Apex%20Legends/UserProfile/Saved%20Games/Respawn/Apex/Local/videoconfig.txt) then make read-only

File Location: `C:\Users\username\Saved Games\Respawn\Apex\local`

```
"setting.defaultres"		"1600"
"setting.defaultresheight"		"1024"
```

### Apex Steam Launch Options:
`+mat_letterbox_aspect_goal 0 +mat_letterbox_aspect_threshold 0 +building_cubemaps "1" -dev -freq 240 +fps_max 240`

---
### Marvel Rivals ~ stretched 1600x1024 (fullscreen)
### patch marvel ["GameUserSettings.ini"](https://github.com/dillacorn/win-glaze-dots/blob/main/Game_Config_Files/Marvel%20Rivals/AppData/Local/Marvel/Saved/Config/Windows/GameUserSettings.ini) then make read-only

File Location: `C:\Users\username\AppData\Local\Marvel\Saved\Config\Windows`

```
ResolutionSizeX=1600
ResolutionSizeY=1024
```

### Marvel Steam Launch Options:
`+fps_max 0 +r_drawparticles 0 +mat_disable_fancy_blending 1 -forcenovsync`

---
### Overwatch 2 ~ stretched 1600x1024 (fullscreen)
---
### The Finals ~ stretched 1600x1024 (fullscreen)
---
### Fortnite ~ stretched 1600x1024 (borderless windowed)
---
### CS2 ~ stretched 1600x1024 and/or 1440x1080 (fullscreen)
---
