"""Check launcher and binding-mode ownership across actual YASB/GlazeWM configurations."""
from pathlib import Path
import yaml

root = Path(__file__).resolve().parents[1]

APPROVED_WGDOT_RUNTIME = (
    "wgdotw.exe mouse-mode-toggle",
    "wgdotw.exe glazewm-binding-mode-toggle",
    "wgdotw.exe bar-autohide-toggle",
    "wgdot.exe theme",
)

FORBIDDEN_WGDOT_RUNTIME = (
    "quick-launch",
    "flow-open",
    "eartrumpet-mixer",
    "clipboard-history",
    "flameshot-gui",
    "display-settings",
    "power-menu",
)

for yasb_name in ("config.yaml", "custom_work_config.yaml"):
    yasb = yaml.safe_load((root / "UserProfile/.config/yasb" / yasb_name).read_text())
    keybindings = yasb["widgets"]["launcher"]["options"].get("keybindings", [])
    assert not keybindings, (yasb_name, "YASB Quick Launch must not own a synthetic/global launcher relay", keybindings)

    mode_callbacks = yasb["widgets"]["glazewm_binding_mode"]["options"]["callbacks"]
    assert mode_callbacks["on_left"] == "disable_binding_mode", (
        yasb_name,
        "active binding-mode label must disable the current mode instead of cycling",
        mode_callbacks,
    )
    assert mode_callbacks["on_right"] == "disable_binding_mode", (
        yasb_name,
        "active binding-mode label right click must disable the current mode",
        mode_callbacks,
    )

    mouse_callbacks = yasb["widgets"]["workspace_mouse"]["options"]["callbacks"]
    assert "wgdotw.exe mouse-mode-toggle" in mouse_callbacks["on_left"], (
        yasb_name,
        "mouse icon must toggle the scoped mouse-mode helper",
        mouse_callbacks,
    )

    power = yasb["widgets"]["power_menu"]
    assert power["type"] == "yasb.power_menu.PowerMenuWidget", (yasb_name, "power menu must remain native YASB")
    assert power["options"]["callbacks"]["on_left"] == "toggle_power_menu", (
        yasb_name,
        "power icon must use YASB's native toggle callback",
    )

for name in ("config.yaml", "custom_work_config.yaml"):
    config = yaml.safe_load((root / "UserProfile/.glzr/glazewm" / name).read_text())
    modes = {m["name"]: m["keybindings"] for m in config["binding_modes"]}
    is_work = name == "custom_work_config.yaml"

    assert "mouse" in modes, (name, "mouse binding mode missing")

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
            for command in binding["commands"]:
                lower = command.lower()
                if "wgdot" in lower:
                    assert any(allowed in lower for allowed in APPROVED_WGDOT_RUNTIME), (
                        name,
                        mode,
                        "unapproved WGDot runtime command",
                        command,
                    )
                    assert not any(forbidden in lower for forbidden in FORBIDDEN_WGDOT_RUNTIME), (
                        name,
                        mode,
                        "native-capable action was routed through WGDot",
                        command,
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

work_text = (root / "UserProfile/.glzr/glazewm/custom_work_config.yaml").read_text()
assert ".ps1" not in work_text.lower(), "Work GlazeWM must not depend on .ps1 runtime files"

print("Desktop launcher/binding-mode hybrid ownership checks passed.")
