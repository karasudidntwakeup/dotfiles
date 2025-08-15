#!/bin/sh
xrandr --auto
xmodmap ~/.Xmodmap &
#slstatus &
mpd&
mpc ls|mpc add & 
mpdn.sh &
#redshift &
xwallpaper --zoom ~/.config/wall.png
#while true; do
 #       dwm >/dev/null 2>&1
#done
exec dbus-run-session dwm
