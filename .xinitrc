#!/bin/sh
xrandr --setprovideroutputsource NVIDIA-G0
xrandr --auto
xmodmap ~/.Xmodmap &
/usr/bin/wireplumber &
/usr/bin/pipewire &
/usr/bin/pipewire-pulse &
picom -f &
slstatus &
redshift &
xwallpaper --zoom ~/.config/wall.png
#while true; do
#        dwm >/dev/null 2>&1
#done
exec dbus-run-session dwm
