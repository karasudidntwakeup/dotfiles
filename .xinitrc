#!/bin/sh
xrandr --setprovideroutputsource NVIDIA-G0
xrandr --auto
xmodmap ~/.Xmodmap &
/usr/bin/wireplumber &
/usr/bin/pipewire &
/usr/bin/pipewire-pulse &
picom -f &
slstatus &
redshift &
xwallpaper --zoom github/github/dotfiles/CustomWallpapers/white/b.png
#while true; do
#        dwm >/dev/null 2>&1
#done
exec dbus-run-session dwm
