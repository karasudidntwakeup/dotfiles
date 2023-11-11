#!/bin/sh
sleep 1
xrandr --setprovideroutputsource modesetting NVIDIA-0
xrandr --auto
slstatus &
nitrogen --restore &
numlockx &
picom  -b &
setxkbmap -layout us,ara -option grp:ctrl_space_toggle,numpad:mac &
xsetroot -cursor_name left_ptr
#while true; do
 #        dwm >/dev/null 2>&1
 #done
 exec dbus-run-session dwm

