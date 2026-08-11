#!/bin/sh
# Scan for wifi networks via iwd (iwctl), machine-readable for the bar popup.
# Output:
#   line 1: #DEVICE <station name>
#   following lines: CONNECTED|KNOWN|SECURITY|SIGNAL|NAME
#     CONNECTED: 1 if this network is currently the connected one
#     KNOWN:     1 if the network has a saved profile in iwd
#     SECURITY:  open / psk / sae / ...
#     SIGNAL:    1-4 signal bars
#     NAME:      ssid (may contain spaces / unicode)

DEV=$(iwctl station list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | awk '
    $2 == "connected" { print $1; found = 1; exit }
    $2 == "disconnected" || $2 == "roaming" { if (!d) d = $1 }
    END { if (!found && d) print d }
')
[ -z "$DEV" ] && exit 0

iwctl station "$DEV" scan >/dev/null 2>&1

echo "#DEVICE $DEV"

knowns=$(mktemp)
iwctl known-networks list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | awk '
    NR == 3 {
        sec = index($0, "Security")
        if (sec == 0) exit
    }
    NR > 3 && NF {
        name = substr($0, 3, sec - 3 - 2)
        gsub(/^ +| +$/, "", name)
        if (name != "") print name
    }
' > "$knowns"

iwctl station "$DEV" get-networks 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | awk -v file="$knowns" '
    BEGIN {
        while ((getline kn < file) > 0) known[kn] = 1
        close(file)
    }
    NR == 3 {
        sec = index($0, "Security")
        sig = index($0, "Signal")
        if (sec == 0 || sig == 0) exit
    }
    NR > 3 && NF {
        connected = 0
        if (substr($0, 3, 1) == ">") connected = 1
        name = substr($0, 5, sec - 5 - 2)
        gsub(/^ +| +$/, "", name)
        if (name == "") next
        if (name ~ /^-+$/) next
        security = substr($0, sec, sig - sec)
        gsub(/^ +| +$/, "", security)
        signal = substr($0, sig)
        gsub(/^ +| +$/, "", signal)
        bars = 0
        n = length(signal)
        for (i = 1; i <= n; i++) if (substr(signal, i, 1) == "*") bars++
        if (bars < 1) bars = 1
        isknown = (name in known) ? 1 : 0
        printf "%d|%d|%s|%d|%s\n", connected, isknown, security, bars, name
    }
'

rm -f "$knowns"
