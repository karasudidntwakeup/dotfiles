#!/usr/bin/env bash
# Supervisor for the WhatsApp follow-sync + notifier.
#
# Exactly one sync runs at a time (blocking flock). The sync is restarted
# whenever it exits AND periodically (every 3h), because a long-lived stream
# can silently stall; on reconnect wacli replays the offline backlog, so a
# restart self-heals any gaps in delivered notifications.
export PATH="$PATH:$HOME/go/bin"

LOCK="$HOME/.cache/quickshell/wa-follow.lock"
mkdir -p "$HOME/.cache/quickshell"
exec 9>"$LOCK"

LOG="$HOME/.cache/quickshell/wa-follow-watch.log"
ts() { date +"%F %T"; }

if [ -f "$LOG" ] && [ "$(wc -c <"$LOG")" -gt 262144 ]; then
  tail -n 400 "$LOG" >"$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi

flock 9

# Record the current session bus so the long-lived notifier can drop a stale
# address (its env bus dies whenever the session restarts; the process being
# long-lived then fails to reach the notification daemon).
if printenv DBUS_SESSION_BUS_ADDRESS >/dev/null 2>&1; then
  echo "DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS" \
    >"$HOME/.cache/quickshell/wa-session.env"
fi

# Restart the notifier so it inherits this session's environment.
pkill -f '[w]a-notify\.py' 2>/dev/null || true
setsid -f python3 "$HOME/.config/quickshell/scripts/wa-notify.py" \
  </dev/null >/dev/null 2>&1

setsid -f python3 "$HOME/.config/quickshell/scripts/wa-notify.py" \
  </dev/null >/dev/null 2>&1

while true; do
  echo "$(ts) sync start" >>"$LOG"
  timeout 10800 wacli sync --follow \
    --webhook "http://127.0.0.1:51828/" \
    --webhook-allow-private >>"$LOG" 2>&1
  rc=$?
  echo "$(ts) sync exited rc=$rc" >>"$LOG"
  sleep 5
done