#!/bin/sh
xrandr --setprovideroutputsource NVIDIA-G0
xrandr --auto
picom --experimental-backend & 
xset r rate 220 50
setxkbmap -option caps:backspace
slstatus &
xwallpaper --zoom /home/karasu/github/dotfiles/CustomWallpapers/tg_image_2416214385.jpeg
#while true; do
#        dwm >/dev/null 2>&1
#done
 exec  dwm

