"""Check launcher ownership across actual YASB/GlazeWM configurations."""
from pathlib import Path
import yaml

root = Path(__file__).resolve().parents[1]

for yasb_name in ("config.yaml", "custom_work_config.yaml"):
    yasb = yaml.safe_load((root / "UserProfile/.config/yasb" / yasb_name).read_text())
    keys = {b["keys"] for b in yasb["widgets"]["launcher"]["options"]["keybindings"]}
    assert keys == {"f24"}, (yasb_name, "YASB must own only the private F24 launcher bridge", keys)

for name in ("config.yaml", "custom_work_config.yaml"):
    config = yaml.safe_load((root / "UserProfile/.glzr/glazewm" / name).read_text())
    modes = {m["name"]: m["keybindings"] for m in config["binding_modes"]}
    is_work = name == "custom_work_config.yaml"

    for mode, bindings in [("normal", config["keybindings"]), ("noalt", modes["noalt"])]:
        yasb_launch = {
            key
            for b in bindings
            if any("yasb-quick-launch.ps1" in c for c in b["commands"])
            for key in b["bindings"]
        }
        flow_launch = {
            key
            for b in bindings
            if any("flow-launcher.ps1" in c for c in b["commands"])
            for key in b["bindings"]
        }

        for binding in bindings:
            assert not any("wgdot" in c.lower() for c in binding["commands"]), (
                name,
                mode,
                "desktop launcher path must not depend on WGDot",
                binding,
            )

        if is_work:
            assert {"lwin+d", "rwin+d"} <= yasb_launch, (name, mode, yasb_launch)
            assert "alt+p" not in yasb_launch, (name, mode, "Alt+P must not also invoke YASB")
            assert {"alt+p"} <= flow_launch, (name, mode, flow_launch)
        else:
            assert {"alt+p", "lwin+d", "rwin+d"} <= yasb_launch, (name, mode, yasb_launch)
            assert "alt+p" not in flow_launch, (name, mode, "Normal profile must not default Alt+P to Flow")

    guest_keys = {key for b in modes["vm"] for key in b["bindings"]}
    assert not ({"alt+p", "lwin+d", "rwin+d", "lwin", "rwin"} & guest_keys), (
        name,
        "VM guest shortcuts intercepted",
    )

print("Desktop launcher ownership checks passed (configuration contract, not Windows input acceptance).")
