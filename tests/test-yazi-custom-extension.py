#!/usr/bin/env python3
"""Verify optional Yazi Lua customizations independently from Yazi's UI."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "UserProfile/AppData/Roaming/yazi/config/init.lua"
source = SOURCE.read_text(encoding="utf-8")
start_marker = "-- BEGIN WGDOT USER CUSTOM LUA"
end_marker = "-- END WGDOT USER CUSTOM LUA"
assert source.count(start_marker) == source.count(end_marker) == 1
assert source.index(start_marker) > source.index(
    "Status:children_add(function(self)\n    return self:modified_time()")
loader = source.split(start_marker, 1)[1].split(end_marker, 1)[0]
assert "dofile(custom)" in loader and 'io.open(custom, "r")' in loader
assert not (SOURCE.parent / "custom.lua").exists(), (
    "User-owned custom.lua must not become a managed repository file")

lua = shutil.which("lua5.4") or shutil.which("lua")
luac = shutil.which("luac5.4") or shutil.which("luac")
assert lua, "The Yazi Lua loader test requires Lua 5.4"
assert luac, "The Yazi syntax test requires luac"
subprocess.run([luac, "-p", str(SOURCE)], check=True, timeout=15)

with tempfile.TemporaryDirectory(prefix="yazi-user-extension-") as name:
    root = Path(name)
    home = root / "home"
    home.mkdir()
    config = root / "custom-root"
    config.mkdir()
    state = root / "custom-loaded"
    env = dict(os.environ, HOME=str(home), YAZI_CONFIG_HOME=str(config),
               CUSTOM_LOAD_RESULT=str(state))
    env.pop("XDG_CONFIG_HOME", None)
    env.pop("APPDATA", None)

    def run(extra_env=env):
        return subprocess.run([lua, "-"], input=loader,
                              text=True, capture_output=True, timeout=10,
                              env=extra_env)

    # Absent optional file must be silent, successful and create nothing.
    empty = run()
    assert empty.returncode == 0, empty.stderr
    assert not state.exists() and list(config.iterdir()) == []

    custom = config / "custom.lua"
    custom.write_text(
        'local file = assert(io.open(os.getenv("CUSTOM_LOAD_RESULT"), "w"))\n'
        'file:write("custom-loaded")\n'
        'file:close()\n', encoding="utf-8")
    loaded = run()
    assert loaded.returncode == 0, loaded.stderr
    assert state.read_text() == "custom-loaded"
    assert custom.is_file(), "Extension must remain user-owned and intact"

    # A malformed custom file must not be silently swallowed or replaced.
    state.unlink()
    custom.write_text("this is invalid Lua syntax (\n", encoding="utf-8")
    malformed = run()
    assert malformed.returncode != 0
    assert "custom.lua" in malformed.stderr, malformed.stderr
    assert custom.read_text() == "this is invalid Lua syntax (\n"

    # The YAZI_CONFIG_HOME override always takes precedence over default
    # Linux (XDG_CONFIG_HOME / HOME) or Windows (APPDATA) roots.
    custom.unlink()
    default = root / "platform-default"
    default = root / "appdata" / "yazi" / "config"
    state.unlink() if state.exists() else None
    default_file = default / "custom.lua"
    default_file.parent.mkdir(parents=True, exist_ok=True)
    default_file.write_text(
        'local file = assert(io.open(os.getenv("CUSTOM_LOAD_RESULT"), "w"))\n'
        'file:write("platform-default")\n'
        'file:close()\n', encoding="utf-8")
    fallback_env = dict(env)
    fallback_env.pop("YAZI_CONFIG_HOME", None)
    fallback_env["APPDATA"] = str(root / "appdata")
    fallback = run(fallback_env)
    assert fallback.returncode == 0, fallback.stderr
    assert state.read_text() == "platform-default"
    # Restore explicit override and ensure it does not load fallback instead.
    state.unlink()
    override = run(env)
    assert override.returncode == 0, override.stderr
    assert not state.exists()

import json
manifest = json.loads((ROOT / "wgdot/manifest.json").read_text(encoding="utf-8"))
yazi = next(c for c in manifest["components"] if c["id"] == "yazi")
assert not any("custom.lua" in str(file) for file in yazi["files"])

print("PASS: user Yazi custom.lua remains optional, untracked and loaded only when present")
