#!/usr/bin/env python3
"""Validate the managed YASB config against a checked-out upstream YASB schema.

Usage:
    python tests/test-yasb-config.py <yasb-source-root>

The workflow checks out the current stable YASB release and supplies its root.
This deliberately validates against upstream Pydantic models instead of keeping
an approximate copy of YASB's schema in win-glaze-dots.
"""

from __future__ import annotations

import sys
from pathlib import Path

import yaml


REPO_ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = REPO_ROOT / "UserProfile" / ".config" / "yasb" / "config.yaml"


def fail(message: str) -> None:
    raise SystemExit(f"YASB CONFIG TEST FAILED: {message}")


if len(sys.argv) != 2:
    fail("expected one argument: path to an upstream YASB checkout")

yasb_root = Path(sys.argv[1]).resolve()
yasb_src = yasb_root / "src"
if not yasb_src.is_dir():
    fail(f"YASB src directory not found: {yasb_src}")

sys.path.insert(0, str(yasb_src))

from core.validation.config import YasbConfig
from core.validation.widgets.glazewm.binding_mode import GlazewmBindingModeConfig
from core.validation.widgets.glazewm.workspaces import GlazewmWorkspacesConfig
from core.validation.widgets.yasb.active_window import ActiveWindowConfig
from core.validation.widgets.yasb.applications import ApplicationsWidgetConfig
from core.validation.widgets.yasb.battery import BatteryConfig
from core.validation.widgets.yasb.bluetooth import BluetoothConfig
from core.validation.widgets.yasb.brightness import BrightnessConfig
from core.validation.widgets.yasb.clock import ClockConfig
from core.validation.widgets.yasb.cpu import CpuConfig
from core.validation.widgets.yasb.grouper import GrouperWidgetConfig
from core.validation.widgets.yasb.memory import MemoryConfig
from core.validation.widgets.yasb.microphone import MicrophoneConfig
from core.validation.widgets.yasb.notifications import NotificationsConfig
from core.validation.widgets.yasb.power_menu import PowerMenuConfig
from core.validation.widgets.yasb.systray import SystrayWidgetConfig
from core.validation.widgets.yasb.taskbar import TaskbarConfig
from core.validation.widgets.yasb.volume import VolumeConfig
from core.validation.widgets.yasb.wifi import WifiConfig


SCHEMAS = {
    "glazewm.binding_mode.GlazewmBindingModeWidget": GlazewmBindingModeConfig,
    "glazewm.workspaces.GlazewmWorkspacesWidget": GlazewmWorkspacesConfig,
    "yasb.active_window.ActiveWindowWidget": ActiveWindowConfig,
    "yasb.applications.ApplicationsWidget": ApplicationsWidgetConfig,
    "yasb.battery.BatteryWidget": BatteryConfig,
    "yasb.bluetooth.BluetoothWidget": BluetoothConfig,
    "yasb.brightness.BrightnessWidget": BrightnessConfig,
    "yasb.clock.ClockWidget": ClockConfig,
    "yasb.cpu.CpuWidget": CpuConfig,
    "yasb.grouper.GrouperWidget": GrouperWidgetConfig,
    "yasb.memory.MemoryWidget": MemoryConfig,
    "yasb.microphone.MicrophoneWidget": MicrophoneConfig,
    "yasb.notifications.NotificationsWidget": NotificationsConfig,
    "yasb.power_menu.PowerMenuWidget": PowerMenuConfig,
    "yasb.systray.SystrayWidget": SystrayWidgetConfig,
    "yasb.taskbar.TaskbarWidget": TaskbarConfig,
    "yasb.volume.VolumeWidget": VolumeConfig,
    "yasb.wifi.WifiWidget": WifiConfig,
}


with CONFIG_PATH.open("r", encoding="utf-8") as handle:
    raw = yaml.safe_load(handle)

if not isinstance(raw, dict):
    fail("config.yaml did not parse to a mapping")

# Validates root options and every bar option, including nested bar fields.
YasbConfig(**raw)

widgets = raw.get("widgets")
if not isinstance(widgets, dict) or not widgets:
    fail("widgets mapping is missing or empty")

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

    try:
        schema(**options)
    except Exception as exc:
        fail(f"widget {name!r} ({widget_type}) failed upstream validation:\n{exc}")

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

print(f"YASB config validated against upstream schemas from {yasb_root}")
