#!/usr/bin/env bash

set -u

PIDFILE="$HOME/.cache/quickshell/ytx-mpv.pid"

if [ -f "$PIDFILE" ]; then
    OLD=$(cat "$PIDFILE" 2>/dev/null)
    [ -n "$OLD" ] && kill "$OLD" 2>/dev/null
fi

mkdir -p "$(dirname "$PIDFILE")"
setsid -f bash -c 'echo $$ > "$0"; exec mpv "$@"' "$PIDFILE" "$@"