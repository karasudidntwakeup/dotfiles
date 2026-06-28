#!/bin/bash

INTERFACE="wlan0"
TMP_FILE="/tmp/wifi-speed-stats"

# load previous value
if [[ -f "$TMP_FILE" ]]; then
  source "$TMP_FILE"
else
  RX_PREV=0
fi

RX_CURR=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)
RX_DIFF=$((RX_CURR - RX_PREV))

# save current value for next run
echo "RX_PREV=$RX_CURR" > "$TMP_FILE"

# calculate speed in KB/s
RX_KB=$((RX_DIFF / 1024 / 5))

# switch to MB/s if > 1024 KB
if [ "$RX_KB" -ge 1024 ]; then
    RX_SPEED=$((RX_KB / 1024))
    UNIT="MB/s"
else
    RX_SPEED=$RX_KB
    UNIT="KB/s"
fi

# output icon + number + unit
echo "↓ ${RX_SPEED} ${UNIT}"

