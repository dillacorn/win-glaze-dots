Notes From Repo: https://github.com/dillacorn/win-glaze-dots

### before running launch option set a working custom resolutions with your specific GPU drivers.

## Apex Legends ~ stretched 1440x1080 240hz
### patch apex videoconfig.txt then make read-only

`C:\Users\username\Saved Games\Respawn\Apex\local\videoconfig.txt`

	"setting.defaultres"		"1440"
	"setting.defaultresheight"		"1080"

Steam Launch Option:
`%command% +mat_letterbox_aspect_goal 0 +mat_letterbox_aspect_threshold 0 +building_cubemaps "1" -dev -freq 240 +fps_max unlimited`

---
## The Finals ~ stretched 1440x1080 240hz

### requires `nircmd`

Before launching game set windows resolution (GlazeWM has issues refocusing if game res is different from OS res) 

Set custom res
```terminal
nircmd setdisplay 1440 1080 32 240
```

When you're done playing revert res.

Revert custom res
```terminal
nircmd setdisplay 1920 1080 32 240
```

alternatively create `.bat` files to run these commands in a folder of your choosing.

Run .bat in terminal (navigate to folder first)
```terminal
.\1440.bat
```

Set game to `Windowed Fullscreen` to eliminate refocusing issues...

---
