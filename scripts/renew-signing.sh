#!/bin/zsh
# Free Personal Team profiles last 7 days from creation and Xcode reuses a cached one,
# so a plain rebuild keeps the old expiry. Move the cached profile aside to force a new one,
# rebuild, then install to the iPhone (USB or same Wi-Fi).
set -eu
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
root="${0:A:h:h}"
state="$root/.local"
mkdir -p "$state"
# Device: argument > last device used (kept in .local, not in the repo) > first connected iPhone.
device="${1:-$(cat "$state/device" 2>/dev/null || true)}"
[[ -n "$device" ]] || device="$(xcrun devicectl list devices 2>/dev/null | grep 'physical' | grep -oE '[0-9A-F]{8}-[0-9A-F]{16}' | head -1)"
[[ -n "$device" ]] || { print -u2 '연결된 iPhone이 없습니다. USB로 연결하거나 UDID를 인자로 넘겨주세요.'; exit 1; }
profiles="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
backup="$state/profile-backup/$(date +%Y%m%d-%H%M%S)"
app="$root/DerivedDataDevice/Build/Products/Debug-iphoneos/WakeUpPlz.app"

# Fail before touching the profile if the phone is unreachable.
xcrun devicectl device info details --device "$device" > /dev/null 2>&1 \
  || { print -u2 'iPhone에 연결할 수 없습니다. USB 연결 또는 Mac과 같은 Wi-Fi, 잠금 해제 상태를 확인하세요.'; exit 2; }

mkdir -p "$backup"
for profile in "$profiles"/*.mobileprovision(N); do
  if /usr/bin/security cms -D -i "$profile" 2>/dev/null | grep -q 'com.luail.WakeUpPlz'; then
    mv "$profile" "$backup/"
  fi
done

cd "$root"
if ! xcodebuild -project WakeUpPlz.xcodeproj -scheme WakeUpPlz -destination 'generic/platform=iOS' \
  -derivedDataPath DerivedDataDevice -allowProvisioningUpdates build > "$backup/build.log" 2>&1; then
  mv "$backup"/*.mobileprovision(N) "$profiles/" 2>/dev/null || true
  print -u2 "빌드 실패(Xcode의 Apple 계정 로그인 만료 가능): $backup/build.log"
  exit 3
fi
python3 scripts/check-app-bundle.py "$app"
expiry="$(scripts/check-signing.sh "$app")"
xcrun devicectl device install app --device "$device" "$app" > /dev/null \
  || { print -u2 'iPhone 설치 실패. 잠금 해제 후 다시 시도하세요.'; exit 4; }
print "$device" > "$state/device"
print "$expiry" > "$state/installed-expiry"
print "설치 완료. 새 만료일(UTC): $expiry"
