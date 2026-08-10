#!/bin/sh

vol=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -oE '[0-9]+%' | head -1 | tr -d '%')
[ -z "$vol" ] && vol=0
mute=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print $2}')
[ -z "$mute" ] && mute=no
echo "$vol|$mute"
