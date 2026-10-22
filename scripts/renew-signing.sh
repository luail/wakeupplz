#!/bin/zsh
# Free Personal Team profiles last 7 days from creation and Xcode reuses a cached one,
# so a plain rebuild keeps the old expiry. Move the cached profile aside to force a new one,
# rebuild, then install to the connected iPhone.
set -eu
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
# Default to the first connected physical iPhone so no device ID lives in the repo.
device="${1:-$(xcrun devicectl list devices 2>/dev/null | grep 'physical' | grep 'connected' | grep -oE '[0-9A-F]{8}-[0-9A-F]{16}' | head -1)}"
[[ -n "$device" ]] || { print -u2 '연결된 iPhone이 없습니다. USB로 연결하거나 UDID를 인자로 넘겨주세요.'; exit 1; }
root="${0:A:h:h}"
profiles="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
backup="$root/.local/profile-backup/$(date +%Y%m%d-%H%M%S)"
app="$root/DerivedDataDevice/Build/Products/Debug-iphoneos/WakeUpPlz.app"

mkdir -p "$backup"
for profile in "$profiles"/*.mobileprovision(N); do
  if /usr/bin/security cms -D -i "$profile" 2>/dev/null | grep -q 'com.luail.WakeUpPlz'; then
    mv "$profile" "$backup/"
  fi
done

cd "$root"
xcodebuild -project WakeUpPlz.xcodeproj -scheme WakeUpPlz -destination 'generic/platform=iOS' \
  -derivedDataPath DerivedDataDevice -allowProvisioningUpdates build > "$backup/build.log" 2>&1 \
  || { print -u2 "빌드 실패: $backup/build.log"; exit 1; }
python3 scripts/check-app-bundle.py "$app"
print "새 만료일(UTC): $(scripts/check-signing.sh "$app")"
xcrun devicectl device install app --device "$device" "$app" > /dev/null
xcrun devicectl device info apps --device "$device" --bundle-id com.luail.WakeUpPlz | tail -1
