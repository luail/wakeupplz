"""Check runtime prerequisites in the built product, not just build settings."""
from pathlib import Path
import plistlib
import sys

if len(sys.argv) != 2:
    raise SystemExit("Usage: python3 scripts/check-app-bundle.py /path/to/WakeUpPlz.app")
app = Path(sys.argv[1])
with (app / "Info.plist").open("rb") as source:
    info = plistlib.load(source)
description = info.get("NSAlarmKitUsageDescription", "")
if not isinstance(description, str) or not description.strip():
    raise SystemExit("FAIL: AlarmKit permission description missing from built Info.plist")
for name in ("Morning Bell.wav", "Soft Chime.wav", "Classic Alarm.wav"):
    if not (app / name).is_file():
        raise SystemExit(f"FAIL: bundled alarm sound missing: {name}")
if not (app / "Assets.car").is_file():
    raise SystemExit("FAIL: compiled assets missing")
print(f"PASS: build {info.get('CFBundleVersion')}; AlarmKit permission, sounds, compiled assets")
