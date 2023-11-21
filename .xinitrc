#!/bin/sh
xrandr --setprovideroutputsource modesetting NVIDIA-0
xrandr --output eDP1 --mode 1920x1080 --rate 60
xrandr --dpi 80
xset r rate 220 50
setxkbmap -option caps:backspace
dbus-update-activation-environment --systemd DBUS_SESSION_BUS_ADDRESS DISPLAY XAUTHORITY &
nitrogen --restore &
slstatus &
numlockx &
setxkbmap -layout us,ara -option grp:ctrl_space_toggle,numpad:mac &
picom --experimental-backend --animations --animation-for-open-window slide-up -b &
#while true; do
#        dwm >/dev/null 2>&1
#done
 exec dbus-run-session dwm

