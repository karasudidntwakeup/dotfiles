#!/bin/sh

# Show bluetooth status (bluetoothctl), waybar-style

# Check if bluetooth is on
power=$(bluetoothctl show 2>/dev/null | grep "Powered:" | awk '{print $2}')
if [ "$power" != "yes" ]; then
    echo "󰂲 OFF"
    exit 0
fi

# Check for connected devices
devices=$(bluetoothctl devices Connected 2>/dev/null | head -1)
if [ -z "$devices" ]; then
    echo "󰂯 ON"
    exit 0
fi

name=$(echo "$devices" | awk '{$1=$2=""; print $0}' | sed 's/^ *//')
echo "󰂱  $name"
