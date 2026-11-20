#!/bin/sh
# Resolve the interface and local source address the kernel selects for
# an external destination. Route lookup does not send any packets.
route_source() {
    ip "$1" route get "$2" 2>/dev/null | awk '
        NR == 1 {
            for (i = 1; i < NF; i++) {
                if ($i == "dev") iface = $(i + 1)
                if ($i == "src") address = $(i + 1)
            }
            if (iface != "" && iface != "lo" && address != "")
                print iface, address
        }
    '
}

route="$(route_source -4 1.1.1.1)"
[ -n "$route" ] || route="$(route_source -6 2606:4700:4700::1111)"
read -r iface ip <<EOF
$route
EOF

signal=""
down=""
connected="false"
if [ -n "$ip" ]; then
    connected="true"
    if [ -d "/sys/class/net/$iface/wireless" ] || [ -e "/sys/class/net/$iface/phy80211" ]; then
        status="$(iwctl station "$iface" show 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')"
        rssi="$(printf '%s\n' "$status" | awk '/RSSI/ && !/Average/ { print $(NF-1); exit }')"
        if [ -n "$rssi" ]; then
            signal=$(( (100 + rssi) * 100 / 60 ))
            [ "$signal" -gt 100 ] && signal=100
            [ "$signal" -lt 0 ] && signal=0
        fi
    else
        signal=100
    fi

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

printf '{"connected":%s,"signal":"%s","down":%d,"ip":"%s"}\n' \
    "$connected" "$signal" "${down:-0}" "$ip"
