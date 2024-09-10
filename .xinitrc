#!/bin/sh
xrandr --setprovideroutputsource NVIDIA-G0
xrandr --auto
xmodmap ~/.Xmodmap
/usr/bin/pipewire &
/usr/bin/pipewire-pulse &
picom -f &
slstatus &
redshift &
xwallpaper --zoom /home/karasu/github//github/dotfiles/CustomWallpapers/white/b.png
/usr/bin/wireplumber &
xset r rate 220 50
while true; do
        dwm >/dev/null 2>&1
done
exec dbus-run-session dwm
