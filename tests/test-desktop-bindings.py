"""Check launcher and binding-mode ownership across actual YASB/GlazeWM configurations."""
from pathlib import Path
import yaml

root = Path(__file__).resolve().parents[1]

APPROVED_WGDOT_RUNTIME = (
    "wgdotw.exe glazewm-binding-mode-toggle",
    "wgdotw.exe bar-autohide-toggle",
    "wgdotw.exe rawaccel-toggle",
    "wgdot.exe theme",
    "wgdotw.exe theme-window-toggle",
    "wgdotw.exe clipboard-anchor",
    "wgdotw.exe power-menu",
    "wgdotw.exe launcher",
)

FORBIDDEN_WGDOT_RUNTIME = (
    "quick-launch",
    "flow-open",
    "eartrumpet-mixer",
    "clipboard-history",
    "flameshot-gui",
    "display-settings",
)

for yasb_name in ("config.yaml", "custom_work_config.yaml"):
    yasb_path = root / "UserProfile/.config/yasb" / yasb_name
    yasb_text = yasb_path.read_text()
    assert ".ps1" not in yasb_text.lower(), (yasb_name, "YASB runtime must not depend on .ps1 files")
    yasb = yaml.safe_load(yasb_text)
    launcher = yasb["widgets"]["launcher"]
    assert launcher["type"] == "yasb.custom.CustomWidget", (
        yasb_name,
        "launcher button must be the lightweight YASB custom control",
    )
    assert launcher["options"]["callbacks"]["on_left"] == "exec wgdotw.exe launcher bar", (
        yasb_name,
        "launcher button must open the compiled bar-relative surface",
    )
    assert launcher["options"]["callbacks"]["on_right"] == "exec wgdotw.exe launcher bar", (
        yasb_name,
        "launcher right click must toggle the same compiled surface",
    )

    clipboard = yasb["widgets"]["clipboard_history"]
    assert clipboard["options"]["callbacks"]["on_left"] == "exec wgdotw.exe clipboard-anchor bar", (
        yasb_name,
        "clipboard button must use the narrow bar-relative native-history anchor",
    )
    assert clipboard["options"]["callbacks"]["on_right"] == "exec wgdotw.exe clipboard-anchor bar", (
        yasb_name,
        "clipboard right click must toggle the same native-history surface",
    )
    assert yasb["widgets"]["wifi"]["options"]["callbacks"]["on_left"] == "exec explorer.exe ms-settings:network-status", (
        yasb_name,
        "Wi-Fi/Ethernet must open the native Windows Network surface",
    )
    assert yasb["widgets"]["bluetooth"]["options"]["callbacks"]["on_left"] == "exec explorer.exe ms-settings:bluetooth", (
        yasb_name,
        "Bluetooth must open the native Windows Bluetooth surface",
    )

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
    assert mode_callbacks["on_middle"] == "do_nothing", (
        yasb_name,
        "active binding-mode label middle click must do nothing",
        mode_callbacks,
    )
    assert "next_binding_mode" not in mode_callbacks.values(), (
        yasb_name,
        "active binding-mode label must never cycle modes",
        mode_callbacks,
    )

    assert "workspace_move_hub" not in yasb["widgets"], (
        yasb_name,
        "retired workspace mover hub must stay removed",
    )
    assert "workspace_move_group" not in yasb["widgets"], (
        yasb_name,
        "workspace arrows must not depend on a fake hover group",
    )
    assert "workspace_move" in yasb["widgets"], (
        yasb_name,
        "workspace mover arrows must stay directly available",
    )
    assert "mouse-mode-toggle" not in yasb_text and "workspace_mouse" not in yasb_text, (
        yasb_name,
        "retired mouse-mode runtime returned to YASB",
    )

    power = yasb["widgets"]["power_menu"]
    assert power["type"] == "yasb.custom.CustomWidget", (yasb_name, "power button must remain a lightweight YASB custom control")
    assert power["options"]["callbacks"]["on_left"] == "exec wgdotw.exe power-menu", (
        yasb_name,
        "power icon must open the compiled Awtarchy-style power surface",
    )
    assert power["options"]["callbacks"]["on_right"] == "exec wgdotw.exe power-menu", (
        yasb_name,
        "power icon right click must toggle the same compiled power surface",
    )

