#!/bin/sh
# Emit mounted disk info for QuickShell widget.
# Output format: each line is "MOUNT_POINT|USED_PCT|FREE_GB|TOTAL_GB"
# Skip tmpfs, devtmpfs, and other virtual filesystems.
df -h -P -B1G 2>/dev/null | tail -n +2 | awk '{
    mount = $NF
    # Skip virtual/pseudo filesystems
    if (mount ~ /^\/(run|dev|sys|proc|tmp|snap|boot\/efi)/) next
    if ($1 ~ /^tmpfs/ || $1 ~ /^devtmpfs/ || $1 ~ /^none/) next
    
    total = $2
    used = $3
    free = $4
    pct = $5
    gsub(/%/, "", pct)
    
    # Convert to GB with 1 decimal
    total_gb = sprintf("%.1f", total)
    free_gb = sprintf("%.1f", free)
    
    printf "%s|%s|%s|%s\n", mount, pct, free_gb, total_gb
}'