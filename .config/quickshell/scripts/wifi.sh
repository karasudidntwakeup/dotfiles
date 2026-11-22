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

    # Sample the receive counter against the previous poll.
    rxnow="$(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null)"
    state_dir="${XDG_RUNTIME_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}}/quickshell"
    if [ -n "$rxnow" ] && (umask 077 && mkdir -p -- "$state_dir"); then
        statefile="$state_dir/wifi-down-$iface.state"
        now="$(date +%s)"
        old_time=''
        old_rx=''
        if [ -f "$statefile" ]; then
            read -r old_time old_rx < "$statefile" || :
        fi
        if [ "$now" -gt "${old_time:-0}" ] 2>/dev/null &&
           [ -n "$old_time" ] && [ "$rxnow" -ge "${old_rx:-0}" ] 2>/dev/null; then
            down=$(( (rxnow - old_rx) / (now - old_time) ))
        fi
        if sample="$(mktemp "$state_dir/.wifi-down-XXXXXXXX")"; then
            printf '%s %s\n' "$now" "$rxnow" > "$sample" &&
                mv -f -- "$sample" "$statefile" || rm -f -- "$sample"
        fi
    fi
fi

printf '{"connected":%s,"signal":"%s","down":%d,"ip":"%s"}\n' \
    "$connected" "$signal" "${down:-0}" "$ip"
