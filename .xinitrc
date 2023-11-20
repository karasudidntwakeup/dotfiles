#!/bin/sh
sleep 1
xrandr --setprovideroutputsource modesetting NVIDIA-0
dbus-update-activation-environment --systemd DBUS_SESSION_BUS_ADDRESS DISPLAY XAUTHORITY &
xrandr --auto
dwmpywal &
nitrogen --restore &
slstatus &
numlockx &
setxkbmap -layout us,ara -option grp:ctrl_space_toggle,numpad:mac &
picom --experimental-backend --animations --animation-for-open-window slide-up -b &
xsetroot -cursor_name left_ptr
while true; do
        dwm >/dev/null 2>&1
done
 exec dbus-run-session dwm

