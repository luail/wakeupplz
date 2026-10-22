#!/bin/zsh
# Install (or with --uninstall, remove) the launchd agent that runs auto-renew.sh every 3 hours.
set -eu
root="${0:A:h:h}"
label="com.luail.wakeupplz.auto-renew"
plist="$HOME/Library/LaunchAgents/$label.plist"
launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
if [[ "${1:-}" == "--uninstall" ]]; then
  rm -f "$plist"; print "자동 갱신을 제거했습니다."; exit 0
fi
mkdir -p "$HOME/Library/LaunchAgents" "$root/.local"
cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key><array><string>/bin/zsh</string><string>$root/scripts/auto-renew.sh</string></array>
  <key>StartInterval</key><integer>10800</integer>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>$root/.local/launchd.log</string>
  <key>StandardErrorPath</key><string>$root/.local/launchd.log</string>
</dict>
</plist>
EOF
launchctl bootstrap "gui/$(id -u)" "$plist"
print "자동 갱신 설치 완료: 3시간마다 확인, 만료 3일 전부터 갱신 시도."
