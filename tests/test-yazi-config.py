from pathlib import Path
import tomllib

ROOT = Path(__file__).resolve().parents[1]
YAZI = ROOT / "UserProfile" / "AppData" / "Roaming" / "yazi" / "config"

files = sorted(YAZI.rglob("*.toml"))
if not files:
    raise SystemExit("No managed Yazi TOML files found")

for path in files:
    with path.open("rb") as handle:
        tomllib.load(handle)

print(f"Yazi TOML validation passed for {len(files)} file(s).")
