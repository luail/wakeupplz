#!/bin/zsh
set -eu
if [[ $# -ne 1 ]]; then
  print -u2 'Usage: scripts/check-signing.sh /path/to/WakeUpPlz.app'
  exit 2
fi
profile="$1/embedded.mobileprovision"
if [[ ! -f "$profile" ]]; then
  print -u2 '실제 기기용 서명 프로필이 없습니다. 시뮬레이터 빌드로는 만료일을 확인할 수 없습니다.'
  exit 1
fi
task_plist=$(mktemp /tmp/wakeupplz-profile.XXXXXX)
trap 'rm -f "$task_plist"' EXIT
/usr/bin/security cms -D -i "$profile" > "$task_plist"
/usr/bin/plutil -extract ExpirationDate raw "$task_plist"
