#!/bin/sh
# Emit "USED_PCT|FREE_GB|TOTAL_GB" for the QuickShell disk widget (root filesystem).
OUT=$(df -P -BG / 2>/dev/null | tail -1)
PCT=$(echo "$OUT" | awk '{print $(NF-1)}' | tr -d '%')
FREE_GB=$(echo "$OUT" | awk '{print $(NF-2)}' | tr -d 'G')
TOTAL_GB=$(echo "$OUT" | awk '{print $(NF-4)}' | tr -d 'G')
[ -z "$PCT" ] && PCT=0
[ -z "$FREE_GB" ] && FREE_GB=0
[ -z "$TOTAL_GB" ] && TOTAL_GB=0

echo "${PCT}|${FREE_GB}|${TOTAL_GB}"
