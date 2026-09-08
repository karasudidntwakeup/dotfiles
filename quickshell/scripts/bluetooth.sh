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

mac=$(echo "$devices" | awk '{print $2}')

# Get battery percentage
battery=$(bluetoothctl info "$mac" 2>/dev/null | grep -i "battery percentage" | grep -oE '\(([0-9]+)\)' | tr -d '()')
if [ -n "$battery" ]; then
    echo "󰂱  $battery%"
else
    echo "󰂱"
fi
