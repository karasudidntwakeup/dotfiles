#!/bin/sh
xrandr --setprovideroutputsource NVIDIA-G0
xrandr --auto
setxkbmap -option caps:backspace
picom -f &
slstatus &
xwallpaper --zoom /home/karasu/github//github/dotfiles/CustomWallpapers/test41.png
xset r rate 220 50
#while true; do
#        dwm >/dev/null 2>&1
#done
exec dbus-run-session dwm
