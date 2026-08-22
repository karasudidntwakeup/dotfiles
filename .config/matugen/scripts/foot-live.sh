#!/bin/sh
# Push generated foot colors into already-running terminals via OSC.
# New windows read foot.ini as usual; this only live-patches existing ones.

ini="$HOME/.config/foot/foot.ini"
[ -r "$ini" ] || exit 0

get() { grep -E "^$1=" "$ini" | head -1 | cut -d= -f2-; }

pal=""
i=0
for key in regular0 regular1 regular2 regular3 regular4 regular5 regular6 regular7 \
           bright0 bright1 bright2 bright3 bright4 bright5 bright6 bright7; do
    c=$(get "$key")
    if [ -n "$c" ]; then
        pal="$pal$i;#$c;"
    fi
    i=$((i + 1))
done
# trim trailing separator
pal=${pal%;}

fg=$(get foreground)
bg=$(get background)
cur=$(get cursor)

osc="\033]4;${pal}\033\\\\\033]10;#${fg}\033\\\\\033]11;#${bg}\033\\\\"
[ -n "$cur" ] && osc="$osc\033]12;#${cur%% *}\033\\\\"

for pts in /dev/pts/*; do
    [ -w "$pts" ] || continue
    printf '%b' "$osc" > "$pts" 2>/dev/null || :
done

exit 0
