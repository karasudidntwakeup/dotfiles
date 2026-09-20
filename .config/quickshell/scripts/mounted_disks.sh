#!/bin/sh
# Emit mounted disk info for QuickShell widget.
# Output format: each line is "MOUNT_POINT|USED_PCT|FREE_GB|TOTAL_GB"
# Skip tmpfs, devtmpfs, and other virtual filesystems.
# Root / is skipped (already covered by the Disk tile).
df -h -P -B1M 2>/dev/null | tail -n +2 | awk '{
    mount = $NF
    # Skip virtual/pseudo filesystems
    if (mount ~ /^\/(run|dev|sys|proc|tmp|snap|boot)/) next
    if (mount == "/") next
    if ($1 ~ /^tmpfs/ || $1 ~ /^devtmpfs/ || $1 ~ /^none/) next

    total = $2
    used = $3
    free = $4
    pct = $5
    gsub(/%/, "", pct)

    # Convert MB to GB with 1 decimal
    total_gb = sprintf("%.1f", total / 1024)
    free_gb = sprintf("%.1f", free / 1024)

    printf "%s|%s|%s|%s\n", mount, pct, free_gb, total_gb
}'
