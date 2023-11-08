#!/bin/sh
sleep 1
xrandr --setprovideroutputsource modesetting NVIDIA-0
xrandr --auto
nitrogen --restore &
numlockx &
picom  -b &
setxkbmap -layout us,ara -option grp:ctrl_space_toggle &
setxkbmap -option numpad:mac
xsetroot -cursor_name left_ptr
slstatus &
exec dbus-run-session dwm
