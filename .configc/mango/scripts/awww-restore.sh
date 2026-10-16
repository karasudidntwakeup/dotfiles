#!/usr/bin/env bash
# Restores last quickshell wallpaper via awww.
# Extracted from autostart.conf: mango values are limited to 255 bytes
# (mango -p fails otherwise), so this long command must live in a script.
pkill -x awww-daemon 2>/dev/null
awww-daemon &
for i in $(seq 1 40); do
  awww query >/dev/null 2>&1 && break
  sleep 0.25
done
IMG=$(cat ~/.cache/quickshell/wallpaper/current.txt 2>/dev/null)
[ -f "$IMG" ] && exec awww img "$IMG" --transition-type none
