#!/bin/sh
# Volume control helper. Targets the currently active output sink (the one
# producing sound), falling back to the default sink when nothing is playing.
#
# Usage: vol.sh get | up | down | set <delta> | mute

resolve_sink() {
    pactl list sink-inputs 2>/dev/null | awk '
        /^[[:space:]]*Sink: / { s = $2 }
        /^[[:space:]]*Corked: / { if ($2 == "no" && s != "") cnt[s]++ }
        END {
            best = ""; bestc = 0
            for (s in cnt) if (cnt[s] > bestc) { best = s; bestc = cnt[s] }
            if (bestc > 0) print best
        }
    '
}

SINK=$(resolve_sink)
[ -z "$SINK" ] && SINK="@DEFAULT_SINK@"

case "$1" in
    get)
        vol=$(pactl get-sink-volume "$SINK" 2>/dev/null | grep -oE '[0-9]+%' | head -1 | tr -d '%')
        [ -z "$vol" ] && vol=0
        mute=$(pactl get-sink-mute "$SINK" 2>/dev/null | awk '{print $2}')
        [ -z "$mute" ] && mute=no
        echo "$vol|$mute"
        ;;
    up)   pactl set-sink-volume "$SINK" "+10%" ;;
    down) pactl set-sink-volume "$SINK" "-10%" ;;
    set)  pactl set-sink-volume "$SINK" "$2" ;;
    mute) pactl set-sink-mute "$SINK" toggle ;;
esac