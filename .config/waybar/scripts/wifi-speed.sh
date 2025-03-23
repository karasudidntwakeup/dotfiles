#!/bin/bash

# WiFi interface name (replace with your actual interface, e.g., wlp2s0)
INTERFACE="wlan0"

# Read previous RX value from a temporary file
TMP_FILE="/tmp/wifi-speed-stats"
if [[ -f "$TMP_FILE" ]]; then
  source "$TMP_FILE"
else
  RX_PREV=0
fi

# Get current RX bytes
RX_CURR=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)

# Calculate difference
RX_DIFF=$((RX_CURR - RX_PREV))

# Save current RX value for next run
echo "RX_PREV=$RX_CURR" > "$TMP_FILE"

# Convert to human-readable format (KB/s)
RX_SPEED=$(echo "scale=1; $RX_DIFF / 1024 / 5" | bc)

# Output JSON for Waybar
echo "{\"text\": \"↓${RX_SPEED}KB/s\", \"tooltip\": \"Download: ${RX_SPEED}KB/s\"}"