for name in ("config.yaml", "custom_work_config.yaml"):
    glaze_path = root / "UserProfile/.glzr/glazewm" / name
    glaze_text = glaze_path.read_text()
    assert ".ps1" not in glaze_text.lower(), (name, "GlazeWM runtime must not depend on .ps1 files")
    config = yaml.safe_load(glaze_text)
    modes = {m["name"]: m["keybindings"] for m in config["binding_modes"]}
    is_work = name == "custom_work_config.yaml"

    assert "mouse" not in modes, (name, "retired mouse binding mode returned")
    assert "lwin+alt+m" not in glaze_text and "rwin+alt+m" not in glaze_text, (
        name,
        "retired Super+Alt+M mouse binding returned",
    )
    assert "mouse-mode-toggle" not in glaze_text, (name, "retired WGDot mouse helper returned")

    assert r'%LOCALAPPDATA%\wgdot\bin\wgdotw.exe' in glaze_text, (
        name,
        "compiled helper hotkeys must not depend on GlazeWM's inherited PATH",
    )

    expected_focus_follows_cursor = not is_work
    assert config["general"]["focus_follows_cursor"] is expected_focus_follows_cursor, (
        name,
        "focus_follows_cursor profile default regressed",
        config["general"]["focus_follows_cursor"],
    )

    for mode, bindings in [("normal", config["keybindings"]), ("noalt", modes["noalt"])]:
        bridge_commands = [
            command
            for binding in bindings
            for command in binding["commands"]
            if "yasb-quick-launch.ps1" in command or "flow-launcher.ps1" in command
        ]
        assert not bridge_commands, (name, mode, "launcher relay script returned", bridge_commands)

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

        power_keys = {
            key
            for binding in bindings
            if any("wgdotw.exe power-menu" in command for command in binding["commands"])
            for key in binding["bindings"]
        }
        assert {"lwin+p", "rwin+p"} <= power_keys, (
            name,
            mode,
            "Super+P must open the compiled Awtarchy-style power surface",
            power_keys,
        )

        launcher_keys = {
            key
            for binding in bindings
            if any("wgdotw.exe launcher hotkey" in command for command in binding["commands"])
            for key in binding["bindings"]
        }
        assert {"lwin+d", "rwin+d"} <= launcher_keys, (
            name,
            mode,
            "Super+D must open the compiled application launcher",
            launcher_keys,
        )
        if mode == "normal":
            assert "alt+p" in launcher_keys, (
                name,
                mode,
                "normal mode must bind Alt+P to the compiled launcher",
                launcher_keys,
            )
        else:
            assert "alt+p" not in launcher_keys, (
                name,
                mode,
                "noalt must leave plain Alt+P uncaptured",
                launcher_keys,
            )

        theme_keys = {
            key
            for binding in bindings
            if any("wgdotw.exe theme-window-toggle" in command for command in binding["commands"])
            for key in binding["bindings"]
        }
        assert {"lwin+alt+t", "rwin+alt+t"} <= theme_keys, (
            name,
            mode,
            "Super+Alt+T must open themes",
            theme_keys,
        )
        tiling_keys = {
            key
            for binding in bindings
            if any(command == "toggle-tiling" for command in binding["commands"])
            for key in binding["bindings"]
        }
        if mode == "normal":
            assert {"alt+t", "lwin+t", "rwin+t"} <= tiling_keys, (
                name,
                mode,
                "normal mode must bind Alt+T and Super+T to tiling",
                tiling_keys,
            )
        else:
            assert {"lwin+t", "rwin+t"} <= tiling_keys, (
                name,
                mode,
                "noalt must keep Super+T tiling",
                tiling_keys,
            )
            assert "alt+t" not in tiling_keys, (
                name,
                mode,
                "noalt must leave plain Alt+T uncaptured",
                tiling_keys,
            )

        eartrumpet_keys = {
            key
            for binding in bindings
            if any("40459File-New-Project.EarTrumpet_1sdd7yawvg6ne!EarTrumpet" in command for command in binding["commands"])
            for key in binding["bindings"]
        }
        assert {"lwin+v", "rwin+v"} <= eartrumpet_keys, (
            name,
            mode,
            "Super+V must launch EarTrumpet directly",
            eartrumpet_keys,
        )
        if mode == "normal":
            assert "alt+v" in eartrumpet_keys, (
                name,
                mode,
                "normal mode must bind Alt+V to EarTrumpet",
                eartrumpet_keys,
            )
        else:
            assert "alt+v" not in eartrumpet_keys, (
                name,
                mode,
                "noalt must leave plain Alt+V uncaptured",
                eartrumpet_keys,
            )

        clipboard_keys = {
            key
            for binding in bindings
            if any("wgdotw.exe clipboard-anchor hotkey" in command for command in binding["commands"])
            for key in binding["bindings"]
        }
        assert {"lwin+c", "rwin+c"} <= clipboard_keys, (
            name,
            mode,
            "Super+C must invoke the narrow native Clipboard History anchor",
            clipboard_keys,
        )

        rawaccel_keys = {
            key
            for binding in bindings
            if any("wgdotw.exe rawaccel-toggle" in command for command in binding["commands"])
            for key in binding["bindings"]
        }
        assert {"lwin+shift+m", "rwin+shift+m"} <= rawaccel_keys, (
            name,
            mode,
            "Super+Shift+M must use the scoped compiled RawAccel toggle",
            rawaccel_keys,
        )
        assert "alt+shift+m" not in rawaccel_keys, (name, mode, "RawAccel must not capture Alt+Shift+M")

    guest_keys = {key for binding in modes["vm"] for key in binding["bindings"]}
    assert not ({"alt+p", "lwin+d", "rwin+d", "lwin", "rwin"} & guest_keys), (
        name,
        "VM guest shortcuts intercepted",
    )

for runtime_path in (
    root / "UserProfile/.glzr/glazewm/config.yaml",
    root / "UserProfile/.glzr/glazewm/custom_work_config.yaml",
    root / "UserProfile/.config/yasb/config.yaml",
    root / "UserProfile/.config/yasb/custom_work_config.yaml",
):
    assert ".ps1" not in runtime_path.read_text().lower(), (
        runtime_path,
        "desktop runtime configs must contain zero .ps1 references",
    )

print("Desktop launcher/binding-mode hybrid ownership checks passed.")
