# Yazi customizations (Windows)

Awtarchy and win-glaze-dots share the same **optional user-owned Lua extension** design. Your extension is loaded after the managed `init.lua` has registered its plugins, UI callbacks, and functions.

## Optional user Lua file

WGDot ships a [comment-only `custom.lua` starter](UserProfile/AppData/Roaming/yazi/config/custom.lua) in GitHub. On a new install or successful managed config apply, WGDot **creates `%APPDATA%\yazi\config\custom.lua` only if it is missing** and Yazi is selected. It is not a manifest-managed file, so updates and resets never overwrite personal edits. If you override `YAZI_CONFIG_HOME`, create/copy the file there yourself. The installed `init.lua` loads it automatically.

Example `custom.lua`:

```lua
-- My Yazi customizations. This file belongs to me.
-- To configure an installed personal plugin, for example:
-- require("my-plugin"):setup()
```

This file can add functions used by your own keybindings, configure plugins, or intentionally override managed Lua definitions. Because it loads last, the current managed definitions are already in place. An absent `custom.lua` does nothing; a syntax/runtime error in your own file is reported by Yazi, not silently ignored.

Yazi's `YAZI_CONFIG_HOME` environment variable takes priority. Without it, the loader uses `APPDATA` and the platform's usual Yazi config directory. The loader lives in `UserProfile/AppData/Roaming/yazi/config/init.lua`.

## Multiple personal Lua files

Only one top-level `custom.lua` is loaded automatically per Yazi configuration directory. To keep settings organized, create any number of additional Lua files such as `custom/plugins.lua` and `custom/appearance.lua`. **Uncomment the matching `dofile(...)` examples in `custom.lua`** to load those files explicitly in your chosen order. Extra files are user-owned, never automatically scanned or managed, and missing/invalid files will produce a visible Lua error. This uses Yazi's existing Lua loader without a background process.

## TOML settings and keybindings

**Do not create `custom.toml` expecting Yazi to load it.** Yazi's supported configuration is its `yazi.toml`, `keymap.toml`, and `theme.toml`; there is no supported generic TOML include file in these configurations.

Edit the relevant managed TOML in place if you need a custom option. For keyboard bindings, the `prepend_keymap` and `append_keymap` arrays in `keymap.toml` control precedence. Awtarchy/WGDot-managed bindings may already occupy higher-priority positions, so check for duplicate chords instead of appending an ineffective binding.

**WGDot:** Only the Yazi paths explicitly declared in `wgdot/manifest.json` are managed. Normal updates use the existing baseline-aware preserve/merge policy for edited TOML and Lua. Conflicting edits remain available for review with backups. Explicit reset can replace managed files after backup; `custom.lua` is not a manifest target.

User-owned plugins under `plugins/` are never adopted merely because they are in the same directory. Avoid editing a managed plugin directly where a distinct personal plugin can provide the desired behavior.

## Upgrade and verification

1. Edit your automatically created `custom.lua` (or create it yourself on an older release / overridden config root), optionally loading your own `custom/*.lua` files.
2. Restart Yazi; already-running Yazi sessions do not automatically reload Lua.
3. Update managed configs normally. Check warnings and merge upstream changes into any preserved customized TOML yourself, rather than resetting personal changes.

The extension does not replace Yazi's TOML parser or the existing update-preservation safeguards.

References: [Yazi configuration](https://yazi-rs.github.io/docs/configuration/overview/) and [Yazi plugins](https://yazi-rs.github.io/docs/plugins/overview/).
