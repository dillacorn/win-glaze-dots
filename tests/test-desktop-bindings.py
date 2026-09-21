"""Check launcher and binding-mode ownership across actual YASB/GlazeWM configurations."""
from pathlib import Path
import yaml

root = Path(__file__).resolve().parents[1]

for yasb_name in ("config.yaml", "custom_work_config.yaml"):
    yasb = yaml.safe_load((root / "UserProfile/.config/yasb" / yasb_name).read_text())
    keybindings = yasb["widgets"]["launcher"]["options"].get("keybindings", [])
    assert not keybindings, (yasb_name, "YASB Quick Launch must not own a synthetic/global launcher relay", keybindings)

for name in ("config.yaml", "custom_work_config.yaml"):
    config = yaml.safe_load((root / "UserProfile/.glzr/glazewm" / name).read_text())
    modes = {m["name"]: m["keybindings"] for m in config["binding_modes"]}
    is_work = name == "custom_work_config.yaml"

    assert "mouse" in modes, (name, "native mouse binding mode missing")

    for mode, bindings in [("normal", config["keybindings"]), ("noalt", modes["noalt"])]:
        bridge_commands = [
            command
            for binding in bindings
            for command in binding["commands"]
            if "yasb-quick-launch.ps1" in command or "flow-launcher.ps1" in command
        ]
        assert not bridge_commands, (name, mode, "launcher relay script returned", bridge_commands)

        flow_direct_keys = {
            key
            for binding in bindings
            if any("%LOCALAPPDATA%/FlowLauncher/Flow.Launcher.exe" in command for command in binding["commands"])
            for key in binding["bindings"]
        }

        for binding in bindings:
            assert not any("wgdot" in command.lower() for command in binding["commands"]), (
                name,
                mode,
                "desktop runtime path must not depend on WGDot",
                binding,
            )

        if is_work:
            assert "alt+p" in flow_direct_keys, (name, mode, "Work Alt+P must launch Flow directly", flow_direct_keys)
        else:
            assert "alt+p" not in flow_direct_keys, (name, mode, "Normal profile must not default Alt+P to Flow")

    mouse_keys = {key for binding in modes["mouse"] for key in binding["bindings"]}
    assert {"lwin+alt+m", "rwin+alt+m"} <= mouse_keys, (name, "mouse mode lacks Super+Alt+M exit")

    guest_keys = {key for binding in modes["vm"] for key in binding["bindings"]}
    assert not ({"alt+p", "lwin+d", "rwin+d", "lwin", "rwin"} & guest_keys), (
        name,
        "VM guest shortcuts intercepted",
    )

print("Desktop launcher/binding-mode ownership checks passed (configuration contract, not Windows input acceptance).")
