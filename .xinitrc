#!/bin/sh
sleep 1
xrandr --setprovideroutputsource modesetting NVIDIA-0
dbus-update-activation-environment --systemd DBUS_SESSION_BUS_ADDRESS DISPLAY XAUTHORITY &
xrandr --auto
slstatus &
nitrogen --restore &
numlockx &
picom --experimental-backend --animations --animation-for-open-window fly-in -b &
setxkbmap -layout us,ara -option grp:ctrl_space_toggle,numpad:mac &
xsetroot -cursor_name left_ptr
while true; do
        dwm >/dev/null 2>&1
done
 exec dbus-run-session dwm

