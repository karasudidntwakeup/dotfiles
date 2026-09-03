#!/bin/sh
# outputs JSON: connected SSID, signal, IP, and network list (with security)
# arg: "scan" = trigger a fresh scan first; otherwise just list cached results fast

iface="$(iwctl station list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | awk '/connected|disconnected/ { print $1; exit }')"
[ -z "$iface" ] && iface="wlan0"
[ "${2:-}" = "scan" ] && iwctl station "$iface" scan 2>/dev/null

status="$(iwctl station "$iface" show 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g')"
ssid="$(echo "$status" | awk '/Connected network/ { for (i=3;i<=NF;i++) printf (i>3?" ":"") $i }')"
state="$(echo "$status" | awk '/State/ { print $NF; exit }')"

signal=""
ip=""
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
fi

# known (saved) SSIDs, one per line, names may contain spaces
known="$(iwctl known-networks list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | tail -n +5 | head -n -1 \
    | awk '{ for (i=1;i<=NF;i++){ if ($i=="psk"||$i=="open") break; printf (i>1?" ":"") $i } print "" }')"

nl='
'
networks=""
[ -n "$known" ] && known="$known$nl"
nets="$(iwctl station "$iface" get-networks 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | tail -n +5 | head -n -1)"
if [ -n "$nets" ]; then
    networks="$(echo "$nets" | awk -v k="$known" '
        function knownOf(n,   a,i,c) { c=split(k,a,"\n"); for (i=1;i<=c;i++) if (a[i]==n) return "true"; return "false" }
        function nameOf(f,   out,first,i) { out=""; first=0; for (i=f;i<=NF-2;i++){ if ($i==">") continue; if (first) out=out " "; out=out $i; first=1 } return out }
        {
            nm=nameOf(1);
            if (nm=="") next;
            sec=$(NF-1); if (sec=="") sec="open";
            l=length($NF); sig=(l>=4?100:(l==3?75:(l==2?50:(l==1?25:0))));
            gsub(/\\/,"\\\\",nm); gsub(/"/,"\\\"",nm);
            printf "%s{\"name\":\"%s\",\"sig\":%d,\"sec\":\"%s\",\"known\":%s}", (first++?",":""), nm, sig, sec, knownOf(nm);
        }')"
fi

printf '{"connected":%s,"iface":"%s","ssid":"%s","signal":"%s","ip":"%s","networks":[%s]}' \
    "$connected" "${iface:-}" "$ssid" "$signal" "$ip" "$networks"
