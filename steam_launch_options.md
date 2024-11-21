Notes From Repo: https://github.com/dillacorn/win-glaze-dots

### before attempting to use a custom resolution you will need to apply the custom resolution with your GPU driver software

## Apex Legends ~ stretched 1440x1080 240hz
### patch apex videoconfig.txt then make read-only

`micro ~/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/compatdata/1172470/pfx/drive_c/users/steamuser/Saved\ Games/Respawn/Apex/local/videoconfig.txt`

	"setting.defaultres"		"1440"
	"setting.defaultresheight"		"1080"

### Steam Launch Option:
+mat_letterbox_aspect_goal 0 +mat_letterbox_aspect_threshold 0 +building_cubemaps "1" -dev -freq 240 +fps_max 240