#!/bin/sh
xrandr --setprovideroutputsource NVIDIA-G0
xrandr --auto
xset r rate 220 50
setxkbmap -option caps:backspace
picom --experimental-backend --animations --animation-for-open-window slide-up -b &
slstatus &
xwallpaper --zoom /home/karasu/github/dotfiles/CustomWallpapers/test41.png
while true; do
        dwm >/dev/null 2>&1
done
exec dbus-run-session dwm
