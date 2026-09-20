#!/usr/bin/env python3
"""Validate the managed YASB config against a checked-out upstream YASB release.

Usage:
    python tests/test-yasb-config.py <yasb-source-root>

The workflow checks out the current stable YASB release and supplies its root.
Validation intentionally uses upstream Pydantic models and upstream callback
registrations instead of maintaining an approximate local copy of YASB's API.
"""

from __future__ import annotations

import ast
import io
import sys
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from typing import Any, Callable

import yaml


REPO_ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = REPO_ROOT / "UserProfile" / ".config" / "yasb" / "config.yaml"
STYLE_PATH = REPO_ROOT / "UserProfile" / ".config" / "yasb" / "styles.css"
THEME_PATH = REPO_ROOT / "UserProfile" / ".config" / "yasb" / "theme.css"
APPEARANCE_PATH = REPO_ROOT / "UserProfile" / ".config" / "yasb" / "appearance.css"


def fail(message: str) -> None:
    raise SystemExit(f"YASB CONFIG TEST FAILED: {message}")


if len(sys.argv) != 2:
    fail("expected one argument: path to an upstream YASB checkout")

yasb_root = Path(sys.argv[1]).resolve()
yasb_src = yasb_root / "src"
if not yasb_src.is_dir():
    fail(f"YASB src directory not found: {yasb_src}")

sys.path.insert(0, str(yasb_src))

from core.utils.css_processor import CSSProcessor
from core.validation.config import YasbConfig
from core.validation.widgets.glazewm.binding_mode import GlazewmBindingModeConfig
from core.validation.widgets.glazewm.tiling_direction import GlazewmTilingDirectionConfig
from core.validation.widgets.glazewm.workspaces import GlazewmWorkspacesConfig
from core.validation.widgets.yasb.active_window import ActiveWindowConfig
from core.validation.widgets.yasb.applications import ApplicationsWidgetConfig
from core.validation.widgets.yasb.battery import BatteryConfig
from core.validation.widgets.yasb.bluetooth import BluetoothConfig
from core.validation.widgets.yasb.brightness import BrightnessConfig
from core.validation.widgets.yasb.clock import ClockConfig
from core.validation.widgets.yasb.control_center import ControlCenterConfig
from core.validation.widgets.yasb.cpu import CpuConfig
from core.validation.widgets.yasb.custom import CustomConfig
from core.validation.widgets.yasb.dnd import DndConfig
from core.validation.widgets.yasb.grouper import GrouperWidgetConfig
from core.validation.widgets.yasb.memory import MemoryConfig
from core.validation.widgets.yasb.microphone import MicrophoneConfig
from core.validation.widgets.yasb.notifications import NotificationsConfig
from core.validation.widgets.yasb.power_menu import PowerMenuConfig
from core.validation.widgets.yasb.quick_launch import QuickLaunchConfig
from core.validation.widgets.yasb.systray import SystrayWidgetConfig
from core.validation.widgets.yasb.taskbar import TaskbarConfig
from core.validation.widgets.yasb.volume import VolumeConfig
from core.validation.widgets.yasb.wifi import WifiConfig


SCHEMAS = {
    "glazewm.binding_mode.GlazewmBindingModeWidget": GlazewmBindingModeConfig,
    "glazewm.tiling_direction.GlazewmTilingDirectionWidget": GlazewmTilingDirectionConfig,
    "glazewm.workspaces.GlazewmWorkspacesWidget": GlazewmWorkspacesConfig,
    "yasb.active_window.ActiveWindowWidget": ActiveWindowConfig,
    "yasb.applications.ApplicationsWidget": ApplicationsWidgetConfig,
    "yasb.battery.BatteryWidget": BatteryConfig,
    "yasb.bluetooth.BluetoothWidget": BluetoothConfig,
    "yasb.brightness.BrightnessWidget": BrightnessConfig,
    "yasb.clock.ClockWidget": ClockConfig,
    "yasb.control_center.ControlCenterWidget": ControlCenterConfig,
    "yasb.cpu.CpuWidget": CpuConfig,
    "yasb.custom.CustomWidget": CustomConfig,
    "yasb.dnd.DndWidget": DndConfig,
    "yasb.grouper.GrouperWidget": GrouperWidgetConfig,
    "yasb.memory.MemoryWidget": MemoryConfig,
    "yasb.microphone.MicrophoneWidget": MicrophoneConfig,
    "yasb.notifications.NotificationsWidget": NotificationsConfig,
    "yasb.power_menu.PowerMenuWidget": PowerMenuConfig,
    "yasb.quick_launch.QuickLaunchWidget": QuickLaunchConfig,
    "yasb.systray.SystrayWidget": SystrayWidgetConfig,
    "yasb.taskbar.TaskbarWidget": TaskbarConfig,
    "yasb.volume.VolumeWidget": VolumeConfig,
    "yasb.wifi.WifiWidget": WifiConfig,
}

