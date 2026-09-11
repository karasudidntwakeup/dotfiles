#!/bin/sh
# Emit "USED_MB|PERCENT" for the QuickShell memory pill.
TOTAL=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
AVAIL=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
USED=$(( (TOTAL - AVAIL) / 1024 ))
PERCENT=$(( (TOTAL - AVAIL) * 100 / TOTAL ))

echo "${USED}|${PERCENT}"