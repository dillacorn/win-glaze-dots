"""Check launcher ownership across actual YASB/GlazeWM configurations."""
from pathlib import Path
import yaml

root = Path(__file__).resolve().parents[1]
yasb = yaml.safe_load((root / "UserProfile/.config/yasb/config.yaml").read_text())
keys = {b["keys"] for b in yasb["widgets"]["launcher"]["options"]["keybindings"]}
assert keys == {"win+alt+d"}, "YASB must not capture ordinary guest launcher chords in VM mode"

for name in ("config.yaml", "custom_work_config.yaml"):
    config = yaml.safe_load((root / "UserProfile/.glzr/glazewm" / name).read_text())
    modes = {m["name"]: m["keybindings"] for m in config["binding_modes"]}
    for mode, bindings in [("normal", config["keybindings"]), ("noalt", modes["noalt"])]:
        launch = {key for b in bindings if any("wgdot.exe quick-launch" in c for c in b["commands"]) for key in b["bindings"]}
        assert {"alt+p", "lwin+d", "rwin+d", "lwin+alt+d", "rwin+alt+d"} <= launch, (name, mode, launch)
    guest_keys = {key for b in modes["vm"] for key in b["bindings"]}
    assert not ({"alt+p", "lwin+d", "rwin+d", "lwin", "rwin"} & guest_keys), (name, "VM guest shortcuts intercepted")
print("Desktop launcher ownership checks passed (configuration contract, not Windows input acceptance).")
