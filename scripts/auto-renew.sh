#!/bin/zsh
# Run periodically by launchd (scripts/install-auto-renew.sh). Renews only when the installed
# app's signing expires within RENEW_HOURS, and reports the outcome as a macOS notification.
set -u
root="${0:A:h:h}"
state="$root/.local"
log="$state/auto-renew.log"
renew_hours="${RENEW_HOURS:-72}"
mkdir -p "$state"
notify() { /usr/bin/osascript -e "display notification \"$1\" with title \"WakeUpPlz 서명 갱신\"" > /dev/null 2>&1 || true; }

expiry="$(cat "$state/installed-expiry" 2>/dev/null || true)"
if [[ -n "$expiry" ]]; then
  expiry_epoch="$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$expiry" +%s 2>/dev/null || print 0)"
  hours_left=$(( (expiry_epoch - $(date +%s)) / 3600 ))
  (( hours_left > renew_hours )) && exit 0
else
  hours_left=0
fi

print "[$(date '+%F %T')] 갱신 시도 (남은 시간 ${hours_left}h)" >> "$log"
if output="$("$root/scripts/renew-signing.sh" 2>&1)"; then
  print "$output" >> "$log"
  notify "갱신 완료 · ${output##*: } (UTC) 까지"
else
  print "$output" >> "$log"
  # Retry quietly on the next run; only interrupt when expiry is close.
  (( hours_left <= 24 )) && notify "갱신 실패 · ${hours_left}시간 남음. iPhone을 Mac에 연결하거나 같은 Wi-Fi에서 잠금 해제해주세요."
  exit 1
fi
