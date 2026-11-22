#!/bin/sh
# Emit used GiB and percent in a single pass over meminfo.
awk '
    /^MemTotal:/ { total = $2 }
    /^MemAvailable:/ { available = $2 }
    END {
        if (total <= 0) exit 1
        used = total - available
        printf "%.1f|%d\n", used / 1048576, used * 100 / total
    }
' /proc/meminfo
