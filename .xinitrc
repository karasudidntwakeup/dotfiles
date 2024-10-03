#!/bin/sh
xrandr --setprovideroutputsource NVIDIA-G0
xmodmap ~/.Xmodmap &
/usr/bin/wireplumber &
/usr/bin/pipewire &
/usr/bin/pipewire-pulse &
picom -f &
slstatus &
redshift &
xwallpaper --zoom /home/karasu/github//github/dotfiles/CustomWallpapers/white/b.png
xset r rate 220 50
#while true; do
#        dwm >/dev/null 2>&1
#done
exec dbus-run-session dwm
