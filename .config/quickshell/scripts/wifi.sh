#!/bin/sh
# outputs JSON: connected SSID, signal, IP, and network list (with security)
# arg: "scan" = trigger a fresh scan first; otherwise just list cached results fast
strip_ansi() { sed 's/\x1b\[[0-9;]*m//g'; }
iface="${1:-$(iwctl station list 2>/dev/null | strip_ansi | awk '/connected|disconnected/ { print $1 }' | head -1)}"
[ -z "$iface" ] && iface="wlan0"
[ "${2:-}" = "scan" ] && iwctl station "$iface" scan 2>/dev/null

status=$(iwctl station "$iface" show 2>/dev/null | strip_ansi)
ssid=$(echo "$status" | awk '/Connected network/ { $1=""; $2=""; print substr($0,3) }' | sed 's/^[[:space:]]*//')
state=$(echo "$status" | awk '/State/ { print $NF }')

signal=""
ip=""
connected="false"
if [ "$state" = "connected" ]; then
    connected="true"
    rssi=$(echo "$status" | awk '/RSSI/ && !/Average/ { print $(NF-1) }' | head -1)
    if [ -n "$rssi" ]; then
        signal=$(( (100 + rssi) * 100 / 60 ))
        [ "$signal" -gt 100 ] && signal=100
        [ "$signal" -lt 0 ] && signal=0
    fi
    ip=$(ip -4 addr show "$iface" 2>/dev/null | awk '/inet / { print $2 }' | cut -d/ -f1 | head -1)
fi

networks=""
# known (saved) SSIDs
known=""
iwctl known-networks list 2>/dev/null | strip_ansi | tail -n +5 | head -n -1 | while IFS= read -r kline; do
    kne=$(echo "$kline" | awk '{ for(i=1;i<=NF;i++){ if ($i=="psk"||$i=="open") break; printf (i>1?" ":"") $i } }')
    [ -z "$kne" ] && continue
    printf '%s\n' "$kne"
done > /tmp/qs_known_wifi
nets=$(iwctl station "$iface" get-networks 2>/dev/null | strip_ansi | tail -n +5 | head -n -1)
while IFS= read -r line; do
    [ -z "$line" ] && continue
    name=$(echo "$line" | awk '{ for(i=1;i<=NF-2;i++) printf (i>1?" ":"") $i }' | sed 's/^[[:space:]]*>//' | sed 's/^[[:space:]]*//')
    sec=$(echo "$line" | awk '{ print $(NF-1) }')
    sig=$(echo "$line" | awk '{ print length($NF) }')
    [ -z "$name" ] && continue
    case "$sig" in
        1) nsig=25;; 2) nsig=50;; 3) nsig=75;; 4) nsig=100;; *) nsig=0;;
    esac
    isknown="false"
    while IFS= read -r kne; do
        [ "$kne" = "$name" ] && isknown="true" && break
    done < /tmp/qs_known_wifi
    name=$(echo "$name" | sed 's/\\/\\\\/g; s/"/\\"/g')
    [ -n "$networks" ] && networks="$networks,"
    networks="$networks{\"name\":\"$name\",\"sig\":$nsig,\"sec\":\"${sec:-open}\",\"known\":$isknown}"
done <<EOF
$nets
EOF
rm -f /tmp/qs_known_wifi

printf '{"connected":%s,"iface":"%s","ssid":"%s","signal":"%s","ip":"%s","networks":[%s]}' \
    "$connected" "${iface:-}" "${ssid:-}" "${signal:-}" "${ip:-}" "$networks"