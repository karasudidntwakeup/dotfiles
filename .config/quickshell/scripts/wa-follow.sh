#!/usr/bin/env bash
# Keep one live-sync + webhook notifier running (flock-guarded against
# duplicates from niri restarts). See wa-notify.py for notifications.
export PATH="$PATH:$HOME/go/bin"

LOCK="$HOME/.cache/quickshell/wa-follow.lock"
mkdir -p "$HOME/.cache/quickshell"
exec 9>"$LOCK"
flock -n 9 || exit 0

exec wacli sync --follow \
    --webhook "http://127.0.0.1:51828/" \
    --webhook-allow-private