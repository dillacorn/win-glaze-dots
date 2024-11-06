Notes From Repo: https://github.com/dillacorn/dill-win-dots

### before running launch option set a custom resolutions.

## Apex Legends ~ stretched 1440x1080 240hz
### patch apex videoconfig.txt then make read-only

`micro ~/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/compatdata/1172470/pfx/drive_c/users/steamuser/Saved\ Games/Respawn/Apex/local/videoconfig.txt`

	"setting.defaultres"		"1440"
	"setting.defaultresheight"		"1080"

%command% +mat_letterbox_aspect_goal 0 +mat_letterbox_aspect_threshold 0 +building_cubemaps "1" -dev -freq 240 +fps_max unlimited