#!/bin/sh
# outputs JSON: connected SSID, signal, IP, and download speed for the bar pill.
# (An older revision also listed visible networks; nothing consumed it.)

iface="$(iwctl station list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | awk '/connected/ && !/disconnected/ { print $1; exit }')"
[ -z "$iface" ] && iface="$(iwctl station list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | awk '/disconnected/ { print $1; exit }')"
[ -z "$iface" ] && iface="wlan0"

status="$(iwctl station "$iface" show 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')"
ssid="$(echo "$status" | awk '/Connected network/ { for (i=3;i<=NF;i++) printf (i>3?" ":"") $i }')"
state="$(echo "$status" | awk '/State/ { print $NF; exit }')"

signal=""
ip=""
down=""
connected="false"
if [ "$state" = "connected" ]; then
    connected="true"
    rssi="$(echo "$status" | awk '/RSSI/ && !/Average/ { print $(NF-1); exit }')"
    if [ -n "$rssi" ]; then
        signal=$(( (100 + rssi) * 100 / 60 ))
        [ "$signal" -gt 100 ] && signal=100
        [ "$signal" -lt 0 ] && signal=0
    fi
    ip="$(ip -4 addr show "$iface" 2>/dev/null | awk '/inet / { print $2; exit }' | cut -d/ -f1)"

    # download speed (bytes/sec) sampled from rx counter between polls
    rxnow="$(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null)"
    if [ -n "$rxnow" ] && [ "$rxnow" -gt 0 ] 2>/dev/null; then
        statefile="/tmp/wifi-down-${iface}.state"
        old="$(cat "$statefile" 2>/dev/null)"
        now="$(date +%s)"
        echo "$now $rxnow" > "$statefile"
        if [ -n "$old" ]; then
            set -- $old
            [ "$now" -gt "$1" ] && {
                drx=$(( rxnow - $2 ))
                [ "$drx" -lt 0 ] && drx=0
                down=$(( drx / (now - "$1") ))
            }
        fi
    fi
fi

printf '{"connected":%s,"iface":"%s","ssid":"%s","signal":"%s","down":%d,"ip":"%s","networks":[]}' \
    "$connected" "${iface:-}" "$ssid" "$signal" "${down:-0}" "$ip"
