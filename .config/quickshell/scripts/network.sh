#!/bin/sh

# Show the connected wifi network (iwd), waybar-style
OUT=$(iwctl station list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -E '[a-zA-Z0-9]+ +connected' | awk '{print $1}' | head -1)

if [ -z "$OUT" ]; then
    echo "󰖪  "
    exit 0
fi

NET=$(iwctl station "$OUT" show 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -i "connected network" | awk '{print $NF}')

if [ -z "$NET" ]; then
    echo "󰖪  "
    exit 0
fi

echo "󰖩   $NET"
