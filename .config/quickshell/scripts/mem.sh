#!/bin/sh
# Emit "USED_GB|PERCENT" for the QuickShell memory pill/widget.
TOTAL=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
AVAIL=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
USED_KB=$(( TOTAL - AVAIL ))
USED_GB=$(awk -v u="$USED_KB" 'BEGIN { printf "%.1f", u / 1024 / 1024 }')
PERCENT=$(( USED_KB * 100 / TOTAL ))

echo "${USED_GB}|${PERCENT}"