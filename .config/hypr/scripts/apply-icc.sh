#!/bin/bash
DEVICE="/org/freedesktop/ColorManager/devices/xrandr_eDP_1_karasu_1000"
PROFILE_URI=$(colormgr get-profiles | awk '/DisplayP3Compat-v2-magic.icc/{f=NR-1} NR==f{print $3}')

colormgr device-add-profile "$DEVICE" "$PROFILE_PATH"
PROFILE_URI=$(colormgr get-profiles | awk -v p="$PROFILE_PATH" 'BEGIN{RS="";FS="\n"} $0~p{ for(i=1;i<=NF;i++) if($i ~ /^Object Path:/) {print $i; break}}' | awk '{print $3}')
[ -n "$PROFILE_URI" ] && colormgr device-make-profile-default "$DEVICE" "$PROFILE_URI"

