Notes From Repo: https://github.com/dillacorn/win-glaze-dots

### before attempting to use a custom resolution you will need to apply the custom resolution with your GPU driver software
---
### Apex Legends ~ stretched 1440x1080
### patch apex "videoconfig.txt" then make read-only

File Location: `C:\Users\username\Saved Games\Respawn\Apex\local`

```
"setting.defaultres"		"1440"
"setting.defaultresheight"		"1080"
```

### Apex Steam Launch Options:
`+mat_letterbox_aspect_goal 0 +mat_letterbox_aspect_threshold 0 +building_cubemaps "1" -dev -freq 240 +fps_max 240`
---
### Marvel Rivals ~ stretched 1728x1080 (fullscreen)
### patch marvel "GameUserSettings.ini" then make read-only

File Location: `C:\Users\username\AppData\Local\Marvel\Saved\Config\Windows`

```
ResolutionSizeX=1728
ResolutionSizeY=1080
```

### Marvel Steam Launch Options:
`+fps_max 0 +r_drawparticles 0 +mat_disable_fancy_blending 1 -forcenovsync`
---

### Overwatch 2 ~ stretched 1728x1080 (borderless windowed)

Change res to 1728x1080.. I'm using [nircmd command](https://github.com/dillacorn/win-glaze-dots/blob/main/UserProfile/scripts/16.10_stretched_res.bat) for quick res changing `alt+shift+m`

---

## The Finals ~ stretched 1440x1080 (fullscreen)

## Fortnite ~ stretched 1440x1080 (borderless windowed)