WIDGET_SOURCE = {
    "glazewm.binding_mode.GlazewmBindingModeWidget": "core/widgets/glazewm/binding_mode.py",
    "yasb.active_window.ActiveWindowWidget": "core/widgets/yasb/active_window.py",
    "yasb.battery.BatteryWidget": "core/widgets/yasb/battery.py",
    "yasb.bluetooth.BluetoothWidget": "core/widgets/yasb/bluetooth.py",
    "yasb.brightness.BrightnessWidget": "core/widgets/yasb/brightness.py",
    "yasb.clock.ClockWidget": "core/widgets/yasb/clock.py",
    "yasb.control_center.ControlCenterWidget": "core/widgets/yasb/control_center.py",
    "yasb.cpu.CpuWidget": "core/widgets/yasb/cpu.py",
    "yasb.custom.CustomWidget": "core/widgets/yasb/custom.py",
    "yasb.dnd.DndWidget": "core/widgets/yasb/dnd.py",
    "yasb.memory.MemoryWidget": "core/widgets/yasb/memory.py",
    "yasb.microphone.MicrophoneWidget": "core/widgets/yasb/microphone.py",
    "yasb.notifications.NotificationsWidget": "core/widgets/yasb/notifications.py",
    "yasb.power_menu.PowerMenuWidget": "core/widgets/yasb/power_menu.py",
    "yasb.quick_launch.QuickLaunchWidget": "core/widgets/yasb/quick_launch.py",
    "yasb.taskbar.TaskbarWidget": "core/widgets/yasb/taskbar.py",
    "yasb.volume.VolumeWidget": "core/widgets/yasb/volume.py",
    "yasb.wifi.WifiWidget": "core/widgets/yasb/wifi.py",
}


def validate_without_deprecations(label: str, validator: Callable[[], Any]) -> Any:
    """Run upstream validation and reject options YASB only accepts as deprecated."""
    captured_out = io.StringIO()
    captured_err = io.StringIO()
    try:
        with redirect_stdout(captured_out), redirect_stderr(captured_err):
            result = validator()
    except Exception as exc:
        fail(f"{label} failed upstream validation:\n{exc}")

    diagnostics = captured_out.getvalue() + captured_err.getvalue()
    if "[DEPRECATED]" in diagnostics:
        fail(f"{label} uses deprecated upstream YASB configuration:\n{diagnostics.strip()}")
    return result


def registered_callbacks(source_path: Path) -> set[str]:
    """Extract literal self.register_callback("name", ...) registrations."""
    if not source_path.is_file():
        fail(f"upstream callback source not found: {source_path}")

    tree = ast.parse(source_path.read_text(encoding="utf-8"), filename=str(source_path))
    names: set[str] = set()
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call) or not node.args:
            continue
        func = node.func
        if not isinstance(func, ast.Attribute) or func.attr != "register_callback":
            continue
        first = node.args[0]
        if isinstance(first, ast.Constant) and isinstance(first.value, str):
            names.add(first.value)
    return names


def callback_actions(value: Any) -> list[str]:
    if isinstance(value, str):
        stripped = value.strip()
        return [stripped.split(None, 1)[0]] if stripped else []
    if isinstance(value, list):
        result: list[str] = []
        for item in value:
            result.extend(callback_actions(item))
        return result
    fail(f"callback value has unsupported shape: {value!r}")
    return []


with CONFIG_PATH.open("r", encoding="utf-8") as handle:
    raw = yaml.safe_load(handle)

if not isinstance(raw, dict):
    fail("config.yaml did not parse to a mapping")

# Root validation covers global options and every nested bar field.
validate_without_deprecations("root/bar configuration", lambda: YasbConfig(**raw))

