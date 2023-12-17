#!/bin/sh
xrandr --setprovideroutputsource modesetting NVIDIA-0
xrandr --output eDP1 --mode 1920x1080 --rate 60
xrdb -merge ~/.Xresources
picom --experimental-backend  & 
xset r rate 220 50
setxkbmap -option caps:backspace
slstatus &
dbus-update-activation-environment --systemd DBUS_SESSION_BUS_ADDRESS DISPLAY XAUTHORITY &
#feh --bg-fill "$(< "${HOME}/.cache/wal/wal")" &
nitrogen --restore &
#while true; do
#        dwm >/dev/null 2>&1
#done
 exec dbus-run-session dwm

