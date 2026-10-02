#!/usr/bin/env bash

set -u

PIDFILE="$HOME/.cache/quickshell/ytx-mpv.pid"

if [ -f "$PIDFILE" ]; then
    OLD=$(cat "$PIDFILE" 2>/dev/null)
    [ -n "$OLD" ] && kill "$OLD" 2>/dev/null
fi

mkdir -p "$(dirname "$PIDFILE")"
# 1080p low-CPU defaults: cap stream to panel resolution, prefer AVC for
# Intel HW decode, use cheap sync/scalers. Placed BEFORE "$@" so any
# explicit caller flags (e.g. --no-video audio mode) still win.
LOWCPU_ARGS=(
    "--ytdl-format=bv*[height<=1080][fps<=60][vcodec~='^(avc|h264)']+ba/bv*[height<=1080][fps<=60]+ba/b[height<=1080]/b"
    "--hwdec=auto-safe"
    "--vo=gpu-next"
    "--profile=fast"
    "--scale=mitchell" "--cscale=mitchell"
    "--video-sync=audio"
    "--deband=no"
)
setsid -f bash -c 'echo $$ > "$0"; exec mpv "$@"' "$PIDFILE" "${LOWCPU_ARGS[@]}" "$@"