widgets = raw.get("widgets")
if not isinstance(widgets, dict) or not widgets:
    fail("widgets mapping is missing or empty")

base_callbacks = registered_callbacks(yasb_src / "core" / "widgets" / "base.py")

for name, widget in widgets.items():
    if not isinstance(widget, dict):
        fail(f"widget {name!r} is not a mapping")

    widget_type = widget.get("type")
    options = widget.get("options", {})
    schema = SCHEMAS.get(widget_type)
    if schema is None:
        fail(f"widget {name!r} uses an unvalidated type: {widget_type!r}")

    if not isinstance(options, dict):
        fail(f"widget {name!r} options are not a mapping")

    validate_without_deprecations(
        f"widget {name!r} ({widget_type})",
        lambda schema=schema, options=options: schema(**options),
    )

    callbacks = options.get("callbacks")
    if callbacks is not None:
        if not isinstance(callbacks, dict):
            fail(f"widget {name!r} callbacks are not a mapping")
        source_rel = WIDGET_SOURCE.get(widget_type)
        if source_rel is None:
            fail(f"widget {name!r} declares callbacks but has no upstream callback-source mapping")

        allowed = base_callbacks | registered_callbacks(yasb_src / source_rel)
        for event_name, callback_value in callbacks.items():
            for action in callback_actions(callback_value):
                if action not in allowed:
                    fail(
                        f"widget {name!r} callback {event_name!r} uses unsupported action "
                        f"{action!r}; upstream registered callbacks: {sorted(allowed)}"
                    )

bars = raw.get("bars", {})
for bar_name, bar in bars.items():
    if not isinstance(bar, dict):
        fail(f"bar {bar_name!r} is not a mapping")
    for section in ("left", "center", "right"):
        for widget_name in bar.get("widgets", {}).get(section, []):
            if widget_name not in widgets:
                fail(f"bar {bar_name!r} references undefined widget {widget_name!r}")

for name, widget in widgets.items():
    if widget.get("type") != "yasb.grouper.GrouperWidget":
        continue
    for child in widget.get("options", {}).get("widgets", []):
        if child not in widgets:
            fail(f"grouper {name!r} references undefined child widget {child!r}")

# Exercise the actual upstream CSS processor with a temporary generated theme
# override. This proves the managed @import ordering resolves WGDot's live
# palette variables instead of merely checking that the text exists.
original_theme = THEME_PATH.read_bytes() if THEME_PATH.exists() else None
original_appearance = APPEARANCE_PATH.read_bytes() if APPEARANCE_PATH.exists() else None
try:
    THEME_PATH.write_text(
        ":root {\n"
        "  --background: #112233;\n"
        "  --foreground: #abcdef;\n"
        "}\n",
        encoding="utf-8",
    )
    APPEARANCE_PATH.write_text(
        "/* test WGDot appearance override */\n"
        ".taskbar-widget .app-container.running { background-color: var(--foreground); }\n",
        encoding="utf-8",
    )
    processor = CSSProcessor(str(STYLE_PATH))
    processed_css = processor.process()
    normalized_imports = {Path(path).resolve() for path in processor.imported_files}

    if THEME_PATH.resolve() not in normalized_imports:
        fail("upstream CSS processor did not register theme.css as an imported stylesheet")
    if APPEARANCE_PATH.resolve() not in normalized_imports:
        fail("upstream CSS processor did not register appearance.css as an imported stylesheet")
    if "#112233" not in processed_css or "#abcdef" not in processed_css:
        fail("generated theme.css variables did not override the fallback YASB palette")
    if ".taskbar-widget .app-container.running" not in processed_css:
        fail("generated appearance.css rules were not included by upstream CSS processing")
    if "var(--" in processed_css:
        fail("managed YASB stylesheet leaves unresolved CSS variables after upstream processing")
finally:
    if original_theme is None:
        THEME_PATH.unlink(missing_ok=True)
    else:
        THEME_PATH.write_bytes(original_theme)
    if original_appearance is None:
        APPEARANCE_PATH.unlink(missing_ok=True)
    else:
        APPEARANCE_PATH.write_bytes(original_appearance)

print(
    "YASB config/CSS validated against upstream schemas, deprecations, callbacks, "
    f"and CSS processing from {yasb_root}"
)
